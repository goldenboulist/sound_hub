#include "audio_device_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

// Windows Core Audio & Media Foundation headers
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <functiondiscoverykeys_devpkey.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#include <wrl/client.h>

#include <codecvt>
#include <locale>
#include <map>
#include <stdexcept>
#include <string>
#include <algorithm>
#include <thread>
#include <vector>

using Microsoft::WRL::ComPtr;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static std::wstring Utf8ToWide(const std::string& str) {
    if (str.empty()) return {};
    int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
    std::wstring result(size - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, result.data(), size);
    return result;
}

static AudioDevice GetDeviceInfo(IMMDevice* device) {
    AudioDevice d;
    if (!device) return d;

    LPWSTR id = nullptr;
    if (SUCCEEDED(device->GetId(&id)) && id) {
        d.id = id;
        CoTaskMemFree(id);
    }

    ComPtr<IPropertyStore> props;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &props)) && props) {
        PROPVARIANT friendlyName;
        PropVariantInit(&friendlyName);
        if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &friendlyName))) {
            d.name = friendlyName.pwszVal ? std::wstring(friendlyName.pwszVal) : L"";
        }
        PropVariantClear(&friendlyName);
    }

    return d;
}

static std::string WideToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string result(size - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, result.data(), size, nullptr, nullptr);
    return result;
}

// ---------------------------------------------------------------------------
// Plugin registration
// ---------------------------------------------------------------------------

// static
void AudioDevicePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(),
        "audio_device_channel",
        &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<AudioDevicePlugin>();

    channel->SetMethodCallHandler(
        [plugin_ptr = plugin.get()](const auto& call, auto result) {
            plugin_ptr->HandleMethodCall(call, std::move(result));
        });

    plugin->channel_ = std::move(channel);
    registrar->AddPlugin(std::move(plugin));
}

AudioDevicePlugin::AudioDevicePlugin() {}

AudioDevicePlugin::~AudioDevicePlugin() {
    StopPlayback();
}

// ---------------------------------------------------------------------------
// Method call handler
// ---------------------------------------------------------------------------

void AudioDevicePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    const std::string& method = method_call.method_name();

    if (method == "getAudioDevices") {
        // Returns: List<Map<String,String>> with keys "id" and "name"
        auto devices = EnumerateDevices();

        flutter::EncodableList device_list;
        for (const auto& d : devices) {
            flutter::EncodableMap entry;
            entry[flutter::EncodableValue("id")]   = flutter::EncodableValue(WideToUtf8(d.id));
            entry[flutter::EncodableValue("name")] = flutter::EncodableValue(WideToUtf8(d.name));
            device_list.push_back(flutter::EncodableValue(entry));
        }
        result->Success(flutter::EncodableValue(device_list));

    } else if (method == "getCurrentDevice") {
        const HRESULT coinit_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

        ComPtr<IMMDeviceEnumerator> enumerator;
        HRESULT hr = CoCreateInstance(
            __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
            IID_PPV_ARGS(&enumerator));
        if (FAILED(hr)) {
            if (SUCCEEDED(coinit_hr)) {
                CoUninitialize();
            }
            result->Error("NATIVE_ERROR", "Failed to create device enumerator");
            return;
        }

        ComPtr<IMMDevice> device;
        if (!selected_device_id_.empty()) {
            hr = enumerator->GetDevice(selected_device_id_.c_str(), &device);
        }
        if (!device) {
            enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
        }

        AudioDevice info = GetDeviceInfo(device.Get());
        flutter::EncodableMap entry;
        entry[flutter::EncodableValue("id")] = flutter::EncodableValue(WideToUtf8(info.id));
        entry[flutter::EncodableValue("name")] = flutter::EncodableValue(WideToUtf8(info.name));
        result->Success(flutter::EncodableValue(entry));

        if (SUCCEEDED(coinit_hr)) {
            CoUninitialize();
        }

    } else if (method == "playAudioOnDevice") {
        const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!args) { result->Error("BAD_ARGS", "Expected a map argument"); return; }

        auto file_it   = args->find(flutter::EncodableValue("filePath"));
        auto device_it = args->find(flutter::EncodableValue("deviceId"));
        auto secondary_device_it = args->find(flutter::EncodableValue("secondaryDeviceId"));
        auto volume_it = args->find(flutter::EncodableValue("volume"));

        if (file_it == args->end()) { result->Error("BAD_ARGS", "Missing filePath"); return; }

        std::wstring filePath = Utf8ToWide(std::get<std::string>(file_it->second));
        std::wstring deviceId;
        if (device_it != args->end() && std::holds_alternative<std::string>(device_it->second)) {
            deviceId = Utf8ToWide(std::get<std::string>(device_it->second));
        }

        std::wstring secondaryDeviceId;
        if (secondary_device_it != args->end() &&
            std::holds_alternative<std::string>(secondary_device_it->second)) {
            secondaryDeviceId = Utf8ToWide(std::get<std::string>(secondary_device_it->second));
        }

        float volume = desired_volume_.load();
        if (volume_it != args->end()) {
            if (std::holds_alternative<double>(volume_it->second)) {
                volume = static_cast<float>(std::get<double>(volume_it->second));
            } else if (std::holds_alternative<int32_t>(volume_it->second)) {
                volume = static_cast<float>(std::get<int32_t>(volume_it->second));
            }
        }
        if (volume < 0.0f) volume = 0.0f;
        if (volume > 1.0f) volume = 1.0f;
        desired_volume_.store(volume);

        if (deviceId.empty() && !selected_device_id_.empty()) {
            deviceId = selected_device_id_;
        }

        PlayOnDevice(filePath, deviceId, secondaryDeviceId, volume);
        result->Success();

    } else if (method == "setVolume") {
        const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!args) { result->Error("BAD_ARGS", "Expected a map argument"); return; }

        auto volume_it = args->find(flutter::EncodableValue("volume"));
        if (volume_it == args->end()) { result->Error("BAD_ARGS", "Missing volume"); return; }

        float volume = desired_volume_.load();
        if (std::holds_alternative<double>(volume_it->second)) {
            volume = static_cast<float>(std::get<double>(volume_it->second));
        } else if (std::holds_alternative<int32_t>(volume_it->second)) {
            volume = static_cast<float>(std::get<int32_t>(volume_it->second));
        } else {
            result->Error("BAD_ARGS", "volume must be a number");
            return;
        }
        if (volume < 0.0f) volume = 0.0f;
        if (volume > 1.0f) volume = 1.0f;
        desired_volume_.store(volume);
        result->Success();

    } else if (method == "stopAudio") {
        StopPlayback();
        result->Success();

    } else if (method == "setDefaultDevice") {
        const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!args) { result->Error("BAD_ARGS", "Expected a map argument"); return; }

        auto device_it = args->find(flutter::EncodableValue("deviceId"));
        if (device_it == args->end()) { result->Error("BAD_ARGS", "Missing deviceId"); return; }

        selected_device_id_ = Utf8ToWide(std::get<std::string>(device_it->second));
        result->Success();

    } else {
        result->NotImplemented();
    }
}

// ---------------------------------------------------------------------------
// Enumerate audio render endpoints via IMMDeviceEnumerator
// ---------------------------------------------------------------------------

std::vector<AudioDevice> AudioDevicePlugin::EnumerateDevices() {
    std::vector<AudioDevice> devices;

    const HRESULT coinit_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    ComPtr<IMMDeviceEnumerator> enumerator;
    HRESULT hr = CoCreateInstance(
        __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
        IID_PPV_ARGS(&enumerator));
    if (FAILED(hr)) {
        if (SUCCEEDED(coinit_hr)) {
            CoUninitialize();
        }
        return devices;
    }

    // --- Default device first ---
    ComPtr<IMMDevice> defaultDevice;
    if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &defaultDevice))) {
        LPWSTR id = nullptr;
        defaultDevice->GetId(&id);

        ComPtr<IPropertyStore> props;
        defaultDevice->OpenPropertyStore(STGM_READ, &props);

        PROPVARIANT friendlyName;
        PropVariantInit(&friendlyName);
        props->GetValue(PKEY_Device_FriendlyName, &friendlyName);

        AudioDevice d;
        d.id   = id ? std::wstring(id) : L"";
        d.name = std::wstring(friendlyName.pwszVal ? friendlyName.pwszVal : L"Default Device") 
                 + L" (Default)";
        devices.push_back(std::move(d));

        PropVariantClear(&friendlyName);
        CoTaskMemFree(id);
    }

    // --- All active render endpoints ---
    ComPtr<IMMDeviceCollection> collection;
    hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
    if (FAILED(hr)) {
        if (SUCCEEDED(coinit_hr)) {
            CoUninitialize();
        }
        return devices;
    }

    UINT count = 0;
    collection->GetCount(&count);

    for (UINT i = 0; i < count; i++) {
        ComPtr<IMMDevice> device;
        if (FAILED(collection->Item(i, &device))) continue;

        LPWSTR id = nullptr;
        device->GetId(&id);

        // Skip if same as default (already added above)
        bool isDefault = false;
        if (!devices.empty() && id && devices[0].id == id) {
            isDefault = true;
        }

        ComPtr<IPropertyStore> props;
        device->OpenPropertyStore(STGM_READ, &props);

        PROPVARIANT friendlyName;
        PropVariantInit(&friendlyName);
        props->GetValue(PKEY_Device_FriendlyName, &friendlyName);

        if (!isDefault) {
            AudioDevice d;
            d.id   = id ? std::wstring(id) : L"";
            d.name = friendlyName.pwszVal ? std::wstring(friendlyName.pwszVal) : L"Unknown Device";
            devices.push_back(std::move(d));
        }

        PropVariantClear(&friendlyName);
        CoTaskMemFree(id);
    }

    if (SUCCEEDED(coinit_hr)) {
        CoUninitialize();
    }

    return devices;
}

// ---------------------------------------------------------------------------
// WASAPI + Media Foundation playback on a specific device
// ---------------------------------------------------------------------------

void AudioDevicePlugin::StopPlayback() {
    stop_playback_ = true;
    stop_secondary_playback_ = true;

    {
        std::lock_guard<std::mutex> lock(playback_mutex_);
        if (active_reader_) {
            // Unblock ReadSample for some formats/streams.
            active_reader_->Flush(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM));
        }
        if (active_audio_client_) {
            // Best-effort stop; ignore failures.
            active_audio_client_->Stop();
        }

        if (active_secondary_reader_) {
            active_secondary_reader_->Flush(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM));
        }
        if (active_secondary_audio_client_) {
            active_secondary_audio_client_->Stop();
        }
    }

    if (playback_thread_.joinable()) {
        playback_thread_.join();
    }

    if (secondary_playback_thread_.joinable()) {
        secondary_playback_thread_.join();
    }

    stop_playback_ = false;
    stop_secondary_playback_ = false;

    {
        std::lock_guard<std::mutex> lock(playback_mutex_);
        active_reader_.Reset();
        active_audio_client_.Reset();

        active_secondary_reader_.Reset();
        active_secondary_audio_client_.Reset();
    }
}

void AudioDevicePlugin::PlayOnDeviceInternal(
    const std::wstring& filePath,
    const std::wstring& deviceId,
    float volume,
    std::atomic<bool>& stop_flag,
    std::thread& thread,
    Microsoft::WRL::ComPtr<IMFSourceReader>& active_reader,
    Microsoft::WRL::ComPtr<IAudioClient>& active_audio_client) {

    // Stop any existing playback on this output thread.
    stop_flag = true;
    {
        std::lock_guard<std::mutex> lock(playback_mutex_);
        if (active_reader) {
            active_reader->Flush(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM));
        }
        if (active_audio_client) {
            active_audio_client->Stop();
        }
    }
    if (thread.joinable()) {
        thread.join();
    }
    stop_flag = false;

    thread = std::thread([this, filePath, deviceId, volume, &stop_flag, &active_reader, &active_audio_client]() {
        CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        MFStartup(MF_VERSION);

        auto cleanup = [&]() {
            MFShutdown();
            CoUninitialize();
        };

        // 1. Resolve the audio device to render to
        ComPtr<IMMDeviceEnumerator> enumerator;
        HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                      IID_PPV_ARGS(&enumerator));
        if (FAILED(hr)) { cleanup(); return; }

        ComPtr<IMMDevice> device;
        if (deviceId.empty()) {
            enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
        } else {
            hr = enumerator->GetDevice(deviceId.c_str(), &device);
            if (FAILED(hr)) {
                // Fallback to default
                enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
            }
        }
        if (!device) { cleanup(); return; }

        // We keep a session volume interface to apply volume updates during playback.
        ComPtr<IAudioSessionManager2> sessionManager;
        ComPtr<ISimpleAudioVolume> simpleVolume;
        if (SUCCEEDED(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr,
                                       reinterpret_cast<void**>(sessionManager.GetAddressOf()))) &&
            sessionManager) {
            // Event context can be nullptr; we just use it to set volume on the session.
            sessionManager->GetSimpleAudioVolume(nullptr, 0, &simpleVolume);
        }

        // 2. Create and configure IAudioClient
        ComPtr<IAudioClient> audioClient;
        hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                               reinterpret_cast<void**>(audioClient.GetAddressOf()));
        if (FAILED(hr)) { cleanup(); return; }

        // 3. Create Media Foundation source reader to decode the audio file
        ComPtr<IMFSourceReader> reader;
        hr = MFCreateSourceReaderFromURL(filePath.c_str(), nullptr, &reader);
        if (FAILED(hr)) { cleanup(); return; }

        // Select only first audio stream
        reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
        reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), TRUE);

        // Request PCM output
        ComPtr<IMFMediaType> pcmType;
        MFCreateMediaType(&pcmType);
        pcmType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
        pcmType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
        reader->SetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), nullptr, pcmType.Get());

        // Get resulting media type (has sample rate / channels / bit depth)
        ComPtr<IMFMediaType> actualType;
        reader->GetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), &actualType);

        WAVEFORMATEX* wfx = nullptr;
        UINT32 wfxSize = 0;
        hr = MFCreateWaveFormatExFromMFMediaType(actualType.Get(), &wfx, &wfxSize);
        if (FAILED(hr)) { cleanup(); return; }

        // 4. Initialise WASAPI in shared mode
        REFERENCE_TIME bufferDuration = 30000000LL; // 3 seconds in 100-ns units
        hr = audioClient->Initialize(AUDCLNT_SHAREMODE_SHARED, 0,
                                     bufferDuration, 0, wfx, nullptr);

        // If format is not supported, try to get the mix format and resample
        if (hr == AUDCLNT_E_UNSUPPORTED_FORMAT) {
            WAVEFORMATEX* mixFormat = nullptr;
            audioClient->GetMixFormat(&mixFormat);

            // Re-create source reader requesting the mix format's sample rate / channels
            ComPtr<IMFMediaType> newType;
            MFCreateMediaType(&newType);
            newType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
            newType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
            newType->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, mixFormat->nChannels);
            newType->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, mixFormat->nSamplesPerSec);
            newType->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, mixFormat->nBlockAlign);
            newType->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, mixFormat->nAvgBytesPerSec);
            newType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, mixFormat->wBitsPerSample);
            reader->SetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), nullptr, newType.Get());

            CoTaskMemFree(wfx);
            wfx = nullptr;
            reader->GetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM), &actualType);
            MFCreateWaveFormatExFromMFMediaType(actualType.Get(), &wfx, &wfxSize);

            hr = audioClient->Initialize(AUDCLNT_SHAREMODE_SHARED, 0,
                                         bufferDuration, 0, wfx, nullptr);
            CoTaskMemFree(mixFormat);
        }

        if (FAILED(hr)) {
            CoTaskMemFree(wfx);
            cleanup();
            return;
        }

        UINT32 bufferFrameCount = 0;
        audioClient->GetBufferSize(&bufferFrameCount);

        ComPtr<IAudioRenderClient> renderClient;
        audioClient->GetService(__uuidof(IAudioRenderClient),
                                reinterpret_cast<void**>(renderClient.GetAddressOf()));

        {
            std::lock_guard<std::mutex> lock(playback_mutex_);
            active_reader = reader;
            active_audio_client = audioClient;
        }

        audioClient->Start();

        if (simpleVolume) {
            simpleVolume->SetMasterVolume(volume, nullptr);
        }

        // 5. Decode → render loop
        bool reached_end_of_stream = false;
        while (!stop_flag) {
            DWORD streamFlags = 0;
            ComPtr<IMFSample> sample;
            hr = reader->ReadSample(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM),
                                    0, nullptr, &streamFlags, nullptr, &sample);

            if (FAILED(hr)) break;

            // MF can report END_OF_STREAM *and* still return a final sample.
            if (streamFlags & MF_SOURCE_READERF_ENDOFSTREAM) {
                reached_end_of_stream = true;
            }
            if (!sample) {
                if (reached_end_of_stream) break;
                continue;
            }

            ComPtr<IMFMediaBuffer> buffer;
            sample->ConvertToContiguousBuffer(&buffer);

            BYTE* audioData = nullptr;
            DWORD dataLength = 0;
            buffer->Lock(&audioData, nullptr, &dataLength);

            UINT32 framesToWrite = dataLength / wfx->nBlockAlign;
            UINT32 offset = 0;

            while (framesToWrite > 0 && !stop_flag) {
                if (simpleVolume) {
                    simpleVolume->SetMasterVolume(desired_volume_.load(), nullptr);
                }
                UINT32 padding = 0;
                audioClient->GetCurrentPadding(&padding);
                UINT32 framesAvailable = bufferFrameCount - padding;
                UINT32 framesNow = std::min(framesAvailable, framesToWrite);

                if (framesNow > 0) {
                    BYTE* dest = nullptr;
                    if (SUCCEEDED(renderClient->GetBuffer(framesNow, &dest))) {
                        memcpy(dest, audioData + offset, framesNow * wfx->nBlockAlign);
                        renderClient->ReleaseBuffer(framesNow, 0);
                    }
                    offset += framesNow * wfx->nBlockAlign;
                    framesToWrite -= framesNow;
                } else {
                    Sleep(1);
                }
            }

            buffer->Unlock();

            if (reached_end_of_stream) {
                break;
            }
        }

        // Drain the buffer before stopping so we don't cut off the tail.
        if (!stop_flag) {
            const ULONGLONG start = GetTickCount64();
            while (true) {
                UINT32 padding = 0;
                if (FAILED(audioClient->GetCurrentPadding(&padding))) break;
                if (padding == 0) break;
                if (GetTickCount64() - start > 3000) break;
                Sleep(10);
            }
        }
        audioClient->Stop();

        {
            std::lock_guard<std::mutex> lock(playback_mutex_);
            active_reader.Reset();
            active_audio_client.Reset();
        }

        CoTaskMemFree(wfx);
        cleanup();
    });
}

void AudioDevicePlugin::PlayOnDevice(const std::wstring& filePath,
                                     const std::wstring& deviceId,
                                     const std::wstring& secondaryDeviceId,
                                     float volume) {
    PlayOnDeviceInternal(filePath, deviceId, volume,
                         stop_playback_, playback_thread_,
                         active_reader_, active_audio_client_);

    // Secondary output is optional. If empty, stop it.
    if (secondaryDeviceId.empty()) {
        stop_secondary_playback_ = true;
        {
            std::lock_guard<std::mutex> lock(playback_mutex_);
            if (active_secondary_reader_) {
                active_secondary_reader_->Flush(static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM));
            }
            if (active_secondary_audio_client_) {
                active_secondary_audio_client_->Stop();
            }
        }
        if (secondary_playback_thread_.joinable()) {
            secondary_playback_thread_.join();
        }
        stop_secondary_playback_ = false;
        {
            std::lock_guard<std::mutex> lock(playback_mutex_);
            active_secondary_reader_.Reset();
            active_secondary_audio_client_.Reset();
        }
        return;
    }

    PlayOnDeviceInternal(filePath, secondaryDeviceId, volume,
                         stop_secondary_playback_, secondary_playback_thread_,
                         active_secondary_reader_, active_secondary_audio_client_);
}
