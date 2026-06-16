import 'package:cloud_firestore/cloud_firestore.dart';

class EvaluationMetrics {
  final double precision;        // 0.0 to 1.0 (accuracy vs ground truth)
  final double hallucinationRate; // 0.0 to 1.0 (unverified claims ratio)
  final double retrievalRecall;     // 0.0 to 1.0 (relevance hit rate)
  final int latencyMs;
  final int tokenCount;

  EvaluationMetrics({
    required this.precision,
    required this.hallucinationRate,
    required this.retrievalRecall,
    required this.latencyMs,
    required this.tokenCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'precision': precision,
      'hallucinationRate': hallucinationRate,
      'retrievalRecall': retrievalRecall,
      'latencyMs': latencyMs,
      'tokenCount': tokenCount,
    };
  }
}

class EvaluationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Logs a run evaluation metric set to Firestore.
  Future<void> logEvaluation({
    required String queryId,
    required String workspaceId,
    required EvaluationMetrics metrics,
  }) async {
    try {
      await _firestore
          .collection('companies')
          .doc(workspaceId)
          .collection('evaluations')
          .doc(queryId)
          .set({
        ...metrics.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Avoid interrupting the main pipeline on logging errors
    }
  }

  /// Calculates aggregated performance metrics.
  Future<Map<String, dynamic>> getAggregatedMetrics({
    required String workspaceId,
  }) async {
    try {
      final snap = await _firestore
          .collection('companies')
          .doc(workspaceId)
          .collection('evaluations')
          .get();

      if (snap.docs.isEmpty) {
        return {
          'averagePrecision': 1.0,
          'averageHallucinationRate': 0.0,
          'averageRetrievalRecall': 1.0,
          'averageLatencyMs': 0,
          'totalEvaluations': 0,
        };
      }

      double totalPrecision = 0.0;
      double totalHallucination = 0.0;
      double totalRecall = 0.0;
      int totalLatency = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        totalPrecision += (data['precision'] ?? 1.0) as num;
        totalHallucination += (data['hallucinationRate'] ?? 0.0) as num;
        totalRecall += (data['retrievalRecall'] ?? 1.0) as num;
        totalLatency += (data['latencyMs'] ?? 0) as int;
      }

      final count = snap.docs.length;
      return {
        'averagePrecision': totalPrecision / count,
        'averageHallucinationRate': totalHallucination / count,
        'averageRetrievalRecall': totalRecall / count,
        'averageLatencyMs': totalLatency ~/ count,
        'totalEvaluations': count,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
