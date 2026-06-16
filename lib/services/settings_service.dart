import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/result.dart';
import '../core/app_error.dart';

class SettingsService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  SettingsService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Updates details of the user profile.
  Future<Result<void>> updateProfile(
    String userId, {
    String? name,
    String? phoneNumber,
    String? photoUrl,
    String? email,
    String? password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Failure(
          AppError(code: 'no-user', message: 'No authenticated user found.'),
        );
      }

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      // Update Email in Firebase Auth and Firestore if requested
      if (email != null &&
          email.trim().isNotEmpty &&
          email.trim() != user.email) {
        await user.verifyBeforeUpdateEmail(email.trim());
        updates['email'] = email.trim();
      }

      // Update Password in Firebase Auth if requested
      if (password != null && password.isNotEmpty) {
        await user.updatePassword(password);
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }
      return const Success(null);
    } on FirebaseAuthException catch (e, stack) {
      if (e.code == 'requires-recent-login') {
        return Failure(
          AppError(
            code: 'requires-recent-login',
            message:
                'This operation is sensitive and requires recent authentication. Please log in again.',
            stackTrace: stack,
          ),
        );
      }
      return Failure(
        AppError(
          code: 'auth-update-failed',
          message: 'Authentication update failed: ${e.message}',
          stackTrace: stack,
        ),
      );
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'profile-update-failed',
          message: 'Failed to update profile: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Toggles/saves biometric security preference.
  Future<Result<void>> updateBiometricPreference(
    String userId,
    bool enabled,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBiometricEnabled': enabled,
      });
      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'biometric-preference-update-failed',
          message: 'Failed to update biometric preference: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Uploads a profile image to Firebase Storage and returns the download URL.
  Future<Result<String>> uploadProfilePhoto(String userId, File file) async {
    try {
      final ref = _storage.ref().child('users/$userId/profile/avatar.png');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return Success(downloadUrl);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'photo-upload-failed',
          message: 'Failed to upload profile photo: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Deletes the user account from Firebase Auth and Firestore.
  Future<Result<void>> deleteAccount(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Failure(
          AppError(code: 'no-user', message: 'No authenticated user found.'),
        );
      }

      // 1. Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // 2. Delete authenticated user
      await user.delete();

      return const Success(null);
    } on FirebaseAuthException catch (e, stack) {
      if (e.code == 'requires-recent-login') {
        return Failure(
          AppError(
            code: 'requires-recent-login',
            message:
                'This operation is sensitive and requires recent authentication. Please log in again.',
            stackTrace: stack,
          ),
        );
      }
      return Failure(
        AppError(
          code: 'delete-account-failed',
          message: 'Failed to delete account: ${e.message}',
          stackTrace: stack,
        ),
      );
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'delete-account-failed',
          message: 'Failed to delete account: $e',
          stackTrace: stack,
        ),
      );
    }
  }
}
