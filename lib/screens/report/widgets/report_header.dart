import 'package:flutter/material.dart';
import '../../../design_system/marita_design_system.dart';
import '../../../providers/report_provider.dart';
import 'report_toc_sheet.dart';

class ReportHeader extends StatelessWidget implements PreferredSizeWidget {
  final ReportState reportState;
  final ScrollController scrollController;

  const ReportHeader({
    super.key,
    required this.reportState,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.maritaColors.backgroundPrimary,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: context.maritaColors.contentPrimary),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Analysis',
            style: context.maritaTypography.titleMedium.copyWith(
              color: context.maritaColors.contentPrimary,
            ),
          ),
          if (reportState.report != null)
            Text(
              'Version ${reportState.report!.reportVersion} · ${_formatDate(reportState.report!.generatedAt)}',
              style: context.maritaTypography.labelSmall.copyWith(
                color: context.maritaColors.contentSecondary,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.menu_rounded, color: context.maritaColors.contentPrimary),
          tooltip: 'Table of Contents',
          onPressed: () {
            if (reportState.report != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ReportTocSheet(
                  report: reportState.report!,
                  onTap: (index) {
                    Navigator.pop(context);
                    // Minimal scroll logic implementation
                    // In a real app with true sections, scrollController would jump to specific heights or GlobalKeys.
                    if (scrollController.hasClients) {
                      scrollController.animateTo(
                        index * 200.0, // Mock scroll distance
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              );
            }
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
