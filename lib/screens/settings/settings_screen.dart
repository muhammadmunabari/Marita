import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../models/user_profile.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../components/marita_primary_button.dart';
import '../../components/marita_text_input.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: MaritaSpacing.lg,
                vertical: MaritaSpacing.md,
              ),
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
                            style: typography.bodyDefault.copyWith(
                              color: colors.contentSecondary,
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileHeader(context, profile),
                          const SizedBox(height: MaritaSpacing.xl),
                          _buildAccountSection(context, profile),
                          const SizedBox(height: MaritaSpacing.xl),
                          _buildSecuritySection(context, profile),
                          const SizedBox(height: MaritaSpacing.xl),
                          _buildAppearanceSection(context),
                          const SizedBox(height: MaritaSpacing.xl),
                          _buildOthersSection(context),
                        ],
                      );
                    },
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (err, _) => Center(
                          child: Text(
                            'Error loading profile: $err',
                            style: typography.bodyDefault.copyWith(
                              color: colors.error,
                            ),
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
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfile profile) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final initials =
        profile.name.isNotEmpty
            ? profile.name
                .trim()
                .split(' ')
                .map((e) => e.isNotEmpty ? e[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : profile.email.isNotEmpty
            ? profile.email[0].toUpperCase()
            : '?';

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickAndUploadPhoto(context),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colors.backgroundSecondary,
                  backgroundImage:
                      profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                          ? NetworkImage(profile.photoUrl!)
                          : null,
                  child:
                      profile.photoUrl == null || profile.photoUrl!.isEmpty
                          ? Text(
                            initials,
                            style: typography.titleLarge.copyWith(
                              color: colors.contentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          )
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.interactivePrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: colors.backgroundPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MaritaSpacing.md),
          Text(
            profile.name.isNotEmpty ? profile.name : 'No Name Set',
            style: typography.bodyLargeBold.copyWith(
              color: colors.contentPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: typography.bodyDefault.copyWith(
              color: colors.contentSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, UserProfile profile) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: typography.bodyLargeBold.copyWith(
            color: colors.contentPrimary,
          ),
        ),
        const SizedBox(height: MaritaSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(color: colors.borderPrimary),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.user,
                title: 'Full Name',
                subtitle:
                    profile.name.isNotEmpty ? profile.name : 'No Name Set',
                trailing: MaritaIcon(
                  icon: MaritaIcons.arrowRight,
                  color: colors.contentTertiary,
                  size: 20,
                ),
                onTap: () => _showEditNameSheet(context, profile),
              ),
              Divider(color: colors.borderPrimary, height: 1),
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.sms,
                title: 'Email Address',
                subtitle: profile.email,
                trailing: MaritaIcon(
                  icon: MaritaIcons.copy,
                  color: colors.contentTertiary,
                  size: 20,
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: profile.email));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Email address copied to clipboard.',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: colors.success,
                      ),
                    );
                  }
                },
              ),
              Divider(color: colors.borderPrimary, height: 1),
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.lock,
                title: 'Change Password',
                subtitle: 'Update your account password',
                trailing: MaritaIcon(
                  icon: MaritaIcons.arrowRight,
                  color: colors.contentTertiary,
                  size: 20,
                ),
                onTap: () => _showChangePasswordSheet(context),
              ),
            ],
          ),
        ),
      ],
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
          style: typography.bodyLargeBold.copyWith(
            color: colors.contentPrimary,
          ),
        ),
        const SizedBox(height: MaritaSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(color: colors.borderPrimary),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildSettingsTile(
            context: context,
            leadingIcon: MaritaIcons.shield,
            title: 'Enabled Biometric Auth',
            subtitle: 'Use fingerprint or face ID to secure your account.',
            trailing: Switch(
              value: profile.isBiometricEnabled,
              activeThumbColor: colors.interactivePrimary,
              activeTrackColor: colors.interactivePrimary.withValues(
                alpha: 0.3,
              ),
              inactiveThumbColor: colors.contentTertiary,
              inactiveTrackColor: colors.backgroundPrimary,
              onChanged: (value) async {
                await ref
                    .read(settingsNotifierProvider.notifier)
                    .toggleBiometrics(value);
              },
            ),
            onTap: () async {
              await ref
                  .read(settingsNotifierProvider.notifier)
                  .toggleBiometrics(!profile.isBiometricEnabled);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: typography.bodyLargeBold.copyWith(
            color: colors.contentPrimary,
          ),
        ),
        const SizedBox(height: MaritaSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(color: colors.borderPrimary),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.sun,
                title: 'Light',
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: currentThemeMode,
                  activeColor: colors.interactivePrimary,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                    }
                  },
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                },
              ),
              Divider(color: colors.borderPrimary, height: 1),
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.moon,
                title: 'Dark',
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: currentThemeMode,
                  activeColor: colors.interactivePrimary,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                    }
                  },
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                },
              ),
              Divider(color: colors.borderPrimary, height: 1),
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.settings,
                title: 'Use Device Settings',
                subtitle: "Match appearance to your device's Display & Brightness settings.",
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: currentThemeMode,
                  activeColor: colors.interactivePrimary,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                    }
                  },
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOthersSection(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Others',
          style: typography.bodyLargeBold.copyWith(
            color: colors.contentPrimary,
          ),
        ),
        const SizedBox(height: MaritaSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(color: colors.borderPrimary),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.logout,
                title: 'Log Out',
                trailing: MaritaIcon(
                  icon: MaritaIcons.arrowRight,
                  color: colors.contentTertiary,
                  size: 20,
                ),
                onTap: () => _confirmLogout(context),
              ),
              Divider(color: colors.borderPrimary, height: 1),
              _buildSettingsTile(
                context: context,
                leadingIcon: MaritaIcons.trash,
                iconColor: colors.error,
                title: 'Delete Account',
                textColor: colors.error,
                trailing: MaritaIcon(
                  icon: MaritaIcons.arrowRight,
                  color: colors.error,
                  size: 20,
                ),
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData leadingIcon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MaritaSpacing.md,
          vertical: MaritaSpacing.md,
        ),
        child: Row(
          children: [
            MaritaIcon(
              icon: leadingIcon,
              color: iconColor ?? colors.contentPrimary,
              size: MaritaIconSize.medium,
            ),
            const SizedBox(width: MaritaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: typography.bodyDefaultBold.copyWith(
                      color: textColor ?? colors.contentPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: typography.bodyDefault.copyWith(
                        color: colors.contentSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: MaritaSpacing.sm),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  void _showEditNameSheet(BuildContext context, UserProfile profile) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final nameController = TextEditingController(text: profile.name);

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
                      'Edit Full Name',
                      style: typography.titleLarge.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    MaritaTextInput(
                      controller: nameController,
                      label: 'Full Name *',
                      hint: 'Enter your full name',
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: MaritaSpacing.xl),
                    MaritaPrimaryButton(
                      label: 'Save Changes',
                      onPressed:
                          isFormValid
                              ? () async {
                                Navigator.pop(context);
                                await ref
                                    .read(settingsNotifierProvider.notifier)
                                    .updateProfile(
                                      name: nameController.text.trim(),
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

  void _showChangePasswordSheet(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

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
            final password = passwordController.text;
            final confirmPassword = confirmPasswordController.text;

            final isPasswordValid = password.isNotEmpty && password.length >= 6;
            final isConfirmPasswordValid = confirmPassword == password;
            final isFormValid = isPasswordValid && isConfirmPasswordValid;

            String? passwordErrorText;
            if (password.isNotEmpty && password.length < 6) {
              passwordErrorText = 'Password must be at least 6 characters';
            }

            String? confirmPasswordErrorText;
            if (confirmPassword.isNotEmpty && confirmPassword != password) {
              confirmPasswordErrorText = 'Passwords do not match';
            }

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
                      'Change Password',
                      style: typography.titleLarge.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    MaritaTextInput(
                      controller: passwordController,
                      label: 'Create New Password',
                      hint: 'Enter a new password (min 6 chars)',
                      obscureText: obscurePassword,
                      errorText: passwordErrorText,
                      suffixIcon:
                          obscurePassword
                              ? MaritaIcons.eyeSlash
                              : MaritaIcons.eye,
                      onSuffixIconTap: () {
                        setModalState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    MaritaTextInput(
                      controller: confirmPasswordController,
                      label: 'Confirm New Password',
                      hint: 'Re-enter the new password',
                      obscureText: obscureConfirmPassword,
                      errorText: confirmPasswordErrorText,
                      suffixIcon:
                          obscureConfirmPassword
                              ? MaritaIcons.eyeSlash
                              : MaritaIcons.eye,
                      onSuffixIconTap: () {
                        setModalState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: MaritaSpacing.xl),
                    MaritaPrimaryButton(
                      label: 'Save Changes',
                      onPressed:
                          isFormValid
                              ? () async {
                                Navigator.pop(context);
                                await ref
                                    .read(settingsNotifierProvider.notifier)
                                    .updateProfile(password: password);
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
        await ref
            .read(settingsNotifierProvider.notifier)
            .uploadProfilePhoto(file);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to select image: $e',
            style: const TextStyle(color: Colors.white),
          ),
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
          title: Text(
            'Log Out',
            style: typography.bodyLargeBold.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of your account?',
            style: typography.bodyDefault.copyWith(
              color: colors.contentSecondary,
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
                await ref.read(settingsNotifierProvider.notifier).logout();
              },
              child: Text(
                'Log Out',
                style: typography.bodyDefaultBold.copyWith(
                  color: colors.interactivePrimary,
                ),
              ),
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
          title: Text(
            'Delete Account',
            style: typography.bodyLargeBold.copyWith(color: colors.error),
          ),
          content: Text(
            'This action is irreversible and will permanently delete your profile and account settings. Are you sure you want to proceed?',
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
                    .read(settingsNotifierProvider.notifier)
                    .deleteAccount();
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
}
