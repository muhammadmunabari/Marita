import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chunk_model.dart';
import 'document_extraction_service.dart';

/// Sliding-window chunker.
///
/// Splits extracted text into overlapping chunks and batch-writes them to
/// Firestore at the path:
///   companies/{companyId}/files/{fileId}/chunks/{chunkId}
///
/// Option B: also persists `extractedText` on the file document so
/// [MigrationService.reindexWorkspaceFiles] can re-chunk without re-downloading
/// from Firebase Storage.
class DocumentChunkerService {
  static const int _chunkSize = 2000; // characters per chunk
  static const int _chunkOverlap = 200; // overlap between consecutive chunks

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  DocumentChunkerService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Extracts text from [file], chunks it, writes chunks to Firestore,
  /// and **persists the raw `extractedText`** on the file doc for future
  /// re-indexing without needing to re-download the file.
  ///
  /// Returns the number of chunks saved, or 0 on failure.
  Future<int> processAndChunk({
    required String companyId,
    required String fileId,
    required File file,
    required String fileName,
  }) async {
    try {
      debugPrint('[Chunker] Extracting text from "$fileName"…');
      final pages = await DocumentExtractionService.extractText(
        file.path,
        fileName,
      );

      if (pages.isEmpty) {
        debugPrint('[Chunker] No text extracted from "$fileName", skipping.');
        return 0;
      }

      // Combine all pages into a single raw text string for storage (Option B)
      final rawText = pages.map((p) => p.text).join('\n');

      final chunks = chunkText(rawText, fileName, fileId);
      if (chunks.isEmpty) {
        debugPrint('[Chunker] No chunks generated for "$fileName".');
        return 0;
      }

      debugPrint('[Chunker] Saving ${chunks.length} chunks for "$fileName"…');
      await saveChunksDirectly(
        companyId: companyId,
        fileId: fileId,
        chunks: chunks,
      );

      // Persist raw extracted text on the file doc so reindex can avoid
      // re-downloading from Storage (Option B)
      try {
        await _db
            .collection('companies')
            .doc(companyId)
            .collection('files')
            .doc(fileId)
            .update({'extractedText': rawText});
      } catch (e) {
        // Non-fatal — chunking succeeded, text storage is best-effort
        debugPrint(
          '[Chunker] Could not persist extractedText for "$fileName": $e',
        );
      }

      debugPrint('[Chunker] ✓ Saved ${chunks.length} chunks for "$fileName".');
      return chunks.length;
    } catch (e, stack) {
      debugPrint('[Chunker] Error processing "$fileName": $e\n$stack');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Public chunking helpers (exposed for Option B reindex path)
  // ---------------------------------------------------------------------------

  /// Splits [rawText] into overlapping [DocumentChunk]s using the sliding-
  /// window algorithm.  Does NOT write to Firestore — call [saveChunksDirectly]
  /// afterwards.
  List<DocumentChunk> chunkText(
    String rawText,
    String fileName,
    String fileId,
  ) {
    final chunks = <DocumentChunk>[];
    final text = rawText.trim();
    if (text.isEmpty) return chunks;

    int chunkIndex = 0;
    int start = 0;

    while (start < text.length) {
      final end = (start + _chunkSize).clamp(0, text.length);
      final excerpt = text.substring(start, end).trim();

      if (excerpt.isNotEmpty) {
        chunks.add(
          DocumentChunk(
            id: _uuid.v4(),
            fileId: fileId,
            fileName: fileName,
            content: excerpt,
            pageNumber: 1, // page-level detail not available from raw text
            chunkIndex: chunkIndex,
            embedding: [],
            metadata: {'startChar': start, 'endChar': end},
          ),
        );
        chunkIndex++;
      }

      start += _chunkSize - _chunkOverlap;
      if (start >= text.length) break;
    }

    return chunks;
  }

  /// Batch-writes [chunks] to Firestore at
  /// `companies/{companyId}/files/{fileId}/chunks/`.
  ///
  /// Returns the number of chunks saved.
  Future<int> saveChunksDirectly({
    required String companyId,
    required String fileId,
    required List<DocumentChunk> chunks,
  }) async {
    if (chunks.isEmpty) return 0;

    const batchLimit = 400;
    final collectionRef = _db
        .collection('companies')
        .doc(companyId)
        .collection('files')
        .doc(fileId)
        .collection('chunks');

    for (int i = 0; i < chunks.length; i += batchLimit) {
      final batch = _db.batch();
      final slice = chunks.sublist(i, (i + batchLimit).clamp(0, chunks.length));

      for (final chunk in slice) {
        final docRef = collectionRef.doc(chunk.id);
        batch.set(docRef, chunk.toMap());
      }

      await batch.commit();
    }

    return chunks.length;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Deletes all chunks for a given file (call before re-indexing).
  Future<void> deleteChunks({
    required String companyId,
    required String fileId,
  }) async {
    final snapshot =
        await _db
            .collection('companies')
            .doc(companyId)
            .collection('files')
            .doc(fileId)
            .collection('chunks')
            .get();

    if (snapshot.docs.isEmpty) return;

    const batchLimit = 400;
    for (int i = 0; i < snapshot.docs.length; i += batchLimit) {
      final batch = _db.batch();
      final slice = snapshot.docs.sublist(
        i,
        (i + batchLimit).clamp(0, snapshot.docs.length),
      );
      for (final doc in slice) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    debugPrint(
      '[Chunker] Deleted ${snapshot.docs.length} existing chunks for file $fileId.',
    );
  }
}
