import 'package:flutter_test/flutter_test.dart';
import 'package:marita/services/ai_pipeline_service.dart';

void main() {
  group('PromptRouter Tests', () {
    test('routes fraud-related queries to fraudDetection', () {
      final query = 'Detect potential fraud in this spreadsheet or calculate the Beneish score.';
      final route = PromptRouter.route(query);
      expect(route, QueryType.fraudDetection);
    });

    test('routes balance/revenue queries to financialAnalysis', () {
      final query = 'Explain the revenue growth and balance sheet ratio trends.';
      final route = PromptRouter.route(query);
      expect(route, QueryType.financialAnalysis);
    });

    test('routes audit queries to auditRequest', () {
      final query = 'Perform a tax compliance audit verify check.';
      final route = PromptRouter.route(query);
      expect(route, QueryType.auditRequest);
    });

    test('routes other queries to general', () {
      final query = 'Hello, how can you help me today?';
      final route = PromptRouter.route(query);
      expect(route, QueryType.general);
    });
  });
}
