import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';

class FileManager {
  static Future<String?> downloadImagesAsZip({
    required List<String> imageUrls,
    required String zipFileName,
  }) async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a folder to save the ZIP file',
      lockParentWindow: true,
    );
    if (dirPath == null) return null;

    final archive = Archive();

    for (int i = 0; i < imageUrls.length; i++) {
      final url = imageUrls[i];
      try {
        final uri = Uri.parse(url);
        final res = await http.get(uri);

        if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
          continue;
        }

        // ชื่อไฟล์
        String base = 'image_${i + 1}';
        String ext = 'jpg';

        final lastSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        if (lastSeg.contains('.')) {
          final dot = lastSeg.lastIndexOf('.');
          if (dot > 0 && dot < lastSeg.length - 1) {
            base = lastSeg.substring(0, dot);
            ext = lastSeg.substring(dot + 1);
          }
        }

        final ct = res.headers['content-type'] ?? '';
        if (ct.contains('png')) {
          ext = 'png';
        } else if (ct.contains('jpeg') || ct.contains('jpg')) {
          ext = 'jpg';
        }

        base = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        if (base.isEmpty) base = 'image_${i + 1}';

        archive.addFile(
          ArchiveFile('$base.$ext', res.bodyBytes.length, res.bodyBytes),
        );
      } catch (e) {
        debugPrint('Failed to download image $i: $e');
      }
    }

    // เขียนไฟล์ ZIP ลงดิสก์
    final safeName = zipFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final zipPath = '$dirPath${Platform.pathSeparator}${safeName.isEmpty ? 'download' : safeName}.zip';
    final zipData = ZipEncoder().encode(archive);
    final outFile = File(zipPath);
    await outFile.writeAsBytes(zipData!);

    return outFile.path;
  }

  // เลือกและตรวจสอบไฟล์
  static Future<PlatformFile?> pickFile({
    required List<String> allowedExtensions,
    int maxSizeMB = 50,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.first;

    if (file.bytes == null) {
      throw Exception('File data not found');
    }

    final maxBytes = maxSizeMB * 1024 * 1024;
    if (file.size > maxBytes) {
      throw Exception('File too large (max ${maxSizeMB}MB)');
    }

    return file;
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}