import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import '../snackbar/fail_snackbar.dart';
import '../snackbar/success_snackbar.dart';

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

  late String status; // เก็บค่า lowercase
  bool saving = false;
  bool uploading = false;
  bool downloading = false;

  // อัปโหลดได้ไฟล์เดียว
  String? uploadedUrl;
  String? uploadedName;
  int? uploadedSize;

  // ✅ จำว่าผู้ใช้กดลบไฟล์ออกในรอบนี้ (เพื่อให้ save() เคลียร์ค่าใน DB)
  bool clearedModelUrl = false;

  @override
  void initState() {
    super.initState();
    final init = widget.stickerStatus.toLowerCase();
    status = statuses.contains(init) ? init : statuses.first;

    // ถ้ามี URL เดิม ให้โชว์เป็นไฟล์เดิม
    if (widget.modelUrl != null && widget.modelUrl!.isNotEmpty) {
      uploadedUrl = widget.modelUrl;
      final parts = uploadedUrl!.split('/');
      uploadedName = parts.isNotEmpty ? parts.last : 'model.pt';
      uploadedSize = null;
    }
  }

  String cap(String s) =>
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
      default: // processing
        return (
          const Color(0xFFFFF8E1),
          Colors.black87,
          const Color(0xFFFFC107),
        );
    }
  }

  void showFailMessage(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
        content: Align(
          alignment: Alignment.topRight,
          child: FailSnackbar(
            title: title,
            message: message,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      ),
    );
  }

  void showSuccessMessage(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 90,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SuccessSnackbar(
            message: message,
            onClose: () => overlayEntry.remove(),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  Widget _statusDropdown() {
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
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          onChanged: (saving || uploading)
              ? null
              : (v) {
                  if (v != null) setState(() => status = v);
                },
          items: statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(cap(s))))
              .toList(),
        ),
      ),
    );
  }

  // ✅ ฟังก์ชันลบไฟล์ออกจาก state และตั้งธงให้ save() เคลียร์ใน DB
  void _clearUploaded() {
    setState(() {
      uploadedUrl = null;
      uploadedName = null;
      uploadedSize = null;
      clearedModelUrl = true;
    });
    debugPrint(
      "🧹 Cleared uploaded file from state; will nullify model_url on save",
    );
  }

  // ✅ อัปโหลดขึ้น Storage/buckets/models
  Future<void> pickAndUpload() async {
    debugPrint("📂 pickAndUpload() called");

    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pt'],
    );
    if (picked == null || picked.files.isEmpty) {
      debugPrint("❌ No file selected");
      return;
    }

    final f = picked.files.first;
    debugPrint("✅ File selected: ${f.name}, size: ${f.size} bytes");

    if (f.bytes == null) {
      if (!mounted) return;
      showFailMessage("File data not found", "Please select again");
      debugPrint("❌ File.bytes is null");
      return;
    }

    // (ออปชัน) จำกัด 50MB ตาม UI
    const maxBytes = 50 * 1024 * 1024;
    if (f.size > maxBytes) {
      showFailMessage("File too large", "Please select a file up to 50MB");
      debugPrint("❌ File too large: ${f.size} bytes");
      return;
    }

    setState(() {
      uploading = true;
      uploadedUrl = null;
      uploadedName = null;
      uploadedSize = null;
    });

    try {
      final safeName = f.name.replaceAll(' ', '_');
      // ⛔️ อย่าใส่ 'models/' ซ้ำ เพราะเราเลือก bucket แล้ว
      final objectKey =
          '${widget.modelId}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      debugPrint("⬆️ Uploading to bucket=models, path=$objectKey");

      await supabase.storage
          .from('models')
          .uploadBinary(
            objectKey,
            f.bytes!,
            fileOptions: const FileOptions(
              upsert: true, // ต้องมี UPDATE policy (คุณสร้างแล้ว)
              contentType: 'application/octet-stream',
              cacheControl: '31536000', // 1 ปี (ออปชัน)
            ),
          );

      debugPrint("📤 Upload success");

      // ได้ URL ไว้โชว์/รอ Save (ยังไม่เขียน DB)
      final publicUrl = supabase.storage.from('models').getPublicUrl(objectKey);
      debugPrint("🌐 Public URL generated (not saved yet): $publicUrl");

      if (!mounted) return;
      setState(() {
        uploadedUrl = publicUrl; // เก็บใน state รอ Save
        uploadedName = f.name;
        uploadedSize = f.size;
        clearedModelUrl = false; // มีไฟล์ใหม่ ไม่ต้องเคลียร์
      });
      showSuccessMessage("Upload success");
    } catch (e, st) {
      if (!mounted) return;
      showFailMessage("Upload failed", e.toString());
      debugPrint("❌ Upload failed: $e");
      debugPrint("Stacktrace: $st");
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> download_Images() async {
    if (downloading) return;

    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a folder to save the ZIP file',
      lockParentWindow: true,
    );
    if (dirPath == null) return;

    setState(() => downloading = true);

    final archive = Archive();

    for (int i = 0; i < widget.imageUrls.length; i++) {
      final url = widget.imageUrls[i];
      try {
        final uri = Uri.parse(url);
        final res = await http.get(uri);

        if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
          continue;
        }

        // ชื่อไฟล์
        String base = 'image_${i + 1}';
        String ext = 'jpg';

        final lastSeg = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : '';
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

        // เพิ่มไฟล์เข้า archive
        archive.addFile(
          ArchiveFile('$base.$ext', res.bodyBytes.length, res.bodyBytes),
        );
      } catch (_) {}
    }

    // เขียนไฟล์ ZIP ลงดิสก์
    final safeModel = widget.modelName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final zipPath =
        '$dirPath${Platform.pathSeparator}${safeModel.isEmpty ? widget.modelId : safeModel}.zip';
    final zipData = ZipEncoder().encode(archive);
    final outFile = File(zipPath);
    await outFile.writeAsBytes(zipData!);

    if (!mounted) return;
    setState(() => downloading = false);
    showSuccessMessage('Saved as ${outFile.path}');
  }

  Future<void> save() async {
    debugPrint(
      "💾 save() called, status=$status, uploadedUrl=$uploadedUrl, clearedModelUrl=$clearedModelUrl",
    );

    setState(() => saving = true);
    try {
      final updateData = <String, dynamic>{'sticker_status': status};

      // ผู้ใช้กดลบไฟล์ในรอบนี้ → เคลียร์ URL ใน DB
      if (clearedModelUrl) {
        updateData['model_url'] = null;
      }
      // ถ้าไม่ได้กดลบ และมีไฟล์ใหม่ที่อัปโหลดไว้ใน state → เขียน URL ใหม่
      else if (uploadedUrl != null && uploadedUrl!.isNotEmpty) {
        updateData['model_url'] = uploadedUrl;
      }

      debugPrint(
        "📦 Updating table=model with data: $updateData (model_id=${widget.modelId})",
      );

      final res = await supabase
          .from('model') // 'model' ตามที่คุณตั้งไว้ด้านบน
          .update(updateData)
          .eq('model_id', widget.modelId);

      debugPrint("📝 Save DB result: $res");

      if (!mounted) return;
      Navigator.of(context).pop(true);
      showSuccessMessage("Save successful");
    } catch (e, st) {
      if (!mounted) return;
      showFailMessage("Save failed", e.toString());
      debugPrint("❌ Save failed: $e");
      debugPrint("Stacktrace: $st");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbs = widget.imageUrls.take(5).toList();
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
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // แถวชื่อโมเดล + สถานะ (แบบ badge dropdown)
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
                  _statusDropdown(),
                ],
              ),
              const SizedBox(height: 10),

              // พรีวิวรูป
              if (thumbs.isNotEmpty)
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: thumbs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 120,
                        height: 86,
                        color: const Color(0xFFE6E6E6),
                        child: Image.network(
                          thumbs[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Uploaded: $created',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // กล่องอัปโหลด (กดเลือกไฟล์อย่างเดียว)
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
                      onPressed: (saving || uploading) ? null : pickAndUpload,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Browse File'),
                    ),
                  ],
                ),
              ),

              // แสดงไฟล์ที่อัปโหลด (แค่ 1 ไฟล์)
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
                                  ? '${(uploadedSize! / 1024).toStringAsFixed(0)} KB'
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
                            : _clearUploaded,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),

              // ปุ่มล่าง
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
                    onPressed: saving || uploading ? null : save,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (saving || uploading || downloading)
                        ? null
                        : download_Images,
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
