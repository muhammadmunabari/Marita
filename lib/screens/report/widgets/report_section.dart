import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../design_system/marita_design_system.dart';

class ReportSection extends StatelessWidget {
  final String title;
  final String content;
  final bool initiallyExpanded;

  const ReportSection({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: context.maritaTypography.titleSmall.copyWith(
          color: context.maritaColors.contentPrimary,
        ),
      ),
      initiallyExpanded: initiallyExpanded,
      iconColor: context.maritaColors.contentSecondary,
      collapsedIconColor: context.maritaColors.contentSecondary,
      shape: Border(
        bottom: BorderSide(color: context.maritaColors.borderPrimary),
      ),
      collapsedShape: Border(
        bottom: BorderSide(color: context.maritaColors.borderPrimary),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: MarkdownBody(
            data: content,
            styleSheet: MarkdownStyleSheet(
              p: context.maritaTypography.bodyMedium.copyWith(
                color: context.maritaColors.contentSecondary,
              ),
              listBullet: context.maritaTypography.bodyMedium.copyWith(
                color: context.maritaColors.contentSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
