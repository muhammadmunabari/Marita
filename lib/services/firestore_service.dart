// =============================================================================
// FIRESTORE SERVICE — Database Operations
// =============================================================================
//
// CRUD operations for all Firestore collections, matching firestore_schema.txt:
//   - users/{userId}
//   - companies/{companyId}
//   - reports/{reportId}
//   - chats/{chatId}
//
// Rules:
//   - No raw Firestore calls in UI layer
//   - All access goes through this service
//   - Schema-aligned field names
//
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Service class wrapping all Firestore operations.
///
/// All methods use typed data maps aligned with the Firestore schema.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ===========================================================================
  // USERS
  // ===========================================================================

  /// Creates a user profile document after sign-up.
  Future<void> createUser({
    required String userId,
    required String name,
    required String email,
    String role = 'founder',
  }) async {
    await _db.collection('users').doc(userId).set({
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches a user profile by ID.
  Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Real-time stream of a user profile.
  Stream<Map<String, dynamic>?> watchUser(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  // ===========================================================================
  // COMPANIES
  // ===========================================================================

  /// Creates a new company.
  Future<String> createCompany({
    required String name,
    required String ownerId,
  }) async {
    final doc = await _db.collection('companies').add({
      'name': name,
      'ownerId': ownerId,
      'members': [ownerId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Fetches companies where the user is owner or member.
  Future<List<Map<String, dynamic>>> getUserCompanies(String userId) async {
    final query =
        await _db
            .collection('companies')
            .where('members', arrayContains: userId)
            .get();

    return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Real-time stream of user's companies.
  Stream<List<Map<String, dynamic>>> watchUserCompanies(String userId) {
    return _db
        .collection('companies')
        .where('members', arrayContains: userId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  // ===========================================================================
  // REPORTS
  // ===========================================================================

  /// Creates a new report with financial input data.
  /// Status is set to "pending" — Cloud Function will process it.
  Future<String> createReport({
    required String companyId,
    required String createdBy,
    required double revenue,
    required double netIncome,
    required double totalAssets,
    required double totalLiabilities,
    required double cashFlow,
  }) async {
    final doc = await _db.collection('reports').add({
      'companyId': companyId,
      'createdBy': createdBy,
      'status': 'pending',
      'input': {
        'revenue': revenue,
        'netIncome': netIncome,
        'totalAssets': totalAssets,
        'totalLiabilities': totalLiabilities,
        'cashFlow': cashFlow,
      },
      'beneishScore': null,
      'fraudRisk': null,
      'aiInsight': null,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    });
    return doc.id;
  }

  /// Fetches a single report by ID.
  Future<Map<String, dynamic>?> getReport(String reportId) async {
    final doc = await _db.collection('reports').doc(reportId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Real-time stream of a single report (for live status updates).
  Stream<Map<String, dynamic>?> watchReport(String reportId) {
    return _db.collection('reports').doc(reportId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  /// Real-time stream of reports for a company, ordered by createdAt DESC.
  /// Uses the composite index: companyId + createdAt DESC.
  Stream<List<Map<String, dynamic>>> watchCompanyReports(String companyId) {
    return _db
        .collection('reports')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  // ===========================================================================
  // CHATS
  // ===========================================================================

  /// Creates a new chat session linked to a report.
  Future<String> createChat({
    required String reportId,
    required String userId,
  }) async {
    final doc = await _db.collection('chats').add({
      'reportId': reportId,
      'userId': userId,
      'messages': <Map<String, dynamic>>[],
    });
    return doc.id;
  }

  /// Appends a message to an existing chat.
  Future<void> addChatMessage({
    required String chatId,
    required String role,
    required String content,
  }) async {
    await _db.collection('chats').doc(chatId).update({
      'messages': FieldValue.arrayUnion([
        {'role': role, 'content': content, 'createdAt': Timestamp.now()},
      ]),
    });
  }

  /// Real-time stream of a chat session.
  Stream<Map<String, dynamic>?> watchChat(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }
}
