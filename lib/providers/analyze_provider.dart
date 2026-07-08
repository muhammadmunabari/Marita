// =============================================================================
// ANALYZE PROVIDER — Riverpod state for the Analyze Screen
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analyze_models.dart';
import '../models/file_item.dart';
import '../providers/auth_provider.dart';
import '../providers/file_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/analyze_service.dart';
import '../services/rag_service.dart';
import '../core/result.dart';

// ---------------------------------------------------------------------------
// Service providers
// ---------------------------------------------------------------------------

final ragServiceProvider = Provider<RAGService>((ref) => RAGService());

final analyzeServiceProvider = Provider<AnalyzeService>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final ragService = ref.watch(ragServiceProvider);
  return AnalyzeService(
    ragService: ragService,
    firestoreService: firestoreService,
  );
});

// ---------------------------------------------------------------------------
// AnalyzeNotifier
// ---------------------------------------------------------------------------

class AnalyzeNotifier extends Notifier<AnalyzeState> {
  @override
  AnalyzeState build() {
    // Get initial files
    final filesResult = ref.read(allWorkspaceFilesProvider).asData?.value;
    final files = (filesResult is Success<List<FileItem>>)
        ? filesResult.data.where((f) => !f.isFolder).toList()
        : const <FileItem>[];
    
    final entries = files.map((f) => FileAnalysisEntry(file: f)).toList();
    
    // Listen for changes to automatically update entries and run analysis
    ref.listen(allWorkspaceFilesProvider, (previous, next) {
      final newFilesResult = next.asData?.value;
      if (newFilesResult is Success<List<FileItem>>) {
        final newFiles = newFilesResult.data;
        _updateFilesAndAnalyze(newFiles);
      }
    });
    
    return AnalyzeState(fileEntries: entries);
  }

  void _updateFilesAndAnalyze(List<FileItem> newFiles) {
    bool hasNewFiles = false;
    final currentEntries = List<FileAnalysisEntry>.from(state.fileEntries);
    
    for (final file in newFiles) {
      if (file.isFolder) continue; // Ignore folder items
      
      final exists = currentEntries.any((e) => e.file.id == file.id);
      if (!exists) {
        currentEntries.add(FileAnalysisEntry(file: file));
        hasNewFiles = true;
      }
    }
    
    if (hasNewFiles) {
      state = state.copyWith(fileEntries: currentEntries);
      if (state.status != AnalysisStatus.running) {
        // Automatically start analysis for new files
        runAllAnalysis(forceFresh: false);
      }
    }
  }

  void _updateEntry(int index, FileAnalysisEntry entry) {
    final newEntries = List<FileAnalysisEntry>.from(state.fileEntries);
    newEntries[index] = entry;
    state = state.copyWith(fileEntries: newEntries);
  }

  // ── Run analysis on all workspace files sequentially ───────────────────────
  Future<void> runAllAnalysis({bool forceFresh = false}) async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final analyzeService = ref.read(analyzeServiceProvider);

    if (state.fileEntries.isEmpty) {
      state = state.copyWith(
        status: AnalysisStatus.error,
        errorMessage: 'No files to analyze in this workspace.',
      );
      return;
    }

    state = state.copyWith(status: AnalysisStatus.running, errorMessage: null);

    const kStageTitles = [
      'File Identification',
      'Document Intelligence',
      'Document Matching',
      'Transaction Risk Assessment',
      'Anomaly Detection',
      "Benford's Law Analysis",
      'Financial Statement Risk',
      'Beneish M-Score',
      'Entity Risk Assessment',
      'Organization Risk Assessment',
      'Explainable AI',
      'Audit Findings',
      'Recommendations',
      'Executive Summary',
    ];

    for (int i = 0; i < state.fileEntries.length; i++) {
      state = state.copyWith(currentFileIndex: i);
      
      final entry = state.fileEntries[i];
      
      // If already completed in the current session, skip entirely
      if (entry.status == AnalysisStatus.completed && !forceFresh) {
        continue;
      }
      
      final fileId = entry.file.id;

      // ── Check Firestore cache first (unless forcing fresh) ───────────────
      if (!forceFresh) {
        final cached = await analyzeService.getCachedResult(workspace.id, fileId);
        if (cached != null) {
          final updatedEntry = entry.copyWith(
            status: AnalysisStatus.completed,
            result: cached,
            stages: cached.stages,
            fromCache: true,
          );
          _updateEntry(i, updatedEntry);
          continue;
        }
      }

      // ── Build initial pending stages ─────────────────────────────────────
      final initialStages = List.generate(
        14,
        (idx) => AnalysisPipelineStage(
          stageNumber: idx + 1,
          title: kStageTitles[idx],
          status: AnalysisStepStatus.pending,
        ),
      );

      _updateEntry(i, entry.copyWith(
        status: AnalysisStatus.running,
        stages: initialStages,
        errorMessage: null,
      ));

      // ── Stream pipeline events ───────────────────────────────────────────
      final updatedStages = List<AnalysisPipelineStage>.from(initialStages);

      try {
        await for (final stageUpdate in analyzeService.runAnalysis(
          companyId: workspace.id,
          fileId: fileId,
          fileName: entry.file.name,
          userId: user.uid,
        )) {
          final idx = stageUpdate.stageNumber - 1;
          updatedStages[idx] = stageUpdate;
          _updateEntry(i, state.fileEntries[i].copyWith(stages: List.from(updatedStages)));
        }

        // Fetch the completed result from Firestore
        final result = await analyzeService.getCachedResult(workspace.id, fileId);
        _updateEntry(i, state.fileEntries[i].copyWith(
          status: result != null ? AnalysisStatus.completed : AnalysisStatus.error,
          result: result,
          stages: List.from(updatedStages),
          errorMessage: result == null ? 'Analysis completed but result not found.' : null,
          fromCache: false,
        ));
      } catch (e) {
        _updateEntry(i, state.fileEntries[i].copyWith(
          status: AnalysisStatus.error,
          stages: List.from(updatedStages),
          errorMessage: e.toString(),
        ));
      }
    }

    // ── All files processed ──────────────────────────────────────────────────
    state = state.copyWith(
      status: AnalysisStatus.completed,
      currentFileIndex: -1,
    );
  }
}

/// Main provider for the Analyze screen.
final analyzeProvider = NotifierProvider<AnalyzeNotifier, AnalyzeState>(
  AnalyzeNotifier.new,
);
