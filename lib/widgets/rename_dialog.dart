import 'package:flutter/material.dart';

class RenameDialog extends StatefulWidget {
  final String currentName;
  final void Function(String name) onRename;

  const RenameDialog({
    super.key,
    required this.currentName,
    required this.onRename,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentName,
    required void Function(String name) onRename,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          RenameDialog(currentName: currentName, onRename: onRename),
    );
  }

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
    _ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) {
      widget.onRename(name);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Sound'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ctrl.text.trim().isNotEmpty ? _submit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
