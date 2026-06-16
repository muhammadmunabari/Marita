import 'package:flutter_test/flutter_test.dart';
import 'package:marita/models/chunk_model.dart';
import 'package:marita/services/vector_search_service.dart';

void main() {
  group('VectorSearchService Tests', () {
    test('calculateCosineSimilarity identical vectors', () {
      final vecA = [1.0, 0.0, 0.0];
      final vecB = [1.0, 0.0, 0.0];

      final similarity = VectorSearchService.calculateCosineSimilarity(vecA, vecB);
      expect(similarity, closeTo(1.0, 0.0001));
    });

    test('calculateCosineSimilarity orthogonal vectors', () {
      final vecA = [1.0, 0.0, 0.0];
      final vecB = [0.0, 1.0, 0.0];

      final similarity = VectorSearchService.calculateCosineSimilarity(vecA, vecB);
      expect(similarity, closeTo(0.0, 0.0001));
    });

    test('calculateCosineSimilarity opposite vectors', () {
      final vecA = [1.0, 0.0];
      final vecB = [-1.0, 0.0];

      final similarity = VectorSearchService.calculateCosineSimilarity(vecA, vecB);
      expect(similarity, closeTo(-1.0, 0.0001));
    });

    test('search filters candidates correctly', () {
      final query = [1.0, 0.0];
      final candidates = [
        DocumentChunk(
          id: '1',
          documentId: 'doc1',
          content: 'Close match',
          embedding: [0.95, 0.05],
          pageNumber: 1,
        ),
        DocumentChunk(
          id: '2',
          documentId: 'doc1',
          content: 'Orthogonal match',
          embedding: [0.0, 1.0],
          pageNumber: 1,
        ),
      ];

      final results = VectorSearchService.search(query, candidates, threshold: 0.8, topK: 1);
      expect(results.length, 1);
      expect(results.first.id, '1');
    });
  });
}
