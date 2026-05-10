// =============================================================================
// MARITA — ROUTER (GoRouter + Auth Guard)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/signup/signup_screen.dart';
import 'screens/signup/create_business_account_screen.dart';
import 'screens/forgot_password/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/upload_report/upload_report_screen.dart';
import 'screens/report_detail/report_detail_screen.dart';
import 'screens/settings/settings_screen.dart';

// =============================================================================
// ROUTE PATHS
// =============================================================================

/// Centralized route path constants — no magic strings.
class MaritaRoutes {
  MaritaRoutes._();

  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String createBusinessAccount = '/create-business-account';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/';
  static const String uploadReport = '/upload';
  static const String reportDetail = '/report/:id';
  static const String settings = '/settings';

  /// Builds the report detail path with a specific [reportId].
  static String reportDetailPath(String reportId) => '/report/$reportId';
}

// =============================================================================
// ROUTER PROVIDER
// =============================================================================

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfileState = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: MaritaRoutes.onboarding,
    debugLogDiagnostics: false,

    // Auth redirect guard
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isPublicRoute =
          state.matchedLocation == MaritaRoutes.login ||
          state.matchedLocation == MaritaRoutes.signup ||
          state.matchedLocation == MaritaRoutes.forgotPassword ||
          state.matchedLocation == MaritaRoutes.onboarding;

      // Not logged in and not on public route → redirect to login
      if (!isLoggedIn && !isPublicRoute) {
        return MaritaRoutes.login;
      }

      // Logged in and on a public auth route (like login) → redirect to home
      // Note: We don't necessarily want to redirect if they are on splash/onboarding,
      // but for now we'll allow splash to do its thing.
      final isAuthScreen =
          state.matchedLocation == MaritaRoutes.login ||
          state.matchedLocation == MaritaRoutes.signup ||
          state.matchedLocation == MaritaRoutes.forgotPassword ||
          state.matchedLocation == MaritaRoutes.onboarding;

      if (isLoggedIn) {
        // If profile is loading, don't redirect yet (prevents flashes)
        if (userProfileState.isLoading) return null;

        final profileData = userProfileState.valueOrNull;
        final hasBusinessAccount = profileData?['hasBusinessAccount'] == true;

        if (!hasBusinessAccount) {
          if (state.matchedLocation != MaritaRoutes.createBusinessAccount) {
            return MaritaRoutes.createBusinessAccount;
          }
          return null;
        }

        // If verified and has business account, they shouldn't be on auth screens or business creation
        if (isAuthScreen || state.matchedLocation == MaritaRoutes.createBusinessAccount) {
          return MaritaRoutes.home;
        }
      }

      return null; // No redirect
    },

    routes: [
      // Entry & Public routes
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

      // Main routes (auth required)
      GoRoute(
        path: MaritaRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: MaritaRoutes.uploadReport,
        builder: (context, state) => const UploadReportScreen(),
      ),
      GoRoute(
        path: MaritaRoutes.reportDetail,
        builder: (context, state) {
          final reportId = state.pathParameters['id']!;
          return ReportDetailScreen(reportId: reportId);
        },
      ),
      GoRoute(
        path: MaritaRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
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
