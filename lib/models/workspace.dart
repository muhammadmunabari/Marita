import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberAccess {
  owner,
  canEdit,
  canView;

  String get label {
    switch (this) {
      case MemberAccess.owner:
        return 'Owner';
      case MemberAccess.canEdit:
        return 'can edit';
      case MemberAccess.canView:
        return 'can view';
    }
  }

  static MemberAccess fromString(String value) {
    switch (value.toLowerCase()) {
      case 'owner':
        return MemberAccess.owner;
      case 'can_edit':
      case 'canedit':
        return MemberAccess.canEdit;
      case 'can_view':
      case 'canview':
      default:
        return MemberAccess.canView;
    }
  }

  String toJsonString() {
    switch (this) {
      case MemberAccess.owner:
        return 'owner';
      case MemberAccess.canEdit:
        return 'can_edit';
      case MemberAccess.canView:
        return 'can_view';
    }
  }
}

enum WorkspaceRole {
  cLevel,
  investor,
  employee;

  String get label {
    switch (this) {
      case WorkspaceRole.cLevel:
        return 'C-Level';
      case WorkspaceRole.investor:
        return 'Investor';
      case WorkspaceRole.employee:
        return 'Employee';
    }
  }

  String get description {
    switch (this) {
      case WorkspaceRole.cLevel:
        return 'Executive/management access';
      case WorkspaceRole.investor:
        return 'View and analyze financial data';
      case WorkspaceRole.employee:
        return 'Standard staff access';
    }
  }

  static WorkspaceRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'c-level':
      case 'clevel':
      case 'ceo':
      case 'cfo':
        return WorkspaceRole.cLevel;
      case 'investor':
        return WorkspaceRole.investor;
      case 'employee':
      default:
        return WorkspaceRole.employee;
    }
  }

  String toJsonString() {
    switch (this) {
      case WorkspaceRole.cLevel:
        return 'c-level';
      case WorkspaceRole.investor:
        return 'investor';
      case WorkspaceRole.employee:
        return 'employee';
    }
  }
}

class WorkspaceMember {
  final String uid;
  final String email;
  final String name;
  final WorkspaceRole role;
  final MemberAccess access;
  final DateTime joinedAt;

  WorkspaceMember({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.access,
    required this.joinedAt,
  });

  factory WorkspaceMember.fromMap(String uid, Map<String, dynamic> map) {
    return WorkspaceMember(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: WorkspaceRole.fromString(map['role'] ?? ''),
      access: MemberAccess.fromString(map['access'] ?? ''),
      joinedAt:
          map['joinedAt'] is Timestamp
              ? (map['joinedAt'] as Timestamp).toDate()
              : map['joinedAt'] != null
              ? DateTime.parse(map['joinedAt'].toString())
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.toJsonString(),
      'access': access.toJsonString(),
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}

class Workspace {
  final String id;
  final String name;
  final String ownerId;
  final List<String> members;
  final Map<String, WorkspaceMember> memberDetails;
  final String? address;
  final String? taxId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Workspace({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.memberDetails,
    this.address,
    this.taxId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Workspace.fromMap(String id, Map<String, dynamic> map) {
    final detailsMap = map['memberDetails'] as Map<String, dynamic>? ?? {};
    final memberDetails = detailsMap.map((uid, detail) {
      return MapEntry(
        uid,
        WorkspaceMember.fromMap(uid, Map<String, dynamic>.from(detail as Map)),
      );
    });

    return Workspace(
      id: id,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      memberDetails: memberDetails,
      address: map['address'],
      taxId: map['taxId'],
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : map['createdAt'] != null
              ? DateTime.parse(map['createdAt'].toString())
              : DateTime.now(),
      updatedAt:
          map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : map['updatedAt'] != null
              ? DateTime.parse(map['updatedAt'].toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'members': members,
      'memberDetails': memberDetails.map(
        (uid, detail) => MapEntry(uid, detail.toMap()),
      ),
      'address': address,
      'taxId': taxId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Workspace copyWith({
    String? name,
    String? ownerId,
    List<String>? members,
    Map<String, WorkspaceMember>? memberDetails,
    String? address,
    String? taxId,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      memberDetails: memberDetails ?? this.memberDetails,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
