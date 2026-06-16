import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_error.dart';
import '../models/user_profile.dart';
import '../services/biometric_service.dart';
import '../services/settings_service.dart';
import 'auth_provider.dart';

// Services
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final localBiometricEnabledProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final profileAsync = ref.watch(userProfileModelProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile?.isBiometricEnabled ?? false,
    orElse: () {
      final prefs = ref.watch(sharedPreferencesProvider);
      return prefs.getBool('biometric_enabled_${user.uid}') ?? false;
    },
  );
});

// User Profile Model Stream Provider
final userProfileModelProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  
  return ref.watch(userProfileProvider).when(
    data: (data) {
      if (data == null) return Stream.value(null);
      final profile = UserProfile.fromMap(user.uid, data);
      
      // Cache in SharedPreferences
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setBool('biometric_enabled_${user.uid}', profile.isBiometricEnabled);
      
      return Stream.value(profile);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => Stream.value(null),
  );
});

// Settings UI State
class SettingsState {
  final bool isLoading;
  final AppError? error;
  final String? successMessage;

  SettingsState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  SettingsState copyWith({
    bool? isLoading,
    AppError? error,
    String? successMessage,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => SettingsState();

  SettingsService get _settingsService => ref.read(settingsServiceProvider);
  BiometricService get _biometricService => ref.read(biometricServiceProvider);

  Future<void> updateProfile({
    String? name,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    final result = await _settingsService.updateProfile(
      user.uid,
      name: name,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
    );

    result.fold(
      (data) {
        state = SettingsState(successMessage: 'Profile updated successfully.');
      },
      (error) {
        state = SettingsState(error: error);
      },
    );
  }

  Future<void> uploadProfilePhoto(File file) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    final uploadResult = await _settingsService.uploadProfilePhoto(user.uid, file);

    await uploadResult.fold(
      (photoUrl) async {
        final updateResult = await _settingsService.updateProfile(user.uid, photoUrl: photoUrl);
        updateResult.fold(
          (data) {
            state = SettingsState(successMessage: 'Profile picture updated successfully.');
          },
          (error) {
            state = SettingsState(error: error);
          },
        );
      },
      (error) async {
        state = SettingsState(error: error);
      },
    );
  }

  Future<void> toggleBiometrics(bool enabled) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true);

    if (enabled) {
      // Must authenticate using biometrics before enabling
      final authResult = await _biometricService.authenticate();
      if (authResult.isFailure) {
        state = SettingsState(error: authResult.errorOrNull);
        return;
      }
    }

    final result = await _settingsService.updateBiometricPreference(user.uid, enabled);
    result.fold(
      (data) {
        // Also save to SharedPreferences
        final prefs = ref.read(sharedPreferencesProvider);
        prefs.setBool('biometric_enabled_${user.uid}', enabled);
        
        state = SettingsState(
          successMessage: enabled ? 'Biometrics enabled successfully.' : 'Biometrics disabled.',
        );
      },
      (error) {
        state = SettingsState(error: error);
      },
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(authServiceProvider).signOut();
      state = SettingsState();
    } catch (e) {
      state = SettingsState(
        error: AppError(code: 'logout-failed', message: 'Failed to log out: $e'),
      );
    }
  }

  Future<void> deleteAccount() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    final result = await _settingsService.deleteAccount(user.uid);
    result.fold(
      (data) {
        state = SettingsState();
      },
      (error) {
        state = SettingsState(error: error);
      },
    );
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

/// Provider to track if the user has verified biometrics during the current app session.
class BiometricSessionNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Listen to auth state changes, and reset to false if the user becomes null
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
      if (next.value == null) {
        state = false;
      }
    });
    return false;
  }

  @override
  set state(bool value) => super.state = value;
}

final biometricSessionProvider = NotifierProvider<BiometricSessionNotifier, bool>(BiometricSessionNotifier.new);


