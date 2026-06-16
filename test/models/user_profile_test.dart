import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marita/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    final mockTimestamp = Timestamp.fromDate(DateTime(2026, 6, 4));
    final mockMap = {
      'email': 'test@example.com',
      'name': 'John Doe',
      'phoneNumber': '+1234567890',
      'photoUrl': 'https://example.com/avatar.png',
      'hasBusinessAccount': true,
      'isBiometricEnabled': true,
      'createdAt': mockTimestamp,
    };

    test('should correctly deserialize from map', () {
      final profile = UserProfile.fromMap('user123', mockMap);

      expect(profile.uid, 'user123');
      expect(profile.email, 'test@example.com');
      expect(profile.name, 'John Doe');
      expect(profile.phoneNumber, '+1234567890');
      expect(profile.photoUrl, 'https://example.com/avatar.png');
      expect(profile.hasBusinessAccount, true);
      expect(profile.isBiometricEnabled, true);
      expect(profile.createdAt, mockTimestamp.toDate());
    });

    test('should correctly serialize to map', () {
      final profile = UserProfile(
        uid: 'user123',
        email: 'test@example.com',
        name: 'John Doe',
        phoneNumber: '+1234567890',
        photoUrl: 'https://example.com/avatar.png',
        hasBusinessAccount: true,
        isBiometricEnabled: true,
        createdAt: mockTimestamp.toDate(),
      );

      final map = profile.toMap();

      expect(map['email'], 'test@example.com');
      expect(map['name'], 'John Doe');
      expect(map['phoneNumber'], '+1234567890');
      expect(map['photoUrl'], 'https://example.com/avatar.png');
      expect(map['hasBusinessAccount'], true);
      expect(map['isBiometricEnabled'], true);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('copyWith should copy properties correctly', () {
      final profile = UserProfile(
        uid: 'user123',
        email: 'test@example.com',
        name: 'John Doe',
        phoneNumber: '+1234567890',
        photoUrl: 'https://example.com/avatar.png',
        hasBusinessAccount: true,
        isBiometricEnabled: true,
        createdAt: mockTimestamp.toDate(),
      );

      final updatedProfile = profile.copyWith(
        name: 'Jane Doe',
        isBiometricEnabled: false,
      );

      expect(updatedProfile.uid, 'user123');
      expect(updatedProfile.name, 'Jane Doe');
      expect(updatedProfile.isBiometricEnabled, false);
      expect(updatedProfile.email, 'test@example.com'); // unchanged
    });
  });
}
