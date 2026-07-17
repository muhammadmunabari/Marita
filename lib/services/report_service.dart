import '../models/report_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'gemini_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Future<ReportModel> generateReport({
    required String workspaceId,
    required String chatId,
    required String messageId,
    required String responseContent,
    required int responseVersion,
  }) async {
    final reportId = _uuid.v4();
    
    // Call Gemini to generate the markdown report
    String content;
    try {
      content = await GeminiService.generateContent(
        prompt: 'Convert the following analysis response into a detailed, professional Markdown report with sections like Executive Summary, Key Findings, Detailed Analysis, and Recommendations. Make sure the content is highly detailed and well-structured. Do NOT include the current date, date of analysis, or any generated timestamps in the report. IMPORTANT: The report MUST be written in the exact same language as the analysis response provided below.\n\nResponse to convert:\n$responseContent',
        modelName: GeminiService.mainModelName,
      );
    } catch (e) {
      throw Exception('Failed to generate report from AI: $e');
    }

    final report = ReportModel(
      reportId: reportId,
      chatId: chatId,
      messageId: messageId,
      responseVersion: responseVersion,
      reportVersion: 1, // Start at 1
      status: ReportStatus.ready,
      content: content,
      generatedAt: DateTime.now(),
    );

    await _firestore
        .collection('companies')
        .doc(workspaceId)
        .collection('chats')
        .doc(chatId)
        .collection('reports')
        .doc(reportId)
        .set(report.toMap());

    return report;
  }

  Future<ReportModel?> getLatestReport({
    required String workspaceId,
    required String chatId,
    required String messageId,
  }) async {
    final snapshot = await _firestore
        .collection('companies')
        .doc(workspaceId)
        .collection('chats')
        .doc(chatId)
        .collection('reports')
        .where('messageId', isEqualTo: messageId)
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return ReportModel.fromMap(snapshot.docs.first.data());
  }

  Future<void> markReportOutdated({
    required String workspaceId,
    required String chatId,
    required String reportId,
  }) async {
    await _firestore
        .collection('companies')
        .doc(workspaceId)
        .collection('chats')
        .doc(chatId)
        .collection('reports')
        .doc(reportId)
        .update({'status': ReportStatus.outdated.name});
  }

  Future<void> saveShareUrl({
    required String workspaceId,
    required String chatId,
    required String reportId,
    required String shareUrl,
  }) async {
    await _firestore
        .collection('companies')
        .doc(workspaceId)
        .collection('chats')
        .doc(chatId)
        .collection('reports')
        .doc(reportId)
        .update({'shareUrl': shareUrl});
  }

  Future<List<ReportModel>> getAllReportsForMessages({
    required String workspaceId,
    required String chatId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return [];
    
    // Firestore whereIn supports up to 30 elements
    final chunks = <List<String>>[];
    for (var i = 0; i < messageIds.length; i += 30) {
      chunks.add(
        messageIds.sublist(i, i + 30 > messageIds.length ? messageIds.length : i + 30),
      );
    }
    
    final allReports = <ReportModel>[];
    
    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('companies')
          .doc(workspaceId)
          .collection('chats')
          .doc(chatId)
          .collection('reports')
          .where('messageId', whereIn: chunk)
          .get();
          
      allReports.addAll(
        snapshot.docs.map((doc) => ReportModel.fromMap(doc.data())).toList(),
      );
    }
    
    // Sort all reports descending by generatedAt
    allReports.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    
    return allReports;
  }
}
