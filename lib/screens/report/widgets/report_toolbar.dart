import 'package:flutter/material.dart';
import '../../../design_system/marita_design_system.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/workspace_provider.dart';
import '../../../services/export_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportToolbar extends ConsumerWidget {
  final ReportState reportState;

  const ReportToolbar({
    super.key,
    required this.reportState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomAppBar(
      color: context.maritaColors.backgroundPrimary,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Export Button
            TextButton.icon(
              onPressed: reportState.report != null ? () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exporting PDF...')),
                );
                try {
                  await ExportService.exportReportToPdf(reportState.report!);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to export PDF: $e')),
                    );
                  }
                }
              } : null,
              icon: Icon(Icons.picture_as_pdf_rounded, color: context.maritaColors.contentSecondary),
              label: Text(
                'Export',
                style: context.maritaTypography.bodyMedium.copyWith(
                  color: context.maritaColors.contentPrimary,
                ),
              ),
            ),
            
            // Version Navigation
            if (reportState.allVersions.length > 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, 
                      color: reportState.currentVersionIndex < reportState.allVersions.length - 1 
                        ? context.maritaColors.contentSecondary 
                        : context.maritaColors.contentTertiary),
                    tooltip: 'Previous Version',
                    onPressed: reportState.currentVersionIndex < reportState.allVersions.length - 1 
                        ? () => ref.read(reportProvider(reportState.report!.messageId).notifier).previousVersion()
                        : null,
                  ),
                  Text(
                    'V${reportState.allVersions.length - reportState.currentVersionIndex} of ${reportState.allVersions.length}',
                    style: context.maritaTypography.bodySmall.copyWith(
                      color: context.maritaColors.contentSecondary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, 
                      color: reportState.currentVersionIndex > 0 
                        ? context.maritaColors.contentSecondary 
                        : context.maritaColors.contentTertiary),
                    tooltip: 'Next Version',
                    onPressed: reportState.currentVersionIndex > 0
                        ? () => ref.read(reportProvider(reportState.report!.messageId).notifier).nextVersion()
                        : null,
                  ),
                ],
              )
            else
              const SizedBox.shrink(), // Spacer if no version nav

            // Share Button
            IconButton(
              icon: Icon(Icons.share_rounded, color: context.maritaColors.contentSecondary),
              tooltip: 'Share',
              onPressed: reportState.report != null ? () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preparing to share...')),
                );
                try {
                  final workspaceId = ref.read(activeWorkspaceProvider)?.id ?? '';
                  await ExportService.shareReportLink(reportState.report!, workspaceId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                }
              } : null,
            ),
          ],
        ),
      ),
    );
  }
}
