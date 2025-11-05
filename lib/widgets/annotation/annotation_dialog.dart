import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/api_service.dart';
import '../../providers/snackbar_func.dart';
import '../../providers/file_manager.dart';

class AnnotationDialog extends StatefulWidget {
  const AnnotationDialog({
    super.key,
    required this.modelId,
    required this.modelName,
    required this.imageUrls,
    required this.stickerStatus,
    this.modelUrl,
    this.createdAt,
  });

  final String modelId;
  final String modelName;
  final List<String> imageUrls;
  final String stickerStatus;
  final String? modelUrl;
  final DateTime? createdAt;

  @override
  State<AnnotationDialog> createState() => _AnnotationDialogState();
}

class _AnnotationDialogState extends State<AnnotationDialog> {
  final supabase = Supabase.instance.client;
  static const List<String> statuses = ['processing', 'ready', 'failed'];

  late String status;
  bool saving = false;
  bool uploading = false;
  bool downloading = false;

  String? uploadedUrl;
  String? uploadedName;
  int? uploadedSize;
  bool clearedModelUrl = false;

  @override
  void initState() {
    super.initState();
    final init = widget.stickerStatus.toLowerCase();
    status = statuses.contains(init) ? init : statuses.first;

    if (widget.modelUrl != null && widget.modelUrl!.isNotEmpty) {
      uploadedUrl = widget.modelUrl;
      final parts = uploadedUrl!.split('/');
      uploadedName = parts.isNotEmpty ? parts.last : 'model.pt';
      uploadedSize = null;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  (Color bg, Color fg, Color border) _statusColors(String s) {
    switch (s) {
      case 'ready':
        return (
          const Color(0xFFE8F5E9),
          Colors.black87,
          const Color(0xFF4CAF50),
        );
      case 'failed':
        return (
          const Color(0xFFFFEBEE),
          Colors.black87,
          const Color(0xFFF44336),
        );
      default:
        return (
          const Color(0xFFFFF8E1),
          Colors.black87,
          const Color(0xFFFFC107),
        );
    }
  }

  Widget buildStatusDropdown() {
    final (bg, fg, border) = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: status,
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          onChanged: (saving || uploading)
              ? null
              : (v) {
                  if (v != null) setState(() => status = v);
                },
          items: statuses.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(
                _capitalize(s),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _clearUploadedFile() {
    setState(() {
      uploadedUrl = null;
      uploadedName = null;
      uploadedSize = null;
      clearedModelUrl = true;
    });
    debugPrint("🧹 Cleared uploaded file from state");
  }

  Future<void> _pickAndUpload() async {
    try {
      final file = await FileManager.pickFile(
        allowedExtensions: ['pt'],
        maxSizeMB: 50,
      );

      if (file == null) return;

      setState(() {
        uploading = true;
        uploadedUrl = null;
        uploadedName = null;
        uploadedSize = null;
      });

      final safeName = file.name.replaceAll(' ', '_');
      final objectKey =
          '${widget.modelId}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      await supabase.storage
          .from('models')
          .uploadBinary(
            objectKey,
            file.bytes!,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/octet-stream',
              cacheControl: '31536000',
            ),
          );

      final publicUrl = supabase.storage.from('models').getPublicUrl(objectKey);

      if (!mounted) return;
      setState(() {
        uploadedUrl = publicUrl;
        uploadedName = file.name;
        uploadedSize = file.size;
        clearedModelUrl = false;
      });
      showSuccessMessage(context, "Upload success");
    } catch (e) {
      if (!mounted) return;
      showFailMessage(context, "Upload failed", e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> downloadImages() async {
    if (downloading) return;

    setState(() => downloading = true);

    try {
      final zipPath = await FileManager.downloadImagesAsZip(
        imageUrls: widget.imageUrls,
        zipFileName: widget.modelName.isEmpty
            ? widget.modelId
            : widget.modelName,
      );

      if (!mounted) return;

      if (zipPath != null) {
        showSuccessMessage(context, 'Saved as $zipPath');
      }
    } catch (e) {
      if (!mounted) return;
      showFailMessage(context, "Download failed", e.toString());
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Future<void> save_data() async {
    setState(() => saving = true);
    try {
      final updateData = <String, dynamic>{'sticker_status': status};

      if (clearedModelUrl) {
        updateData['model_url'] = null;
      } else if (uploadedUrl != null && uploadedUrl!.isNotEmpty) {
        updateData['model_url'] = uploadedUrl;
      }

      await supabase
          .from('model')
          .update(updateData)
          .eq('model_id', widget.modelId);

      debugPrint('status: $status');
      debugPrint('modelId: ${widget.modelId}');
      

      // if (status == 'ready') {
      //   await ApiService.sendNotificationStatus(widget.modelId, 'save');
      // } else if (status == 'failed') {
      //   await ApiService.sendNotificationStatus(widget.modelId, 'fail');
      
      // } // processing ไม่ต้องส่งการแจ้งเตือน
      if (status == 'ready') {
        // ส่ง 'save' เมื่อ status เป็น 'ready'
        await ApiService.sendNotificationStatus(widget.modelId, 'save');
      } else if (status == 'failed') {
        // ส่ง 'fail' เมื่อ status เป็น 'failed'
        await ApiService.sendNotificationStatus(widget.modelId, 'fail');
      } // processing ไม่ต้องส่งการแจ้งเตือน

      if (!mounted) return;
      Navigator.of(context).pop(true);
      showSuccessMessage(context, "Save successful");
    } catch (e) {
      if (!mounted) return;
      showFailMessage(context, "Save failed", e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = widget.createdAt != null
        ? '${widget.createdAt!.day}/${widget.createdAt!.month}/${widget.createdAt!.year}'
        : '-';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Download Sticker',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E63F1),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'If you want to download stickers to use for labeling, press Download\nIf you want to save the model URL, press Save',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Header with model name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.modelName.isEmpty
                          ? widget.modelId
                          : widget.modelName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  buildStatusDropdown(),
                ],
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Uploaded: $created',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 16),

              // Upload box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 36,
                      color: Colors.black38,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a file',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PT format, up to 50MB',
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: (saving || uploading) ? null : _pickAndUpload,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF1E63F1),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: const Color(0xFF1E63F1),
                      ),
                      child: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1E63F1),
                              ),
                            )
                          : const Text('Browse File'),
                    ),
                  ],
                ),
              ),

              // Uploaded file display
              const SizedBox(height: 12),
              if (uploadedUrl != null && uploadedUrl!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE3E6EE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file,
                        color: Colors.black45,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uploadedName ?? 'model.pt',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              uploadedSize != null
                                  ? FileManager.formatFileSize(uploadedSize!)
                                  : 'Uploaded',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: (saving || uploading)
                            ? null
                            : _clearUploadedFile,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),

              // Action buttons
              Row(
                children: [
                  TextButton(
                    onPressed: saving || uploading
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: saving || uploading ? null : save_data,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E63F1),
                      side: const BorderSide(color: Color(0xFF1E63F1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1E63F1),
                            ),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (saving || uploading || downloading)
                        ? null
                        : downloadImages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E63F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Download'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
