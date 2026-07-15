import 'package:flutter/material.dart';
import '../../../design_system/marita_design_system.dart';
import '../../../models/report_model.dart';

class ReportTocSheet extends StatelessWidget {
  final ReportModel report;
  final Function(int) onTap;

  const ReportTocSheet({
    super.key,
    required this.report,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // In a real implementation, you would parse the markdown to get headers
    // For now, we mock the sections based on the implementation plan
    final sections = [
      'Executive Summary',
      'Revenue Analysis',
      'Expense Breakdown',
      'Cash Flow Assessment',
      'Risk Indicators',
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.maritaColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Table of Contents',
                    style: context.maritaTypography.titleMedium.copyWith(
                      color: context.maritaColors.contentPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.maritaColors.contentPrimary),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.maritaColors.borderPrimary),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      sections[index],
                      style: context.maritaTypography.bodyMedium.copyWith(
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                    onTap: () => onTap(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
