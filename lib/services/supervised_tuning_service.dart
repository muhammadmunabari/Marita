import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisedTuningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Logs a training example to Firestore for supervised fine-tuning dataset aggregation.
  Future<void> logTrainingExample({
    required String workspaceId,
    required String prompt,
    required String response,
    required String context,
    required String domain, // e.g., 'accounting', 'fraud', 'auditing'
    double userFeedbackRating = 1.0, // 1.0 for positive, 0.0 for negative
  }) async {
    try {
      await _firestore.collection('supervised_tuning_dataset').add({
        'workspaceId': workspaceId,
        'prompt': prompt,
        'response': response,
        'context': context,
        'domain': domain,
        'rating': userFeedbackRating,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Fail silently to prevent interrupting main user thread, adhering to logging/observability guidelines
    }
  }

  /// Exports the logged training datasets in Vertex AI JSONL format.
  Future<String> exportToJsonlFormat({required String domain}) async {
    try {
      final snap =
          await _firestore
              .collection('supervised_tuning_dataset')
              .where('domain', isEqualTo: domain)
              .where(
                'rating',
                isGreaterThanOrEqualTo: 0.5,
              ) // Export positive reviews
              .get();

      final sb = StringBuffer();
      for (final doc in snap.docs) {
        final data = doc.data();
        final example = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      'Context:\n${data['context']}\n\nQuestion: ${data['prompt']}',
                },
              ],
            },
            {
              'role': 'model',
              'parts': [
                {'text': data['response']},
              ],
            },
          ],
        };
        sb.writeln(jsonEncode(example));
      }
      return sb.toString();
    } catch (e) {
      return 'Error exporting dataset: $e';
    }
  }
}
