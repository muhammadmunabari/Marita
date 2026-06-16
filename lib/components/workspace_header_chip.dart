import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/marita_design_system.dart';
import '../design_system/marita_icons.dart';
import '../providers/workspace_provider.dart';
import 'workspace_switcher_sheet.dart';

/// A chip displayed in app headers showing the active workspace and allowing switching.
class WorkspaceHeaderChip extends ConsumerWidget {
  const WorkspaceHeaderChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final hasActiveWorkspace = activeWorkspace != null;
    final displayName = hasActiveWorkspace ? activeWorkspace.name : 'No Workspace';

    return Semantics(
      label: 'Select Workspace',
      button: true,
      child: InkWell(
        onTap: () => WorkspaceSwitcherSheet.show(context),
        borderRadius: MaritaRadius.borderFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MaritaSpacing.md,
            vertical: MaritaSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: hasActiveWorkspace
                ? colors.interactivePrimary.withValues(alpha: 0.06)
                : colors.backgroundSecondary,
            borderRadius: MaritaRadius.borderFull,
            border: Border.all(
              color: hasActiveWorkspace
                  ? colors.interactivePrimary.withValues(alpha: 0.3)
                  : colors.borderSecondary,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MaritaIcon(
                icon: hasActiveWorkspace ? MaritaIcons.buildingsActive : MaritaIcons.buildings,
                size: MaritaIconSize.small,
                color: hasActiveWorkspace ? colors.interactivePrimary : colors.contentTertiary,
              ),
              const SizedBox(width: MaritaSpacing.xs + 2),
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyDefaultBold.copyWith(
                    color: hasActiveWorkspace ? colors.interactivePrimary : colors.contentSecondary,
                  ),
                ),
              ),
              const SizedBox(width: MaritaSpacing.xs),
              MaritaIcon(
                icon: MaritaIcons.arrowDown,
                size: MaritaIconSize.extraSmall,
                color: hasActiveWorkspace ? colors.interactivePrimary : colors.contentTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
