import 'dart:math';
import 'package:marita/models/chunk_model.dart';

class VectorSearchService {
  /// Calculates the cosine similarity between two vectors.
  static double calculateCosineSimilarity(
    List<double> vectorA,
    List<double> vectorB,
  ) {
    if (vectorA.isEmpty ||
        vectorB.isEmpty ||
        vectorA.length != vectorB.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Performs semantic search over a list of chunks given a query embedding vector.
  static List<DocumentChunk> search(
    List<double> queryVector,
    List<DocumentChunk> candidates, {
    double threshold = 0.7,
    int topK = 5,
  }) {
    final results = <MapEntry<DocumentChunk, double>>[];

    for (final chunk in candidates) {
      final similarity = calculateCosineSimilarity(
        queryVector,
        chunk.embedding,
      );
      if (similarity >= threshold) {
        results.add(MapEntry(chunk, similarity));
      }
    }

    // Sort by similarity descending
    results.sort((a, b) => b.value.compareTo(a.value));

    return results.map((entry) => entry.key).take(topK).toList();
  }
}
