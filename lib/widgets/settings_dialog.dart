import 'package:flutter/material.dart';
import '../widgets/device_picker.dart';

class SettingsDialog extends StatelessWidget {
  final bool allowMultiple;
  final bool darkMode;
  final void Function(bool) onAllowMultipleChanged;
  final void Function(bool) onDarkModeChanged;

  const SettingsDialog({
    super.key,
    required this.allowMultiple,
    required this.darkMode,
    required this.onAllowMultipleChanged,
    required this.onDarkModeChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required bool allowMultiple,
    required bool darkMode,
    required void Function(bool) onAllowMultipleChanged,
    required void Function(bool) onDarkModeChanged,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        allowMultiple: allowMultiple,
        darkMode: darkMode,
        onAllowMultipleChanged: onAllowMultipleChanged,
        onDarkModeChanged: onDarkModeChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AudioDevicePicker(),
            _SettingsTile(
              title: 'Simultaneous Playback',
              subtitle: 'Allow multiple sounds to play at the same time',
              value: allowMultiple,
              onChanged: (v) {
                onAllowMultipleChanged(v);
                Navigator.of(context).pop();
                show(
                  context,
                  allowMultiple: v,
                  darkMode: darkMode,
                  onAllowMultipleChanged: onAllowMultipleChanged,
                  onDarkModeChanged: onDarkModeChanged,
                );
              },
            ),
            const Divider(),
            _SettingsTile(
              title: 'Dark Mode',
              subtitle: 'Toggle dark appearance',
              leading: darkMode
                  ? const Icon(Icons.dark_mode)
                  : const Icon(Icons.light_mode),
              value: darkMode,
              onChanged: (v) {
                onDarkModeChanged(v);
                Navigator.of(context).pop();
                show(
                  context,
                  allowMultiple: allowMultiple,
                  darkMode: v,
                  onAllowMultipleChanged: onAllowMultipleChanged,
                  onDarkModeChanged: onDarkModeChanged,
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading;
  final bool value;
  final void Function(bool) onChanged;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        )),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
