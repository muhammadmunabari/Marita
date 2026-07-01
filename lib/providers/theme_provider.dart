import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

/// Notifier to manage and persist the selected [ThemeMode].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeStr = prefs.getString(_themeKey);
    if (themeStr != null) {
      for (final mode in ThemeMode.values) {
        if (mode.name == themeStr) {
          return mode;
        }
      }
    }
    return ThemeMode.system;
  }

  /// Updates the theme mode and persists it to SharedPreferences.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_themeKey, mode.name);
  }
}

/// Provider for the application's current [ThemeMode].
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
