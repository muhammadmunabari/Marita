// =============================================================================
// ANALYZE SCREEN — AI Risk Intelligence Engine UI (Batch Mode)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/analysis_pipeline_step.dart';
import '../../components/audit_finding_card.dart';
import '../../components/risk_level_badge.dart';
import '../../components/risk_score_gauge.dart';
import '../../design_system/marita_design_system.dart';
import '../../models/analyze_models.dart';
import '../../models/file_item.dart';
import '../../providers/analyze_provider.dart';

class AnalyzeScreen extends ConsumerWidget {
  const AnalyzeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyzeProvider);

    return Scaffold(
      backgroundColor: SemanticColors.colorBackgroundCanvas,
      body: SafeArea(
        child: switch (state.status) {
          AnalysisStatus.idle => _IdleView(state: state),
          AnalysisStatus.running => _RunningView(state: state),
          AnalysisStatus.completed => _CompletedView(state: state),
          AnalysisStatus.error => _ErrorView(state: state),
        },
      ),
    );
  }
}

// =============================================================================
// IDLE VIEW — Workspace File List + Analyze CTA
// =============================================================================

class _IdleView extends ConsumerWidget {
  final AnalyzeState state;
  const _IdleView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final notifier = ref.read(analyzeProvider.notifier);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch Risk Analysis',
                  style: typography.titleLarge.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '14-stage AI Risk Intelligence Engine',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Workspace Files'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // File list
        if (state.fileEntries.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyFilesCard(colors: colors, typography: typography),
            ),
          )
        else
          SliverList.separated(
            itemCount: state.fileEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final file = state.fileEntries[i].file;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _FileCard(file: file),
              );
            },
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: _AnalyzeButton(
              enabled: state.fileEntries.isNotEmpty,
              onTap: () => notifier.runAllAnalysis(forceFresh: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFilesCard extends StatelessWidget {
  final dynamic colors;
  final dynamic typography;
  const _EmptyFilesCard({required this.colors, required this.typography});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SemanticColors.colorBackgroundCard,
        borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
        border: Border.all(color: SemanticColors.colorBorderDefault),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 40, color: colors.contentSecondary),
          const SizedBox(height: 12),
          Text(
            'No files found',
            style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload documents in the Files tab to get started.',
            style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final FileItem file;

  const _FileCard({required this.file});

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SemanticColors.colorBackgroundCard,
        borderRadius: BorderRadius.circular(SemanticRadius.radiusInput),
        border: Border.all(
          color: SemanticColors.colorBorderDefault,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SemanticColors.colorBackgroundSurface,
              borderRadius: BorderRadius.circular(SemanticRadius.radiusBadge),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 18,
              color: colors.contentSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: typography.bodyDefaultBold.copyWith(
                    color: colors.contentPrimary,
                    fontSize: 13.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  file.type.toUpperCase(),
                  style: typography.bodyDefault.copyWith(
                    fontSize: 11.0,
                    color: colors.contentSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzeButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _AnalyzeButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typography = context.maritaTypography;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: enabled
                ? SemanticColors.colorButtonPrimaryBackground
                : SemanticColors.colorButtonPrimaryDisabledBackground,
            borderRadius: BorderRadius.circular(SemanticRadius.radiusInput),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: enabled
                      ? SemanticColors.colorButtonPrimaryForeground
                      : SemanticColors.colorButtonPrimaryDisabledForeground,
                ),
                const SizedBox(width: 8),
                Text(
                  'Run Batch Analysis',
                  style: typography.bodyDefaultBold.copyWith(
                    color: enabled
                        ? SemanticColors.colorButtonPrimaryForeground
                        : SemanticColors.colorButtonPrimaryDisabledForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// RUNNING VIEW — Live pipeline progress for all files
// =============================================================================

class _RunningView extends StatelessWidget {
  final AnalyzeState state;
  const _RunningView({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    
    final totalFiles = state.totalFiles;
    final completedCount = state.completedCount;
    final currentFileIndex = state.currentFileIndex;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analyzing Batch',
                    style: typography.titleLarge.copyWith(color: colors.contentPrimary)),
                const SizedBox(height: 4),
                Text(
                  '$completedCount of $totalFiles files complete',
                  style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                ),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: totalFiles == 0 ? 0 : completedCount / totalFiles,
                    minHeight: 6,
                    backgroundColor: SemanticColors.colorBorderSubtle,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      SemanticColors.colorButtonPrimaryBackground,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('File Progress'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: state.fileEntries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final entry = state.fileEntries[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FileProgressCard(entry: entry, isCurrent: i == currentFileIndex),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _FileProgressCard extends StatelessWidget {
  final FileAnalysisEntry entry;
  final bool isCurrent;

  const _FileProgressCard({required this.entry, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    
    final stages = entry.stages;
    final completedStages = stages.where((s) => s.status == AnalysisStepStatus.completed).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SemanticColors.colorBackgroundCard,
        borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
        border: Border.all(
          color: isCurrent ? SemanticColors.colorBorderSelected : SemanticColors.colorBorderDefault,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.file.name,
                  style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.status == AnalysisStatus.completed)
                const Icon(Icons.check_circle_rounded, size: 16, color: SemanticColors.colorTextSuccess)
              else if (entry.status == AnalysisStatus.error)
                const Icon(Icons.error_rounded, size: 16, color: SemanticColors.colorTextDanger)
              else if (isCurrent)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: SemanticColors.colorButtonPrimaryBackground),
                ),
            ],
          ),
          if (isCurrent && stages.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: completedStages / 14,
                minHeight: 4,
                backgroundColor: SemanticColors.colorBorderSubtle,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  SemanticColors.colorButtonPrimaryBackground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (int j = 0; j < stages.length; j++)
              if (stages[j].status == AnalysisStepStatus.running || 
                 (stages[j].status == AnalysisStepStatus.pending && (j == 0 || stages[j-1].status == AnalysisStepStatus.completed)))
                AnalysisPipelineStep(
                  stage: stages[j],
                  isLast: true,
                ),
          ]
        ],
      ),
    );
  }
}

// =============================================================================
// COMPLETED VIEW — Full batch results
// =============================================================================

class _CompletedView extends ConsumerWidget {
  final AnalyzeState state;
  const _CompletedView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final notifier = ref.read(analyzeProvider.notifier);
    
    final aggregateScore = state.aggregateScore ?? 0;
    final aggregateLevel = state.aggregateRiskLevel ?? RiskLevel.low;

    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Batch Analysis Complete',
                          style: typography.titleLarge.copyWith(color: colors.contentPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${state.completedCount} files analyzed successfully',
                        style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => notifier.runAllAnalysis(forceFresh: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: SemanticColors.colorBackgroundSurface,
                      borderRadius: BorderRadius.circular(SemanticRadius.radiusInput),
                      border: Border.all(color: SemanticColors.colorBorderDefault),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 14, color: SemanticColors.colorTextDefault),
                        const SizedBox(width: 4),
                        Text('Re-run',
                            style: typography.bodyDefault.copyWith(
                              fontSize: 12.0,
                              color: SemanticColors.colorTextDefault,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Aggregate Risk Gauge Card ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SemanticColors.colorBackgroundCard,
                borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
                border: Border.all(color: SemanticColors.colorBorderDefault),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RiskScoreGauge(score: aggregateScore, level: aggregateLevel, size: 120),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aggregate Risk Score',
                            style: typography.bodyDefaultBold.copyWith(
                              color: colors.contentPrimary,
                            )),
                        const SizedBox(height: 6),
                        RiskLevelBadge(level: aggregateLevel),
                        const SizedBox(height: 8),
                        Text(
                          'Average risk across all analyzed workspace files.',
                          style: typography.bodyDefault.copyWith(
                            fontSize: 12.0,
                            color: colors.contentSecondary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── File Results List ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: const _SectionLabel('File Results'),
          ),
        ),
        
        SliverList.separated(
          itemCount: state.fileEntries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final entry = state.fileEntries[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _CompletedFileCard(entry: entry),
            );
          },
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _CompletedFileCard extends StatefulWidget {
  final FileAnalysisEntry entry;
  const _CompletedFileCard({required this.entry});
  @override
  State<_CompletedFileCard> createState() => _CompletedFileCardState();
}

class _CompletedFileCardState extends State<_CompletedFileCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final result = widget.entry.result;
    
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SemanticColors.colorBackgroundCard,
          borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
          border: Border.all(color: SemanticColors.colorBorderDefault),
        ),
        child: Row(
          children: [
            Expanded(child: Text(widget.entry.file.name, style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary))),
            Text('Failed', style: typography.bodyDefault.copyWith(color: SemanticColors.colorTextDanger)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: SemanticColors.colorBackgroundCard,
        borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
        border: Border.all(color: SemanticColors.colorBorderDefault),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.fileName,
                          style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Score: ${result.overallScore}',
                              style: typography.bodyDefault.copyWith(fontSize: 12.0, color: colors.contentSecondary),
                            ),
                            const SizedBox(width: 8),
                            RiskLevelBadge(level: result.highestRiskLevel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: colors.contentSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: SemanticColors.colorBorderSubtle),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Executive Summary', style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    result.executiveSummary,
                    style: typography.bodyDefault.copyWith(color: colors.contentSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (result.findings.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('Top Findings', style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SemanticColors.colorBackgroundDanger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${result.findings.length}',
                            style: typography.bodyDefault.copyWith(fontSize: 10.0, color: SemanticColors.colorTextDanger, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < result.findings.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      AuditFindingCard(finding: result.findings[i]),
                    ]
                  ],
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// =============================================================================
// ERROR VIEW
// =============================================================================

class _ErrorView extends ConsumerWidget {
  final AnalyzeState state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final notifier = ref.read(analyzeProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: SemanticColors.colorBackgroundDanger,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 32, color: SemanticColors.colorTextDanger),
            ),
            const SizedBox(height: 16),
            Text('Analysis Failed',
                style: typography.titleSmall.copyWith(color: colors.contentPrimary)),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'An unexpected error occurred.',
              style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => notifier.runAllAnalysis(forceFresh: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: SemanticColors.colorButtonPrimaryBackground,
                  borderRadius: BorderRadius.circular(SemanticRadius.radiusInput),
                ),
                child: Text('Try Again',
                    style: typography.bodyDefaultBold.copyWith(
                      color: SemanticColors.colorButtonPrimaryForeground,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED HELPERS
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.maritaTypography.bodyDefault.copyWith(
        fontSize: 11.0,
        fontWeight: FontWeight.w700,
        color: SemanticColors.colorTextMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}
