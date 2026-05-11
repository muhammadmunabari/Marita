// =============================================================================
// MARITA — ROUTER (GoRouter + Auth Guard)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/signup/signup_screen.dart';
import 'screens/signup/create_business_account_screen.dart';
import 'screens/forgot_password/forgot_password_screen.dart';
import 'screens/main_navigation/main_navigation_screen.dart';
import 'screens/marita_ai/marita_ai_screen.dart';
import 'screens/report/report_screen.dart';
import 'screens/files/files_screen.dart';
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
  static const String createBusinessAccount = '/create-business-account';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/';
  static const String report = '/report';
  static const String files = '/files';
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

// =============================================================================
// ROUTER PROVIDER
// =============================================================================

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfileState = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: MaritaRoutes.splash,
    debugLogDiagnostics: false,

    // Auth redirect guard
    redirect: (context, state) {
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

        // If logged in, we MUST wait for the profile to decide where to go
        if (userProfileState.isLoading || userProfileState.isRefreshing) {
          return MaritaRoutes.splash; 
        }

        final profile = userProfileState.value;
        if (profile == null) {
          return MaritaRoutes.createBusinessAccount;
        }

        final hasBusiness = profile['hasBusinessAccount'] == true;
        return hasBusiness ? MaritaRoutes.home : MaritaRoutes.createBusinessAccount;
      }

      // 3. Protected Route Guard: If not logged in, only allow public routes
      if (!isLoggedIn && !isPublicRoute) {
        return MaritaRoutes.login;
      }

      // 4. Authenticated Guard: If logged in, prevent access to public auth routes
      if (isLoggedIn && (location == MaritaRoutes.login || location == MaritaRoutes.signup || location == MaritaRoutes.onboarding)) {
        if (userProfileState.isLoading) return MaritaRoutes.splash;

        final profile = userProfileState.value;
        final hasBusiness = profile?['hasBusinessAccount'] == true;
        return hasBusiness ? MaritaRoutes.home : MaritaRoutes.createBusinessAccount;
      }

      // 5. Business Account Guard: Ensure logged-in users have a business account
      if (isLoggedIn && 
          location != MaritaRoutes.createBusinessAccount && 
          location != MaritaRoutes.splash &&
          location != MaritaRoutes.settings) { 
        
        if (userProfileState.isLoading) return null;

        final profile = userProfileState.value;
        final hasBusiness = profile?['hasBusinessAccount'] == true;
        
        if (!hasBusiness) {
          return MaritaRoutes.createBusinessAccount;
        }
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
        path: MaritaRoutes.createBusinessAccount,
        builder: (context, state) => const CreateBusinessAccountScreen(),
      ),
      GoRoute(
        path: MaritaRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
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
                path: MaritaRoutes.report,
                builder: (context, state) => const ReportScreen(),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MaritaRoutes.workspaces,
                builder: (context, state) => const WorkspacesScreen(),
              ),
            ],
          ),
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
