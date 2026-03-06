#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>
#include <thread>
#include <atomic>
#include <mutex>

#include <wrl/client.h>

struct IMFSourceReader;
struct IAudioClient;

struct AudioDevice {
    std::wstring id;
    std::wstring name;
};

class AudioDevicePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  AudioDevicePlugin();
  virtual ~AudioDevicePlugin();

  // Disallow copy and move.
  AudioDevicePlugin(const AudioDevicePlugin&) = delete;
  AudioDevicePlugin& operator=(const AudioDevicePlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::vector<AudioDevice> EnumerateDevices();
  void PlayOnDeviceInternal(const std::wstring& filePath,
                            const std::wstring& deviceId,
                            float volume,
                            std::atomic<bool>& stop_flag,
                            std::thread& thread,
                            Microsoft::WRL::ComPtr<IMFSourceReader>& active_reader,
                            Microsoft::WRL::ComPtr<IAudioClient>& active_audio_client);
  void PlayOnDevice(const std::wstring& filePath,
                    const std::wstring& deviceId,
                    const std::wstring& secondaryDeviceId,
                    float volume);
  void StopPlayback();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::wstring selected_device_id_;

  std::thread playback_thread_;
  std::atomic<bool> stop_playback_{false};
  std::thread secondary_playback_thread_;
  std::atomic<bool> stop_secondary_playback_{false};

  std::atomic<float> desired_volume_{1.0f};

  std::mutex playback_mutex_;
  Microsoft::WRL::ComPtr<IMFSourceReader> active_reader_;
  Microsoft::WRL::ComPtr<IAudioClient> active_audio_client_;

  Microsoft::WRL::ComPtr<IMFSourceReader> active_secondary_reader_;
  Microsoft::WRL::ComPtr<IAudioClient> active_secondary_audio_client_;
};
