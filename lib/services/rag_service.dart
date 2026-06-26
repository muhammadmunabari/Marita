import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marita/models/chunk_model.dart';
import 'package:marita/services/vector_search_service.dart';

class RAGService {
  final FirebaseFirestore _firestore;

  RAGService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Retrieves relevant document chunks based on a query embedding or text keywords.
  Future<List<DocumentChunk>> retrieveRelevantContext({
    required String workspaceId,
    required List<double> queryEmbedding,
    String query = '',
    int topK = 8,
    double similarityThreshold = 0.7,
  }) async {
    try {
      // Query all chunks for documents in the specific workspace.
      final docSnapshots =
          await _firestore
              .collection('companies')
              .doc(workspaceId)
              .collection('files')
              .get();

      print("  │  [RAG DEBUG] Files in workspace: ${docSnapshots.docs.length}");

      final List<DocumentChunk> allChunks = [];

      for (final doc in docSnapshots.docs) {
        final chunkSnapshots = await doc.reference.collection('chunks').get();
        print(
          "  │  [RAG DEBUG] File '${doc.id}' has ${chunkSnapshots.docs.length} chunks",
        );
        for (final chunkDoc in chunkSnapshots.docs) {
          try {
            final chunkData = chunkDoc.data();
            allChunks.add(
              DocumentChunk.fromMap({
                ...chunkData,
                'id': chunkDoc.id,
                'documentId': doc.id,
              }),
            );
          } catch (_) {
            // Skip invalid chunk records
          }
        }
      }

      print("  │  [RAG DEBUG] Total chunks loaded: ${allChunks.length}");

      // Check if we should use keyword-based fallback search
      if (queryEmbedding.isEmpty && query.isNotEmpty) {
        final stopwords = {
          'what',
          'is',
          'are',
          'the',
          'a',
          'an',
          'to',
          'for',
          'in',
          'of',
          'and',
          'or',
          'on',
          'with',
          'by',
          'at',
          'from',
          'this',
          'that',
          'these',
          'those',
          'it',
          'its',
          'we',
          'our',
          'you',
          'your',
          'they',
          'their',
          'he',
          'she',
          'him',
          'her',
          'was',
          'were',
          'be',
          'been',
          'have',
          'has',
          'had',
          'do',
          'does',
          'did',
          'but',
          'if',
          'then',
          'else',
          'because',
          'as',
          'until',
          'while',
          'about',
          'against',
          'between',
          'into',
          'through',
          'during',
          'before',
          'after',
          'above',
          'below',
          'up',
          'down',
          'out',
          'off',
          'over',
          'under',
          'again',
          'further',
          'once',
          'here',
          'there',
          'when',
          'where',
          'why',
          'how',
          'all',
          'any',
          'both',
          'each',
          'few',
          'more',
          'most',
          'other',
          'some',
          'such',
          'no',
          'nor',
          'not',
          'only',
          'own',
          'same',
          'so',
          'than',
          'too',
          'very',
          's',
          't',
          'can',
          'will',
          'just',
          'don',
          'should',
          'now'
        };

        final cleanQuery = query.toLowerCase().replaceAll(
          RegExp(r'[^\w\s]'),
          ' ',
        );
        final keywords =
            cleanQuery
                .split(RegExp(r'\s+'))
                .where((w) => w.length > 2 && !stopwords.contains(w))
                .toSet() // Deduplicate
                .take(20) // Cap to first 20 meaningful keywords
                .toList();

        print(
          "  │  [RAG DEBUG] Keywords (${keywords.length}): ${keywords.join(', ')}",
        );

        if (keywords.isNotEmpty) {
          final ratedChunks = <MapEntry<DocumentChunk, double>>[];
          for (final chunk in allChunks) {
            final contentLower = chunk.content.toLowerCase();
            int matchCount = 0;
            for (final kw in keywords) {
              if (contentLower.contains(kw)) {
                matchCount++;
              }
            }
            if (matchCount > 0) {
              final score = matchCount / keywords.length;
              ratedChunks.add(MapEntry(chunk, score));
            }
          }
          // Sort descending by match score
          ratedChunks.sort((a, b) => b.value.compareTo(a.value));
          final results =
              ratedChunks.map((entry) => entry.key).take(topK).toList();
          print(
            "  │  [RAG DEBUG] Keyword-scored chunks: ${ratedChunks.length}, returning top ${results.length}",
          );
          return results;
        }
      }

      // Perform local vector search over workspace candidates
      final bestChunks = VectorSearchService.search(
        queryEmbedding,
        allChunks,
        threshold: similarityThreshold,
        topK: topK,
      );

      return bestChunks;
    } catch (e) {
      // Return empty context if there are failures, adhering to RAG fallback guidelines
      print("  │  [RAG ERROR] Failed to retrieve chunks: $e");
      return [];
    }
  }

  /// Builds context string from retrieved chunks to be injected into the prompt.
  String buildContextString(List<DocumentChunk> chunks) {
    if (chunks.isEmpty) {
      return "No additional source document context found.";
    }

    final sb = StringBuffer();
    sb.writeln("=== RETRIEVED SOURCE CONTEXT ===");
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      // Prefer top-level fileName, fall back to metadata for older chunks
      final sourceName =
          chunk.fileName.isNotEmpty
              ? chunk.fileName
              : (chunk.metadata['fileName'] as String? ?? 'Unknown');
      sb.writeln("Source [${i + 1}] — $sourceName, Halaman ${chunk.pageNumber}:");
      sb.writeln(chunk.content);
      sb.writeln("-----------------------------------------");
    }
    return sb.toString();
  }
}
