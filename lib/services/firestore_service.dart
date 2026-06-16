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

  /// Creates a new chat session.
  Future<String> createChat({
    String? reportId,
    required String userId,
    String? initialMessage,
    String? title,
  }) async {
    final doc = await _db.collection('chats').add({
      'reportId': reportId,
      'userId': userId,
      'messages': <Map<String, dynamic>>[],
      'lastMessage': initialMessage ?? '',
      'title': title ?? 'New Chat',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Appends a message to an existing chat.
  Future<void> addChatMessage({
    required String chatId,
    required Map<String, dynamic> messageMap,
  }) async {
    await _db.collection('chats').doc(chatId).update({
      'messages': FieldValue.arrayUnion([messageMap]),
      'lastMessage': messageMap['text'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches all chat sessions for a user.
  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    final query = await _db
        .collection('chats')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .get();

    return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Deletes a chat session.
  Future<void> deleteChat(String chatId) async {
    await _db.collection('chats').doc(chatId).delete();
  }

  /// Updates the title of a chat session.
  Future<void> updateChatTitle(String chatId, String newTitle) async {
    await _db.collection('chats').doc(chatId).update({
      'title': newTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of a chat session.
  Stream<Map<String, dynamic>?> watchChat(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  // ===========================================================================
  // WORKSPACE CHATS
  // ===========================================================================

  /// Creates a new workspace chat session.
  Future<String> createWorkspaceChat({
    required String companyId,
    String? reportId,
    required String userId,
    String? initialMessage,
    String? title,
  }) async {
    final doc = await _db
        .collection('companies')
        .doc(companyId)
        .collection('chats')
        .add({
      'reportId': reportId,
      'userId': userId,
      'messages': <Map<String, dynamic>>[],
      'lastMessage': initialMessage ?? '',
      'title': title ?? 'New Chat',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Appends a message to an existing workspace chat.
  Future<void> addWorkspaceChatMessage({
    required String companyId,
    required String chatId,
    required Map<String, dynamic> messageMap,
  }) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('chats')
        .doc(chatId)
        .update({
      'messages': FieldValue.arrayUnion([messageMap]),
      'lastMessage': messageMap['text'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches all chat sessions for a workspace.
  Future<List<Map<String, dynamic>>> getWorkspaceChats(String companyId) async {
    final query = await _db
        .collection('companies')
        .doc(companyId)
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .get();

    return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Deletes a workspace chat session.
  Future<void> deleteWorkspaceChat(String companyId, String chatId) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('chats')
        .doc(chatId)
        .delete();
  }

  /// Updates the title of a workspace chat session.
  Future<void> updateWorkspaceChatTitle(String companyId, String chatId, String newTitle) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('chats')
        .doc(chatId)
        .update({
      'title': newTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of a workspace chat session.
  Stream<Map<String, dynamic>?> watchWorkspaceChat(String companyId, String chatId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  // ===========================================================================
  // PROFILE / USER ENHANCEMENTS
  // ===========================================================================

  /// Updates user profile fields.
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes user document from Firestore.
  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  // ===========================================================================
  // FILES & FOLDERS
  // ===========================================================================

  /// Real-time stream of user files.
  Stream<List<Map<String, dynamic>>> watchUserFiles(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('files')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Saves (creates or overwrites) a file or folder document.
  Future<void> saveUserFile({
    required String userId,
    required String fileId,
    required Map<String, dynamic> fileData,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('files')
        .doc(fileId)
        .set({
      ...fileData,
      'createdAt': fileData['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates specific fields in a file or folder document.
  Future<void> updateUserFile({
    required String userId,
    required String fileId,
    required Map<String, dynamic> updateData,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('files')
        .doc(fileId)
        .update({
      ...updateData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a file or folder document.
  Future<void> deleteUserFile({
    required String userId,
    required String fileId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('files')
        .doc(fileId)
        .delete();
  }

  // ===========================================================================
  // WORKSPACE FILES
  // ===========================================================================

  /// Real-time stream of workspace files.
  Stream<List<Map<String, dynamic>>> watchWorkspaceFiles(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('files')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Saves (creates or overwrites) a workspace file or folder document.
  Future<void> saveWorkspaceFile({
    required String companyId,
    required String fileId,
    required Map<String, dynamic> fileData,
  }) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('files')
        .doc(fileId)
        .set({
      ...fileData,
      'createdAt': fileData['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates specific fields in a workspace file or folder document.
  Future<void> updateWorkspaceFile({
    required String companyId,
    required String fileId,
    required Map<String, dynamic> updateData,
  }) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('files')
        .doc(fileId)
        .update({
      ...updateData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a workspace file or folder document.
  Future<void> deleteWorkspaceFile({
    required String companyId,
    required String fileId,
  }) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('files')
        .doc(fileId)
        .delete();
  }

  /// Fetches legacy files for a user (for migration purposes).
  Future<List<Map<String, dynamic>>> getLegacyUserFiles(String userId) async {
    final query = await _db
        .collection('users')
        .doc(userId)
        .collection('files')
        .get();
    return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // ===========================================================================
  // COMPANIES / WORKSPACES ENHANCEMENTS
  // ===========================================================================

  /// Updates company information, e.g. name, address, taxId, members, memberDetails.
  Future<void> updateCompanyDetails({
    required String companyId,
    required Map<String, dynamic> updateData,
  }) async {
    await _db.collection('companies').doc(companyId).update({
      ...updateData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a company workspace.
  Future<void> deleteCompany(String companyId) async {
    await _db.collection('companies').doc(companyId).delete();
  }

  /// Real-time stream of invitations for a company.
  Stream<List<Map<String, dynamic>>> watchCompanyInvitations(String companyId) {
    return _db
        .collection('invitations')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Creates a workspace invitation.
  Future<void> createWorkspaceInvitation({
    required String companyId,
    required String invitationId,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection('invitations')
        .doc(invitationId)
        .set({
      ...data,
      'companyId': companyId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a workspace invitation.
  Future<void> deleteWorkspaceInvitation({
    required String companyId,
    required String invitationId,
  }) async {
    await _db
        .collection('invitations')
        .doc(invitationId)
        .delete();
  }
}
