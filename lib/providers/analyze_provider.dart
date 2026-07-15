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
  final String workspaceId;
  AnalyzeNotifier(this.workspaceId);

  @override
  AnalyzeState build() {
    // Read the files initially (do not watch, to avoid rebuilds of state)
    final filesResult = ref.read(allWorkspaceFilesProvider).asData?.value;
    final files = (filesResult is Success<List<FileItem>>)
        ? filesResult.data.where((f) => !f.isFolder).toList()
        : const <FileItem>[];

    final entries = files.map((f) => FileAnalysisEntry(file: f)).toList();

    // Listen for file changes to keep the list synced (no auto-audit run)
    ref.listen(allWorkspaceFilesProvider, (previous, next) {
      final newFilesResult = next.asData?.value;
      if (newFilesResult is Success<List<FileItem>>) {
        _syncFileList(newFilesResult.data);
      }
    });

    return AnalyzeState(
      fileEntries: entries,
      workspaceId: workspaceId,
    );
  }

  void _syncFileList(List<FileItem> newFiles) {
    final nonFolders = newFiles.where((f) => !f.isFolder).toList();
    final currentEntries = List<FileAnalysisEntry>.from(state.fileEntries);
    final updatedEntries = <FileAnalysisEntry>[];

    for (final file in nonFolders) {
      final existingIndex = currentEntries.indexWhere((e) => e.file.id == file.id);
      if (existingIndex != -1) {
        final existingEntry = currentEntries[existingIndex];
        updatedEntries.add(existingEntry.copyWith(file: file));
      } else {
        updatedEntries.add(FileAnalysisEntry(file: file));
      }
    }

    state = state.copyWith(fileEntries: updatedEntries);
  }

  void _updateEntry(int index, FileAnalysisEntry entry) {
    final newEntries = List<FileAnalysisEntry>.from(state.fileEntries);
    newEntries[index] = entry;
    state = state.copyWith(fileEntries: newEntries);
  }

  // ── Run analysis on all workspace files sequentially ───────────────────────
  Future<void> runAllAnalysis({bool forceFresh = false}) async {
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
        final cachedHash = await analyzeService.getCachedContentHash(state.workspaceId, fileId);
        final currentHash = entry.file.contentHash;
        final isUnmodified = currentHash != null && cachedHash != null && currentHash == cachedHash;

        if (isUnmodified) {
          final cached = await analyzeService.getCachedResult(state.workspaceId, fileId);
          if (cached != null) {
            final updatedEntry = entry.copyWith(
              status: AnalysisStatus.completed,
              result: cached,
              stages: cached.stages,
              fromCache: true,
              auditedContentHash: cachedHash,
            );
            _updateEntry(i, updatedEntry);
            continue;
          }
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
        AnalysisResult? streamedResult;
        await for (final stageUpdate in analyzeService.runAnalysis(
          companyId: state.workspaceId,
          fileId: fileId,
          fileName: entry.file.name,
          userId: user.uid,
          contentHash: entry.file.contentHash,
        )) {
          final idx = stageUpdate.stageNumber - 1;
          updatedStages[idx] = stageUpdate;
          if (stageUpdate.result != null) {
            streamedResult = stageUpdate.result;
          }
          _updateEntry(i, state.fileEntries[i].copyWith(stages: List.from(updatedStages)));
        }

        // Fetch the completed result from Firestore
        final result = streamedResult ?? await analyzeService.getCachedResult(state.workspaceId, fileId);
        final currentHash = entry.file.contentHash;
        _updateEntry(i, state.fileEntries[i].copyWith(
          status: result != null ? AnalysisStatus.completed : AnalysisStatus.error,
          result: result,
          stages: List.from(updatedStages),
          errorMessage: result == null ? 'Analysis completed but result not found.' : null,
          fromCache: false,
          auditedContentHash: currentHash,
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
final analyzeProvider = NotifierProvider.family<AnalyzeNotifier, AnalyzeState, String>(
  (workspaceId) => AnalyzeNotifier(workspaceId),
);
