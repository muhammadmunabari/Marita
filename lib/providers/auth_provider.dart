// =============================================================================
// AUTH PROVIDERS — Riverpod
// =============================================================================
//
// Provides authentication state and services to the widget tree.
//
// Providers:
//   - authServiceProvider  → singleton AuthService instance
//   - authStateProvider    → real-time stream of Firebase User
//   - currentUserProvider  → convenience accessor for current User
//
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// Singleton [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Real-time stream of the Firebase [User].
///
/// Emits `null` when the user is signed out.
/// Used by the router for auth redirect guards.
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Convenience provider for the currently signed-in [User].
///
/// Returns `null` if not authenticated.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Real-time stream of the current user's Firestore document.
///
/// Used to check custom claims or fields like `isPhoneVerified`.
final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});
