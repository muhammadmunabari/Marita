import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../models/workspace.dart';
import '../../providers/workspace_provider.dart';
import '../../providers/auth_provider.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../components/marita_primary_button.dart';
import '../../components/marita_text_input.dart';
import '../../components/marita_select_field.dart';

class WorkspacesScreen extends ConsumerStatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  ConsumerState<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends ConsumerState<WorkspacesScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final workspacesResult = ref.watch(userWorkspacesProvider);
    final invitationsResult = ref.watch(userInvitationsProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final opsState = ref.watch(workspaceOpsProvider);
    final currentUser = ref.watch(authStateProvider).value;

    // Listen to success or error messages
    ref.listen(workspaceOpsProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error!.message,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: colors.error,
          ),
        );
      } else if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.successMessage!,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: colors.success,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MaritaSpacing.lg,
                    vertical: MaritaSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Workspaces',
                        style: typography.titleLarge.copyWith(
                          color: colors.contentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Listing
                Expanded(
                  child: workspacesResult.when(
                    data: (wsResult) {
                      return invitationsResult.when(
                        data: (invResult) {
                          if (wsResult.isFailure) {
                            return Center(
                              child: Text(
                                wsResult.errorOrNull?.message ??
                                    'Unknown error',
                                style: typography.bodyDefault.copyWith(
                                  color: colors.error,
                                ),
                              ),
                            );
                          }
                          if (invResult.isFailure) {
                            return Center(
                              child: Text(
                                invResult.errorOrNull?.message ??
                                    'Unknown error',
                                style: typography.bodyDefault.copyWith(
                                  color: colors.error,
                                ),
                              ),
                            );
                          }

                          final workspaces =
                              (wsResult as Success<List<Workspace>>).data;
                          final invitations =
                              (invResult as Success<List<Map<String, dynamic>>>)
                                  .data;

                          final createdWorkspaces =
                              workspaces
                                  .where((w) => w.ownerId == currentUser?.uid)
                                  .toList();
                          final joinedWorkspaces =
                              workspaces
                                  .where((w) => w.ownerId != currentUser?.uid)
                                  .toList();

                          if (workspaces.isEmpty && invitations.isEmpty) {
                            return _buildEmptyState(context);
                          }

                          final List<Widget> listItems = [];

                          // 1. Pending Invitations Section
                          if (invitations.isNotEmpty) {
                            listItems.add(
                              _buildSectionHeader(
                                context,
                                'Pending Invitations',
                                invitations.length,
                              ),
                            );
                            for (final invitation in invitations) {
                              listItems.add(
                                _buildInvitationCard(context, invitation),
                              );
                            }
                          }

                          // 2. Created Workspaces Section
                          if (createdWorkspaces.isNotEmpty) {
                            listItems.add(
                              _buildSectionHeader(
                                context,
                                'Created Workspaces',
                                createdWorkspaces.length,
                              ),
                            );
                            for (final workspace in createdWorkspaces) {
                              final isSelected =
                                  activeWorkspace?.id == workspace.id;
                              listItems.add(
                                _buildWorkspaceCard(
                                  context,
                                  workspace,
                                  isSelected,
                                  currentUser?.uid,
                                ),
                              );
                            }
                          }

                          // 3. Joined Workspaces Section
                          if (joinedWorkspaces.isNotEmpty) {
                            listItems.add(
                              _buildSectionHeader(
                                context,
                                'Joined Workspaces',
                                joinedWorkspaces.length,
                              ),
                            );
                            for (final workspace in joinedWorkspaces) {
                              final isSelected =
                                  activeWorkspace?.id == workspace.id;
                              listItems.add(
                                _buildWorkspaceCard(
                                  context,
                                  workspace,
                                  isSelected,
                                  currentUser?.uid,
                                ),
                              );
                            }
                          }

                          return ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MaritaSpacing.lg,
                              vertical: MaritaSpacing.md,
                            ),
                            children: listItems,
                          );
                        },
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error:
                            (err, stack) => Center(
                              child: Text(
                                'Error loading invitations: $err',
                                style: typography.bodyDefault.copyWith(
                                  color: colors.error,
                                ),
                              ),
                            ),
                      );
                    },
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (err, stack) => Center(
                          child: Text(
                            'Error loading workspaces: $err',
                            style: typography.bodyDefault.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),

          if (opsState.isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.interactivePrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    Text(
                      'Processing...',
                      style: typography.bodyDefault.copyWith(
                        color: colors.contentSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateWorkspaceSheet(context),
        backgroundColor: colors.interactivePrimary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: colors.contentInverse, size: 28),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MaritaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaritaIcon(
              icon: MaritaIcons.buildings,
              size: MaritaIconSize.large,
              color: colors.contentTertiary,
            ),
            const SizedBox(height: MaritaSpacing.md),
            Text(
              'No Workspaces Found',
              style: typography.bodyLargeBold.copyWith(
                color: colors.contentPrimary,
              ),
            ),
            const SizedBox(height: MaritaSpacing.xs),
            Text(
              'Create a workspace to collaborate and share financial data.',
              style: typography.bodyDefault.copyWith(
                color: colors.contentSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MaritaSpacing.xl),
            MaritaPrimaryButton(
              label: 'Create Workspace',
              onPressed: () => _showCreateWorkspaceSheet(context),
              isExpanded: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard(
    BuildContext context,
    Workspace workspace,
    bool isSelected,
    String? currentUserId,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final isOwner = workspace.ownerId == currentUserId;

    // Get current user's role in this workspace
    final memberDetail = workspace.memberDetails[currentUserId];
    final roleLabel = memberDetail?.role.label ?? 'Employee';
    final accessLabel = memberDetail?.access.label ?? 'can view';

    return GestureDetector(
      onTap: () {
        ref.read(activeWorkspaceProvider.notifier).state = workspace;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: MaritaSpacing.md),
        padding: const EdgeInsets.all(MaritaSpacing.lg),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? colors.interactivePrimary.withValues(alpha: 0.04)
                  : colors.backgroundSecondary,
          borderRadius: MaritaRadius.borderMedium,
          border: Border.all(
            color:
                isSelected ? colors.interactivePrimary : colors.borderPrimary,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    workspace.name,
                    style: typography.bodyLargeBold.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MaritaSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: MaritaRadius.borderSmall,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MaritaIcon(
                          icon: MaritaIcons.success,
                          size: MaritaIconSize.extraSmall,
                          color: colors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: typography.bodyDefaultBold.copyWith(
                            color: colors.success,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MaritaSpacing.sm),
                ],
                if (isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MaritaSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.interactivePrimary.withValues(alpha: 0.12),
                      borderRadius: MaritaRadius.borderSmall,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MaritaIcon(
                          icon: MaritaIcons.crown,
                          size: MaritaIconSize.extraSmall,
                          color: colors.interactivePrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Owner',
                          style: typography.bodyDefaultBold.copyWith(
                            color: colors.interactivePrimary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MaritaSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: MaritaRadius.borderSmall,
                      border: Border.all(color: colors.borderPrimary),
                    ),
                    child: Text(
                      accessLabel,
                      style: typography.bodyDefault.copyWith(
                        color: colors.contentSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MaritaSpacing.sm),
            Row(
              children: [
                MaritaIcon(
                  icon: MaritaIcons.user,
                  size: MaritaIconSize.small,
                  color: colors.contentTertiary,
                ),
                const SizedBox(width: MaritaSpacing.xs),
                Text(
                  'Role: $roleLabel',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentSecondary,
                  ),
                ),
              ],
            ),
            if (workspace.taxId != null && workspace.taxId!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  MaritaIcon(
                    icon: MaritaIcons.document,
                    size: MaritaIconSize.small,
                    color: colors.contentTertiary,
                  ),
                  const SizedBox(width: MaritaSpacing.xs),
                  Text(
                    'Tax ID: ${workspace.taxId}',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (workspace.address != null && workspace.address!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MaritaIcon(
                    icon: MaritaIcons.buildings,
                    size: MaritaIconSize.small,
                    color: colors.contentTertiary,
                  ),
                  const SizedBox(width: MaritaSpacing.xs),
                  Expanded(
                    child: Text(
                      workspace.address!,
                      style: typography.bodyDefault.copyWith(
                        color: colors.contentSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: MaritaSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed:
                      () =>
                          _showShareWorkspaceSheet(context, workspace, isOwner),
                  icon: MaritaIcon(
                    icon: MaritaIcons.people,
                    size: MaritaIconSize.small,
                    color: colors.interactivePrimary,
                  ),
                  label: Text(
                    'Members',
                    style: typography.bodyDefaultBold.copyWith(
                      color: colors.interactivePrimary,
                    ),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: MaritaSpacing.md),
                  TextButton.icon(
                    onPressed:
                        () => _showEditWorkspaceSheet(context, workspace),
                    icon: MaritaIcon(
                      icon: MaritaIcons.edit,
                      size: MaritaIconSize.small,
                      color: colors.contentPrimary,
                    ),
                    label: Text(
                      'Edit',
                      style: typography.bodyDefaultBold.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: MaritaSpacing.md),
                  IconButton(
                    icon: MaritaIcon(
                      icon: MaritaIcons.trash,
                      size: MaritaIconSize.medium,
                      color: colors.error,
                    ),
                    onPressed:
                        () => _confirmDeleteWorkspace(context, workspace),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateWorkspaceSheet(BuildContext context) {
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
                      'Create New Workspace',
                      style: typography.titleMedium.copyWith(
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
                        _showRoleSelector(context, (role) {
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
                      label: 'Create Workspace',
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

  void _showEditWorkspaceSheet(BuildContext context, Workspace workspace) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final nameController = TextEditingController(text: workspace.name);
    final addressController = TextEditingController(
      text: workspace.address ?? '',
    );
    final taxIdController = TextEditingController(text: workspace.taxId ?? '');

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
            final isFormValid = nameController.text.trim().isNotEmpty;

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
                      'Edit Workspace Details',
                      style: typography.titleMedium.copyWith(
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
                      label: 'Save Changes',
                      onPressed:
                          isFormValid
                              ? () async {
                                Navigator.pop(context);
                                await ref
                                    .read(workspaceOpsProvider.notifier)
                                    .updateWorkspace(
                                      workspaceId: workspace.id,
                                      name: nameController.text.trim(),
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

  void _showRoleSelector(
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

  void _showShareWorkspaceSheet(
    BuildContext context,
    Workspace workspace,
    bool isOwner,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final emailController = TextEditingController();
    MemberAccess selectedAccess = MemberAccess.canView;

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
            final isFormValid = emailController.text.trim().isNotEmpty;
            final invitationsStream = ref.watch(
              workspaceInvitationsProvider(workspace.id),
            );

            return Padding(
              padding: EdgeInsets.only(
                left: MaritaSpacing.lg,
                right: MaritaSpacing.lg,
                top: MaritaSpacing.lg,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + MaritaSpacing.lg,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      'Share Workspace',
                      style: typography.titleMedium.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    if (isOwner) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: MaritaTextInput(
                              controller: emailController,
                              hint: 'Enter email to invite',
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: MaritaSpacing.sm),
                          GestureDetector(
                            onTap: () {
                              _showAccessSelector(context, (access) {
                                setModalState(() {
                                  selectedAccess = access;
                                });
                              });
                            },
                            child: Container(
                              height: MaritaSizing.inputHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: MaritaSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: MaritaRadius.borderMedium,
                                border: Border.all(color: colors.borderPrimary),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    selectedAccess.label,
                                    style: typography.bodyDefault.copyWith(
                                      color: colors.contentPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  MaritaIcon(
                                    icon: MaritaIcons.arrowDown,
                                    size: MaritaIconSize.small,
                                    color: colors.contentSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: MaritaSpacing.sm),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  isFormValid
                                      ? colors.interactivePrimary
                                      : colors.interactiveDisabled,
                              shape: RoundedRectangleBorder(
                                borderRadius: MaritaRadius.borderMedium,
                              ),
                            ),
                            icon: MaritaIcon(
                              icon: MaritaIcons.add,
                              color:
                                  isFormValid
                                      ? colors.contentInverse
                                      : colors.contentTertiary,
                            ),
                            onPressed:
                                isFormValid
                                    ? () async {
                                      final email = emailController.text.trim();
                                      emailController.clear();
                                      setModalState(() {});
                                      await ref
                                          .read(workspaceOpsProvider.notifier)
                                          .inviteMember(
                                            workspaceId: workspace.id,
                                            email: email,
                                            access:
                                                selectedAccess.toJsonString(),
                                          );
                                    }
                                    : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: MaritaSpacing.lg),
                    ],
                    Text(
                      'Who has access',
                      style: typography.bodyLargeBold.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.sm),
                    Expanded(
                      child: ListView(
                        children: [
                          // Render members
                          ...workspace.memberDetails.values.map((member) {
                            final isSelf = member.uid == workspace.ownerId;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                member.name.isEmpty
                                    ? member.email
                                    : member.name,
                                style: typography.bodyDefaultBold.copyWith(
                                  color: colors.contentPrimary,
                                ),
                              ),
                              subtitle: Text(
                                member.email,
                                style: typography.bodyDefault.copyWith(
                                  color: colors.contentSecondary,
                                ),
                              ),
                              trailing:
                                  isSelf
                                      ? Text(
                                        'Owner',
                                        style: typography.bodyDefaultBold
                                            .copyWith(
                                              color: colors.contentTertiary,
                                            ),
                                      )
                                      : (isOwner
                                          ? GestureDetector(
                                            onTap: () {
                                              _showMemberActionsSelector(
                                                context,
                                                member,
                                                workspace.id,
                                              );
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  member.access.label,
                                                  style: typography
                                                      .bodyDefaultBold
                                                      .copyWith(
                                                        color:
                                                            colors
                                                                .interactivePrimary,
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                MaritaIcon(
                                                  icon: MaritaIcons.arrowDown,
                                                  size: MaritaIconSize.small,
                                                  color:
                                                      colors.interactivePrimary,
                                                ),
                                              ],
                                            ),
                                          )
                                          : Text(
                                            member.access.label,
                                            style: typography.bodyDefault
                                                .copyWith(
                                                  color:
                                                      colors.contentSecondary,
                                                ),
                                          )),
                            );
                          }),

                          // Render pending invitations
                          invitationsStream.when(
                            data: (result) {
                              if (result is Failure) {
                                return const SizedBox.shrink();
                              }
                              final invitations =
                                  (result
                                          as Success<
                                            List<Map<String, dynamic>>
                                          >)
                                      .data;
                              if (invitations.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(height: MaritaSpacing.xl),
                                  Text(
                                    'Pending Invitations',
                                    style: typography.bodyLargeBold.copyWith(
                                      color: colors.contentPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: MaritaSpacing.sm),
                                  ...invitations.map((invite) {
                                    final inviteId =
                                        invite['id'] as String? ?? '';
                                    final inviteEmail =
                                        invite['email'] as String? ?? '';
                                    final inviteAccess =
                                        MemberAccess.fromString(
                                          invite['access'] as String? ?? '',
                                        );

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        inviteEmail,
                                        style: typography.bodyDefaultBold
                                            .copyWith(
                                              color: colors.contentPrimary,
                                            ),
                                      ),
                                      subtitle: Text(
                                        'Access: ${inviteAccess.label}',
                                        style: typography.bodyDefault.copyWith(
                                          color: colors.contentSecondary,
                                        ),
                                      ),
                                      trailing:
                                          isOwner
                                              ? IconButton(
                                                icon: MaritaIcon(
                                                  icon: MaritaIcons.trash,
                                                  size: MaritaIconSize.small,
                                                  color: colors.error,
                                                ),
                                                onPressed: () async {
                                                  await ref
                                                      .read(
                                                        workspaceOpsProvider
                                                            .notifier,
                                                      )
                                                      .cancelInvitation(
                                                        workspaceId:
                                                            workspace.id,
                                                        invitationId: inviteId,
                                                      );
                                                },
                                              )
                                              : Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal:
                                                          MaritaSpacing.sm,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      colors.backgroundPrimary,
                                                  borderRadius:
                                                      MaritaRadius.borderSmall,
                                                  border: Border.all(
                                                    color: colors.borderPrimary,
                                                  ),
                                                ),
                                                child: Text(
                                                  'Pending',
                                                  style: typography.bodyDefault
                                                      .copyWith(
                                                        color:
                                                            colors
                                                                .contentSecondary,
                                                        fontSize: 10,
                                                      ),
                                                ),
                                              ),
                                    );
                                  }),
                                ],
                              );
                            },
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error: (err, stack) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
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

  void _showAccessSelector(
    BuildContext context,
    ValueChanged<MemberAccess> onAccessSelected,
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
                  'Select Access Level',
                  style: typography.bodyLargeBold.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: MaritaSpacing.md),
                ...[MemberAccess.canEdit, MemberAccess.canView].map((access) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      access.label,
                      style: typography.bodyDefaultBold.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    onTap: () {
                      onAccessSelected(access);
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

  void _showMemberActionsSelector(
    BuildContext context,
    WorkspaceMember member,
    String workspaceId,
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
                  'Manage Access for ${member.name}',
                  style: typography.bodyLargeBold.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: MaritaSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      member.access == MemberAccess.canEdit
                          ? MaritaIcon(
                            icon: MaritaIcons.success,
                            color: colors.interactivePrimary,
                          )
                          : const SizedBox(width: MaritaIconSize.medium),
                  title: Text(
                    'can edit',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref
                        .read(workspaceOpsProvider.notifier)
                        .updateMemberRoleOrAccess(
                          workspaceId: workspaceId,
                          memberId: member.uid,
                          access: MemberAccess.canEdit.toJsonString(),
                        );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      member.access == MemberAccess.canView
                          ? MaritaIcon(
                            icon: MaritaIcons.success,
                            color: colors.interactivePrimary,
                          )
                          : const SizedBox(width: MaritaIconSize.medium),
                  title: Text(
                    'can view',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref
                        .read(workspaceOpsProvider.notifier)
                        .updateMemberRoleOrAccess(
                          workspaceId: workspaceId,
                          memberId: member.uid,
                          access: MemberAccess.canView.toJsonString(),
                        );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: MaritaIcon(
                    icon: MaritaIcons.trash,
                    color: colors.error,
                  ),
                  title: Text(
                    'Remove member',
                    style: typography.bodyDefaultBold.copyWith(
                      color: colors.error,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    _confirmRemoveMember(context, member, workspaceId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveMember(
    BuildContext context,
    WorkspaceMember member,
    String workspaceId,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text(
            'Remove Member',
            style: typography.bodyLargeBold.copyWith(color: colors.error),
          ),
          content: Text(
            'Are you sure you want to remove ${member.name} from this workspace?',
            style: typography.bodyDefault.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref
                    .read(workspaceOpsProvider.notifier)
                    .removeMember(
                      workspaceId: workspaceId,
                      memberId: member.uid,
                    );
              },
              child: Text(
                'Remove',
                style: typography.bodyDefaultBold.copyWith(color: colors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteWorkspace(BuildContext context, Workspace workspace) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text(
            'Delete Workspace',
            style: typography.bodyLargeBold.copyWith(color: colors.error),
          ),
          content: Text(
            'Are you sure you want to delete ${workspace.name}? This action is irreversible.',
            style: typography.bodyDefault.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref
                    .read(workspaceOpsProvider.notifier)
                    .deleteWorkspace(workspace.id);
              },
              child: Text(
                'Delete',
                style: typography.bodyDefaultBold.copyWith(color: colors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Padding(
      padding: const EdgeInsets.only(
        top: MaritaSpacing.md,
        bottom: MaritaSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: typography.bodySmall.copyWith(
              color: colors.contentSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: MaritaSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.borderSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: typography.bodySmall.copyWith(
                color: colors.contentPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(
    BuildContext context,
    Map<String, dynamic> invitation,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final companyName = invitation['companyName'] ?? 'Workspace';
    final invitedByName = invitation['invitedByName'] ?? 'Someone';
    final access = invitation['access'] ?? 'can view';
    final companyId = invitation['companyId'] ?? '';
    final invitationId = invitation['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: MaritaSpacing.md),
      padding: const EdgeInsets.all(MaritaSpacing.lg),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: MaritaRadius.borderMedium,
        border: Border.all(color: colors.borderPrimary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  companyName,
                  style: typography.bodyLargeBold.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MaritaSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.interactivePrimary.withValues(alpha: 0.12),
                  borderRadius: MaritaRadius.borderSmall,
                ),
                child: Text(
                  'Pending Invite',
                  style: typography.bodyDefaultBold.copyWith(
                    color: colors.interactivePrimary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MaritaSpacing.sm),
          Row(
            children: [
              MaritaIcon(
                icon: MaritaIcons.user,
                size: MaritaIconSize.small,
                color: colors.contentTertiary,
              ),
              const SizedBox(width: MaritaSpacing.xs),
              Expanded(
                child: Text(
                  'Invited by: $invitedByName',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              MaritaIcon(
                icon: MaritaIcons.shield,
                size: MaritaIconSize.small,
                color: colors.contentTertiary,
              ),
              const SizedBox(width: MaritaSpacing.xs),
              Expanded(
                child: Text(
                  'Access: $access',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MaritaSpacing.md),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(workspaceOpsProvider.notifier)
                        .declineInvitation(
                          workspaceId: companyId,
                          invitationId: invitationId,
                        );
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: MaritaRadius.borderSmall,
                      border: Border.all(color: colors.borderPrimary),
                    ),
                    child: Center(
                      child: Text(
                        'Decline',
                        style: typography.bodyDefaultBold.copyWith(
                          color: colors.contentSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MaritaSpacing.md),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(workspaceOpsProvider.notifier)
                        .acceptInvitation(
                          workspaceId: companyId,
                          invitationId: invitationId,
                        );
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.interactivePrimary,
                      borderRadius: MaritaRadius.borderSmall,
                    ),
                    child: Center(
                      child: Text(
                        'Accept',
                        style: typography.bodyDefaultBold.copyWith(
                          color: colors.backgroundPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
