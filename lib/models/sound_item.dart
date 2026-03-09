class SoundItem {
  final String id;
  final String name;
  final String fileName;
  final String filePath;
  final String category;
  final bool favorite;
  final double volume;
  final int order;
  final int size;
  final double duration;
  final int createdAt;
  final String? shortcut;

  const SoundItem({
    required this.id,
    required this.name,
    required this.fileName,
    required this.filePath,
    this.category = 'Uncategorized',
    this.favorite = false,
    this.volume = 1.0,
    required this.order,
    required this.size,
    required this.duration,
    required this.createdAt,
    this.shortcut,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fileName': fileName,
        'filePath': filePath,
        'category': category,
        'favorite': favorite ? 1 : 0,
        'volume': volume,
        'orderIndex': order,
        'size': size,
        'duration': duration,
        'createdAt': createdAt,
        'shortcut': shortcut,
      };

  factory SoundItem.fromMap(Map<String, dynamic> map) => SoundItem(
        id: map['id'] as String,
        name: map['name'] as String,
        fileName: map['fileName'] as String,
        filePath: map['filePath'] as String,
        category: (map['category'] as String?) ?? 'Uncategorized',
        favorite: (map['favorite'] as int) == 1,
        volume: (map['volume'] as num).toDouble(),
        order: map['orderIndex'] as int,
        size: map['size'] as int,
        duration: (map['duration'] as num).toDouble(),
        createdAt: map['createdAt'] as int,
        shortcut: map['shortcut'] as String?,
      );

  SoundItem copyWith({
    String? name,
    String? category,
    bool? favorite,
    double? volume,
    int? order,
    double? duration,
    Object? shortcut = _sentinel,
  }) =>
      SoundItem(
        id: id,
        name: name ?? this.name,
        fileName: fileName,
        filePath: filePath,
        category: category ?? this.category,
        favorite: favorite ?? this.favorite,
        volume: volume ?? this.volume,
        order: order ?? this.order,
        size: size,
        duration: duration ?? this.duration,
        createdAt: createdAt,
        shortcut:
            shortcut == _sentinel ? this.shortcut : shortcut as String?,
      );
}

const _sentinel = Object();
