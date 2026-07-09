import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../core/result.dart';
import '../core/error_mapper.dart';
import '../models/file_item.dart';
import 'document_chunker_service.dart';
import 'firestore_service.dart';

class FileService {
  final FirestoreService _firestoreService;
  final FirebaseStorage _storage;
  final DocumentChunkerService _chunker;
  final _uuid = const Uuid();

  FileService({
    required FirestoreService firestoreService,
    FirebaseStorage? storage,
    DocumentChunkerService? chunker,
  }) : _firestoreService = firestoreService,
       _storage = storage ?? FirebaseStorage.instance,
       _chunker = chunker ?? DocumentChunkerService();

  /// Stream user files & folders
  Stream<Result<List<FileItem>>> watchUserFiles(String userId) {
    return _firestoreService.watchUserFiles(userId).map((list) {
      try {
        final items =
            list.map((map) => FileItem.fromMap(map['id'], map)).toList();
        return Success(items);
      } catch (e, stack) {
        return Failure(ErrorMapper.map(e, stack));
      }
    });
  }

  /// Create folder
  Future<Result<FileItem>> createFolder({
    required String userId,
    required String name,
    String? parentId,
  }) async {
    try {
      final id = _uuid.v4();
      final folder = FileItem(
        id: id,
        name: name,
        type: 'folder',
        isFolder: true,
        parentId: parentId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.saveUserFile(
        userId: userId,
        fileId: id,
        fileData: folder.toMap(),
      );
      return Success(folder);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Upload file and save metadata
  Future<Result<FileItem>> uploadAndSaveFile({
    required String userId,
    required File file,
    required String originalName,
    String? parentId,
  }) async {
    try {
      final id = _uuid.v4();
      final extension =
          p.extension(originalName).replaceAll('.', '').toLowerCase();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // Determine standardized type
      String type = 'doc';
      if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(extension)) {
        type = 'image';
      } else if (extension == 'pdf') {
        type = 'pdf';
      } else if (extension == 'csv') {
        type = 'csv';
      } else if (['xls', 'xlsx'].contains(extension)) {
        type = 'xls';
      } else if (['txt', 'json', 'sql', 'md', 'xml'].contains(extension)) {
        type = 'text';
      }

      // Compute content hash
      final bytes = await file.readAsBytes();
      final contentHash = sha256.convert(bytes).toString();

      // Upload to Firebase Storage
      final ref = _storage.ref().child('users/$userId/files/$id.$extension');
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(
          contentType: mimeType,
          customMetadata: {'originalName': originalName, 'type': type},
        ),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final size = await file.length();

      final fileItem = FileItem(
        id: id,
        name: originalName,
        type: type,
        mimeType: mimeType,
        size: size,
        url: downloadUrl,
        parentId: parentId,
        isFolder: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        contentHash: contentHash,
      );

      await _firestoreService.saveUserFile(
        userId: userId,
        fileId: id,
        fileData: fileItem.toMap(),
      );
      return Success(fileItem);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Rename file or folder
  Future<Result<void>> renameFile({
    required String userId,
    required String fileId,
    required String newName,
  }) async {
    try {
      await _firestoreService.updateUserFile(
        userId: userId,
        fileId: fileId,
        updateData: {'name': newName},
      );
      return const Success(null);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Delete file or folder
  Future<Result<void>> deleteFile({
    required String userId,
    required FileItem item,
  }) async {
    try {
      // If it's a folder, we could recursively delete children, or just delete the folder itself.
      // Let's delete the item itself. If it's a file with a storage url, try to delete the storage object.
      if (!item.isFolder && item.url != null) {
        try {
          final ref = _storage.refFromURL(item.url!);
          await ref.delete();
        } catch (_) {
          // If storage delete fails (e.g. file doesn't exist), proceed with firestore delete
        }
      }

      await _firestoreService.deleteUserFile(userId: userId, fileId: item.id);
      return const Success(null);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Sync all chat attachments to a special folder "Chat Attachments"
  Future<Result<void>> syncChatAttachments(String userId) async {
    try {
      // Get all user chats
      final chats = await _firestoreService.getUserChats(userId);
      if (chats.isEmpty) return const Success(null);

      // Find all unique attachments in those chats
      final attachments = <Map<String, dynamic>>[];
      for (final chat in chats) {
        final messagesList = chat['messages'] as List? ?? [];
        for (final msg in messagesList) {
          final attachmentsList = msg['attachments'] as List? ?? [];
          for (final attach in attachmentsList) {
            if (attach is Map<String, dynamic> && attach['url'] != null) {
              attachments.add({...attach, 'chatId': chat['id']});
            }
          }
        }
      }

      if (attachments.isEmpty) return const Success(null);

      // Get current user files to find or create "Chat Attachments" folder
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('files')
              .get();

      final existingFiles =
          querySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

      // Look for folder named "Chat Attachments" at root
      var chatFolder = existingFiles.firstWhere(
        (f) =>
            f['name'] == 'Chat Attachments' &&
            f['parentId'] == null &&
            (f['isFolder'] == true),
        orElse: () => {},
      );

      String folderId;
      if (chatFolder.isEmpty) {
        // Create the folder
        folderId = _uuid.v4();
        final folder = FileItem(
          id: folderId,
          name: 'Chat Attachments',
          type: 'folder',
          isFolder: true,
          parentId: null,
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUserFile(
          userId: userId,
          fileId: folderId,
          fileData: folder.toMap(),
        );
      } else {
        folderId = chatFolder['id'];
      }

      // Add each attachment that doesn't exist yet
      for (final attach in attachments) {
        final attachId = attach['id'] ?? _uuid.v4();
        final alreadySaved = existingFiles.any((f) => f['id'] == attachId);

        if (!alreadySaved) {
          final type = attach['type'] ?? 'doc';

          final fileItem = FileItem(
            id: attachId,
            name: attach['name'] ?? 'Attachment',
            type: type,
            url: attach['url'],
            size:
                attach['size'] is num ? (attach['size'] as num).toInt() : null,
            parentId: folderId,
            isFolder: false,
            chatId: attach['chatId'],
            createdAt: DateTime.now(),
          );

          await _firestoreService.saveUserFile(
            userId: userId,
            fileId: attachId,
            fileData: fileItem.toMap(),
          );
        }
      }

      return const Success(null);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  // ===========================================================================
  // WORKSPACE FILES
  // ===========================================================================

  /// Stream workspace files & folders
  Stream<Result<List<FileItem>>> watchWorkspaceFiles(String companyId) {
    return _firestoreService.watchWorkspaceFiles(companyId).map((list) {
      try {
        final items =
            list.map((map) => FileItem.fromMap(map['id'], map)).toList();
        return Success(items);
      } catch (e, stack) {
        return Failure(ErrorMapper.map(e, stack));
      }
    });
  }

  /// Create folder in workspace
  Future<Result<FileItem>> createWorkspaceFolder({
    required String companyId,
    required String name,
    String? parentId,
  }) async {
    try {
      final id = _uuid.v4();
      final folder = FileItem(
        id: id,
        name: name,
        type: 'folder',
        isFolder: true,
        parentId: parentId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.saveWorkspaceFile(
        companyId: companyId,
        fileId: id,
        fileData: folder.toMap(),
      );
      return Success(folder);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Upload file and save metadata to workspace
  Future<Result<FileItem>> uploadAndSaveWorkspaceFile({
    required String companyId,
    required File file,
    required String originalName,
    String? parentId,
  }) async {
    final id = _uuid.v4();
    final extension =
        p.extension(originalName).replaceAll('.', '').toLowerCase();
    try {
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // Determine standardized type
      String type = 'doc';
      if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(extension)) {
        type = 'image';
      } else if (extension == 'pdf') {
        type = 'pdf';
      } else if (extension == 'csv') {
        type = 'csv';
      } else if (['xls', 'xlsx'].contains(extension)) {
        type = 'xls';
      } else if (['txt', 'json', 'sql', 'md', 'xml'].contains(extension)) {
        type = 'text';
      }

      // Compute content hash
      final bytes = await file.readAsBytes();
      final contentHash = sha256.convert(bytes).toString();

      // Upload to Firebase Storage
      final ref = _storage.ref().child(
        'companies/$companyId/files/$id.$extension',
      );
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(
          contentType: mimeType,
          customMetadata: {'originalName': originalName, 'type': type},
        ),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final size = await file.length();

      final fileItem = FileItem(
        id: id,
        name: originalName,
        type: type,
        mimeType: mimeType,
        size: size,
        url: downloadUrl,
        parentId: parentId,
        isFolder: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isIndexed: false,
        contentHash: contentHash,
      );

      await _firestoreService.saveWorkspaceFile(
        companyId: companyId,
        fileId: id,
        fileData: fileItem.toMap(),
      );

      // Kick off chunking asynchronously — don't await so the UI isn't blocked.
      _triggerChunking(
        companyId: companyId,
        fileId: id,
        file: file,
        fileName: originalName,
        extension: extension,
      );

      debugPrint('[FileService] ✅ Upload success: companies/$companyId/files/$id.$extension');
      return Success(fileItem);
    } on FirebaseException catch (e, stack) {
      debugPrint('[FileService] ❌ UPLOAD FAILED (FirebaseException)');
      debugPrint('  Path   : companies/$companyId/files/$id.$extension');
      debugPrint('  Plugin : ${e.plugin}');
      debugPrint('  Code   : ${e.code}');
      debugPrint('  Message: ${e.message}');
      return Failure(ErrorMapper.map(e, stack));
    } catch (e, stack) {
      debugPrint('[FileService] ❌ UPLOAD FAILED (${e.runtimeType}): $e');
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Rename workspace file or folder
  Future<Result<void>> renameWorkspaceFile({
    required String companyId,
    required String fileId,
    required String newName,
  }) async {
    try {
      await _firestoreService.updateWorkspaceFile(
        companyId: companyId,
        fileId: fileId,
        updateData: {'name': newName},
      );
      return const Success(null);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Delete workspace file or folder
  Future<Result<void>> deleteWorkspaceFile({
    required String companyId,
    required FileItem item,
  }) async {
    try {
      if (!item.isFolder && item.url != null) {
        try {
          final ref = _storage.refFromURL(item.url!);
          await ref.delete();
        } catch (_) {
          // If storage delete fails, proceed with firestore delete
        }
      }

      await _firestoreService.deleteWorkspaceFile(
        companyId: companyId,
        fileId: item.id,
      );
      return const Success(null);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  /// Sync all chat attachments for a workspace to a special folder "Chat Attachments"
  Future<Result<void>> syncWorkspaceChatAttachments(String companyId) async {
    try {
      // Get all workspace chats
      final chats = await _firestoreService.getWorkspaceChats(companyId);
      if (chats.isEmpty) return const Success(null);

      // Find all unique attachments in those chats
      final attachments = <Map<String, dynamic>>[];
      for (final chat in chats) {
        final messagesList = chat['messages'] as List? ?? [];
        for (final msg in messagesList) {
          final attachmentsList = msg['attachments'] as List? ?? [];
          for (final attach in attachmentsList) {
            if (attach is Map<String, dynamic> && attach['url'] != null) {
              attachments.add({...attach, 'chatId': chat['id']});
            }
          }
        }
      }

      if (attachments.isEmpty) return const Success(null);

      // Get current workspace files to find or create "Chat Attachments" folder
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('files')
              .get();

      final existingFiles =
          querySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

      // Look for folder named "Chat Attachments" at root
      var chatFolder = existingFiles.firstWhere(
        (f) =>
            f['name'] == 'Chat Attachments' &&
            f['parentId'] == null &&
            (f['isFolder'] == true),
        orElse: () => {},
      );

      String folderId;
      if (chatFolder.isEmpty) {
        // Create the folder
        folderId = _uuid.v4();
        final folder = FileItem(
          id: folderId,
          name: 'Chat Attachments',
          type: 'folder',
          isFolder: true,
          parentId: null,
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveWorkspaceFile(
          companyId: companyId,
          fileId: folderId,
          fileData: folder.toMap(),
        );
      } else {
        folderId = chatFolder['id'];
      }

      // Add each attachment that doesn't exist yet
      for (final attach in attachments) {
        final attachId = attach['id'] ?? _uuid.v4();
        final alreadySaved = existingFiles.any((f) => f['id'] == attachId);

        if (!alreadySaved) {
          final type = attach['type'] ?? 'doc';

          final fileItem = FileItem(
            id: attachId,
            name: attach['name'] ?? 'Attachment',
            type: type,
            url: attach['url'],
            size:
                attach['size'] is num ? (attach['size'] as num).toInt() : null,
            parentId: folderId,
            isFolder: false,
            chatId: attach['chatId'],
            createdAt: DateTime.now(),
          );

          await _firestoreService.saveWorkspaceFile(
            companyId: companyId,
            fileId: attachId,
            fileData: fileItem.toMap(),
          );
        }
      }

      return const Success(null);
    } catch (e, stack) {
      return Failure(ErrorMapper.map(e, stack));
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static const _indexableExtensions = {
    'pdf',
    'txt',
    'md',
    'csv',
    'xls',
    'xlsx',
    'docx',
    'doc',
    'json',
    'xml',
    'sql',
  };

  /// Runs document chunking in the background for indexable file types.
  /// Updates `isIndexed`, `indexedAt`, and `chunkCount` on the Firestore doc
  /// when complete.
  void _triggerChunking({
    required String companyId,
    required String fileId,
    required File file,
    required String fileName,
    required String extension,
  }) {
    if (!_indexableExtensions.contains(extension)) {
      debugPrint(
        '[FileService] Skipping chunking for non-text file: $fileName',
      );
      return;
    }

    // Fire-and-forget — intentionally unawaited.
    () async {
      try {
        debugPrint(
          '[FileService] Starting background chunking for "$fileName"…',
        );
        final count = await _chunker.processAndChunk(
          companyId: companyId,
          fileId: fileId,
          file: file,
          fileName: fileName,
        );

        await _firestoreService.updateWorkspaceFile(
          companyId: companyId,
          fileId: fileId,
          updateData: {
            'isIndexed': count > 0,
            'indexedAt': DateTime.now().toIso8601String(),
            'chunkCount': count,
          },
        );
        debugPrint('[FileService] ✓ Indexed "$fileName" with $count chunks.');
      } catch (e) {
        debugPrint('[FileService] Chunking failed for "$fileName": $e');
        // Mark as not indexed so the user can retry
        try {
          await _firestoreService.updateWorkspaceFile(
            companyId: companyId,
            fileId: fileId,
            updateData: {'isIndexed': false, 'chunkCount': 0},
          );
        } catch (_) {}
      }
    }();
  }
}
