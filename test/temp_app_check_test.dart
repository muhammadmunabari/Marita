import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() {
  test('App check test', () {
    try {
      final provider = WebDebugProvider(
        debugToken: 'test-token',
      );
      print('WebDebugProvider created: $provider');
    } catch (e) {
      print('Error: $e');
    }
  });
}
