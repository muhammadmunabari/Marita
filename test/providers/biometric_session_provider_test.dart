import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marita/providers/settings_provider.dart';

void main() {
  group('BiometricSessionProvider Tests', () {
    test('starts with false by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(biometricSessionProvider);
      expect(state, isFalse);
    });

    test('can toggle state to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(biometricSessionProvider.notifier).state = true;
      expect(container.read(biometricSessionProvider), isTrue);
    });
  });
}
