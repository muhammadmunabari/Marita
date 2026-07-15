import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design_system/marita_design_system.dart';
import '../../providers/report_provider.dart';
import '../../models/report_model.dart';
import 'widgets/report_header.dart';
import 'widgets/report_outdated_banner.dart';
import 'widgets/report_section.dart';
import 'widgets/report_toolbar.dart';

class ReportScreen extends ConsumerWidget {
  final String messageId;

  const ReportScreen({
    super.key,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(reportProvider(messageId));
    final scrollController = ScrollController();

    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      appBar: ReportHeader(
        reportState: reportState,
        scrollController: scrollController,
      ),
      body: Column(
        children: [
          if (reportState.status == ReportStatus.outdated)
            ReportOutdatedBanner(
              onRegenerate: () {
                ref.read(reportProvider(messageId).notifier).regenerateReport();
              },
            ),
          Expanded(
            child: _buildBody(context, reportState, scrollController),
          ),
        ],
      ),
      bottomNavigationBar: ReportToolbar(reportState: reportState),
    );
  }

  Widget _buildBody(BuildContext context, ReportState reportState, ScrollController scrollController) {
    if (reportState.status == ReportStatus.generating || reportState.report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating your report...',
              style: context.maritaTypography.bodyLarge.copyWith(
                color: context.maritaColors.contentSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (reportState.status == ReportStatus.error) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.maritaColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.maritaColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: context.maritaColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error Loading Report',
                style: context.maritaTypography.titleMedium.copyWith(
                  color: context.maritaColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reportState.error ?? 'An unknown error occurred.',
                textAlign: TextAlign.center,
                style: context.maritaTypography.bodyMedium.copyWith(
                  color: context.maritaColors.contentSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final content = reportState.report!.content;
    
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _buildSectionsFromMarkdown(content),
    );
  }

  List<Widget> _buildSectionsFromMarkdown(String markdown) {
    final lines = markdown.split('\n');
    
    final sections = <Widget>[];
    String currentTitle = 'Overview';
    List<String> currentContent = [];
    bool isFirst = true;

    for (var line in lines) {
      if (line.startsWith('## ') || line.startsWith('### ')) {
        if (currentContent.isNotEmpty && currentContent.join('').trim().isNotEmpty) {
          sections.add(ReportSection(
            title: currentTitle,
            content: currentContent.join('\n').trim(),
            initiallyExpanded: isFirst,
          ));
          isFirst = false;
          currentContent.clear();
        }
        currentTitle = line.replaceAll(RegExp(r'^#+\s'), '').trim();
      } else if (line.startsWith('# ')) {
        // Main title, ignore or just add to content
        currentContent.add(line);
      } else {
        currentContent.add(line);
      }
    }

    if (currentContent.isNotEmpty && currentContent.join('').trim().isNotEmpty) {
      sections.add(ReportSection(
        title: currentTitle,
        content: currentContent.join('\n').trim(),
        initiallyExpanded: isFirst,
      ));
    }

    return sections;
  }
}
