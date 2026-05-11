import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marita/models/chat_message.dart';
import 'package:uuid/uuid.dart';

class AttachmentService {
  static final _uuid = const Uuid();
  static final _imagePicker = ImagePicker();
  static final _storage = FirebaseStorage.instance;

  /// Picks multiple files from the device.
  static Future<List<ChatAttachment>> pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'csv', 'doc', 'docx', 'xls', 'xlsx', 
          'txt', 'json', 'sql', 'md', 'xml'
        ],
      );

      if (result == null || result.files.isEmpty) return [];

      return result.files.map((file) {
        final path = file.path!;
        final name = file.name;
        final type = _determineType(name);
        
        return ChatAttachment(
          id: _uuid.v4(),
          name: name,
          path: path,
          type: type,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Picks an image from the gallery.
  static Future<ChatAttachment?> pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      return ChatAttachment(
        id: _uuid.v4(),
        name: image.name,
        path: image.path,
        type: 'image',
      );
    } catch (e) {
      return null;
    }
  }

  /// Takes a photo using the camera.
  static Future<ChatAttachment?> takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo == null) return null;

      return ChatAttachment(
        id: _uuid.v4(),
        name: photo.name,
        path: photo.path,
        type: 'image',
      );
    } catch (e) {
      return null;
    }
  }

  static String _determineType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'pdf';
      case 'csv':
        return 'csv';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'xls':
      case 'xlsx':
        return 'xls';
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'heic':
        return 'image';
      case 'txt':
      case 'json':
      case 'sql':
      case 'md':
      case 'xml':
        return 'text';
      default:
        return 'file';
    }
  }

  /// Uploads an attachment to Firebase Storage.
  static Future<String?> uploadAttachment(ChatAttachment attachment, String userId) async {
    try {
      final file = File(attachment.path);
      if (!await file.exists()) return null;

      final extension = attachment.name.split('.').last;
      final fileName = '${attachment.id}.$extension';
      final ref = _storage
          .ref()
          .child('users/$userId/attachments/$fileName');

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(customMetadata: {
          'originalName': attachment.name,
          'type': attachment.type,
        }),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}
