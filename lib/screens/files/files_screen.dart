import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../services/attachment_service.dart';
import '../../services/file_open_service.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../components/marita_card.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    // Auto-sync chat files on load
    Future.microtask(() {
      ref.read(fileOpsProvider.notifier).syncChatFiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final currentFolderId = ref.watch(currentFolderIdProvider);
    final files = ref.watch(currentFolderFilesProvider);
    final breadcrumbs = ref.watch(folderBreadcrumbsProvider);
    final isGrid = ref.watch(fileGridViewProvider);
    final opsState = ref.watch(fileOpsProvider);
    final canWrite = ref.watch(canWriteRobustProvider);

    // Listen to success or error messages
    ref.listen(fileOpsProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error!.message,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: colors.error,
          ),
        );
      } else if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.successMessage!,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: colors.success,
          ),
        );
      }
    });

    // Filter files by search query
    final filteredFiles =
        files.where((item) {
          if (_searchQuery.isEmpty) return true;
          return item.name.toLowerCase().contains(_searchQuery);
        }).toList();

    // Sort: Folders first, then alphabetical by name
    filteredFiles.sort((a, b) {
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;
      return a.name.compareTo(b.name);
    });

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context),

                // Search field (conditional)
                if (_isSearching) _buildSearchBar(context),

                // Breadcrumbs & Toggle
                _buildBreadcrumbsAndActions(
                  context,
                  breadcrumbs,
                  currentFolderId,
                  isGrid,
                ),

                if (!canWrite)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: MaritaSpacing.lg,
                      vertical: MaritaSpacing.xs,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MaritaSpacing.md,
                      vertical: MaritaSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.borderPrimary),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          color: colors.contentTertiary,
                          size: 16,
                        ),
                        const SizedBox(width: MaritaSpacing.xs),
                        Expanded(
                          child: Text(
                            'View Only — you cannot upload, rename, or delete files',
                            style: typography.bodySmall.copyWith(
                              color: colors.contentTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Content
                Expanded(
                  child:
                      filteredFiles.isEmpty
                          ? _buildEmptyState(context)
                          : (isGrid
                              ? _buildGridView(context, filteredFiles)
                              : _buildListView(context, filteredFiles)),
                ),
              ],
            ),
          ),
          if (opsState.isLoading && opsState.uploadProgress == null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.interactivePrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.md),
                    Text(
                      'Processing...',
                      style: typography.bodyDefault.copyWith(
                        color: colors.contentSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (opsState.uploadProgress != null)
            Positioned(
              left: MaritaSpacing.lg,
              right: MaritaSpacing.lg,
              bottom: MaritaSpacing.lg,
              child: _UploadProgressBanner(
                progress: opsState.uploadProgress!,
                totalBytes: opsState.uploadTotalBytes,
              ),
            ),
        ],
      ),
      floatingActionButton:
          canWrite
              ? FloatingActionButton(
                onPressed: () => _showAddOptions(context),
                backgroundColor: colors.interactivePrimary,
                shape: const CircleBorder(),
                child: Icon(Icons.add, color: colors.contentInverse, size: 28),
              )
              : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.xl,
        vertical: MaritaSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            'Files',
            style: typography.titleLarge.copyWith(
              color: colors.contentPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: MaritaSpacing.xl),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : MaritaIcons.search,
              color: colors.contentPrimary,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.sync, color: colors.contentPrimary, size: 22),
            onPressed: () async {
              await ref.read(fileOpsProvider.notifier).syncChatFiles();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.lg,
        vertical: MaritaSpacing.xs,
      ),
      child: TextField(
        controller: _searchController,
        style: typography.bodyDefault.copyWith(color: colors.contentPrimary),
        decoration: InputDecoration(
          hintText: 'Search files and folders...',
          hintStyle: typography.bodyDefault.copyWith(
            color: colors.contentTertiary,
          ),
          prefixIcon: Icon(
            MaritaIcons.search,
            color: colors.contentTertiary,
            size: 20,
          ),
          fillColor: colors.backgroundSecondary,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: MaritaSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: MaritaRadius.borderMedium,
            borderSide: BorderSide(color: colors.borderPrimary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: MaritaRadius.borderMedium,
            borderSide: BorderSide(color: colors.interactivePrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbsAndActions(
    BuildContext context,
    List<FileItem> breadcrumbs,
    String? currentFolderId,
    bool isGrid,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.lg,
        vertical: MaritaSpacing.sm,
      ),
      child: Row(
        children: [
          // Breadcrumbs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.read(currentFolderIdProvider.notifier).state = null;
                    },
                    child: Text(
                      'My Files',
                      style: typography.bodySmall.copyWith(
                        color:
                            currentFolderId == null
                                ? colors.interactivePrimary
                                : colors.contentSecondary,
                        fontWeight:
                            currentFolderId == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                  for (final crumb in breadcrumbs) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: colors.contentTertiary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ref.read(currentFolderIdProvider.notifier).state =
                            crumb.id;
                      },
                      child: Text(
                        crumb.name,
                        style: typography.bodySmall.copyWith(
                          color:
                              crumb.id == currentFolderId
                                  ? colors.interactivePrimary
                                  : colors.contentSecondary,
                          fontWeight:
                              crumb.id == currentFolderId
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: MaritaSpacing.md),
          // View Switcher Toggle
          GestureDetector(
            onTap: () {
              ref.read(fileGridViewProvider.notifier).state = !isGrid;
            },
            child: Icon(
              isGrid ? MaritaIcons.list : MaritaIcons.grid,
              color: colors.contentSecondary,
              size: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MaritaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MaritaIcons.document,
              size: 64,
              color: colors.contentTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: MaritaSpacing.lg),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No files match "$_searchQuery"'
                  : 'This folder is empty',
              style: typography.bodyLargeBold.copyWith(
                color: colors.contentPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MaritaSpacing.xs),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching for something else or clear filter.'
                  : 'Tap the "+" button below to upload files or create folders.',
              style: typography.bodyDefault.copyWith(
                color: colors.contentSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<FileItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(MaritaSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: MaritaSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildListTile(context, item);
      },
    );
  }

  Widget _buildGridView(BuildContext context, List<FileItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(MaritaSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MaritaSpacing.md,
        mainAxisSpacing: MaritaSpacing.md,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildGridCard(context, item);
      },
    );
  }

  Widget _buildListTile(BuildContext context, FileItem item) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return MaritaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.md,
        vertical: MaritaSpacing.sm,
      ),
      onTap: () => _handleItemTap(item),
      child: Row(
        children: [
          _buildTypeIcon(item, size: 28),
          const SizedBox(width: MaritaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyLargeBold.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.isFolder
                      ? 'Folder'
                      : '${_formatSize(item.size)} • ${_formatDate(item.createdAt)}',
                  style: typography.bodySmall.copyWith(
                    color: colors.contentTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              MaritaIcons.more,
              color: colors.contentSecondary,
              size: 20,
            ),
            onPressed: () => _showItemOptions(context, item),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, FileItem item) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return MaritaCard(
      padding: const EdgeInsets.all(MaritaSpacing.sm),
      onTap: () => _handleItemTap(item),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTypeIcon(item, size: 44),
                const SizedBox(height: MaritaSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MaritaSpacing.xs,
                  ),
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: typography.bodyDefaultBold.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                ),
                if (!item.isFolder) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatSize(item.size),
                    style: typography.bodySmall.copyWith(
                      color: colors.contentTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              icon: Icon(
                MaritaIcons.more,
                color: colors.contentSecondary,
                size: 18,
              ),
              onPressed: () => _showItemOptions(context, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(FileItem item, {required double size}) {
    final colors = context.maritaColors;

    if (item.isFolder) {
      return Icon(
        MaritaIcons.folder,
        color: colors.interactivePrimary,
        size: size,
      );
    }

    IconData icon;
    Color color;

    switch (item.type) {
      case 'image':
        icon = MaritaIcons.gallery;
        color = Colors.teal;
        break;
      case 'pdf':
        icon = MaritaIcons.document;
        color = Colors.redAccent;
        break;
      case 'csv':
      case 'xls':
        icon = MaritaIcons.document;
        color = Colors.green;
        break;
      case 'text':
        icon = MaritaIcons.document;
        color = Colors.blueGrey;
        break;
      default:
        icon = MaritaIcons.document;
        color = colors.contentSecondary;
    }

    return Icon(icon, color: color, size: size);
  }

  void _handleItemTap(FileItem item) {
    if (item.isFolder) {
      ref.read(currentFolderIdProvider.notifier).state = item.id;
    } else {
      // Preview or view details
      _showFileDetails(context, item);
    }
  }

  void _showFileDetails(BuildContext context, FileItem item) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(MaritaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTypeIcon(item, size: 36),
                  const SizedBox(width: MaritaSpacing.md),
                  Expanded(
                    child: Text(
                      item.name,
                      style: typography.bodyLargeBold.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: MaritaSpacing.xl),
              _buildDetailRow('Type', item.type.toUpperCase(), context),
              _buildDetailRow('Size', _formatSize(item.size), context),
              _buildDetailRow(
                'Created At',
                _formatDate(item.createdAt),
                context,
              ),
              if (item.chatId != null)
                _buildDetailRow('Source', 'Chat Attachment', context),
              const SizedBox(height: MaritaSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.interactivePrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: MaritaSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: MaritaRadius.borderMedium,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        if (item.url == null) return;

                        double downloadProgress = 0;
                        StateSetter? dialogSetState;
                        if (!context.mounted) return;

                        final dialogContextCompleter = Completer<BuildContext>();

                        // Show download/open progress dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogCtx) {
                            if (!dialogContextCompleter.isCompleted) {
                              dialogContextCompleter.complete(dialogCtx);
                            }
                            return StatefulBuilder(
                              builder: (statefulCtx, setDialogState) {
                                dialogSetState = setDialogState;
                                return AlertDialog(
                                  backgroundColor: colors.backgroundSecondary,
                                  title: Text(
                                    'Opening File',
                                    style: typography.bodyLargeBold.copyWith(
                                      color: colors.contentPrimary,
                                    ),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      LinearProgressIndicator(
                                        value:
                                            downloadProgress > 0
                                                ? downloadProgress
                                                : null,
                                        color: colors.interactivePrimary,
                                        backgroundColor:
                                            colors.backgroundPrimary,
                                      ),
                                      const SizedBox(
                                        height: MaritaSpacing.md,
                                      ),
                                      Text(
                                        downloadProgress > 0
                                            ? 'Downloading: ${(downloadProgress * 100).toStringAsFixed(0)}%'
                                            : 'Connecting...',
                                        style: typography.bodyDefault
                                            .copyWith(
                                              color: colors.contentSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );

                        final dialogContext = await dialogContextCompleter.future;

                        final error = await FileOpenService.downloadAndOpen(
                          item,
                          onProgress: (progress) {
                            if (dialogSetState != null) {
                              dialogSetState!(() {
                                downloadProgress = progress;
                              });
                            }
                          },
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext); // Dismiss progress dialog
                        }

                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  error,
                                  style: typography.bodyDefault.copyWith(
                                    color: colors.contentInverse,
                                  ),
                                ),
                                backgroundColor: colors.error,
                              ),
                            );
                        }
                      },
                      child: Text(
                        'Open File',
                        style: typography.bodyDefaultBold.copyWith(
                          color: colors.contentInverse,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MaritaSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: typography.bodyDefault.copyWith(
              color: colors.contentSecondary,
            ),
          ),
          Text(
            value,
            style: typography.bodyDefaultBold.copyWith(
              color: colors.contentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showItemOptions(BuildContext context, FileItem item) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.url != null)
                ListTile(
                  leading: Icon(
                    MaritaIcons.share,
                    color: colors.contentPrimary,
                  ),
                  title: Text(
                    'Share Link',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SharePlus.instance.share(
                      ShareParams(text: item.url!, subject: item.name),
                    );
                  },
                ),
              ListTile(
                leading: Icon(MaritaIcons.edit, color: colors.contentPrimary),
                title: Text(
                  'Rename',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!ref.read(canWriteRobustProvider)) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "error: view only can't rename",
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: colors.error,
                      ),
                    );
                    return;
                  }
                  _showRenameDialog(context, item);
                },
              ),
              ListTile(
                leading: Icon(MaritaIcons.trash, color: colors.error),
                title: Text(
                  'Delete',
                  style: typography.bodyDefault.copyWith(color: colors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!ref.read(canWriteRobustProvider)) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "error: view only can't delete",
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: colors.error,
                      ),
                    );
                    return;
                  }
                  _confirmDelete(context, item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, FileItem item) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final controller = TextEditingController(text: item.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text(
            'Rename',
            style: typography.bodyLargeBold.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            style: typography.bodyDefault.copyWith(
              color: colors.contentPrimary,
            ),
            decoration: InputDecoration(
              fillColor: colors.backgroundPrimary,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty && newName != item.name) {
                  Navigator.pop(context);
                  await ref
                      .read(fileOpsProvider.notifier)
                      .rename(item, newName);
                }
              },
              child: Text(
                'Rename',
                style: typography.bodyDefaultBold.copyWith(
                  color: colors.interactivePrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, FileItem item) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text(
            'Delete',
            style: typography.bodyLargeBold.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
            style: typography.bodyDefault.copyWith(
              color: colors.contentSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(fileOpsProvider.notifier).delete(item);
              },
              child: Text(
                'Delete',
                style: typography.bodyDefaultBold.copyWith(color: colors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddOptions(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  MaritaIcons.folderAdd,
                  color: colors.interactivePrimary,
                ),
                title: Text(
                  'Create Folder',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCreateFolderDialog(context);
                },
              ),
              ListTile(
                leading: Icon(
                  MaritaIcons.document,
                  color: colors.contentPrimary,
                ),
                title: Text(
                  'Upload Files',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleUploadDocument();
                },
              ),
              ListTile(
                leading: Icon(
                  MaritaIcons.gallery,
                  color: colors.contentPrimary,
                ),
                title: Text(
                  'Upload Images',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleUploadImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text(
            'New Folder',
            style: typography.bodyLargeBold.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            style: typography.bodyDefault.copyWith(
              color: colors.contentPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Folder Name',
              hintStyle: typography.bodyDefault.copyWith(
                color: colors.contentTertiary,
              ),
              fillColor: colors.backgroundPrimary,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  await ref.read(fileOpsProvider.notifier).createFolder(name);
                }
              },
              child: Text(
                'Create',
                style: typography.bodyDefaultBold.copyWith(
                  color: colors.interactivePrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleUploadDocument() async {
    final picked = await AttachmentService.pickFiles();
    if (picked.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    for (final attach in picked) {
      if (attach.path.isNotEmpty) {
        // We have local file, upload it
        final file = File(attach.path);
        final parentId = ref.read(currentFolderIdProvider);

        // Show loading state manually if wanted, or let service/ops notifier handle it.
        // Let's create an action on OpsNotifier or call it directly.
        await ref
            .read(fileOpsProvider.notifier)
            .uploadFile(file, attach.name, parentId);
      }
    }
  }

  Future<void> _handleUploadImage() async {
    final picked = await AttachmentService.pickImage();
    if (picked == null || picked.path.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final file = File(picked.path);
    final parentId = ref.read(currentFolderIdProvider);
    await ref
        .read(fileOpsProvider.notifier)
        .uploadFile(file, picked.name, parentId);
  }

  String _formatSize(int? sizeBytes) {
    if (sizeBytes == null) return '0 KB';
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }
}

class _UploadProgressBanner extends StatelessWidget {
  final double progress;
  final int? totalBytes;

  const _UploadProgressBanner({
    required this.progress,
    this.totalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    
    String sizeText = '';
    if (totalBytes != null) {
      final mb = totalBytes! / (1024 * 1024);
      sizeText = ' (${mb.toStringAsFixed(1)} MB)';
    }

    return MaritaCard(
      padding: const EdgeInsets.all(MaritaSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploading...$sizeText',
                style: typography.bodyDefaultBold.copyWith(
                  color: colors.contentPrimary,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: typography.bodySmall.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MaritaSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colors.backgroundPrimary,
            color: colors.interactivePrimary,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
