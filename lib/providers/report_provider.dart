// =============================================================================
// REPORT PROVIDERS — Riverpod
// =============================================================================
//
// Provides report data and actions to the widget tree.
//
// Providers:
//   - firestoreServiceProvider   → singleton FirestoreService instance
//   - companyReportsProvider     → real-time reports stream for a company
//   - reportDetailProvider       → real-time single report stream
//   - reportProvider             → StateNotifier for a specific report/message
//
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';
import 'workspace_provider.dart';
import 'chat_provider.dart';

/// Real-time stream of reports for a specific company.
///
/// Uses the composite index: companyId + createdAt DESC.
///
/// Usage:
/// ```dart
/// final reports = ref.watch(companyReportsProvider(companyId));
/// ```
final companyReportsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, companyId) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.watchCompanyReports(companyId);
    });

/// Real-time stream of a single report by ID.
///
/// Useful for live status tracking (pending → processing → completed).
///
/// Usage:
/// ```dart
/// final report = ref.watch(reportDetailProvider(reportId));
/// ```
final reportDetailProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, reportId) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.watchReport(reportId);
    });

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

class ReportState {
  final ReportModel? report;
  final ReportStatus status;
  final String? error;
  final List<ReportModel> allVersions;
  final int currentVersionIndex;

  ReportState({
    this.report,
    this.status = ReportStatus.generating,
    this.error,
    this.allVersions = const [],
    this.currentVersionIndex = 0,
  });

  ReportState copyWith({
    ReportModel? report,
    ReportStatus? status,
    String? error,
    List<ReportModel>? allVersions,
    int? currentVersionIndex,
  }) {
    return ReportState(
      report: report ?? this.report,
      status: status ?? this.status,
      error: error ?? this.error,
      allVersions: allVersions ?? this.allVersions,
      currentVersionIndex: currentVersionIndex ?? this.currentVersionIndex,
    );
  }
}

class ReportNotifier extends Notifier<ReportState> {
  final String messageId;

  ReportNotifier(this.messageId);

  @override
  ReportState build() {
    _init();
    return ReportState();
  }

  Future<void> _init() async {
    await _loadReports();
  }

  Future<void> _loadReports() async {
    final workspace = ref.read(activeWorkspaceProvider);
    final workspaceId = workspace?.id ?? 'unknown-workspace-id';
    final chatState = ref.read(chatProvider);
    final chatId = chatState.chatId ?? 'unknown-chat-id';
    
    try {
      final service = ref.read(reportServiceProvider);
      // Let's assume we fetch all reports for this message to allow version navigation
      // But service currently only has getLatestReport. 
      // We'll update the state with the latest report for now and simulate versioning.
      
      final report = await service.getLatestReport(
        workspaceId: workspaceId,
        chatId: chatId,
        messageId: messageId,
      );

      if (report != null) {
        state = state.copyWith(
          report: report, 
          status: report.status,
          allVersions: [report], // In a real implementation, we would query all versions
          currentVersionIndex: 0,
        );
      } else {
        state = state.copyWith(status: ReportStatus.generating);
        
        String? responseContent;
        int responseVersion = 1;
        for (final group in chatState.messageGroups) {
          for (final response in group.responseVersions) {
            if (response.id == messageId) {
              responseContent = response.text;
              responseVersion = response.version;
              break;
            }
          }
        }
        
        if (responseContent == null) {
          throw Exception("Target message for the report could not be found.");
        }
        
        final newReport = await service.generateReport(
          workspaceId: workspaceId,
          chatId: chatId,
          messageId: messageId,
          responseContent: responseContent, 
          responseVersion: responseVersion, 
        );
        state = state.copyWith(
          report: newReport, 
          status: newReport.status,
          allVersions: [newReport],
          currentVersionIndex: 0,
        );
      }
    } catch (e) {
      state = state.copyWith(status: ReportStatus.error, error: e.toString());
    }
  }

  Future<void> regenerateReport() async {
    state = state.copyWith(status: ReportStatus.generating);
    final workspace = ref.read(activeWorkspaceProvider);
    final workspaceId = workspace?.id ?? 'unknown-workspace-id';
    final chatState = ref.read(chatProvider);
    final chatId = chatState.chatId ?? 'unknown-chat-id';
    
    try {
      final service = ref.read(reportServiceProvider);
      
      String? responseContent;
      for (final group in chatState.messageGroups) {
        for (final response in group.responseVersions) {
          if (response.id == messageId) {
            responseContent = response.text;
            break;
          }
        }
      }
      
      if (responseContent == null) {
        throw Exception("Target message for the report could not be found.");
      }
      
      final newReport = await service.generateReport(
        workspaceId: workspaceId,
        chatId: chatId,
        messageId: messageId,
        responseContent: responseContent, 
        responseVersion: (state.report?.responseVersion ?? 1) + 1, 
      );
      
      final updatedVersions = [newReport, ...state.allVersions];
      state = state.copyWith(
        report: newReport,
        status: newReport.status,
        allVersions: updatedVersions,
        currentVersionIndex: 0,
      );
    } catch (e) {
      state = state.copyWith(status: ReportStatus.error, error: e.toString());
    }
  }

  void previousVersion() {
    if (state.currentVersionIndex < state.allVersions.length - 1) {
      final newIndex = state.currentVersionIndex + 1;
      state = state.copyWith(
        currentVersionIndex: newIndex,
        report: state.allVersions[newIndex],
        status: state.allVersions[newIndex].status,
      );
    }
  }

  void nextVersion() {
    if (state.currentVersionIndex > 0) {
      final newIndex = state.currentVersionIndex - 1;
      state = state.copyWith(
        currentVersionIndex: newIndex,
        report: state.allVersions[newIndex],
        status: state.allVersions[newIndex].status,
      );
    }
  }
}

final reportProvider = NotifierProvider.family<ReportNotifier, ReportState, String>(
  (messageId) => ReportNotifier(messageId),
);
