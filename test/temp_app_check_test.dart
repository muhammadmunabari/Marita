import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() {
  test('App check test', () {
    try {
      final provider = WebDebugProvider(
        debugToken: 'test-token',
      );
      debugPrint('WebDebugProvider created: $provider');
    } catch (e) {
      debugPrint('Error: $e');
    }
  });
}
