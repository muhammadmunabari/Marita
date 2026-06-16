import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/workspace_provider.dart';
import 'document_chunker_service.dart';
import 'firestore_service.dart';

final migrationServiceProvider = Provider<MigrationService>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return MigrationService(
    firestoreService: firestoreService,
    db: FirebaseFirestore.instance,
  );
});

class MigrationService {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;

  MigrationService({
    required FirestoreService firestoreService,
    FirebaseFirestore? db,
  }) : _firestoreService = firestoreService,
       _db = db ?? FirebaseFirestore.instance;

  /// Runs the user-scoped data migration to the active workspace if not already done.
  Future<void> runMigrationIfNeeded({
    required String userId,
    required String companyId,
  }) async {
    try {
      // 1. Check if migration has already been executed for this user
      final flagDocRef = _db
          .collection('users')
          .doc(userId)
          .collection('migrationState')
          .doc('workspaceIsolation');

      final flagDoc = await flagDocRef.get();
      if (flagDoc.exists) {
        debugPrint('Migration already completed for user: $userId');
        return; // Migration already done
      }

      debugPrint(
        'Starting workspace isolation migration for user: $userId to company: $companyId',
      );

      // 2. Migrate chats
      await _migrateChats(userId, companyId);

      // 3. Migrate files
      await _migrateFiles(userId, companyId);

      // 4. Set migration completion flag
      await flagDocRef.set({
        'migratedAt': FieldValue.serverTimestamp(),
        'companyId': companyId,
        'status': 'completed',
      });

      debugPrint(
        'Successfully completed workspace isolation migration for user: $userId',
      );
    } catch (e, stack) {
      debugPrint('Error during workspace isolation migration: $e\n$stack');
    }
  }

  Future<void> _migrateChats(String userId, String companyId) async {
    try {
      final legacyChats = await _firestoreService.getUserChats(userId);
      if (legacyChats.isEmpty) {
        debugPrint('No legacy chats found for user: $userId');
        return;
      }

      debugPrint('Migrating ${legacyChats.length} chats for user: $userId');
      final batch = _db.batch();

      for (final chat in legacyChats) {
        final chatId = chat['id'] as String?;
        if (chatId == null) continue;

        final chatData = Map<String, dynamic>.from(chat)..remove('id');

        final targetRef = _db
            .collection('companies')
            .doc(companyId)
            .collection('chats')
            .doc(chatId);

        batch.set(targetRef, {
          ...chatData,
          'migratedFrom': 'user_scoped',
          'migratedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('Successfully migrated ${legacyChats.length} chats');
    } catch (e) {
      debugPrint('Error migrating chats: $e');
      rethrow;
    }
  }

  Future<void> _migrateFiles(String userId, String companyId) async {
    try {
      final legacyFiles = await _firestoreService.getLegacyUserFiles(userId);
      if (legacyFiles.isEmpty) {
        debugPrint('No legacy files found for user: $userId');
        return;
      }

      debugPrint('Migrating ${legacyFiles.length} files for user: $userId');
      final batch = _db.batch();

      for (final file in legacyFiles) {
        final fileId = file['id'] as String?;
        if (fileId == null) continue;

        final fileData = Map<String, dynamic>.from(file)..remove('id');

        final targetRef = _db
            .collection('companies')
            .doc(companyId)
            .collection('files')
            .doc(fileId);

        batch.set(targetRef, {
          ...fileData,
          'migratedFrom': 'user_scoped',
          'migratedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('Successfully migrated ${legacyFiles.length} files');
    } catch (e) {
      debugPrint('Error migrating files: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Re-indexing (retroactive chunking for existing workspace files)
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

  /// Finds all workspace files that have not been indexed yet (or have stale
  /// indexing state) and chunks them.
  ///
  /// **Option A fixes applied:**
  /// - `isFolder` is checked in Dart (null-safe) — not via Firestore `.where()`
  ///   so files missing the field are not silently excluded.
  /// - [force] mode re-indexes even files flagged `isIndexed: true` but with
  ///   zero stored chunks.
  /// - Firebase Storage errors are caught per-file with a 2-minute timeout so
  ///   App Check issues don't abort the whole batch.
  ///
  /// **Option B fast path:**
  /// - If the file doc has an `extractedText` field (stored at upload time by
  ///   [DocumentChunkerService.processAndChunk]), re-chunking happens entirely
  ///   in-memory — no Storage download needed.
  Future<void> reindexWorkspaceFiles(
    String companyId, {
    bool force = false,
  }) async {
    debugPrint(
      '[Migration] Starting reindex for workspace: $companyId (force=$force)',
    );
    final chunker = DocumentChunkerService();
    int indexed = 0;
    int skipped = 0;
    int failed = 0;

    try {
      // ── Option A Fix 1: remove brittle .where('isFolder') filter ──────────
      // Fetch ALL file docs; filter in Dart with null-safe check.
      final snapshot =
          await _db
              .collection('companies')
              .doc(companyId)
              .collection('files')
              .get();

      debugPrint(
        '[Migration] Found ${snapshot.docs.length} doc(s) to evaluate.',
      );

      final tempDir = await getTemporaryDirectory();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fileId = doc.id;
        final fileName = data['name'] as String? ?? '';
        final ext =
            fileName.contains('.')
                ? fileName.split('.').last.toLowerCase()
                : '';

        // ── Option A Fix 1: null-safe isFolder check ────────────────────────
        final isFolder = data['isFolder'] as bool? ?? false;
        if (isFolder) {
          skipped++;
          continue;
        }

        // ── Option A Fix 2: skip only when truly indexed AND has chunks ──────
        final alreadyIndexed = data['isIndexed'] == true;
        final chunkCount = data['chunkCount'] as int? ?? 0;
        if (!force && alreadyIndexed && chunkCount > 0) {
          debugPrint(
            '[Migration] Skipping already-indexed file ($chunkCount chunks): $fileName',
          );
          skipped++;
          continue;
        }

        if (!_indexableExtensions.contains(ext)) {
          debugPrint('[Migration] Skipping non-indexable file type: $fileName');
          skipped++;
          continue;
        }

        final url = data['url'] as String?;

        // ── Option B fast path: use stored extractedText ─────────────────────
        final storedText = data['extractedText'] as String?;
        if (storedText != null && storedText.isNotEmpty) {
          debugPrint(
            '[Migration] Using stored extractedText for "$fileName" (no download needed)',
          );
          try {
            await chunker.deleteChunks(companyId: companyId, fileId: fileId);

            final chunks = chunker.chunkText(storedText, fileName, fileId);
            final count = await chunker.saveChunksDirectly(
              companyId: companyId,
              fileId: fileId,
              chunks: chunks,
            );

            await _updateIndexState(companyId, fileId, count);
            debugPrint(
              '[Migration] ✓ "$fileName" → $count chunks (from stored text)',
            );
            indexed++;
          } catch (e) {
            debugPrint(
              '[Migration] Failed to reindex "$fileName" from stored text: $e',
            );
            await _markFailed(companyId, fileId, e.toString());
            failed++;
          }
          continue;
        }

        // ── Storage download path (with App Check resilience) ────────────────
        if (url == null) {
          debugPrint('[Migration] Skipping URL-less file: $fileName');
          skipped++;
          continue;
        }

        final tempFile = File('${tempDir.path}/${fileId}_$fileName');
        try {
          debugPrint('[Migration] Downloading "$fileName" for indexing…');

          // ── Option A Fix 3: timeout + per-file error handling ───────────────
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref
              .writeToFile(tempFile)
              .timeout(
                const Duration(minutes: 2),
                onTimeout:
                    () =>
                        throw TimeoutException(
                          'Storage download timed out for "$fileName"',
                        ),
              );

          await chunker.deleteChunks(companyId: companyId, fileId: fileId);

          final count = await chunker.processAndChunk(
            companyId: companyId,
            fileId: fileId,
            file: tempFile,
            fileName: fileName,
          );

          await _updateIndexState(companyId, fileId, count);
          debugPrint(
            '[Migration] ✓ "$fileName" → $count chunks (from download)',
          );
          indexed++;
        } on FirebaseException catch (e) {
          // ── Option A Fix 3: App Check / permission errors don't abort batch ─
          debugPrint(
            '[Migration] Firebase error for "$fileName": ${e.code} - ${e.message}',
          );
          await _markFailed(companyId, fileId, '${e.code}: ${e.message}');
          failed++;
        } catch (e) {
          debugPrint('[Migration] Failed to index "$fileName": $e');
          await _markFailed(companyId, fileId, e.toString());
          failed++;
        } finally {
          if (await tempFile.exists()) await tempFile.delete();
        }
      }

      debugPrint(
        '[Migration] Reindex complete: '
        '$indexed indexed, $skipped skipped, $failed failed.',
      );
    } catch (e, stack) {
      debugPrint('[Migration] Error during reindex: $e\n$stack');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _updateIndexState(
    String companyId,
    String fileId,
    int count,
  ) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('files')
        .doc(fileId)
        .update({
          'isIndexed': count > 0,
          'indexedAt': FieldValue.serverTimestamp(),
          'chunkCount': count,
          'indexError': FieldValue.delete(), // clear any previous error
        });
  }

  Future<void> _markFailed(
    String companyId,
    String fileId,
    String error,
  ) async {
    try {
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('files')
          .doc(fileId)
          .update({'isIndexed': false, 'chunkCount': 0, 'indexError': error});
    } catch (_) {}
  }
}

/// Thrown when [FirebaseStorage] writeToFile times out.
class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}
