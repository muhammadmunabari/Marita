import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/marita_primary_button.dart';
import '../../components/marita_text_input.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../providers/auth_provider.dart';
import '../../router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
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
      await authService.signInWithEmail(email: email, password: password);

      // Router handles navigation automatically
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: context.maritaColors.error,
          ),
        );
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
                      onTap: () => context.go(MaritaRoutes.onboarding),
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
                      'Welcome back',
                      style: context.maritaTypography.displaySmall.copyWith(
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Log in to access your financial oversight.',
                      style: context.maritaTypography.bodyDefault.copyWith(
                        color: context.maritaColors.contentSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form Fields
                    MaritaTextInput(
                      hint: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    MaritaTextInput(
                      hint: 'Password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      suffixIcon:
                          _obscurePassword
                              ? MaritaIcons.eyeSlash
                              : MaritaIcons.eye,
                      onSuffixIconTap: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: Text(
                          'Forgot password?',
                          style: context.maritaTypography.bodyDefault.copyWith(
                            color: context.maritaColors.interactivePrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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
                label: _isLoading ? 'Logging in...' : 'Log in',
                onPressed: (_isLoading || !_isFormValid) ? null : _handleLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
