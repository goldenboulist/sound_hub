import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/sound_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  DatabaseService._();
  static DatabaseService get instance => _instance;

  Database? _db;

  Future<Database> get db async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dir = await getApplicationDocumentsDirectory();
    final dbDir = p.join(dir.path, 'Soundboard');
    await Directory(dbDir).create(recursive: true);
    return factory.openDatabase(
      p.join(dbDir, 'soundboard.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE sounds (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              fileName TEXT NOT NULL,
              filePath TEXT NOT NULL,
              category TEXT NOT NULL DEFAULT 'Uncategorized',
              favorite INTEGER NOT NULL DEFAULT 0,
              volume REAL NOT NULL DEFAULT 1.0,
              orderIndex INTEGER NOT NULL DEFAULT 0,
              size INTEGER NOT NULL DEFAULT 0,
              duration REAL NOT NULL DEFAULT 0.0,
              createdAt INTEGER NOT NULL,
              shortcut TEXT
            )
          ''');
        },
      ),
    );
  }

  Future<String> get soundsDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    final soundsDir = p.join(dir.path, 'Soundboard', 'sounds');
    await Directory(soundsDir).create(recursive: true);
    return soundsDir;
  }

  Future<List<SoundItem>> getAllSounds() async {
    final database = await db;
    final maps =
        await database.query('sounds', orderBy: 'orderIndex ASC');
    return maps.map(SoundItem.fromMap).toList();
  }

  Future<void> addSound(SoundItem sound) async {
    final database = await db;
    await database.insert('sounds', sound.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSound(SoundItem sound) async {
    final database = await db;
    await database.update('sounds', sound.toMap(),
        where: 'id = ?', whereArgs: [sound.id]);
  }

  Future<void> deleteSound(String id) async {
    final database = await db;
    final rows = await database
        .query('sounds', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final filePath = rows.first['filePath'] as String;
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    }
    await database.delete('sounds', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateOrder(List<SoundItem> sounds) async {
    final database = await db;
    final batch = database.batch();
    for (int i = 0; i < sounds.length; i++) {
      batch.update(
        'sounds',
        {'orderIndex': i},
        where: 'id = ?',
        whereArgs: [sounds[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Copy the source file into the app's sounds directory and return the
  /// new path.
  Future<String> copyAudioFile(String sourcePath, String fileName) async {
    final dir = await soundsDirectory;
    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    // Avoid name collisions
    var dest = p.join(dir, fileName);
    var counter = 1;
    while (await File(dest).exists()) {
      dest = p.join(dir, '${base}_$counter$ext');
      counter++;
    }
    await File(sourcePath).copy(dest);
    return dest;
  }
}
