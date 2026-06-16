import 'package:cloud_firestore/cloud_firestore.dart';

class FileItem {
  final String id;
  final String name;
  final String type; // folder | pdf | image | csv | doc | xls | text
  final String? mimeType;
  final int? size;
  final String? url;
  final String? thumbnailUrl;
  final String? parentId; // null = root
  final bool isFolder;
  final String? chatId; // If synced from a chat
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isIndexed;
  final DateTime? indexedAt;
  final int? chunkCount;

  const FileItem({
    required this.id,
    required this.name,
    required this.type,
    this.mimeType,
    this.size,
    this.url,
    this.thumbnailUrl,
    this.parentId,
    required this.isFolder,
    this.chatId,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.isIndexed = false,
    this.indexedAt,
    this.chunkCount,
  });

  factory FileItem.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return FileItem(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? 'folder',
      mimeType: map['mimeType'],
      size: map['size'] is num ? (map['size'] as num).toInt() : null,
      url: map['url'],
      thumbnailUrl: map['thumbnailUrl'],
      parentId: map['parentId'],
      isFolder: map['isFolder'] ?? (map['type'] == 'folder'),
      chatId: map['chatId'],
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDateTime(map['updatedAt']) : null,
      isIndexed: map['isIndexed'] ?? false,
      indexedAt: map['indexedAt'] != null ? parseDateTime(map['indexedAt']) : null,
      chunkCount: map['chunkCount'] is num ? (map['chunkCount'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'mimeType': mimeType,
      'size': size,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'parentId': parentId,
      'isFolder': isFolder,
      'chatId': chatId,
      'tags': tags,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isIndexed': isIndexed,
      'indexedAt': indexedAt,
      'chunkCount': chunkCount,
    };
  }

  FileItem copyWith({
    String? id,
    String? name,
    String? type,
    String? mimeType,
    int? size,
    String? url,
    String? thumbnailUrl,
    String? parentId,
    bool? isFolder,
    String? chatId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isIndexed,
    DateTime? indexedAt,
    int? chunkCount,
  }) {
    return FileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      parentId: parentId ?? this.parentId,
      isFolder: isFolder ?? this.isFolder,
      chatId: chatId ?? this.chatId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isIndexed: isIndexed ?? this.isIndexed,
      indexedAt: indexedAt ?? this.indexedAt,
      chunkCount: chunkCount ?? this.chunkCount,
    );
  }
}
