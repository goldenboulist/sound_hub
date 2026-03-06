import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShortcutDialog extends StatefulWidget {
  final String soundName;
  final String? currentShortcut;
  final void Function(String? shortcut) onAssign;

  const ShortcutDialog({
    super.key,
    required this.soundName,
    this.currentShortcut,
    required this.onAssign,
  });

  static Future<void> show(
    BuildContext context, {
    required String soundName,
    String? currentShortcut,
    required void Function(String? shortcut) onAssign,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ShortcutDialog(
        soundName: soundName,
        currentShortcut: currentShortcut,
        onAssign: onAssign,
      ),
    );
  }

  @override
  State<ShortcutDialog> createState() => _ShortcutDialogState();
}

class _ShortcutDialogState extends State<ShortcutDialog> {
  String? _captured;
  bool _listening = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String? _hotkeyKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.escape) return 'Esc';

    final label = key.keyLabel;
    if (label.isNotEmpty) {
      if (label.length == 1 && RegExp(r'^[a-zA-Z0-9]$').hasMatch(label)) {
        return label.toUpperCase();
      }
      if (RegExp(r'^F(\d|1\d|2[0-4])$').hasMatch(label)) {
        return label.toUpperCase();
      }
    }
    return null;
  }

  String _formatKeyEvent(KeyEvent event) {
    final parts = <String>[];
    final key = event.logicalKey;

    final keyName = _hotkeyKeyName(key);
    if (keyName == null) return '';

    if (HardwareKeyboard.instance.isControlPressed &&
        key != LogicalKeyboardKey.controlLeft &&
        key != LogicalKeyboardKey.controlRight) {
      parts.add('Ctrl');
    }
    if (HardwareKeyboard.instance.isAltPressed &&
        key != LogicalKeyboardKey.altLeft &&
        key != LogicalKeyboardKey.altRight) {
      parts.add('Alt');
    }
    if (HardwareKeyboard.instance.isShiftPressed &&
        key != LogicalKeyboardKey.shiftLeft &&
        key != LogicalKeyboardKey.shiftRight) {
      parts.add('Shift');
    }

    // Skip pure modifier keys
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return '';
    }

    parts.add(keyName);

    return parts.join('+');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (!_listening || event is! KeyDownEvent) return;
        final combo = _formatKeyEvent(event);
        if (combo.isNotEmpty) {
          setState(() {
            _captured = combo;
            _listening = false;
          });
        }
      },
      child: AlertDialog(
        title: const Text('Keyboard Shortcut'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: 'Assign a shortcut to '),
                    TextSpan(
                      text: '"${widget.soundName}"',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (widget.currentShortcut != null &&
                  _captured == null &&
                  !_listening) ...[
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Current: '),
                    WidgetSpan(
                      child: _KbdBadge(widget.currentShortcut!),
                    ),
                  ]),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _captured = null;
                    _listening = true;
                  });
                  _focusNode.requestFocus();
                },
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _listening
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: _listening ? 2 : 1,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                  child: Center(
                    child: _listening
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.keyboard,
                                  size: 28,
                                  color: colorScheme.primary),
                              const SizedBox(height: 8),
                              Text(
                                'Press any key combination…',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          )
                        : _captured != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _KbdBadge(_captured!, large: true),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Click to re-record',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.keyboard,
                                      size: 28,
                                      color: colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Click then press a key',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.currentShortcut != null)
                TextButton(
                  style:
                      TextButton.styleFrom(foregroundColor: colorScheme.error),
                  onPressed: () {
                    widget.onAssign(null);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Remove'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _captured != null
                    ? () {
                        widget.onAssign(_captured);
                        Navigator.of(context).pop();
                      }
                    : null,
                child: const Text('Assign'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KbdBadge extends StatelessWidget {
  final String label;
  final bool large;

  const _KbdBadge(this.label, {this.large = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 6,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: large ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: large ? 18 : 11,
          fontWeight: FontWeight.w600,
          color: large ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
