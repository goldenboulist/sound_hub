import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/sound_item.dart';
import '../providers/sounds_provider.dart';
import '../services/audio_service.dart';
import '../widgets/delete_dialog.dart';
import '../widgets/rename_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/shortcut_dialog.dart';
import '../widgets/sound_card.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum FilterMode { all, favorites, category, shortcut }

class HomeScreen extends StatefulWidget {
  final bool darkMode;
  final bool allowMultiple;
  final void Function(bool) onDarkModeChanged;
  final void Function(bool) onAllowMultipleChanged;

  const HomeScreen({
    super.key,
    required this.darkMode,
    required this.allowMultiple,
    required this.onDarkModeChanged,
    required this.onAllowMultipleChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  FilterMode _filterMode = FilterMode.all;
  String? _selectedCategory;
  bool _dragOver = false;
  String _importStatus = '';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (Navigator.of(context).canPop()) return false;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus?.context?.widget is EditableText) return false;

    final combo = _formatKeyCombo(event);
    if (combo.isEmpty) return false;

    final provider = context.read<SoundsProvider>();
    final match =
        provider.sounds.where((s) => s.shortcut == combo).firstOrNull;
    if (match != null) {
      if (AudioService.instance.isPlaying(match.id)) {
        provider.stop(match.id);
      } else {
        provider.play(match.id);
      }
      return true;
    }
    return false;
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

  String _formatKeyCombo(KeyEvent event) {
    final key = event.logicalKey;
    final modifierKeys = {
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    };
    if (modifierKeys.contains(key)) return '';

    final keyName = _hotkeyKeyName(key);
    if (keyName == null) return '';

    final parts = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) parts.add('Ctrl');
    if (HardwareKeyboard.instance.isAltPressed) parts.add('Alt');
    if (HardwareKeyboard.instance.isShiftPressed) parts.add('Shift');
    parts.add(keyName);
    return parts.join('+');
  }

  Future<void> _importFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final paths =
        result.files.map((f) => f.path).whereType<String>().toList();
    await _doImport(paths);
  }

  Future<void> _doImport(List<String> paths) async {
    if (paths.isEmpty) return;
    final provider = context.read<SoundsProvider>();
    final errors = await provider.importFiles(paths);
    final imported = paths.length - errors.length;
    if (!mounted) return;
    if (imported > 0) {
      setState(() {
        _importStatus =
            'Imported $imported sound${imported != 1 ? "s" : ""}';
      });
      Future.delayed(const Duration(seconds: 3),
          () => mounted ? setState(() => _importStatus = '') : null);
    }
    for (final err in errors) {
      if (!mounted) break;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  List<SoundItem> _filtered(List<SoundItem> sounds) {
    var list = sounds;
    if (_filterMode == FilterMode.favorites) {
      list = list.where((s) => s.favorite).toList();
    } else if (_filterMode == FilterMode.category &&
        _selectedCategory != null) {
      list = list.where((s) => s.category == _selectedCategory).toList();
    } else if (_filterMode == FilterMode.shortcut) {
      list = list.where((s) => s.shortcut != null && s.shortcut!.isNotEmpty).toList();
    }
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<SoundsProvider>(
      builder: (context, provider, _) {
        final filtered = _filtered(provider.sounds);
        final categories = provider.sounds
            .map((s) => s.category)
            .where((c) => c != 'Uncategorized')
            .toSet()
            .toList()
          ..sort();

        return DropTarget(
          onDragEntered: (_) => setState(() => _dragOver = true),
          onDragExited: (_) => setState(() => _dragOver = false),
          onDragDone: (details) {
            setState(() => _dragOver = false);
            final paths = details.files
                .where((f) => f.path.isNotEmpty)
                .map((f) => f.path)
                .toList();
            _doImport(paths);
          },
          child: Stack(
            children: [
              Scaffold(
                body: Column(
                  children: [
                    _Header(
                      soundCount: provider.sounds.length,
                      onImport: _importFilePicker,
                      onSettings: () => SettingsDialog.show(
                        context,
                        allowMultiple: widget.allowMultiple,
                        darkMode: widget.darkMode,
                        onAllowMultipleChanged: widget.onAllowMultipleChanged,
                        onDarkModeChanged: widget.onDarkModeChanged,
                      ),
                      searchCtrl: _searchCtrl,
                      onSearchChanged: (_) => setState(() {}),
                    ),
                    _FilterBar(
                      filterMode: _filterMode,
                      selectedCategory: _selectedCategory,
                      categories: categories,
                      onAll: () => setState(() {
                        _filterMode = FilterMode.all;
                        _selectedCategory = null;
                      }),
                      onFavorites: () =>
                          setState(() => _filterMode = FilterMode.favorites),
                      onCategory: (cat) => setState(() {
                        _filterMode = FilterMode.category;
                        _selectedCategory = cat;
                      }),
                      onShortcut: () => setState(() {
                        _filterMode = FilterMode.shortcut;
                        _selectedCategory = null;
                      }),
                    ),
                    if (_importStatus.isNotEmpty)
                      Container(
                        color: colorScheme.primaryContainer,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Text(
                          _importStatus,
                          style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 13),
                        ),
                      ),
                    Expanded(
                      child: provider.loading
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                              ? _EmptyState(
                                  hasAnySounds: provider.sounds.isNotEmpty,
                                  onImport: _importFilePicker,
                                )
                              : ReorderableListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  onReorder: (oldIdx, newIdx) {
                                    if (_filterMode == FilterMode.all &&
                                        _searchCtrl.text.isEmpty) {
                                      provider.reorder(oldIdx, newIdx);
                                    }
                                  },
                                  itemBuilder: (_, i) {
                                    final sound = filtered[i];
                                    return Padding(
                                      key: ValueKey(sound.id),
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: SoundCard(
                                        sound: sound,
                                        isPlaying: provider.playingIds
                                            .contains(sound.id),
                                        onPlay: () => provider.play(sound.id),
                                        onStop: () => provider.stop(sound.id),
                                        onRename: () => RenameDialog.show(
                                          context,
                                          currentName: sound.name,
                                          onRename: (name) =>
                                              provider.rename(sound.id, name),
                                        ),
                                        onDelete: () => DeleteDialog.show(
                                          context,
                                          soundName: sound.name,
                                          onConfirm: () =>
                                              provider.remove(sound.id),
                                        ),
                                        onToggleFavorite: () =>
                                            provider.toggleFavorite(sound.id),
                                        onVolumeChange: (v) =>
                                            provider.setVolume(sound.id, v),
                                        onSetShortcut: () =>
                                            ShortcutDialog.show(
                                          context,
                                          soundName: sound.name,
                                          currentShortcut: sound.shortcut,
                                          onAssign: (shortcut) =>
                                              provider.setShortcut(
                                                  sound.id, shortcut),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              if (_dragOver)
                Positioned.fill(
                  child: Container(
                    color: colorScheme.surface.withValues(alpha: 0.88),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file,
                            size: 72, color: colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Drop audio files here',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'MP3, WAV, OGG, FLAC, AAC, M4A supported',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
  final int soundCount;
  final VoidCallback onImport;
  final VoidCallback onSettings;
  final TextEditingController searchCtrl;
  final void Function(String) onSearchChanged;

  const _Header({
    required this.soundCount,
    required this.onImport,
    required this.onSettings,
    required this.searchCtrl,
    required this.onSearchChanged,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _importHovered = false;
  bool _settingsHovered = false;

  static const _svgMusic = '''
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
        viewBox="0 0 24 24" fill="none" stroke="currentColor"
        stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M9 18V5l12-2v13"></path>
      <circle cx="6" cy="18" r="3"></circle>
      <circle cx="18" cy="16" r="3"></circle>
    </svg>
  ''';

  static const _svgUpload = '''
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
        viewBox="0 0 24 24" fill="none" stroke="currentColor"
        stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
      <polyline points="17 8 12 3 7 8"></polyline>
      <line x1="12" x2="12" y1="3" y2="15"></line>
    </svg>
  ''';

  static const _svgSettings = '''
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"
        viewBox="0 0 24 24" fill="none" stroke="currentColor"
        stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"></path>
      <circle cx="12" cy="12" r="3"></circle>
    </svg>
  ''';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final importIconColor =
        _importHovered ? const Color(0xFF080A0C) : colorScheme.onSurface;
    final settingsIconColor =
        _settingsHovered ? const Color(0xFF080A0C) : colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              // Logo icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF18DCB5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SvgPicture.string(
                    _svgMusic,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF080A0C),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title & count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sound_hub',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          )),
                  Text(
                    '${widget.soundCount} sound${widget.soundCount != 1 ? "s" : ""}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const Spacer(),

              // Import button with hover-aware SVG
              MouseRegion(
                onEnter: (_) => setState(() => _importHovered = true),
                onExit: (_) => setState(() => _importHovered = false),
                child: OutlinedButton.icon(
                  onPressed: widget.onImport,
                  style: ButtonStyle(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.hovered)
                          ? const Color(0xFF18DCB5)
                          : colorScheme.surfaceContainer,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.hovered)
                          ? const Color(0xFF080A0C)
                          : colorScheme.onSurface,
                    ),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    padding: WidgetStateProperty.all(const EdgeInsets.all(16)),
                    side: WidgetStateProperty.all(
                      const BorderSide(color: Color(0xFF272B34), width: 1),
                    ),
                  ),
                  icon: SvgPicture.string(
                    _svgUpload,
                    width: 16,
                    height: 16,
                    colorFilter:
                        ColorFilter.mode(importIconColor, BlendMode.srcIn),
                  ),
                  label: const Text('Import'),
                ),
              ),
              const SizedBox(width: 8),

              // Settings button with hover-aware SVG
              MouseRegion(
                onEnter: (_) => setState(() => _settingsHovered = true),
                onExit: (_) => setState(() => _settingsHovered = false),
                child: IconButton(
                  onPressed: widget.onSettings,
                  tooltip: 'Settings',
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.hovered)
                          ? const Color(0xFF18DCB5)
                          : Theme.of(context).scaffoldBackgroundColor,
                    ),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  icon: SvgPicture.string(
                    _svgSettings,
                    width: 18,
                    height: 18,
                    colorFilter:
                        ColorFilter.mode(settingsIconColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          TextField(
            controller: widget.searchCtrl,
            onChanged: widget.onSearchChanged,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
            decoration: InputDecoration(
              hintText: 'Search sounds…',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon:
                  Icon(Icons.search, size: 18, color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: colorScheme.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: colorScheme.primary.withValues(alpha: 0.3), width: 1),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final FilterMode filterMode;
  final String? selectedCategory;
  final List<String> categories;
  final VoidCallback onAll;
  final VoidCallback onFavorites;
  final void Function(String) onCategory;
  final VoidCallback onShortcut;

  const _FilterBar({
    required this.filterMode,
    required this.selectedCategory,
    required this.categories,
    required this.onAll,
    required this.onFavorites,
    required this.onCategory,
    required this.onShortcut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical:12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
                label: 'All',
                icon: Icons.grid_view,
                active: filterMode == FilterMode.all,
                onTap: onAll),
            const SizedBox(width: 6),
            _FilterChip(
                label: 'Favorites',
                icon: Icons.star_outline,
                active: filterMode == FilterMode.favorites,
                onTap: onFavorites),
            const SizedBox(width: 6),
            _FilterChip(
                label: 'Shortcut',
                icon: Icons.keyboard,
                active: filterMode == FilterMode.shortcut,
                onTap: onShortcut),
            ...categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterChip(
                    label: cat,
                    icon: Icons.layers_outlined,
                    active: filterMode == FilterMode.category &&
                        selectedCategory == cat,
                    onTap: () => onCategory(cat),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: active
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasAnySounds;
  final VoidCallback onImport;

  const _EmptyState({required this.hasAnySounds, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (hasAnySounds) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No sounds match your search',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.music_note,
                size: 40, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('No sounds yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SizedBox(
            width: 280,
            child: Text(
              'Import audio files to get started.\nDrag & drop or click the import button.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Import Sounds'),
          ),
        ],
      ),
    );
  }
}
