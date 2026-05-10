import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marita/models/prompt_template.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class TemplateService {
  static final _firestore = FirebaseFirestore.instance;

  static List<PromptTemplate> getStaticTemplates() {
    return [
      const PromptTemplate(
        id: 'fraud_analysis',
        title: 'Fraud Risk Analysis',
        description: 'Analyze transaction patterns for potential fraud indicators.',
        prompt: 'Analyze the following transaction data for potential fraud indicators. Look for unusual frequency, amount spikes, or suspicious geographic patterns: ',
        icon: IconsaxPlusLinear.shield_search,
      ),
      const PromptTemplate(
        id: 'anomaly_detection',
        title: 'Detect Anomalies',
        description: 'Identify statistical outliers in your financial datasets.',
        prompt: 'Identify statistical anomalies in this financial dataset. Focus on outliers that exceed standard deviation thresholds: ',
        icon: IconsaxPlusLinear.graph,
      ),
      const PromptTemplate(
        id: 'budget_review',
        title: 'Budget Compliance',
        description: 'Check if expenditures align with established budget limits.',
        prompt: 'Review these expenditures against the provided budget limits. Flag any overruns or suspicious misallocations: ',
        icon: IconsaxPlusLinear.receipt_item,
      ),
      const PromptTemplate(
        id: 'audit_prep',
        title: 'Audit Preparation',
        description: 'Summarize financial documents for internal or external audits.',
        prompt: 'Prepare a summary of these financial documents for an audit. Categorize by risk level and provide a high-level overview: ',
        icon: IconsaxPlusLinear.document_favorite,
      ),
      const PromptTemplate(
        id: 'startup_runway',
        title: 'Burn Rate & Runway',
        description: 'Calculate burn rate and project remaining startup runway.',
        prompt: 'Calculate the monthly burn rate and projected runway based on the following cash flow data: ',
        icon: IconsaxPlusLinear.flash,
      ),
    ];
  }

  /// Fetches custom templates for a specific user from Firestore.
  static Future<List<PromptTemplate>> getCustomTemplates(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_templates')
          .get();

      return snapshot.docs
          .map((doc) => PromptTemplate.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Saves a new custom template to Firestore.
  static Future<bool> saveCustomTemplate(String userId, PromptTemplate template) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_templates')
          .doc(template.id)
          .set(template.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }
}
