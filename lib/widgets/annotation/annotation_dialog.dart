import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnotationDialog extends StatefulWidget {
  const AnnotationDialog({
    super.key,
    required this.modelId,
    required this.modelName,
    required this.imageUrls,
    required this.stickerStatus, // expect lowercase from DB: processing|ready|failed
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
  final supa = Supabase.instance.client;

  // ✅ ค่ามาตรฐานตรงกับ enum ใน DB
  static const List<String> kStatuses = ['processing', 'ready', 'failed'];

  late String _status; // เก็บค่าเป็น lowercase เสมอ
  late TextEditingController _urlCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.stickerStatus.toLowerCase();
    _status = kStatuses.contains(init) ? init : kStatuses.first;
    _urlCtrl = TextEditingController(text: widget.modelUrl ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPt() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pt'],
    );
    if (picked == null || picked.files.isEmpty) return;

    final f = picked.files.first;
    if (f.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบ bytes ของไฟล์ กรุณาเลือกใหม่')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${f.name.replaceAll(' ', '_')}';
      final objectKey = '${widget.modelId}/$fileName';

      await supa.storage.from('models').uploadBinary(
            objectKey,
            f.bytes!,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/octet-stream',
            ),
          );

      final publicUrl = supa.storage.from('models').getPublicUrl(objectKey);
      if (!mounted) return;
      setState(() => _urlCtrl.text = publicUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปโหลดไฟล์ .pt สำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปโหลดล้มเหลว: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await supa
          .from('model')
          .update({
            'sticker_status': _status, // ✅ ส่งเป็น lowercase ตรง enum
            if (_urlCtrl.text.trim().isNotEmpty) 'model_url': _urlCtrl.text.trim(),
          })
          .eq('model_id', widget.modelId); // ✅ ใช้ eq() ตรง ๆ

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbs = widget.imageUrls.take(5).toList();
    final created = widget.createdAt != null
        ? '${widget.createdAt!.day}/${widget.createdAt!.month}/${widget.createdAt!.year}'
        : '-';

    // ฟังก์ชันเล็ก ๆ เพื่อแสดง label สวย ๆ แต่เก็บค่าเป็น lowercase
    String _labelize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
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

              // กล่องเหลือง: รายละเอียด + รูป
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6D7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF0D784)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ชื่อ + สถานะ
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.modelName.isEmpty ? widget.modelId : widget.modelName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.brightness_1, size: 10, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(_labelize(_status)),
                        const SizedBox(width: 8),

                        // ✅ dropdown ใช้ค่า lowercase ตรง enum
                        DropdownButton<String>(
                          value: _status,
                          items: kStatuses
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(_labelize(s)),
                                  ))
                              .toList(),
                          onChanged: _saving ? null : (v) {
                            if (v != null) setState(() => _status = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // แถบรูป
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: const Color(0xFFE6E6E6),
                            width: 120,
                            height: 86,
                            child: Image.network(
                              thumbs[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                          ),
                        ),
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemCount: thumbs.length,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Uploaded: $created',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // URL input สำหรับ model_url
              Align(
                alignment: Alignment.centerLeft,
                child: Text('URL for saving the model', style: TextStyle(color: Colors.grey.shade700)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                readOnly: _saving,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF1F2F4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Upload .pt',
                    icon: const Icon(Icons.upload_file),
                    onPressed: _saving ? null : _pickAndUploadPt,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ปุ่ม
              Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _saving ? null : _save,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            // TODO: ใส่ลอจิกดาวน์โหลดสติกเกอร์จริงตาม requirement
                            Navigator.of(context).pop(false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E63F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    child: const Text('Download'),
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
