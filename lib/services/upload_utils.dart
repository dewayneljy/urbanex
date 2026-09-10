import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

/// Bytes above this size aren't kept in local storage (shared_preferences
/// isn't meant for large blobs) - the attachment still shows up by name,
/// it just won't have an in-app preview available for the admin.
const int kMaxStoredDocumentBytes = 6 * 1024 * 1024; // 6 MB

/// Best-effort MIME type from a filename's extension - used to decide
/// how the admin's document viewer should render a file (image preview,
/// text preview, or a generic "can't preview this" fallback).
String? mimeTypeForFileName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'heic':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
      return 'text/plain';
    case 'csv':
      return 'text/csv';
    case 'json':
      return 'application/json';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default:
      return null;
  }
}

/// Reads an [XFile] picked via camera/gallery into an [UploadedDocument],
/// keeping the actual image bytes (base64-encoded) so it can be shown
/// full-size later rather than just listing its filename.
Future<UploadedDocument> uploadedDocumentFromXFile(String label, XFile file) async {
  Uint8List? bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    // Fall through with no bytes - the filename alone still gets stored.
  }
  final tooLarge = bytes != null && bytes.length > kMaxStoredDocumentBytes;
  return UploadedDocument(
    label: label,
    fileName: file.name,
    base64Data: (bytes != null && !tooLarge) ? base64Encode(bytes) : null,
    mimeType: mimeTypeForFileName(file.name) ?? 'image/jpeg',
  );
}

/// Reads a [PlatformFile] picked via the file picker into an
/// [UploadedDocument]. Callers should request the picker with
/// `withData: true` so [PlatformFile.bytes] is populated on every
/// platform (including web, where there's no file-system path to read
/// from separately).
UploadedDocument uploadedDocumentFromPlatformFile(String label, PlatformFile file) {
  final bytes = file.bytes;
  final tooLarge = bytes != null && bytes.length > kMaxStoredDocumentBytes;
  return UploadedDocument(
    label: label,
    fileName: file.name,
    base64Data: (bytes != null && !tooLarge) ? base64Encode(bytes) : null,
    mimeType: mimeTypeForFileName(file.name),
  );
}



