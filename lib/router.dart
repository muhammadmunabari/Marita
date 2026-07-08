// =============================================================================
// MARITA — ROUTER (GoRouter + Auth Guard)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/biometric_lock_screen.dart';
import 'screens/signup/signup_screen.dart';
import 'screens/forgot_password/forgot_password_screen.dart';
import 'screens/main_navigation/main_navigation_screen.dart';
import 'screens/marita_ai/marita_ai_screen.dart';
import 'screens/files/files_screen.dart';
import 'screens/analyze/analyze_screen.dart';
import 'screens/workspaces/workspaces_screen.dart';
import 'screens/settings/settings_screen.dart';

// =============================================================================
// ROUTE PATHS
// =============================================================================

/// Centralized route path constants — no magic strings.
class MaritaRoutes {
  MaritaRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String biometricLock = '/biometric-lock';
  static const String home = '/';
  static const String files = '/files';
  static const String analyze = '/analyze';
  static const String workspaces = '/workspaces';
  static const String settings = '/settings';
  static const List<String> publicRoutes = [
    splash,
    onboarding,
    login,
    signup,
    forgotPassword,
  ];
}

class RouterListenable extends ChangeNotifier {
  final Ref _ref;

  RouterListenable(this._ref) {
    _ref.listen(authStateProvider, (prev, next) => notifyListeners());
    _ref.listen(userProfileModelProvider, (prev, next) => notifyListeners());
    _ref.listen(biometricSessionProvider, (prev, next) => notifyListeners());
    _ref.listen(
      localBiometricEnabledProvider,
      (prev, next) => notifyListeners(),
    );
  }

  void refresh() {
    notifyListeners();
  }
}

final routerListenableProvider = Provider<RouterListenable>((ref) {
  return RouterListenable(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerListenableProvider);

  return GoRouter(
    initialLocation: MaritaRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: listenable,

    // Auth redirect guard
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      // 1. Wait for Auth State to be fully determined
      if (authState.isLoading || authState.isRefreshing) {
        return MaritaRoutes.splash;
      }

      final user = authState.value;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;

      final isSplash = location == MaritaRoutes.splash;
      final isPublicRoute = MaritaRoutes.publicRoutes.contains(location);

      // 2. Handle Splash Screen Transition (initial load)
      if (isSplash) {
        if (!isLoggedIn) {
          return MaritaRoutes.onboarding;
        }
      }

      // 3. Protected Route Guard: If not logged in, only allow public routes
      if (!isLoggedIn) {
        if (!isPublicRoute) {
          return MaritaRoutes.login;
        }
        return null;
      }

      // 4. Authenticated Guard: If logged in, prevent access to public auth routes
      if (location == MaritaRoutes.login ||
          location == MaritaRoutes.signup ||
          location == MaritaRoutes.onboarding) {
        return MaritaRoutes.home;
      }

      // 5. Biometric Lock Guard
      final isBiometricEnabled = ref.read(localBiometricEnabledProvider);
      final isBiometricVerified = ref.read(biometricSessionProvider);

      if (isBiometricEnabled && !isBiometricVerified) {
        if (location != MaritaRoutes.biometricLock) {
          return MaritaRoutes.biometricLock;
        }
      } else {
        // If biometric is verified or not enabled, prevent access to biometricLock screen
        if (location == MaritaRoutes.biometricLock) {
          return MaritaRoutes.home;
        }
      }

      // If we are logged in and just came from Splash (and don't need biometric redirect or already verified)
      if (isSplash) {
        return MaritaRoutes.home;
      }

      return null; // No redirect
    },

    routes: [
      // Entry & Public routes
      GoRoute(
        path: MaritaRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: MaritaRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Auth routes
      GoRoute(
        path: MaritaRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: MaritaRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: MaritaRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: MaritaRoutes.biometricLock,
        builder: (context, state) => const BiometricLockScreen(),
      ),

      // Main Application Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MaritaRoutes.home,
                builder: (context, state) => const MaritaAIScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MaritaRoutes.files,
                builder: (context, state) => const FilesScreen(),
              ),
            ],
          ),
          // Index 2 — Analyze
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MaritaRoutes.analyze,
                builder: (context, state) => const AnalyzeScreen(),
              ),
            ],
          ),
          // Index 3 — Workspaces
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MaritaRoutes.workspaces,
                builder: (context, state) => const WorkspacesScreen(),
              ),
            ],
          ),
          // Index 4 — Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MaritaRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],

    // Error page
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
  );
});
