import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../models/user_profile.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../services/migration_service.dart';
import '../../components/marita_primary_button.dart';
import '../../components/marita_text_input.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();

  // Option A/C — re-index state
  bool _isReindexing = false;
  String? _reindexResult;

  // Option C — diagnostic result
  String? _diagnosticResult;

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final profileAsync = ref.watch(userProfileModelProvider);
    final settingsState = ref.watch(settingsNotifierProvider);

    // Listen to success or error messages
    ref.listen(settingsNotifierProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!.message, style: const TextStyle(color: Colors.white)),
            backgroundColor: colors.error,
          ),
        );
      } else if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!, style: const TextStyle(color: Colors.white)),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.lg, vertical: MaritaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: typography.titleLarge.copyWith(
                      color: colors.contentPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: MaritaSpacing.xl),

                  profileAsync.when(
                    data: (profile) {
                      if (profile == null) {
                        return Center(
                          child: Text(
                            'User profile not found.',
                            style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileCard(context, profile),
                          const SizedBox(height: MaritaSpacing.xl),
                          _buildSecuritySection(context, profile),
                          const SizedBox(height: MaritaSpacing.xl),
                          _buildWorkspaceSection(context),
                          const SizedBox(height: MaritaSpacing.xl),
                          _buildActionsSection(context),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text(
                        'Error loading profile: $err',
                        style: typography.bodyDefault.copyWith(color: colors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (settingsState.isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(colors.interactivePrimary),
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    Text(
                      'Processing...',
                      style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserProfile profile) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final initials = profile.name.isNotEmpty
        ? profile.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : profile.email.isNotEmpty
            ? profile.email[0].toUpperCase()
            : '?';

    return Container(
      padding: const EdgeInsets.all(MaritaSpacing.lg),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: MaritaRadius.borderMedium,
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickAndUploadPhoto(context),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: colors.backgroundPrimary,
                  backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                      ? Text(
                          initials,
                          style: typography.titleLarge.copyWith(
                            color: colors.contentPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.interactivePrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: colors.backgroundPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MaritaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name.isNotEmpty ? profile.name : 'No Name Set',
                  style: typography.bodyLargeBold.copyWith(color: colors.contentPrimary),
                ),
                Text(
                  profile.email,
                  style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                ),
                if (profile.phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.phoneNumber,
                    style: typography.bodyDefault.copyWith(color: colors.contentTertiary),
                  ),
                ],
                const SizedBox(height: MaritaSpacing.xs),
                GestureDetector(
                  onTap: () => _showEditProfileSheet(context, profile),
                  child: Text(
                    'Edit Profile',
                    style: typography.bodyDefaultBold.copyWith(
                      color: colors.interactivePrimary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context, UserProfile profile) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security',
          style: typography.bodyLargeBold.copyWith(color: colors.contentPrimary),
        ),
        const SizedBox(height: MaritaSpacing.md),
        Container(
          padding: const EdgeInsets.all(MaritaSpacing.md),
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(color: colors.borderPrimary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biometric Authentication',
                      style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Use fingerprint or face ID to secure your account.',
                      style: typography.bodyDefault.copyWith(color: colors.contentSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: profile.isBiometricEnabled,
                activeThumbColor: colors.interactivePrimary,
                activeTrackColor: colors.interactivePrimary.withValues(alpha: 0.3),
                inactiveThumbColor: colors.contentTertiary,
                inactiveTrackColor: colors.backgroundPrimary,
                onChanged: (value) async {
                  await ref.read(settingsNotifierProvider.notifier).toggleBiometrics(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Workspace Intelligence section (Option A + C)
  // ---------------------------------------------------------------------------

  Widget _buildWorkspaceSection(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final workspace = ref.watch(activeWorkspaceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workspace Intelligence',
          style: typography.bodyLargeBold.copyWith(color: colors.contentPrimary),
        ),
        const SizedBox(height: MaritaSpacing.md),
        Container(
          padding: const EdgeInsets.all(MaritaSpacing.md),
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(color: colors.borderPrimary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: colors.interactivePrimary, size: 18),
                  const SizedBox(width: MaritaSpacing.xs),
                  Expanded(
                    child: Text(
                      'Document Re-indexing',
                      style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Force re-process all workspace files so Marita AI can cite them correctly.',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: MaritaSpacing.md),

              // Result banner
              if (_reindexResult != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MaritaSpacing.sm,
                    vertical: MaritaSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: MaritaRadius.borderSmall,
                    border: Border.all(color: colors.borderPrimary),
                  ),
                  child: Text(
                    _reindexResult!,
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.sm),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: workspace == null || _isReindexing
                          ? null
                          : () => _runDiagnostic(workspace.id),
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Diagnose'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.contentSecondary,
                        side: BorderSide(color: colors.borderPrimary),
                        textStyle: typography.bodyDefault.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: MaritaSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: workspace == null || _isReindexing
                          ? null
                          : () => _forceReindex(workspace.id),
                      icon: _isReindexing
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.backgroundPrimary,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(_isReindexing ? 'Indexing…' : 'Force Re-index'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.interactivePrimary,
                        foregroundColor: colors.backgroundPrimary,
                        textStyle: typography.bodyDefault.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),

              // Diagnostic output
              if (_diagnosticResult != null) ...[
                const SizedBox(height: MaritaSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(MaritaSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: MaritaRadius.borderSmall,
                    border: Border.all(color: colors.borderPrimary),
                  ),
                  child: Text(
                    _diagnosticResult!,
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Option A — force re-index all workspace files.
  Future<void> _forceReindex(String workspaceId) async {
    setState(() {
      _isReindexing = true;
      _reindexResult = null;
      _diagnosticResult = null;
    });
    try {
      await ref
          .read(migrationServiceProvider)
          .reindexWorkspaceFiles(workspaceId, force: true);
      if (mounted) {
        setState(() => _reindexResult = '✓ Re-index complete. Check Files tab to verify.');
      }
    } catch (e) {
      if (mounted) setState(() => _reindexResult = '✗ Re-index failed: $e');
    } finally {
      if (mounted) setState(() => _isReindexing = false);
    }
  }

  /// Option C — diagnostic: count files and chunks in Firestore.
  Future<void> _runDiagnostic(String workspaceId) async {
    setState(() {
      _diagnosticResult = 'Running diagnostic…';
      _reindexResult = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final filesSnap = await db
          .collection('companies')
          .doc(workspaceId)
          .collection('files')
          .get();

      final sb = StringBuffer();
      sb.writeln('Workspace: $workspaceId');
      sb.writeln('Total file docs: ${filesSnap.docs.length}');
      sb.writeln('');

      int totalChunks = 0;
      for (final doc in filesSnap.docs) {
        final data = doc.data();
        final name = data['name'] ?? doc.id;
        final isFolder = data['isFolder'] as bool? ?? false;
        final isIndexed = data['isIndexed'] as bool? ?? false;
        final chunkCount = data['chunkCount'] as int? ?? 0;
        final hasText = (data['extractedText'] as String?)?.isNotEmpty ?? false;
        final error = data['indexError'] as String?;

        if (!isFolder) {
          final chunksSnap = await doc.reference.collection('chunks').get();
          totalChunks += chunksSnap.docs.length;
          sb.writeln('📄 $name');
          sb.writeln('   indexed=$isIndexed  chunkCount=$chunkCount  realChunks=${chunksSnap.docs.length}  hasStoredText=$hasText');
          if (error != null) sb.writeln('   ⚠ error: $error');
        }
      }

      sb.writeln('');
      sb.writeln('Total real chunks in Firestore: $totalChunks');

      if (mounted) setState(() => _diagnosticResult = sb.toString());
    } catch (e) {
      if (mounted) setState(() => _diagnosticResult = '✗ Diagnostic error: $e');
    }
  }

  Widget _buildActionsSection(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Actions',
          style: typography.bodyLargeBold.copyWith(color: colors.contentPrimary),
        ),
        const SizedBox(height: MaritaSpacing.md),
        ListTile(
          tileColor: colors.backgroundSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: MaritaRadius.borderMedium,
            side: BorderSide(color: colors.borderPrimary),
          ),
          leading: Icon(MaritaIcons.logout, color: colors.contentPrimary),
          title: Text(
            'Log Out',
            style: typography.bodyDefaultBold.copyWith(color: colors.contentPrimary),
          ),
          trailing: Icon(MaritaIcons.arrowRight, color: colors.contentTertiary, size: 20),
          onTap: () => _confirmLogout(context),
        ),
        const SizedBox(height: MaritaSpacing.md),
        ListTile(
          tileColor: colors.backgroundSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: MaritaRadius.borderMedium,
            side: BorderSide(color: colors.borderPrimary),
          ),
          leading: Icon(MaritaIcons.trash, color: colors.error),
          title: Text(
            'Delete Account',
            style: typography.bodyDefaultBold.copyWith(color: colors.error),
          ),
          trailing: Icon(MaritaIcons.arrowRight, color: colors.error, size: 20),
          onTap: () => _confirmDeleteAccount(context),
        ),
      ],
    );
  }

  void _showEditProfileSheet(BuildContext context, UserProfile profile) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final nameController = TextEditingController(text: profile.name);
    final phoneController = TextEditingController(text: profile.phoneNumber);

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
                bottom: MediaQuery.of(context).viewInsets.bottom + MaritaSpacing.lg,
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
                      'Edit Profile Details',
                      style: typography.titleLarge.copyWith(color: colors.contentPrimary),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    MaritaTextInput(
                      controller: nameController,
                      label: 'Full Name *',
                      hint: 'Enter your full name',
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    MaritaTextInput(
                      controller: phoneController,
                      label: 'Phone Number',
                      hint: 'Enter your phone number',
                    ),
                    const SizedBox(height: MaritaSpacing.xl),
                    MaritaPrimaryButton(
                      label: 'Save Changes',
                      onPressed: isFormValid
                          ? () async {
                              Navigator.pop(context);
                              await ref.read(settingsNotifierProvider.notifier).updateProfile(
                                    name: nameController.text.trim(),
                                    phoneNumber: phoneController.text.trim(),
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

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final colors = context.maritaColors;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = colors.error;
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        await ref.read(settingsNotifierProvider.notifier).uploadProfilePhoto(file);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to select image: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text('Log Out', style: typography.bodyLargeBold.copyWith(color: colors.contentPrimary)),
          content: Text(
            'Are you sure you want to log out of your account?',
            style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: typography.bodyDefault.copyWith(color: colors.contentSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(settingsNotifierProvider.notifier).logout();
              },
              child: Text('Log Out', style: typography.bodyDefaultBold.copyWith(color: colors.interactivePrimary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text('Delete Account', style: typography.bodyLargeBold.copyWith(color: colors.error)),
          content: Text(
            'This action is irreversible and will permanently delete your profile and account settings. Are you sure you want to proceed?',
            style: typography.bodyDefault.copyWith(color: colors.contentPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: typography.bodyDefault.copyWith(color: colors.contentSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(settingsNotifierProvider.notifier).deleteAccount();
              },
              child: Text('Delete', style: typography.bodyDefaultBold.copyWith(color: colors.error)),
            ),
          ],
        );
      },
    );
  }
}
