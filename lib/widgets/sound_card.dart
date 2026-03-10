import 'package:flutter/material.dart';
import '../models/sound_item.dart';

class SoundCard extends StatefulWidget {
  final SoundItem sound;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final void Function(double) onVolumeChange;
  final VoidCallback onSetShortcut;

  const SoundCard({
    super.key,
    required this.sound,
    required this.isPlaying,
    required this.onPlay,
    required this.onStop,
    required this.onRename,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onVolumeChange,
    required this.onSetShortcut,
  });

  @override
  State<SoundCard> createState() => _SoundCardState();
}

class _SoundCardState extends State<SoundCard> {
  bool _showVolume = false;
  bool _hovered = false;

  String _formatDuration(double seconds) {
    if (seconds <= 0 || seconds.isInfinite || seconds.isNaN) return '0:00';
    final m = seconds ~/ 60;
    final s = (seconds % 60).floor();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sound = widget.sound;

    final cardColor = widget.isPlaying
        ? colorScheme.primaryContainer.withValues(alpha: 0.35)
        : _hovered
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainer;

    final borderColor = widget.isPlaying
        ? colorScheme.primary.withValues(alpha: 0.5)
        : _hovered
            ? colorScheme.primary.withValues(alpha: 0.3)
            : colorScheme.outlineVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                // Play/Stop button
                _PlayButton(
                  isPlaying: widget.isPlaying,
                  onPlay: widget.onPlay,
                  onStop: widget.onStop,
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sound.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDuration(sound.duration),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                          _Dot(),
                          Text(
                            _formatSize(sound.size),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                          if (sound.category != 'Uncategorized') ...[
                            _Dot(),
                            Text(
                              sound.category,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                if (sound.shortcut != null && sound.shortcut!.isNotEmpty)
                  _KbdBadge(sound.shortcut!),

                // Action buttons (shown on hover)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 8),
                        _IconBtn(
                          icon: sound.favorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: sound.favorite
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          tooltip: sound.favorite
                              ? 'Remove favorite'
                              : 'Add favorite',
                          onPressed: widget.onToggleFavorite,
                        ),
                        _IconBtn(
                          icon: Icons.volume_up_outlined,
                          color: _showVolume
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          tooltip: 'Volume',
                          onPressed: () =>
                              setState(() => _showVolume = !_showVolume),
                        ),
                        _IconBtn(
                          icon: Icons.keyboard,
                          color: sound.shortcut != null
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          tooltip: 'Keyboard shortcut',
                          onPressed: widget.onSetShortcut,
                        ),
                        _IconBtn(
                          icon: Icons.edit_outlined,
                          color: colorScheme.onSurfaceVariant,
                          tooltip: 'Rename',
                          onPressed: widget.onRename,
                        ),
                        _IconBtn(
                          icon: Icons.delete_outline,
                          color: colorScheme.error,
                          tooltip: 'Delete',
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),

            // Volume slider (expandable)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _showVolume
                  ? Padding(
                      padding:
                          const EdgeInsets.only(top: 10, left: 36, right: 4),
                      child: Row(
                        children: [
                          Icon(Icons.volume_down,
                              size: 16,
                              color: colorScheme.onSurfaceVariant),
                          Expanded(
                            child: Slider(
                              value: sound.volume,
                              min: 0,
                              max: 1,
                              onChanged: widget.onVolumeChange,
                            ),
                          ),
                          Icon(Icons.volume_up,
                              size: 16,
                              color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '${(sound.volume * 100).round()}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  const _PlayButton({
    required this.isPlaying,
    required this.onPlay,
    required this.onStop,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = widget.isPlaying
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isPlaying ? widget.onStop : widget.onPlay,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered
                  ? colorScheme.primary
                  : backgroundColor,
            ),
            child: Icon(
              widget.isPlaying ? Icons.stop : Icons.play_arrow,
              color: widget.isPlaying || _isHovered
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.all(6),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '·',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _KbdBadge extends StatelessWidget {
  final String label;
  const _KbdBadge(this.label);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
