import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../widgets/loading.dart';

// import '../widgets/loading.dart';
// bool isUploading = false;
// setState(() => isUploading = true);
//  Loading(visible: isUploading),
// setState(() => isUploading = false);

class FileWrapper {
  final String name;
  final int size;
  final File? file;
  final Uint8List? bytes;
  final String? path;

  FileWrapper({
    required this.name,
    required this.size,
    this.file,
    this.bytes,
    this.path,
  });

  bool get isWeb => bytes != null;
  bool get isFile => file != null;
}

class FileUpload extends StatefulWidget {
  final bool isUploading;
  final String locationId;
  final VoidCallback? onUploadStart;
  final VoidCallback? onUploadComplete;
  final VoidCallback? onUploadError;

  const FileUpload({
    super.key,
    required this.isUploading,
    required this.locationId,
    this.onUploadStart,
    this.onUploadComplete,
    this.onUploadError,
  });

  @override
  State<FileUpload> createState() => _FileUploadState();
}

class _FileUploadState extends State<FileUpload> {
  List<FileWrapper> selectedFiles = [];
  List<String> errors = [];
  final TextEditingController modelNameController = TextEditingController();
  String? modelNameError;

  @override
  void initState() {
    super.initState();
    debugPrint('📦 [FileUpload] widget.locationId = ${widget.locationId}');
  }

  String? validateFileBytes(Uint8List bytes, String fileName) {
    final mimeType = lookupMimeType(fileName, headerBytes: bytes);
    final isValidMime = mimeType == 'image/png' || mimeType == 'image/jpeg';

    if (!isValidMime) {
      return '$fileName: Only PNG and JPG files are allowed';
    }

    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      return '$fileName: File size must be less than 5MB';
    }

    return null;
  }

  String? validateFile(File file) {
    try {
      final bytes = file.readAsBytesSync();
      return validateFileBytes(bytes, file.path.split('/').last);
    } catch (e) {
      return 'Error reading file: ${file.path.split('/').last}';
    }
  }

  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result != null) {
        final newFiles = <FileWrapper>[];
        final newErrors = <String>[];

        for (final platformFile in result.files) {
          if (kIsWeb) {
            if (platformFile.bytes != null) {
              final error = validateFileBytes(
                platformFile.bytes!,
                platformFile.name,
              );
              if (error != null) {
                newErrors.add(error);
              } else {
                newFiles.add(
                  FileWrapper(
                    name: platformFile.name,
                    size: platformFile.size,
                    bytes: platformFile.bytes,
                    path: platformFile.name,
                  ),
                );
              }
            } else {
              newErrors.add('${platformFile.name}: Failed to read file data');
            }
          } else {
            if (platformFile.path != null) {
              final file = File(platformFile.path!);
              final error = validateFile(file);

              if (error != null) {
                newErrors.add(error);
              } else {
                newFiles.add(
                  FileWrapper(
                    name: platformFile.name,
                    size: platformFile.size,
                    file: file,
                    path: platformFile.path,
                  ),
                );
              }
            } else {
              newErrors.add('${platformFile.name}: Invalid file path');
            }
          }
        }

        setState(() {
          selectedFiles.addAll(newFiles);
          errors = newErrors;
        });
      }
    } catch (e) {
      setState(() {
        errors = ['Error picking files: $e'];
      });
    }
  }

  void removeFile(int index) {
    setState(() {
      selectedFiles.removeAt(index);
      if (selectedFiles.isEmpty) {
        errors.clear();
      }
    });
  }

  void handleUpload() async {
  final totalSize = selectedFiles.fold(0, (sum, file) => sum + file.size);
  final modelName = modelNameController.text.trim();

  // ตรวจสอบชื่อโมเดล
  if (modelName.isEmpty) {
    setState(() {
      modelNameError = 'Please enter a model name';
    });
    return;
  } else {
    setState(() {
      modelNameError = null;
    });
  }

  // ตรวจสอบไฟล์และขนาด
  if (selectedFiles.length < 5 || totalSize > 5 * 1024 * 1024) {
    debugPrint(
      '❌ File validation failed: ${selectedFiles.length} files, ${totalSize} bytes',
    );
    return;
  }

  if (widget.locationId == "null") {
    debugPrint("❌ Invalid locationId: ${widget.locationId}");
    return;
  }

  // เรียก callback เมื่อเริ่มอัปโหลด
  if (widget.onUploadStart != null) {
    widget.onUploadStart!();
  }

  try {
    // เริ่มอัปโหลดไฟล์
    final uri = Uri.parse("http://127.0.0.1:5000/upload-sticker-model");
    final request = http.MultipartRequest("POST", uri);
    request.fields['model_name'] = modelName;
    request.fields['location_id'] = widget.locationId;

    for (final fileWrapper in selectedFiles) {
      if (fileWrapper.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            fileWrapper.bytes!,
            filename: fileWrapper.name,
          ),
        );
      } else if (fileWrapper.file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            fileWrapper.file!.path,
            filename: fileWrapper.name,
          ),
        );
      }
    }

    final streamedRes = await request.send();
    final response = await http.Response.fromStream(streamedRes);

    if (response.statusCode == 201) {
      setState(() {
        selectedFiles.clear();
        errors.clear();
        modelNameController.clear();
      });

      // เรียก callback เมื่ออัปโหลดสำเร็จ
      if (widget.onUploadComplete != null) {
        widget.onUploadComplete!();
      }
    } else {
      debugPrint('❌ Upload failed: ${response.body}');
      // เรียก callback เมื่อเกิดข้อผิดพลาด
      if (widget.onUploadError != null) {
        widget.onUploadError!();
      }
    }
  } catch (e) {
    debugPrint('❌ Upload error: $e');
    // เรียก callback เมื่อเกิดข้อผิดพลาด
    if (widget.onUploadError != null) {
      widget.onUploadError!();
    }
  }
}

  void clearAll() {
    setState(() {
      selectedFiles.clear();
      errors.clear();
    });
  }

  String formatFileSize(int bytes) {
    if (bytes == 0) return '0 Bytes';
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    final size = bytes / (1 << (i * 10));
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${sizes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upload New Sticker Model',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildUsageInstructions(),
            const SizedBox(height: 16),
            DottedBorder(
              color: const Color(0xFF9CA3AF),
              strokeWidth: 2,
              dashPattern: const [8, 4],
              borderType: BorderType.RRect,
              radius: const Radius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Click the button below to choose your sticker images',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PNG or JPG files, max 5MB each. Minimum 5 images required. Total size must not exceed 5MB.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: widget.isUploading ? null : pickFiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Choose Files',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Upload Errors:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...errors.map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $error',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Files (${selectedFiles.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  if (selectedFiles.isNotEmpty)
                    TextButton(
                      onPressed: widget.isUploading ? null : clearAll,
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                child: Column(
                  children: List.generate(selectedFiles.length, (index) {
                    final fileWrapper = selectedFiles[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.image,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileWrapper.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      formatFileSize(fileWrapper.size),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: fileWrapper.isWeb
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        fileWrapper.isWeb ? 'Web' : 'File',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: fileWrapper.isWeb
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.isUploading
                                ? null
                                : () => removeFile(index),
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  selectedFiles.length < 5
                      ? '${5 - selectedFiles.length} more images needed'
                      : selectedFiles.fold(0, (sum, file) => sum + file.size) >
                            5 * 1024 * 1024
                      ? 'Total size exceeds 5MB'
                      : 'Ready to upload!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        (selectedFiles.length >= 5 &&
                            selectedFiles.fold(
                                  0,
                                  (sum, file) => sum + file.size,
                                ) <=
                                5 * 1024 * 1024)
                        ? const Color(0xFF059669)
                        : const Color(0xFFE4960F),
                  ),
                ),
                const SizedBox(width: 8),

                Icon(
                  (selectedFiles.length >= 5 &&
                          selectedFiles.fold(
                                0,
                                (sum, file) => sum + file.size,
                              ) <=
                              5 * 1024 * 1024)
                      ? Icons.check_circle
                      : Icons.warning,
                  size: 16,
                  color:
                      (selectedFiles.length >= 5 &&
                          selectedFiles.fold(
                                0,
                                (sum, file) => sum + file.size,
                              ) <=
                              5 * 1024 * 1024)
                      ? const Color(0xFF059669)
                      : const Color(0xFFE4960F),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Model Name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: modelNameController,
              decoration: InputDecoration(
                hintText: 'e.g. Gate1 Entry V1',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 2,
                  ),
                ),
                errorText: modelNameError?.isEmpty == true
                    ? null
                    : modelNameError,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total: ${formatFileSize(selectedFiles.fold(0, (sum, file) => sum + file.size))}',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                selectedFiles.fold(
                                      0,
                                      (sum, file) => sum + file.size,
                                    ) >
                                    5 * 1024 * 1024
                                ? const Color(0xFFEF4444) // สีแดงถ้าเกิน 5MB
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        if (selectedFiles.fold(
                              0,
                              (sum, file) => sum + file.size,
                            ) >
                            5 * 1024 * 1024)
                          const Text(
                            ' (Exceeds 5MB)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed:
                          (selectedFiles.length >= 5 &&
                              !widget.isUploading &&
                              selectedFiles.fold(
                                    0,
                                    (sum, file) => sum + file.size,
                                  ) <=
                                  5 * 1024 * 1024)
                          ? handleUpload
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: widget.isUploading
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Uploading...',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          : const Text(
                              'Upload Stickers',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageInstructions() {
    final instructions = [
      'Upload at least 5 high-quality images (PNG or JPG format)',
      'Each image must be less than 5MB in size',
      'Total size of all images must not exceed 5MB',
      'Only one model can be active at a time',
      'New uploads will automatically deactivate the current active model',
      'You can reactivate previous models at any time',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEA),
        border: Border.all(color: const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usage Instructions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 12),
          ...instructions.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontSize: 14, color: Color(0xFF92400E)),
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
