import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_audio_output/flutter_audio_output.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

export 'package:flutter_audio_output/flutter_audio_output.dart'
    show AudioInput, AudioPort;

class AudioService {
  static final AudioService _instance = AudioService._();
  AudioService._() {
    _initHotkeys();
  }
  static AudioService get instance => _instance;

  static const MethodChannel _windowsChannel = MethodChannel('audio_device_channel');
  static const MethodChannel _hotkeyChannel = MethodChannel('global_hotkey_channel');

  final StreamController<int> _hotkeyEventsCtrl = StreamController<int>.broadcast();
  Stream<int> get hotkeyEvents => _hotkeyEventsCtrl.stream;

  final Map<String, AudioPlayer> _players = {};
  bool _allowMultiple = false;
  AudioInput? _currentDevice;

  String? _selectedWindowsDeviceId;
  String? _selectedWindowsSecondaryDeviceId;

  bool get allowMultiple => _allowMultiple;
  AudioInput? get currentDevice => _currentDevice;

  void setAllowMultiple(bool value) => _allowMultiple = value;

  bool get _isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  void _initHotkeys() {
    if (!_isWindows) return;
    _hotkeyChannel.setMethodCallHandler((call) async {
      if (call.method == 'onHotkey') {
        final args = call.arguments;
        if (args is Map) {
          final id = args['id'];
          if (id is int) {
            _hotkeyEventsCtrl.add(id);
          }
        }
      }
    });
  }

  Future<bool> registerGlobalHotkey({required int id, required String combo}) async {
    if (!_isWindows) return false;
    try {
      final ok = await _hotkeyChannel.invokeMethod<bool>('registerHotkey', {
        'id': id,
        'combo': combo,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> unregisterAllGlobalHotkeys() async {
    if (!_isWindows) return;
    try {
      await _hotkeyChannel.invokeMethod('unregisterAll');
    } on PlatformException {
      return;
    }
  }

  // ─── Mirrors VideoSDK.getAudioDevices() ─────────────────────────────────────

  /// Returns all available audio output devices.
  Future<List<AudioInput>> getAudioDevices() async {
    if (_isWindows) {
      final List<dynamic> raw =
          (await _windowsChannel.invokeMethod<List<dynamic>>('getAudioDevices')) ??
              const <dynamic>[];

      return raw
          .whereType<Map>()
          .map((m) => AudioInput(
                (m['name'] as String?) ?? 'Unknown Device',
                AudioPort.speaker.index,
              ))
          .toList(growable: false);
    }
    return await FlutterAudioOutput.getAvailableInputs();
  }

  /// Returns the currently active audio output device.
  Future<AudioInput> getCurrentOutput() async {
    if (_isWindows) {
      final Map<dynamic, dynamic>? raw =
          await _windowsChannel.invokeMethod<Map<dynamic, dynamic>>(
              'getCurrentDevice');

      final name = (raw?['name'] as String?) ?? 'Default Device';
      final id = (raw?['id'] as String?) ?? '';
      _selectedWindowsDeviceId = id.isEmpty ? null : id;

      return AudioInput(
        name,
        AudioPort.speaker.index,
      );
    }
    return await FlutterAudioOutput.getCurrentOutput();
  }

  /// Listen to hardware audio device changes (e.g. headphones plugged in).
  /// Mirrors: VideoSDK device-change event listener
  void setListener(void Function() onChanged) {
    FlutterAudioOutput.setListener(onChanged);
  }

  void removeListener() {
    FlutterAudioOutput.removeListener();
  }

  // ─── Mirrors room.switchAudioDevice(device) ──────────────────────────────────

  /// Switch output to the given AudioInput device.
  /// Mirrors: _room.switchAudioDevice(device)
  Future<bool> switchAudioDevice(AudioInput device) async {
    if (_isWindows) {
      return false;
    }
    bool success = false;

    switch (device.port) {
      case AudioPort.speaker:
        success = await FlutterAudioOutput.changeToSpeaker();
        break;
      case AudioPort.receiver:
        success = await FlutterAudioOutput.changeToReceiver();
        break;
      case AudioPort.headphones:
        success = await FlutterAudioOutput.changeToHeadphones();
        break;
      case AudioPort.bluetooth:
        success = await FlutterAudioOutput.changeToBluetooth();
        break;
      default:
        break;
    }

    if (success) {
      _currentDevice = device;
    }
    return success;
  }

  Future<List<Map<String, String>>> getWindowsAudioDevices() async {
    if (!_isWindows) return const <Map<String, String>>[];

    final List<dynamic> raw =
        (await _windowsChannel.invokeMethod<List<dynamic>>('getAudioDevices')) ??
            const <dynamic>[];

    return raw
        .whereType<Map>()
        .map((m) => {
              'id': (m['id'] as String?) ?? '',
              'name': (m['name'] as String?) ?? 'Unknown Device',
            })
        .where((m) => (m['id'] ?? '').isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, String>?> getWindowsCurrentDevice() async {
    if (!_isWindows) return null;

    final Map<dynamic, dynamic>? raw =
        await _windowsChannel.invokeMethod<Map<dynamic, dynamic>>(
            'getCurrentDevice');
    if (raw == null) return null;

    final id = (raw['id'] as String?) ?? '';
    final name = (raw['name'] as String?) ?? 'Default Device';
    _selectedWindowsDeviceId = id.isEmpty ? null : id;

    return {
      'id': id,
      'name': name,
    };
  }

  Future<void> setWindowsOutputDevice(String? deviceId) async {
    if (!_isWindows) return;

    _selectedWindowsDeviceId = (deviceId != null && deviceId.isNotEmpty)
        ? deviceId
        : null;

    if (_selectedWindowsDeviceId == null) return;

    await _windowsChannel.invokeMethod('setDefaultDevice', {
      'deviceId': _selectedWindowsDeviceId!,
    });
  }

  Future<void> setWindowsSecondaryOutputDevice(String? deviceId) async {
    if (!_isWindows) return;
    _selectedWindowsSecondaryDeviceId =
        (deviceId != null && deviceId.isNotEmpty) ? deviceId : null;
  }

  String? get windowsSecondaryOutputDeviceId => _selectedWindowsSecondaryDeviceId;

  // ─── Playback ────────────────────────────────────────────────────────────────

  Future<void> play(String id, String filePath, double volume) async {
    if (!_allowMultiple) await stopAll();
    await stop(id);

    if (_isWindows) {
      await _windowsChannel.invokeMethod('playAudioOnDevice', {
        'filePath': filePath,
        'deviceId': _selectedWindowsDeviceId ?? '',
        'secondaryDeviceId': _selectedWindowsSecondaryDeviceId ?? '',
        'volume': volume.clamp(0.0, 1.0),
      });
      _players[id] = AudioPlayer();
      return;
    }

    final player = AudioPlayer();
    _players[id] = player;

    player.onPlayerComplete.listen((_) {
      _players.remove(id);
      player.dispose();
    });

    await player.setVolume(volume.clamp(0.0, 1.0));
    await player.play(DeviceFileSource(filePath));
  }

  Future<void> stop(String id) async {
    final player = _players.remove(id);
    if (player != null) {
      if (_isWindows) {
        await _windowsChannel.invokeMethod('stopAudio');
        await player.dispose();
        return;
      }
      await player.stop();
      await player.dispose();
    }
  }

  Future<void> stopAll() async {
    final players = Map.of(_players);
    _players.clear();
    if (_isWindows) {
      await _windowsChannel.invokeMethod('stopAudio');
      for (final player in players.values) {
        await player.dispose();
      }
      return;
    }
    for (final player in players.values) {
      await player.stop();
      await player.dispose();
    }
  }

  bool isPlaying(String id) => _players.containsKey(id);
  Set<String> get playingIds => Set.unmodifiable(_players.keys);

  void setVolume(String id, double volume) {
    final v = volume.clamp(0.0, 1.0);
    if (_isWindows) {
      _windowsChannel.invokeMethod('setVolume', {'volume': v});
      return;
    }
    _players[id]?.setVolume(v);
  }

  void dispose() {
    removeListener();
    stopAll();
    _hotkeyEventsCtrl.close();
  }
}