import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/result.dart';
import '../core/app_error.dart';
import '../models/workspace.dart';
import 'firestore_service.dart';

class WorkspaceService {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  WorkspaceService({
    FirestoreService? firestoreService,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Stream of workspaces the user is part of.
  Stream<Result<List<Workspace>>> watchUserWorkspaces(String userId) {
    try {
      return _firestoreService.watchUserCompanies(userId).map((list) {
        try {
          final workspaces =
              list.map((map) {
                final id = map['id'] as String;
                return Workspace.fromMap(id, map);
              }).toList();
          return Success(workspaces);
        } catch (e, stack) {
          return Failure(
            AppError(
              code: 'parse-error',
              message: 'Failed to parse workspaces: $e',
              stackTrace: stack,
            ),
          );
        }
      });
    } catch (e, stack) {
      return Stream.value(
        Failure(
          AppError(
            code: 'stream-error',
            message: 'Failed to watch workspaces: $e',
            stackTrace: stack,
          ),
        ),
      );
    }
  }

  /// Creates a new workspace and updates user's business account status.
  Future<Result<String>> createWorkspace({
    required String name,
    required String role,
    String? address,
    String? taxId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Failure(
          AppError(
            code: 'unauthenticated',
            message: 'No authenticated user found.',
          ),
        );
      }

      // Fetch user profile to get name and email
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? user.displayName ?? 'User';
      final userEmail = userDoc.data()?['email'] ?? user.email ?? '';

      final workspaceRef = _db.collection('companies').doc();
      final workspaceId = workspaceRef.id;

      final memberDetail = WorkspaceMember(
        uid: user.uid,
        email: userEmail,
        name: userName,
        role: WorkspaceRole.fromString(role),
        access: MemberAccess.owner,
        joinedAt: DateTime.now(),
      );

      final workspace = Workspace(
        id: workspaceId,
        name: name,
        ownerId: user.uid,
        members: [user.uid],
        memberDetails: {user.uid: memberDetail},
        address: address,
        taxId: taxId,
        createdAt: DateTime.now(),
      );

      // Write to Firestore in a batch/transaction to be atomic
      final batch = _db.batch();
      batch.set(workspaceRef, {
        ...workspace.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user hasBusinessAccount status
      final userRef = _db.collection('users').doc(user.uid);
      batch.set(userRef, {
        'hasBusinessAccount': true,
        'business': {
          'companyName': name,
          'role': role,
          'address': address,
          'taxId': taxId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      await batch.commit();
      return Success(workspaceId);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'create-failed',
          message: 'Failed to create workspace: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Updates details of an existing workspace.
  Future<Result<void>> updateWorkspaceDetails({
    required String workspaceId,
    required String name,
    String? address,
    String? taxId,
  }) async {
    try {
      await _firestoreService.updateCompanyDetails(
        companyId: workspaceId,
        updateData: {'name': name, 'address': address, 'taxId': taxId},
      );
      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'update-failed',
          message: 'Failed to update workspace: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Deletes a workspace.
  Future<Result<void>> deleteWorkspace(String workspaceId) async {
    try {
      // 1. Delete company document
      await _firestoreService.deleteCompany(workspaceId);
      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'delete-failed',
          message: 'Failed to delete workspace: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Streams pending invitations for a workspace.
  Stream<Result<List<Map<String, dynamic>>>> watchInvitations(
    String workspaceId,
  ) {
    try {
      return _firestoreService.watchCompanyInvitations(workspaceId).map((list) {
        return Success(list);
      });
    } catch (e, stack) {
      return Stream.value(
        Failure(
          AppError(
            code: 'invitations-stream-failed',
            message: 'Failed to watch invitations: $e',
            stackTrace: stack,
          ),
        ),
      );
    }
  }

  /// Sends a pending workspace invitation.
  Future<Result<void>> sendInvitation({
    required String workspaceId,
    required String email,
    required String access,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Failure(
          AppError(
            code: 'unauthenticated',
            message: 'No authenticated user found.',
          ),
        );
      }

      final companyDoc =
          await _db.collection('companies').doc(workspaceId).get();
      final companyName = companyDoc.data()?['name'] ?? 'Workspace';

      final userDoc = await _db.collection('users').doc(user.uid).get();
      final invitedByName =
          userDoc.data()?['name'] ?? user.displayName ?? 'User';

      final invitationId = _db.collection('invitations').doc().id;

      await _firestoreService.createWorkspaceInvitation(
        companyId: workspaceId,
        invitationId: invitationId,
        data: {
          'email': email.trim().toLowerCase(),
          'access': access,
          'status': 'pending',
          'invitedBy': user.uid,
          'companyName': companyName,
          'invitedByName': invitedByName,
        },
      );

      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'invite-failed',
          message: 'Failed to send invitation: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Watch all invitations across all workspaces sent to this user's email.
  Stream<Result<List<Map<String, dynamic>>>> watchUserInvitations(
    String email,
  ) {
    try {
      final emailLower = email.trim().toLowerCase();
      return _db
          .collection('invitations')
          .where('email', isEqualTo: emailLower)
          .snapshots()
          .map((snap) {
            try {
              final list =
                  snap.docs
                      .map((doc) {
                        final data = doc.data();
                        final companyId = data['companyId'] ?? '';
                        return {'id': doc.id, 'companyId': companyId, ...data};
                      })
                      .where((item) => item['status'] == 'pending')
                      .toList();
              return Success(list);
            } catch (e, stack) {
              return Failure(
                AppError(
                  code: 'parse-invitations-failed',
                  message: 'Failed to parse invitations: $e',
                  stackTrace: stack,
                ),
              );
            }
          });
    } catch (e, stack) {
      return Stream.value(
        Failure(
          AppError(
            code: 'watch-user-invitations-failed',
            message: 'Failed to watch user invitations: $e',
            stackTrace: stack,
          ),
        ),
      );
    }
  }

  /// Accepts a workspace invitation.
  Future<Result<void>> acceptInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Failure(
          AppError(
            code: 'unauthenticated',
            message: 'No authenticated user found.',
          ),
        );
      }

      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? user.displayName ?? 'User';

      await _db.collection('invitations').doc(invitationId).update({
        'status': 'accepted',
        'acceptedByUid': user.uid,
        'acceptedByName': userName,
      });

      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'accept-failed',
          message: 'Failed to accept invitation: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Declines a workspace invitation.
  Future<Result<void>> declineInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    try {
      await _db.collection('invitations').doc(invitationId).delete();

      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'decline-failed',
          message: 'Failed to decline invitation: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Removes (cancels) a pending invitation.
  Future<Result<void>> removeInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    try {
      await _firestoreService.deleteWorkspaceInvitation(
        companyId: workspaceId,
        invitationId: invitationId,
      );
      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'remove-invite-failed',
          message: 'Failed to remove invitation: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Updates access level for a member.
  Future<Result<void>> updateMemberAccess({
    required String workspaceId,
    required String memberId,
    required String access,
  }) async {
    try {
      await _db.collection('companies').doc(workspaceId).update({
        'memberDetails.$memberId.access': access,
      });
      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'update-member-failed',
          message: 'Failed to update member access: $e',
          stackTrace: stack,
        ),
      );
    }
  }

  /// Removes a member from a workspace.
  Future<Result<void>> removeMember({
    required String workspaceId,
    required String memberId,
  }) async {
    try {
      final batch = _db.batch();
      final companyRef = _db.collection('companies').doc(workspaceId);

      batch.update(companyRef, {
        'members': FieldValue.arrayRemove([memberId]),
      });

      // To remove from map: memberDetails.memberId
      batch.update(companyRef, {
        'memberDetails.$memberId': FieldValue.delete(),
      });

      await batch.commit();
      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError(
          code: 'remove-member-failed',
          message: 'Failed to remove member: $e',
          stackTrace: stack,
        ),
      );
    }
  }
}
