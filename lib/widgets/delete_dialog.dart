import 'package:flutter/material.dart';

class DeleteDialog extends StatelessWidget {
  final String soundName;
  final VoidCallback onConfirm;

  const DeleteDialog({
    super.key,
    required this.soundName,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required String soundName,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          DeleteDialog(soundName: soundName, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete Sound'),
      content: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            const TextSpan(text: 'Are you sure you want to delete '),
            TextSpan(
              text: '"$soundName"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: '? This cannot be undone.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
