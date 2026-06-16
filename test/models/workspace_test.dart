import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marita/models/workspace.dart';

void main() {
  group('Workspace Model Tests', () {
    final mockJoinedAt = Timestamp.fromDate(DateTime(2026, 6, 4));
    final mockMemberMap = {
      'email': 'member@example.com',
      'name': 'Member Name',
      'role': 'employee',
      'access': 'can_view',
      'joinedAt': mockJoinedAt,
    };

    test('WorkspaceMember fromMap & toMap', () {
      final member = WorkspaceMember.fromMap('uid123', mockMemberMap);

      expect(member.uid, 'uid123');
      expect(member.email, 'member@example.com');
      expect(member.name, 'Member Name');
      expect(member.role, WorkspaceRole.employee);
      expect(member.access, MemberAccess.canView);
      expect(member.joinedAt, mockJoinedAt.toDate());

      final mapped = member.toMap();
      expect(mapped['email'], 'member@example.com');
      expect(mapped['role'], 'employee');
      expect(mapped['access'], 'can_view');
    });

    test('Workspace fromMap', () {
      final mockCreatedAt = Timestamp.fromDate(DateTime(2026, 6, 1));
      final mockWorkspaceMap = {
        'name': 'Test Company',
        'ownerId': 'owner123',
        'members': ['owner123', 'uid123'],
        'memberDetails': {'uid123': mockMemberMap},
        'address': '123 Test St',
        'taxId': 'TIN-456',
        'createdAt': mockCreatedAt,
      };

      final workspace = Workspace.fromMap('ws123', mockWorkspaceMap);

      expect(workspace.id, 'ws123');
      expect(workspace.name, 'Test Company');
      expect(workspace.ownerId, 'owner123');
      expect(workspace.members, containsAll(['owner123', 'uid123']));
      expect(workspace.memberDetails, contains('uid123'));
      expect(workspace.address, '123 Test St');
      expect(workspace.taxId, 'TIN-456');
      expect(workspace.createdAt, mockCreatedAt.toDate());
    });
  });
}
