import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/marita_primary_button.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final biometricService = ref.read(biometricServiceProvider);
      final result = await biometricService.authenticate();
      
      if (result.isSuccess && result.dataOrNull == true) {
        // Set the session state to true
        ref.read(biometricSessionProvider.notifier).state = true;
        // GoRouter will automatically handle redirection since the guard evaluates again
      } else {
        if (mounted) {
          final error = result.errorOrNull;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error?.message ?? 'Biometric verification failed.'),
              backgroundColor: context.maritaColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: context.maritaColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await ref.read(authServiceProvider).signOut();
      // Reset the session state
      ref.read(biometricSessionProvider.notifier).state = false;
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Log out failed: $e'),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              
              // Logo
              Center(
                child: Image.asset(
                  'assets/logos/Logobug black bg.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: MaritaSpacing.xl),
              
              // Lock Status Title
              Center(
                child: Text(
                  'App Locked',
                  style: context.maritaTypography.displaySmall.copyWith(
                    color: context.maritaColors.contentPrimary,
                  ),
                ),
              ),
              const SizedBox(height: MaritaSpacing.xs),
              
              // Lock Status Subtitle
              Center(
                child: Text(
                  'Verify your identity to open Marita',
                  style: context.maritaTypography.bodyDefault.copyWith(
                    color: context.maritaColors.contentSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const Spacer(),
              
              // Fingerprint Icon / Scanning visual
              Center(
                child: GestureDetector(
                  onTap: _authenticate,
                  child: Container(
                    padding: const EdgeInsets.all(MaritaSpacing.xl),
                    decoration: BoxDecoration(
                      color: context.maritaColors.backgroundSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.maritaColors.borderPrimary,
                        width: 1,
                      ),
                    ),
                    child: MaritaIcon(
                      icon: MaritaIcons.fingerScan,
                      size: 64,
                      color: _isAuthenticating
                          ? context.maritaColors.interactivePrimary
                          : context.maritaColors.contentPrimary,
                    ),
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Buttons
              MaritaPrimaryButton(
                label: _isAuthenticating ? 'Verifying...' : 'Unlock with Biometrics',
                onPressed: _authenticate,
              ),
              
              const SizedBox(height: MaritaSpacing.md),
              
              TextButton(
                onPressed: _handleLogout,
                child: Text(
                  'Sign Out',
                  style: context.maritaTypography.bodyDefault.copyWith(
                    color: context.maritaColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: MaritaSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
