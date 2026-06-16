import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marita/main.dart';
import 'package:marita/providers/settings_provider.dart';
import 'package:marita/models/workspace.dart';
import 'package:marita/providers/workspace_provider.dart';
import 'package:marita/components/workspace_header_chip.dart';
import 'package:marita/components/workspace_switcher_sheet.dart';
import 'package:marita/core/result.dart';
import 'package:marita/providers/auth_provider.dart';
import 'package:marita/design_system/marita_design_system.dart';

void main() {
  testWidgets('MaritaApp pump smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaritaApp(),
      ),
    );
  });

  testWidgets('MaritaApp biometric bypass / lock based on 30-second background duration', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaritaApp(),
      ),
    );

    // 2. Find the app state and mock its clock (nowFn)
    final stateFinder = find.byType(MaritaApp);
    expect(stateFinder, findsOneWidget);
    
    // Retrieve the state of MaritaApp
    final state = tester.state(stateFinder);
    final dynamicApp = state as dynamic;

    // Set mock time
    DateTime mockTime = DateTime(2026, 6, 16, 12, 0, 0);
    dynamicApp.nowFn = () => mockTime;

    // Get the container to set biometric session
    final container = ProviderScope.containerOf(tester.element(stateFinder));
    
    // Set biometricSession to true (already authenticated)
    container.read(biometricSessionProvider.notifier).state = true;
    expect(container.read(biometricSessionProvider), isTrue);

    // 3. Simulate leaving the app (inactive -> hidden -> paused)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // 4. Return to the app after 15 seconds (less than 30 seconds)
    mockTime = mockTime.add(const Duration(seconds: 15));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // Biometric session should STILL be true (bypassed)
    expect(container.read(biometricSessionProvider), isTrue);

    // 5. Simulate leaving the app again
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // 6. Return to the app after 35 seconds (>= 30 seconds)
    mockTime = mockTime.add(const Duration(seconds: 35));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // Biometric session should now be false (locked/reset)
    expect(container.read(biometricSessionProvider), isFalse);
  });

  testWidgets('WorkspaceHeaderChip limits workspace name to 3 words', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final testContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reindexOnWorkspaceChangeProvider.overrideWithValue(null),
        activeWorkspaceProvider.overrideWith(() => _MockActiveWorkspaceNotifier()),
      ],
    );

    // Let's pump the widget with a ProviderScope that has our overrides
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: testContainer,
        child: MaterialApp(
          theme: MaritaTheme.dark(),
          home: const Scaffold(
            body: WorkspaceHeaderChip(),
          ),
        ),
      ),
    );

    // Get active workspace notifier and set a long workspace name (5 words)
    final workspaceLong = Workspace(
      id: 'test-id-1',
      name: 'PT Asri Karya Ilmiah Mahasiswa',
      ownerId: 'owner-id',
      members: const [],
      memberDetails: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testContainer.read(activeWorkspaceProvider.notifier).state = workspaceLong;
    await tester.pump();

    // It should display the limited words: 'PT Asri Karya....' (3 words plus '....')
    expect(find.text('PT Asri Karya....'), findsOneWidget);
    expect(find.text('PT Asri Karya Ilmiah Mahasiswa'), findsNothing);

    // Set a short workspace name (2 words)
    final workspaceShort = Workspace(
      id: 'test-id-2',
      name: 'PT Asri',
      ownerId: 'owner-id',
      members: const [],
      memberDetails: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testContainer.read(activeWorkspaceProvider.notifier).state = workspaceShort;
    await tester.pump();

    // It should display 'PT Asri' exactly as is
    expect(find.text('PT Asri'), findsOneWidget);
    expect(find.text('PT Asri....'), findsNothing);
  });

  testWidgets('WorkspaceSwitcherSheet visibility of Create New Workspace button', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final testContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reindexOnWorkspaceChangeProvider.overrideWithValue(null),
        userWorkspacesProvider.overrideWith((ref) => Stream.value(Success(<Workspace>[]))),
        userInvitationsProvider.overrideWith((ref) => Stream.value(Success(<Map<String, dynamic>>[]))),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );

    // 1. With showCreateButton = true
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: testContainer,
        child: MaterialApp(
          theme: MaritaTheme.dark(),
          home: const Scaffold(
            body: WorkspaceSwitcherSheet(showCreateButton: true),
          ),
        ),
      ),
    );
    await tester.pump(); // Let state streams resolve

    // The 'Create New Workspace' button should be visible
    expect(find.text('Create New Workspace'), findsOneWidget);

    // 2. With showCreateButton = false
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: testContainer,
        child: MaterialApp(
          theme: MaritaTheme.dark(),
          home: const Scaffold(
            body: WorkspaceSwitcherSheet(showCreateButton: false),
          ),
        ),
      ),
    );
    await tester.pump(); // Let state streams resolve

    // The 'Create New Workspace' button should NOT be visible
    expect(find.text('Create New Workspace'), findsNothing);
  });
}

class _MockActiveWorkspaceNotifier extends ActiveWorkspaceNotifier {
  @override
  Workspace? build() => null;
}


