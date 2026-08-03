import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/marita_primary_button.dart';
import '../../components/marita_text_input.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isFormValid => _emailController.text.trim().isNotEmpty;

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your email address.'),
          backgroundColor: context.maritaColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset link sent to your email.'),
            backgroundColor: context.maritaColors.success,
          ),
        );
        context.pop(); // Go back to login
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset link: ${e.toString()}'),
            backgroundColor: context.maritaColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(
                left: MaritaSpacing.xl,
                right: MaritaSpacing.xl,
                top: MaritaSpacing.md,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: MaritaIcon(
                        icon: MaritaIcons.arrowLeft,
                        size: MaritaIconSize.medium,
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/logos/Logobug black bg.png',
                    width: 36,
                    height: 36,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MaritaSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Forgot password',
                      style: context.maritaTypography.titleMedium.copyWith(
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Enter your registered email address to receive a password reset link.',
                      style: context.maritaTypography.bodyDefault.copyWith(
                        color: context.maritaColors.contentSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Input Email
                    MaritaTextInput(
                      hint: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.only(
                left: MaritaSpacing.xl,
                right: MaritaSpacing.xl,
                bottom: 24, // 24px
              ),
              child: MaritaPrimaryButton(
                label: _isLoading ? 'Sending...' : 'Send Reset Link',
                onPressed:
                    (_isLoading || !_isFormValid) ? null : _handleResetPassword,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
