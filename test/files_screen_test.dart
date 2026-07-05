import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marita/screens/files/files_screen.dart';
import 'package:marita/models/file_item.dart';
import 'package:marita/providers/file_provider.dart';
import 'package:marita/providers/workspace_provider.dart';
import 'package:marita/providers/settings_provider.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/design_system/marita_icons.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createFilesScreen(
    ProviderContainer container,
  ) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: MaritaTheme.dark(),
        home: const Scaffold(
          body: FilesScreen(),
        ),
      ),
    );
  }

  testWidgets('More icon is visible in FilesScreen list view for both write and read-only users', (WidgetTester tester) async {
    final file = FileItem(
      id: 'file-1',
      name: 'Startup_Pitch_Deck.pdf',
      type: 'pdf',
      isFolder: false,
      createdAt: DateTime.now(),
      url: 'https://example.com/pitch.pdf',
      size: 1024,
    );

    // 1. Test for read-only user
    final readOnlyContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reindexOnWorkspaceChangeProvider.overrideWithValue(null),
        canWriteRobustProvider.overrideWithValue(false),
        currentFolderFilesProvider.overrideWithValue([file]),
        folderBreadcrumbsProvider.overrideWithValue([]),
        currentFolderIdProvider.overrideWith(() => _MockFolderIdNotifier(null)),
      ],
    );

    await tester.pumpWidget(createFilesScreen(readOnlyContainer));
    await tester.pumpAndSettle();

    // Verify file list tile exists
    expect(find.text('Startup_Pitch_Deck.pdf'), findsOneWidget);

    // Verify "More" button exists (IconButton with the more icon)
    final moreButtonFinder = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.icon is Icon && (widget.icon as Icon).icon == MaritaIcons.more,
    );
    expect(moreButtonFinder, findsOneWidget);

    // 2. Test for write user
    final writeContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reindexOnWorkspaceChangeProvider.overrideWithValue(null),
        canWriteRobustProvider.overrideWithValue(true),
        currentFolderFilesProvider.overrideWithValue([file]),
        folderBreadcrumbsProvider.overrideWithValue([]),
        currentFolderIdProvider.overrideWith(() => _MockFolderIdNotifier(null)),
      ],
    );

    await tester.pumpWidget(createFilesScreen(writeContainer));
    await tester.pumpAndSettle();

    expect(find.text('Startup_Pitch_Deck.pdf'), findsOneWidget);
    expect(moreButtonFinder, findsOneWidget);
  });

  testWidgets('More options: View-only user gets error snackbar when choosing Rename or Delete', (WidgetTester tester) async {
    final file = FileItem(
      id: 'file-1',
      name: 'Financials.xlsx',
      type: 'xlsx',
      isFolder: false,
      createdAt: DateTime.now(),
      url: 'https://example.com/fin.xlsx',
      size: 2048,
    );

    final readOnlyContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reindexOnWorkspaceChangeProvider.overrideWithValue(null),
        canWriteRobustProvider.overrideWithValue(false),
        currentFolderFilesProvider.overrideWithValue([file]),
        folderBreadcrumbsProvider.overrideWithValue([]),
        currentFolderIdProvider.overrideWith(() => _MockFolderIdNotifier(null)),
      ],
    );

    await tester.pumpWidget(createFilesScreen(readOnlyContainer));
    await tester.pumpAndSettle();

    // Open options sheet
    final moreButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.icon is Icon && (widget.icon as Icon).icon == MaritaIcons.more,
    );
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Rename option should be visible
    final renameOption = find.text('Rename');
    expect(renameOption, findsOneWidget);

    // Tap Rename option
    await tester.tap(renameOption);
    await tester.pumpAndSettle();

    // SnackBar with error message should be displayed
    expect(find.text("error: view only can't rename"), findsOneWidget);

    // Open options sheet again
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Delete option should be visible
    final deleteOption = find.text('Delete');
    expect(deleteOption, findsOneWidget);

    // Tap Delete option
    await tester.tap(deleteOption);
    await tester.pumpAndSettle();

    // SnackBar with error message should be displayed
    expect(find.text("error: view only can't delete"), findsOneWidget);
  });

  testWidgets('More options: Write user opens dialog when choosing Rename or Delete', (WidgetTester tester) async {
    final file = FileItem(
      id: 'file-1',
      name: 'Tax_Document.pdf',
      type: 'pdf',
      isFolder: false,
      createdAt: DateTime.now(),
      url: 'https://example.com/tax.pdf',
      size: 512,
    );

    final writeContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reindexOnWorkspaceChangeProvider.overrideWithValue(null),
        canWriteRobustProvider.overrideWithValue(true),
        currentFolderFilesProvider.overrideWithValue([file]),
        folderBreadcrumbsProvider.overrideWithValue([]),
        currentFolderIdProvider.overrideWith(() => _MockFolderIdNotifier(null)),
      ],
    );

    await tester.pumpWidget(createFilesScreen(writeContainer));
    await tester.pumpAndSettle();

    // Open options sheet
    final moreButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.icon is Icon && (widget.icon as Icon).icon == MaritaIcons.more,
    );
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Tap Rename option
    final renameOption = find.text('Rename');
    await tester.tap(renameOption);
    await tester.pumpAndSettle();

    // The rename dialog should open, which has title 'Rename' (alert dialog)
    // There will be a Cancel button
    expect(find.text('Cancel'), findsOneWidget);
    // Let's close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Open options sheet again
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Tap Delete option
    final deleteOption = find.text('Delete');
    await tester.tap(deleteOption);
    await tester.pumpAndSettle();

    // The delete confirmation dialog should open
    expect(find.text('Are you sure you want to delete "Tax_Document.pdf"? This action cannot be undone.'), findsOneWidget);
  });
}

class _MockFolderIdNotifier extends CurrentFolderIdNotifier {
  final String? initialValue;
  _MockFolderIdNotifier(this.initialValue);

  @override
  String? build() => initialValue;
}
