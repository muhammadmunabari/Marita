import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String phoneNumber;
  final String? photoUrl;
  final bool hasBusinessAccount;
  final bool isBiometricEnabled;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.phoneNumber,
    this.photoUrl,
    required this.hasBusinessAccount,
    required this.isBiometricEnabled,
    required this.createdAt,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final createdTimestamp = map['createdAt'] as Timestamp?;
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      photoUrl: map['photoUrl'],
      hasBusinessAccount: map['hasBusinessAccount'] ?? false,
      isBiometricEnabled: map['isBiometricEnabled'] ?? false,
      createdAt: createdTimestamp != null ? createdTimestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'hasBusinessAccount': hasBusinessAccount,
      'isBiometricEnabled': isBiometricEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserProfile copyWith({
    String? name,
    String? phoneNumber,
    String? photoUrl,
    bool? hasBusinessAccount,
    bool? isBiometricEnabled,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      hasBusinessAccount: hasBusinessAccount ?? this.hasBusinessAccount,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      createdAt: createdAt,
    );
  }
}
