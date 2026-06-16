import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import '../services/workspace_service.dart';
import '../services/migration_service.dart';
import '../core/result.dart';
import '../core/app_error.dart';
import 'auth_provider.dart';
import '../services/firestore_service.dart';
import 'settings_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final workspaceServiceProvider = Provider<WorkspaceService>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return WorkspaceService(firestoreService: firestoreService);
});

/// Stream of all workspaces for the authenticated user
final userWorkspacesProvider = StreamProvider<Result<List<Workspace>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(Success(<Workspace>[]));
  }
  return ref.watch(workspaceServiceProvider).watchUserWorkspaces(user.uid);
});

/// Currently selected active workspace notifier and provider
class ActiveWorkspaceNotifier extends Notifier<Workspace?> {
  static const _prefKey = 'last_active_workspace_id';

  @override
  Workspace? build() {
    final workspacesResult = ref.watch(userWorkspacesProvider).value;
    if (workspacesResult == null || workspacesResult is Failure) {
      return null;
    }
    final list = (workspacesResult as Success<List<Workspace>>).data;
    if (list.isEmpty) return null;

    final prefs = ref.watch(sharedPreferencesProvider);
    final savedId = prefs.getString(_prefKey);
    if (savedId != null) {
      final found = list.where((w) => w.id == savedId).firstOrNull;
      if (found != null) return found;
    }

    return list.first;
  }

  @override
  set state(Workspace? value) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (value != null) {
      prefs.setString(_prefKey, value.id);
    } else {
      prefs.remove(_prefKey);
    }
    super.state = value;
  }
}

final activeWorkspaceProvider = NotifierProvider<ActiveWorkspaceNotifier, Workspace?>(ActiveWorkspaceNotifier.new);

/// Stream of invitations for a specific workspace
final workspaceInvitationsProvider = StreamProvider.family<Result<List<Map<String, dynamic>>>, String>((ref, workspaceId) {
  return ref.watch(workspaceServiceProvider).watchInvitations(workspaceId);
});

/// Stream of all pending invitations for the logged-in user
final userInvitationsProvider = StreamProvider<Result<List<Map<String, dynamic>>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(Success(<Map<String, dynamic>>[]));
  }
  
  String? email = user.email;
  if (email == null) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile != null) {
      email = profile['email'] as String?;
    }
  }
  
  if (email == null) {
    return Stream.value(Success(<Map<String, dynamic>>[]));
  }
  
  return ref.watch(workspaceServiceProvider).watchUserInvitations(email);
});

/// State tracking workspace asynchronous operations
class WorkspaceOpsState {
  final bool isLoading;
  final AppError? error;
  final String? successMessage;

  const WorkspaceOpsState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  WorkspaceOpsState copyWith({
    bool? isLoading,
    AppError? error,
    String? successMessage,
  }) {
    return WorkspaceOpsState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Can reset to null
      successMessage: successMessage,
    );
  }
}

class WorkspaceOpsNotifier extends Notifier<WorkspaceOpsState> {
  @override
  WorkspaceOpsState build() => const WorkspaceOpsState();

  WorkspaceService get _service => ref.read(workspaceServiceProvider);

  Future<bool> createWorkspace({
    required String name,
    required String role,
    String? address,
    String? taxId,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.createWorkspace(
      name: name,
      role: role,
      address: address,
      taxId: taxId,
    );

    return result.fold(
      (id) {
        state = const WorkspaceOpsState(successMessage: 'Workspace created successfully');
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> updateWorkspace({
    required String workspaceId,
    required String name,
    String? address,
    String? taxId,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.updateWorkspaceDetails(
      workspaceId: workspaceId,
      name: name,
      address: address,
      taxId: taxId,
    );

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Workspace updated successfully');
        // Update active workspace locally if needed
        final active = ref.read(activeWorkspaceProvider);
        if (active != null && active.id == workspaceId) {
          ref.read(activeWorkspaceProvider.notifier).state = active.copyWith(
            name: name,
            address: address,
            taxId: taxId,
            updatedAt: DateTime.now(),
          );
        }
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> deleteWorkspace(String workspaceId) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.deleteWorkspace(workspaceId);

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Workspace deleted successfully');
        final active = ref.read(activeWorkspaceProvider);
        if (active != null && active.id == workspaceId) {
          ref.read(activeWorkspaceProvider.notifier).state = null;
        }
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> inviteMember({
    required String workspaceId,
    required String email,
    required String access,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.sendInvitation(
      workspaceId: workspaceId,
      email: email,
      access: access,
    );

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Invitation sent successfully');
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> cancelInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.removeInvitation(
      workspaceId: workspaceId,
      invitationId: invitationId,
    );

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Invitation cancelled successfully');
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> updateMemberRoleOrAccess({
    required String workspaceId,
    required String memberId,
    required String access,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.updateMemberAccess(
      workspaceId: workspaceId,
      memberId: memberId,
      access: access,
    );

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Member access updated successfully');
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> removeMember({
    required String workspaceId,
    required String memberId,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.removeMember(
      workspaceId: workspaceId,
      memberId: memberId,
    );

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Member removed successfully');
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> acceptInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.acceptInvitation(
      workspaceId: workspaceId,
      invitationId: invitationId,
    );

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Invitation accepted');
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> declineInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    state = const WorkspaceOpsState(isLoading: true);
    final result = await _service.declineInvitation(
      workspaceId: workspaceId,
      invitationId: invitationId,
    );

    return result.fold(
      (_) {
        state = const WorkspaceOpsState(successMessage: 'Invitation declined');
        return true;
      },
      (error) {
        state = WorkspaceOpsState(error: error);
        return false;
      },
    );
  }
}

final workspaceOpsProvider = NotifierProvider<WorkspaceOpsNotifier, WorkspaceOpsState>(WorkspaceOpsNotifier.new);

/// Provider for the active user's access level in the current workspace
final activeWorkspaceAccessProvider = Provider<MemberAccess?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final activeWorkspace = ref.watch(activeWorkspaceProvider);
  if (user == null || activeWorkspace == null) {
    return null;
  }
  if (activeWorkspace.ownerId == user.uid) {
    return MemberAccess.owner;
  }
  final memberDetail = activeWorkspace.memberDetails[user.uid];
  return memberDetail?.access;
});

/// Provider checking if the active user can write in the current workspace (owner or canEdit)
final canWriteProvider = Provider<bool>((ref) {
  final access = ref.watch(activeWorkspaceAccessProvider);
  if (access == null) return false;
  return access == MemberAccess.owner || access == MemberAccess.canEdit;
});

/// Triggers background re-indexing of any un-indexed files whenever the
/// active workspace changes.  Purely a side-effect provider; consumers
/// should watch it once to activate it (e.g. in the home/shell widget).
final reindexOnWorkspaceChangeProvider = Provider<void>((ref) {
  final workspace = ref.watch(activeWorkspaceProvider);
  if (workspace == null) return;

  final migrationService = ref.read(migrationServiceProvider);
  // Fire-and-forget — intentionally unawaited.
  migrationService.reindexWorkspaceFiles(workspace.id);
});
