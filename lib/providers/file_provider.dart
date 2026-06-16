import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';
import 'workspace_provider.dart';
import '../core/result.dart';
import '../core/app_error.dart';

/// Singleton [FileService] provider
final fileServiceProvider = Provider<FileService>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FileService(firestoreService: firestoreService);
});

/// Current folder ID notifier & provider (null for root)
class CurrentFolderIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  @override
  set state(String? value) => super.state = value;
}

final currentFolderIdProvider =
    NotifierProvider<CurrentFolderIdNotifier, String?>(
      CurrentFolderIdNotifier.new,
    );

/// View mode notifier & provider (true for grid view, false for list view)
class FileGridViewNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

final fileGridViewProvider = NotifierProvider<FileGridViewNotifier, bool>(
  FileGridViewNotifier.new,
);

/// Stream provider for all files in the active workspace
final allWorkspaceFilesProvider = StreamProvider<Result<List<FileItem>>>((ref) {
  final activeWorkspace = ref.watch(activeWorkspaceProvider);
  if (activeWorkspace == null) {
    return Stream.value(Success(<FileItem>[]));
  }
  return ref.watch(fileServiceProvider).watchWorkspaceFiles(activeWorkspace.id);
});

/// Computes the list of files in the current folder
final currentFolderFilesProvider = Provider<List<FileItem>>((ref) {
  final allFilesResult = ref.watch(allWorkspaceFilesProvider).value;
  if (allFilesResult == null || allFilesResult is Failure) {
    return [];
  }

  final files = (allFilesResult as Success<List<FileItem>>).data;
  final currentFolderId = ref.watch(currentFolderIdProvider);

  return files.where((item) => item.parentId == currentFolderId).toList();
});

/// Folder breadcrumbs path from root to current folder
final folderBreadcrumbsProvider = Provider<List<FileItem>>((ref) {
  final allFilesResult = ref.watch(allWorkspaceFilesProvider).value;
  if (allFilesResult == null || allFilesResult is Failure) {
    return [];
  }

  final files = (allFilesResult as Success<List<FileItem>>).data;
  final currentFolderId = ref.watch(currentFolderIdProvider);

  if (currentFolderId == null) return [];

  final path = <FileItem>[];
  String? nextId = currentFolderId;

  while (nextId != null) {
    final parent = files.firstWhere(
      (item) => item.id == nextId && item.isFolder,
      orElse:
          () => FileItem(
            id: '',
            name: '',
            type: '',
            isFolder: false,
            createdAt: DateTime.now(),
          ),
    );

    if (parent.id.isEmpty) break;
    path.insert(0, parent);
    nextId = parent.parentId;
  }

  return path;
});

/// State notifier for async file operations status
class FileOpsState {
  final bool isLoading;
  final AppError? error;
  final String? successMessage;

  const FileOpsState({this.isLoading = false, this.error, this.successMessage});

  FileOpsState copyWith({
    bool? isLoading,
    AppError? error,
    String? successMessage,
  }) {
    return FileOpsState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Can reset to null
      successMessage: successMessage,
    );
  }
}

class FileOpsNotifier extends Notifier<FileOpsState> {
  @override
  FileOpsState build() => const FileOpsState();

  FileService get _fileService => ref.read(fileServiceProvider);

  Future<bool> createFolder(String name) async {
    final activeWorkspace = ref.read(activeWorkspaceProvider);
    if (activeWorkspace == null) return false;

    state = const FileOpsState(isLoading: true);
    final parentId = ref.read(currentFolderIdProvider);

    final result = await _fileService.createWorkspaceFolder(
      companyId: activeWorkspace.id,
      name: name,
      parentId: parentId,
    );

    return result.fold(
      (data) {
        state = const FileOpsState(
          successMessage: 'Folder created successfully',
        );
        return true;
      },
      (error) {
        state = FileOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> rename(FileItem item, String newName) async {
    final activeWorkspace = ref.read(activeWorkspaceProvider);
    if (activeWorkspace == null) return false;

    state = const FileOpsState(isLoading: true);

    final result = await _fileService.renameWorkspaceFile(
      companyId: activeWorkspace.id,
      fileId: item.id,
      newName: newName,
    );

    return result.fold(
      (_) {
        state = const FileOpsState(successMessage: 'Renamed successfully');
        return true;
      },
      (error) {
        state = FileOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> delete(FileItem item) async {
    final activeWorkspace = ref.read(activeWorkspaceProvider);
    if (activeWorkspace == null) return false;

    state = const FileOpsState(isLoading: true);

    final result = await _fileService.deleteWorkspaceFile(
      companyId: activeWorkspace.id,
      item: item,
    );

    return result.fold(
      (_) {
        state = const FileOpsState(successMessage: 'Deleted successfully');
        return true;
      },
      (error) {
        state = FileOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> syncChatFiles() async {
    final activeWorkspace = ref.read(activeWorkspaceProvider);
    if (activeWorkspace == null) return false;

    state = const FileOpsState(isLoading: true);
    final result = await _fileService.syncWorkspaceChatAttachments(
      activeWorkspace.id,
    );

    return result.fold(
      (_) {
        state = const FileOpsState(successMessage: 'Chat files synchronized');
        return true;
      },
      (error) {
        state = FileOpsState(error: error);
        return false;
      },
    );
  }

  Future<bool> uploadFile(
    File file,
    String originalName,
    String? parentId,
  ) async {
    final activeWorkspace = ref.read(activeWorkspaceProvider);
    if (activeWorkspace == null) return false;

    state = const FileOpsState(isLoading: true);
    final result = await _fileService.uploadAndSaveWorkspaceFile(
      companyId: activeWorkspace.id,
      file: file,
      originalName: originalName,
      parentId: parentId,
    );

    return result.fold(
      (_) {
        state = const FileOpsState(
          successMessage: 'File uploaded successfully',
        );
        return true;
      },
      (error) {
        state = FileOpsState(error: error);
        return false;
      },
    );
  }
}

final fileOpsProvider = NotifierProvider<FileOpsNotifier, FileOpsState>(
  FileOpsNotifier.new,
);
