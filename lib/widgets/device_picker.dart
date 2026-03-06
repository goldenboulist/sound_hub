// lib/widgets/device_picker.dart
// Mirrors the VideoSDK "Change Audio Device" dialog pattern.
// Uses flutter_audio_output under the hood — no C++ required.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/audio_service.dart';

class AudioDevicePicker extends StatefulWidget {
  const AudioDevicePicker({super.key});

  @override
  State<AudioDevicePicker> createState() => _AudioDevicePickerState();
}

class _AudioDevicePickerState extends State<AudioDevicePicker> {
  // Mirrors VideoSDK: List<AudioDeviceInfo>? speakers = [];
  List<AudioInput> _devices = [];
  AudioInput? _currentOutput;

  List<Map<String, String>> _windowsDevices = const [];
  String? _windowsSelectedId;
  String? _windowsCurrentName;
  String? _windowsSecondarySelectedId;
  String? _windowsSecondaryName;

  @override
  void initState() {
    super.initState();
    // Mirrors VideoSDK: fetchSpeakers()
    _fetchDevices();

    // Auto-refresh when hardware changes (headphones/bluetooth plugged in)
    AudioService.instance.setListener(() async {
      await _fetchDevices();
    });
  }

  @override
  void dispose() {
    AudioService.instance.removeListener();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final devices = await AudioService.instance.getWindowsAudioDevices();
      final current = await AudioService.instance.getWindowsCurrentDevice();
      if (mounted) {
        setState(() {
          _windowsDevices = devices;
          _windowsSelectedId = current?['id'] ?? _windowsSelectedId;
          _windowsCurrentName = current?['name'] ?? _windowsCurrentName;
          _windowsSecondarySelectedId ??=
              AudioService.instance.windowsSecondaryOutputDeviceId;
          _windowsSecondaryName ??= _windowsDevices
              .firstWhere(
                (d) => d['id'] == _windowsSecondarySelectedId,
                orElse: () => const {'name': 'None', 'id': ''},
              )['name'];
        });
      }
      return;
    }

    final devices = await AudioService.instance.getAudioDevices();
    final current = await AudioService.instance.getCurrentOutput();
    if (mounted) {
      setState(() {
        _devices = devices;
        _currentOutput = current;
      });
    }
  }

  IconData _iconFor(AudioPort port) {
    switch (port) {
      case AudioPort.speaker:
        return Icons.volume_up;
      case AudioPort.receiver:
        return Icons.phone;
      case AudioPort.headphones:
        return Icons.headphones;
      case AudioPort.bluetooth:
        return Icons.bluetooth;
      default:
        return Icons.device_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    if (isWindows) {
      final selectedName = _windowsCurrentName ??
          _windowsDevices
              .firstWhere(
                (d) => d['id'] == _windowsSelectedId,
                orElse: () => const {'name': 'Default Device', 'id': ''},
              )['name'];

      final secondaryName = _windowsSecondaryName ??
          _windowsDevices
              .firstWhere(
                (d) => d['id'] == _windowsSecondarySelectedId,
                orElse: () => const {'name': 'None', 'id': ''},
              )['name'];

      return ElevatedButton.icon(
        icon: const Icon(Icons.volume_up),
        label: Text('${selectedName ?? 'Default Device'} + ${secondaryName ?? 'None'}'),
        onPressed: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Audio Device'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Primary Output'),
                ),
                SingleChildScrollView(
                  child: _windowsDevices.isNotEmpty
                      ? Column(
                          children: _windowsDevices.map((device) {
                            final id = device['id'] ?? '';
                            final name = device['name'] ?? 'Unknown Device';
                            final isSelected = id == _windowsSelectedId;
                            return ElevatedButton.icon(
                              icon: const Icon(Icons.volume_up),
                              label: Text(name),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                foregroundColor:
                                    isSelected ? Colors.white : null,
                              ),
                              onPressed: () async {
                                await AudioService.instance
                                    .setWindowsOutputDevice(id);
                                if (mounted) {
                                  setState(() {
                                    _windowsSelectedId = id;
                                    _windowsCurrentName = name;
                                  });
                                }
                                if (context.mounted) Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        )
                      : const Text('No audio output devices found.'),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Secondary Output (optional)'),
                ),
                SingleChildScrollView(
                  child: _windowsDevices.isNotEmpty
                      ? Column(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.volume_up),
                              label: const Text('None'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_windowsSecondarySelectedId ==
                                            null ||
                                        _windowsSecondarySelectedId!.isEmpty)
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                foregroundColor:
                                    (_windowsSecondarySelectedId == null ||
                                            _windowsSecondarySelectedId!
                                                .isEmpty)
                                        ? Colors.white
                                        : null,
                              ),
                              onPressed: () async {
                                await AudioService.instance
                                    .setWindowsSecondaryOutputDevice(null);
                                if (mounted) {
                                  setState(() {
                                    _windowsSecondarySelectedId = null;
                                    _windowsSecondaryName = 'None';
                                  });
                                }
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                            ..._windowsDevices.map((device) {
                              final id = device['id'] ?? '';
                              final name = device['name'] ?? 'Unknown Device';
                              final isSelected = id == _windowsSecondarySelectedId;
                              return ElevatedButton.icon(
                                icon: const Icon(Icons.volume_up),
                                label: Text(name),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  foregroundColor:
                                      isSelected ? Colors.white : null,
                                ),
                                onPressed: () async {
                                  await AudioService.instance
                                      .setWindowsSecondaryOutputDevice(id);
                                  if (mounted) {
                                    setState(() {
                                      _windowsSecondarySelectedId = id;
                                      _windowsSecondaryName = name;
                                    });
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                },
                              );
                            }),
                          ],
                        )
                      : const Text('No audio output devices found.'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      icon: Icon(_iconFor(_currentOutput?.port ?? AudioPort.speaker)),
      label: Text(_currentOutput?.name ?? 'Select Output Device'),
      // Mirrors VideoSDK: showDialog with device list
      onPressed: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Audio Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                child: _devices.isNotEmpty
                    ? Column(
                        children: _devices.map((device) {
                          final isSelected =
                              device.port == _currentOutput?.port;
                          return ElevatedButton.icon(
                            icon: Icon(_iconFor(device.port)),
                            label: Text(device.name),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              foregroundColor:
                                  isSelected ? Colors.white : null,
                            ),
                            // Mirrors VideoSDK: _room.switchAudioDevice(device)
                            onPressed: () async {
                              await AudioService.instance
                                  .switchAudioDevice(device);
                              if (context.mounted) {
                                Navigator.pop(context);
                                await _fetchDevices();
                              }
                            },
                          );
                        }).toList(),
                      )
                    : const Text('No audio output devices found.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}