import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/sound_item.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';

class SoundsProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;
  final _audio = AudioService.instance;
  final _uuid = const Uuid();

  List<SoundItem> _sounds = [];
  Set<String> _playingIds = {};
  bool _loading = true;
  Timer? _pollTimer;

  StreamSubscription<int>? _hotkeySub;
  final Map<int, String> _hotkeyIdToSoundId = {};
  Map<String, int> _comboToHotkeyId = {};

  List<SoundItem> get sounds => _sounds;
  Set<String> get playingIds => _playingIds;
  bool get loading => _loading;

  SoundsProvider() {
    _init();
  }

  Future<void> _init() async {
    await _refresh();
    _loading = false;
    notifyListeners();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _syncGlobalHotkeys();
      _hotkeySub = _audio.hotkeyEvents.listen((id) {
        final soundId = _hotkeyIdToSoundId[id];
        if (soundId == null) return;

        if (_audio.isPlaying(soundId)) {
          stop(soundId);
        } else {
          play(soundId);
        }
      });
    }
    // Poll playing state at ~10fps
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final next = _audio.playingIds;
      if (!setEquals(next, _playingIds)) {
        _playingIds = next;
        notifyListeners();
      }
    });
  }

  Future<void> _refresh() async {
    _sounds = await _db.getAllSounds();
    notifyListeners();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _syncGlobalHotkeys();
    }
  }

  Future<void> _syncGlobalHotkeys() async {
    final nextCombos = <String>{
      for (final s in _sounds)
        if (s.shortcut != null && s.shortcut!.trim().isNotEmpty) s.shortcut!.trim(),
    };

    if (nextCombos.length == _comboToHotkeyId.length &&
        nextCombos.containsAll(_comboToHotkeyId.keys)) {
      return;
    }

    await _audio.unregisterAllGlobalHotkeys();
    _hotkeyIdToSoundId.clear();
    _comboToHotkeyId = {};

    int nextId = 1;
    for (final sound in _sounds) {
      final combo = sound.shortcut?.trim();
      if (combo == null || combo.isEmpty) continue;

      final id = nextId++;
      final ok = await _audio.registerGlobalHotkey(id: id, combo: combo);
      if (!ok) continue;
      _hotkeyIdToSoundId[id] = sound.id;
      _comboToHotkeyId[combo] = id;
    }
  }

  Future<List<String>> importFiles(List<String> paths) async {
    final errors = <String>[];
    final supportedExts = {'.mp3', '.wav', '.ogg', '.flac', '.aac', '.m4a'};

    for (final path in paths) {
      final file = File(path);
      final fileName = file.uri.pathSegments.last;
      final ext = '.${fileName.split('.').last.toLowerCase()}';

      if (!supportedExts.contains(ext)) {
        errors.add('"$fileName" is not a supported audio format');
        continue;
      }

      final stat = await file.stat();
      if (stat.size > 50 * 1024 * 1024) {
        errors.add('"$fileName" exceeds 50 MB limit');
        continue;
      }

      try {
        final destPath = await _db.copyAudioFile(path, fileName);
        final sound = SoundItem(
          id: _uuid.v4(),
          name: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
          fileName: fileName,
          filePath: destPath,
          order: _sounds.length,
          size: stat.size,
          duration: 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _db.addSound(sound);
      } catch (_) {
        errors.add('Failed to import "$fileName"');
      }
    }

    await _refresh();
    return errors;
  }

  Future<void> play(String id) async {
    final sound = _findById(id);
    if (sound == null) return;
    await _audio.play(id, sound.filePath, sound.volume);
  }

  Future<void> stop(String id) async {
    await _audio.stop(id);
  }

  Future<void> rename(String id, String name) async {
    final sound = _findById(id);
    if (sound == null) return;
    await _db.updateSound(sound.copyWith(name: name));
    await _refresh();
  }

  Future<void> remove(String id) async {
    await _audio.stop(id);
    await _db.deleteSound(id);
    await _refresh();
  }

  Future<void> toggleFavorite(String id) async {
    final sound = _findById(id);
    if (sound == null) return;
    await _db.updateSound(sound.copyWith(favorite: !sound.favorite));
    await _refresh();
  }

  Future<void> setVolume(String id, double volume) async {
    _audio.setVolume(id, volume);
    final sound = _findById(id);
    if (sound == null) return;
    await _db.updateSound(sound.copyWith(volume: volume));
    await _refresh();
  }

  Future<void> setShortcut(String id, String? shortcut) async {
    final sound = _findById(id);
    if (sound == null) return;

    final normalized = shortcut?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      final conflicts = _sounds
          .where((s) => s.id != id && (s.shortcut?.trim() == normalized))
          .toList();
      for (final s in conflicts) {
        await _db.updateSound(s.copyWith(shortcut: null));
      }
    }

    await _db.updateSound(
      sound.copyWith(shortcut: (normalized == null || normalized.isEmpty) ? null : normalized),
    );
    await _refresh();
  }

  Future<void> updateCategory(String id, String category) async {
    final sound = _findById(id);
    if (sound == null) return;
    await _db.updateSound(sound.copyWith(category: category));
    await _refresh();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final updated = List<SoundItem>.from(_sounds);
    if (newIndex > oldIndex) newIndex--;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    _sounds = updated;
    notifyListeners();
    await _db.updateOrder(updated);
  }

  SoundItem? _findById(String id) {
    try {
      return _sounds.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _hotkeySub?.cancel();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _audio.unregisterAllGlobalHotkeys();
    }
    _audio.dispose();
    super.dispose();
  }
}
