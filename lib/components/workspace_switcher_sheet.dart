import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/result.dart';
import '../models/workspace.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../design_system/marita_design_system.dart';
import '../design_system/marita_icons.dart';
import 'marita_primary_button.dart';
import 'marita_text_input.dart';
import 'marita_select_field.dart';

/// A bottom sheet that allows users to switch between their workspaces.
class WorkspaceSwitcherSheet extends ConsumerWidget {
  final bool showCreateButton;

  const WorkspaceSwitcherSheet({
    super.key,
    this.showCreateButton = true,
  });

  /// Displays the workspace switcher bottom sheet.
  static void show(BuildContext context, {bool showCreateButton = true}) {
    final colors = context.maritaColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return WorkspaceSwitcherSheet(showCreateButton: showCreateButton);
      },
    );
  }

  /// Displays the role selector bottom sheet.
  static void showRoleSelector(
    BuildContext context,
    ValueChanged<WorkspaceRole> onRoleSelected,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MaritaSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Your Role',
                  style: typography.bodyLargeBold.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: MaritaSpacing.md),
                ...WorkspaceRole.values.map((role) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      role.label,
                      style: typography.bodyDefaultBold.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    subtitle: Text(
                      role.description,
                      style: typography.bodyDefault.copyWith(
                        color: colors.contentSecondary,
                      ),
                    ),
                    trailing: MaritaIcon(
                      icon: MaritaIcons.arrowRight,
                      size: MaritaIconSize.small,
                      color: colors.contentTertiary,
                    ),
                    onTap: () {
                      onRoleSelected(role);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Reusable static method to show the create workspace sheet.
  static void showCreateWorkspaceSheet(BuildContext context, WidgetRef ref) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final taxIdController = TextEditingController();
    WorkspaceRole? selectedRole;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isFormValid =
                nameController.text.trim().isNotEmpty && selectedRole != null;

            return Padding(
              padding: EdgeInsets.only(
                left: MaritaSpacing.lg,
                right: MaritaSpacing.lg,
                top: MaritaSpacing.lg,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + MaritaSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.borderPrimary,
                          borderRadius: MaritaRadius.borderFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    Text(
                      'Create Business Account',
                      style: typography.titleLarge.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    MaritaTextInput(
                      controller: nameController,
                      label: 'Company Name *',
                      hint: 'Enter company name',
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    MaritaSelectField(
                      label: 'Your Role *',
                      value: selectedRole?.label ?? 'Select Role',
                      onTap: () {
                        showRoleSelector(context, (role) {
                          setModalState(() {
                            selectedRole = role;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    MaritaTextInput(
                      controller: addressController,
                      label: 'Address',
                      hint: 'Enter address (optional)',
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    MaritaTextInput(
                      controller: taxIdController,
                      label: 'Tax Identification Number (TIN)',
                      hint: 'Enter TIN (optional)',
                    ),
                    const SizedBox(height: MaritaSpacing.xl),
                    MaritaPrimaryButton(
                      label: 'Create Account',
                      onPressed:
                          isFormValid
                              ? () async {
                                Navigator.pop(context);
                                await ref
                                    .read(workspaceOpsProvider.notifier)
                                    .createWorkspace(
                                      name: nameController.text.trim(),
                                      role: selectedRole!.toJsonString(),
                                      address:
                                          addressController.text.trim().isEmpty
                                              ? null
                                              : addressController.text.trim(),
                                      taxId:
                                          taxIdController.text.trim().isEmpty
                                              ? null
                                              : taxIdController.text.trim(),
                                    );
                              }
                              : null,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final workspacesResult = ref.watch(userWorkspacesProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final currentUser = ref.watch(currentUserProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: MaritaSpacing.lg),
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderPrimary,
                    borderRadius: MaritaRadius.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: MaritaSpacing.lg),
              Text(
                'Switch Workspace',
                style: typography.titleMedium.copyWith(
                  color: colors.contentPrimary,
                ),
              ),
              const SizedBox(height: MaritaSpacing.lg),
              Expanded(
                child: workspacesResult.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (err, stack) => Center(
                        child: Text(
                          'Failed to load workspaces',
                          style: typography.bodyDefault.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                  data: (result) {
                    if (result is Failure<List<Workspace>>) {
                      return Center(
                        child: Text(
                          result.error.message,
                          style: typography.bodyDefault.copyWith(
                            color: colors.error,
                          ),
                        ),
                      );
                    }

                    final workspaces =
                        (result as Success<List<Workspace>>).data;
                    if (workspaces.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'No Workspaces Found',
                              style: typography.bodyLargeBold.copyWith(
                                color: colors.contentPrimary,
                              ),
                            ),
                            const SizedBox(height: MaritaSpacing.sm),
                            Text(
                              'Create a new workspace to get started.',
                              style: typography.bodyDefault.copyWith(
                                color: colors.contentSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final currentUid = currentUser?.uid ?? '';
                    final createdWorkspaces =
                        workspaces
                            .where((w) => w.ownerId == currentUid)
                            .toList();
                    final joinedWorkspaces =
                        workspaces
                            .where((w) => w.ownerId != currentUid)
                            .toList();

                    return ListView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      children: [
                        if (createdWorkspaces.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: MaritaSpacing.sm,
                            ),
                            child: Text(
                              'Created Workspaces',
                              style: typography.bodyDefaultBold.copyWith(
                                color: colors.contentSecondary,
                              ),
                            ),
                          ),
                          ...createdWorkspaces.map(
                            (w) => _buildWorkspaceItem(
                              context,
                              ref,
                              w,
                              activeWorkspace,
                              currentUid,
                            ),
                          ),
                          const SizedBox(height: MaritaSpacing.md),
                        ],
                        if (joinedWorkspaces.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: MaritaSpacing.sm,
                            ),
                            child: Text(
                              'Joined Workspaces',
                              style: typography.bodyDefaultBold.copyWith(
                                color: colors.contentSecondary,
                              ),
                            ),
                          ),
                          ...joinedWorkspaces.map(
                            (w) => _buildWorkspaceItem(
                              context,
                              ref,
                              w,
                              activeWorkspace,
                              currentUid,
                            ),
                          ),
                          const SizedBox(height: MaritaSpacing.md),
                        ],
                      ],
                    );
                  },
                ),
              ),
              if (showCreateButton) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: MaritaSpacing.lg),
                  child: MaritaPrimaryButton(
                    label: 'Create New Workspace',
                    onPressed: () {
                      Navigator.pop(context);
                      showCreateWorkspaceSheet(context, ref);
                    },
                  ),
                ),
              ] else
                const SizedBox(height: MaritaSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceItem(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    Workspace? activeWorkspace,
    String currentUid,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final isActive = workspace.id == activeWorkspace?.id;
    final isOwner = workspace.ownerId == currentUid;

    final memberDetail = workspace.memberDetails[currentUid];
    final accessLabel =
        memberDetail?.access.label ?? (isOwner ? 'Owner' : 'can view');

    return Padding(
      padding: const EdgeInsets.only(bottom: MaritaSpacing.sm),
      child: InkWell(
        onTap: () {
          ref.read(activeWorkspaceProvider.notifier).state = workspace;
          Navigator.pop(context);
        },
        borderRadius: MaritaRadius.borderMedium,
        child: Ink(
          decoration: BoxDecoration(
            color:
                isActive
                    ? colors.interactivePrimary.withValues(alpha: 0.08)
                    : colors.backgroundPrimary,
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(
              color:
                  isActive ? colors.interactivePrimary : colors.borderSecondary,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(MaritaSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(MaritaSpacing.sm),
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? colors.interactivePrimary.withValues(alpha: 0.12)
                            : colors.backgroundSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: MaritaIcon(
                    icon:
                        isActive
                            ? MaritaIcons.buildingsActive
                            : MaritaIcons.buildings,
                    size: MaritaIconSize.small,
                    color:
                        isActive
                            ? colors.interactivePrimary
                            : colors.contentSecondary,
                  ),
                ),
                const SizedBox(width: MaritaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        style: typography.bodyLargeBold.copyWith(
                          color:
                              isActive
                                  ? colors.interactivePrimary
                                  : colors.contentPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isOwner)
                            MaritaIcon(
                              icon: MaritaIcons.crown,
                              size: MaritaIconSize.extraSmall,
                              color: colors.interactivePrimary,
                            )
                          else
                            MaritaIcon(
                              icon: MaritaIcons.user,
                              size: MaritaIconSize.extraSmall,
                              color: colors.contentSecondary,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            isOwner ? 'Owner' : accessLabel,
                            style: typography.bodySmall.copyWith(
                              color:
                                  isOwner
                                      ? colors.interactivePrimary
                                      : colors.contentSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  MaritaIcon(
                    icon: MaritaIcons.successActive,
                    size: MaritaIconSize.medium,
                    color: colors.interactivePrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
