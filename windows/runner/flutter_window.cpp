#include "flutter_window.h"

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/plugin_registrar_windows.h>
#include "audio_device_plugin.h"

namespace {

UINT ParseHotkeyModifiers(const std::string& combo) {
  UINT mods = 0;
  if (combo.find("Ctrl+") != std::string::npos) mods |= MOD_CONTROL;
  if (combo.find("Alt+") != std::string::npos) mods |= MOD_ALT;
  if (combo.find("Shift+") != std::string::npos) mods |= MOD_SHIFT;
  return mods;
}

UINT ParseHotkeyVkey(const std::string& combo) {
  const auto pos = combo.rfind('+');
  std::string key = (pos == std::string::npos) ? combo : combo.substr(pos + 1);

  if (key.size() == 1) {
    const char c = key[0];
    if (c >= 'A' && c <= 'Z') return static_cast<UINT>(c);
    if (c >= '0' && c <= '9') return static_cast<UINT>(c);
  }

  // Function keys: F1..F24
  if (key.size() >= 2 && (key[0] == 'F' || key[0] == 'f')) {
    int n = 0;
    try {
      n = std::stoi(key.substr(1));
    } catch (...) {
      n = 0;
    }
    if (n >= 1 && n <= 24) {
      return VK_F1 + (n - 1);
    }
  }

  // Common named keys
  if (key == "SPACE" || key == "Space") return VK_SPACE;
  if (key == "ENTER" || key == "Enter") return VK_RETURN;
  if (key == "TAB" || key == "Tab") return VK_TAB;
  if (key == "ESC" || key == "Esc" || key == "Escape") return VK_ESCAPE;

  return 0;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  AudioDevicePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(
              flutter_controller_->engine()->GetRegistrarForPlugin(
                  "AudioDevicePlugin")));

  hotkey_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "global_hotkey_channel",
      &flutter::StandardMethodCodec::GetInstance());

  hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();

        if (method == "registerHotkey") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("BAD_ARGS", "Expected map");
            return;
          }

          auto id_it = args->find(flutter::EncodableValue("id"));
          auto combo_it = args->find(flutter::EncodableValue("combo"));
          if (id_it == args->end() || combo_it == args->end()) {
            result->Error("BAD_ARGS", "Missing id/combo");
            return;
          }

          const int id = std::get<int32_t>(id_it->second);
          const std::string combo = std::get<std::string>(combo_it->second);

          const UINT mods = ParseHotkeyModifiers(combo) | MOD_NOREPEAT;
          const UINT vkey = ParseHotkeyVkey(combo);
          if (vkey == 0) {
            result->Error("BAD_ARGS", "Unsupported key");
            return;
          }

          if (::RegisterHotKey(GetHandle(), id, mods, vkey)) {
            registered_hotkey_ids_.insert(id);
            result->Success(flutter::EncodableValue(true));
          } else {
            result->Success(flutter::EncodableValue(false));
          }
          return;
        }

        if (method == "unregisterHotkey") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("BAD_ARGS", "Expected map");
            return;
          }
          auto id_it = args->find(flutter::EncodableValue("id"));
          if (id_it == args->end()) {
            result->Error("BAD_ARGS", "Missing id");
            return;
          }
          const int id = std::get<int32_t>(id_it->second);
          ::UnregisterHotKey(GetHandle(), id);
          registered_hotkey_ids_.erase(id);
          result->Success();
          return;
        }

        if (method == "unregisterAll") {
          for (int id : registered_hotkey_ids_) {
            ::UnregisterHotKey(GetHandle(), id);
          }
          registered_hotkey_ids_.clear();
          result->Success();
          return;
        }

        result->NotImplemented();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  for (int id : registered_hotkey_ids_) {
    ::UnregisterHotKey(GetHandle(), id);
  }
  registered_hotkey_ids_.clear();
  hotkey_channel_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_HOTKEY: {
      if (hotkey_channel_) {
        flutter::EncodableMap args;
        args[flutter::EncodableValue("id")] =
            flutter::EncodableValue(static_cast<int32_t>(wparam));
        hotkey_channel_->InvokeMethod("onHotkey",
                                      std::make_unique<flutter::EncodableValue>(args));
      }
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
