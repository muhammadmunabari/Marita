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
  final _inputController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;
  String?
  _verificationId; // Null means we are on step 1: enter email/phone. Non-null means step 2: enter OTP
  bool _isPhoneMode = false;

  @override
  void dispose() {
    _inputController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final input = _inputController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an email or phone number.'),
          backgroundColor: context.maritaColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);

      // Determine if it's an email or phone number
      if (input.contains('@')) {
        // Handle Email Reset
        _isPhoneMode = false;
        await authService.sendPasswordResetEmail(email: input);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Password reset link sent to your email.'),
              backgroundColor: context.maritaColors.success,
            ),
          );
          context.pop(); // Go back to login
        }
      } else {
        // Handle Phone Reset
        _isPhoneMode = true;
        await authService.verifyPhoneForPasswordReset(
          phoneNumber: input.startsWith('+') ? input : '+$input',
          codeSent: (verificationId) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _isLoading = false;
              });
            }
          },
          verificationFailed: (error) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Verification failed: ${error.message}'),
                  backgroundColor: context.maritaColors.error,
                ),
              );
            }
          },
        );
        return; // Wait for codeSent callback
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: context.maritaColors.error,
          ),
        );
      }
    } finally {
      if (mounted && !_isPhoneMode) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVerifyAndReset() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;

    if (otp.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields.'),
          backgroundColor: context.maritaColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPasswordWithPhoneOTP(
        verificationId: _verificationId!,
        smsCode: otp,
        newPassword: newPassword,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password successfully updated.'),
            backgroundColor: context.maritaColors.success,
          ),
        );
        context.go('/'); // Navigate to home since they are now signed in
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: ${e.toString()}'),
            backgroundColor: context.maritaColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStepTwo = _verificationId != null;

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
                      onTap: () {
                        if (isStepTwo) {
                          setState(() {
                            _verificationId = null;
                            _otpController.clear();
                            _newPasswordController.clear();
                          });
                        } else {
                          context.pop();
                        }
                      },
                      child: MaritaIcon(
                        icon: MaritaIcons.arrowLeft,
                        size: MaritaIconSize.medium,
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/logos/Logobug black bg.png',
                    width: 48,
                    height: 48,
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
                      isStepTwo ? 'Reset Password' : 'Forgot Password',
                      style: context.maritaTypography.displaySmall.copyWith(
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      isStepTwo
                          ? 'Enter the 6-digit verification code sent to your phone and your new password.'
                          : 'Enter your registered email or phone number (e.g. +628123...) to receive a password reset link or verification code.',
                      style: context.maritaTypography.bodyDefault.copyWith(
                        color: context.maritaColors.contentSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (!isStepTwo) ...[
                      // Step 1: Input Email/Phone
                      MaritaTextInput(
                        hint: 'Email or Phone Number',
                        controller: _inputController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 32),
                      MaritaPrimaryButton(
                        label: _isLoading ? 'Sending...' : 'Continue',
                        onPressed: _isLoading ? null : _handleContinue,
                      ),
                    ] else ...[
                      // Step 2: Input OTP & New Password
                      MaritaTextInput(
                        hint: '6-digit SMS Code',
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      MaritaTextInput(
                        hint: 'New Password',
                        controller: _newPasswordController,
                        obscureText: _isObscure,
                        suffixIcon:
                            _isObscure ? MaritaIcons.eyeSlash : MaritaIcons.eye,
                        onSuffixIconTap: () {
                          setState(() {
                            _isObscure = !_isObscure;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      MaritaPrimaryButton(
                        label: _isLoading ? 'Updating...' : 'Update Password',
                        onPressed: _isLoading ? null : _handleVerifyAndReset,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
