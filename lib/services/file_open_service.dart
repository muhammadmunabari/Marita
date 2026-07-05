import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';

class FileOpenService {
  /// Resolves MIME type based on file type or stored mimeType
  static String mimeTypeFor(FileItem item) {
    if (item.mimeType != null && item.mimeType!.isNotEmpty) {
      return item.mimeType!;
    }
    switch (item.type.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv':
        return 'text/csv';
      case 'txt':
      case 'text':
        return 'text/plain';
      case 'image':
        return 'image/*';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return '*/*';
    }
  }

  /// Checks if the file is already fully cached locally.
  /// Returns the File if cached, null otherwise.
  static Future<File?> getCachedFile(FileItem item) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final maritaDir = Directory(p.join(cacheDir.path, 'marita_files'));
      if (!maritaDir.existsSync()) return null;

      final fileName = item.name.isNotEmpty ? '${item.id}_${item.name}' : '${item.id}.${item.type}';
      final localPath = p.join(maritaDir.path, fileName);
      final localFile = File(localPath);

      if (localFile.existsSync()) {
        final localLength = localFile.lengthSync();
        // If file size matches the record size (if available), consider it a cache hit.
        if (item.size == null || item.size! <= 0 || localLength == item.size) {
          debugPrint('[FileOpenService] Cache hit: $localPath ($localLength bytes)');
          return localFile;
        } else {
          debugPrint('[FileOpenService] Cache size mismatch. Local: $localLength, Expected: ${item.size}');
        }
      }
    } catch (e) {
      debugPrint('[FileOpenService] Error checking cache: $e');
    }
    return null;
  }

  /// Downloads file from URL and opens it with the native app chooser.
  ///
  /// [onProgress] callback receives 0.0–1.0 progress.
  /// Returns an error string, or null on success.
  static Future<String?> downloadAndOpen(
    FileItem item, {
    void Function(double progress)? onProgress,
  }) async {
    if (item.url == null || item.url!.isEmpty) {
      return 'File does not have a valid URL.';
    }

    try {
      // 1. Check Cache first
      final cachedFile = await getCachedFile(item);
      if (cachedFile != null) {
        onProgress?.call(1.0);
        final mime = mimeTypeFor(item);
        final result = await OpenFilex.open(cachedFile.path, type: mime);
        if (result.type != ResultType.done) {
          return 'No app available to open this file (${result.message}).';
        }
        return null;
      }

      // 2. Prepare temp directory
      final cacheDir = await getTemporaryDirectory();
      final maritaDir = Directory(p.join(cacheDir.path, 'marita_files'));
      if (!maritaDir.existsSync()) {
        maritaDir.createSync(recursive: true);
      }

      final fileName = item.name.isNotEmpty ? '${item.id}_${item.name}' : '${item.id}.${item.type}';
      final localPath = p.join(maritaDir.path, fileName);
      final localFile = File(localPath);

      // 3. Download file
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(item.url!));
      final response = await request.close();

      if (response.statusCode != 200) {
        return 'Failed to download file (HTTP ${response.statusCode}).';
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      final sink = localFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }
      await sink.close();
      client.close();

      // 4. Open with native app
      final mime = mimeTypeFor(item);
      final result = await OpenFilex.open(localPath, type: mime);

      if (result.type != ResultType.done) {
        return 'No app available to open this file (${result.message}).';
      }

      return null; // success
    } on SocketException {
      return 'No internet connection.';
    } catch (e) {
      return 'Failed to open file: $e';
    }
  }
}
