import 'package:local_auth/local_auth.dart';
import '../core/result.dart';
import '../core/app_error.dart';

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<Result<bool>> authenticate() async {
    try {
      final isSupported = await canAuthenticate();
      if (!isSupported) {
        return const Failure(AppError(
          code: 'biometrics_unavailable',
          message: 'Biometrics are not available or supported on this device.',
        ));
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Verify your identity to update security settings',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        return const Success(true);
      } else {
        return const Failure(AppError(
          code: 'authentication_failed',
          message: 'Biometric verification failed.',
        ));
      }
    } catch (e) {
      return Failure(AppError(
        code: 'biometric_error',
        message: e.toString(),
      ));
    }
  }
}
