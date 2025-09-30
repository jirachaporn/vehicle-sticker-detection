import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../snackbar/success_snackbar.dart';
import '../snackbar/fail_snackbar.dart';

class ExcelImportDialog extends StatefulWidget {
  const ExcelImportDialog({super.key});

  @override
  State<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<ExcelImportDialog> {
  bool _parsing = false;
  PlatformFile? _picked;
  List<Map<String, String>> _previewRows = [];

  void showFailMessage(
    BuildContext context,
    String errorMessage,
    dynamic error,
  ) {
    final ctx = Navigator.of(context, rootNavigator: true).context;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        elevation: 20,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
        content: Align(
          alignment: Alignment.topRight,
          child: FailSnackbar(
            title: errorMessage,
            message: error,
            onClose: () => ScaffoldMessenger.of(ctx).hideCurrentSnackBar(),
          ),
        ),
      ),
    );
  }

  void showSuccessMessage(BuildContext context, String message) {
    final nav = Navigator.of(context, rootNavigator: true);
    final overlay = nav.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 90,
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          child: SuccessSnackbar(
            message: message,
            onClose: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> downloadExample() async {
    const fileName = 'Excel file format (example).xlsx';
    const assetPath = 'assets/excel_format/Excel file format (example).xlsx';

    try {
      // โหลดจาก assets
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      // ดึงโฟลเดอร์ Downloads ของ user ปัจจุบัน
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) throw 'ไม่พบโฟลเดอร์ Downloads';

      final outFile = File(p.join(downloadsDir.path, fileName));
      await outFile.writeAsBytes(bytes, flush: true);

      // เปิด Explorer ชี้ไฟล์ที่เพิ่งบันทึก
      await Process.run('explorer.exe', ['/select,', outFile.path]);

      if (!mounted) return;

      if (context.mounted) {
        showSuccessMessage(context, 'Saved example to: ${outFile.path}');
      }
    } catch (e) {
      // ❌ แจ้งเตือนล้มเหลว
      if (context.mounted) {
        showFailMessage(context, "Download failed", e.toString());
      }
    }
  }

  // เปิดไฟล์เลือก .xlsx/.xls
  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    setState(() {
      _picked = res.files.first;
      _previewRows.clear();
    });

    await _parsePicked();
  }

  // อ่านไฟล์ที่เลือกแล้วแปลงเป็น list ของ map
  Future<void> _parsePicked() async {
    if (_picked == null) return;
    setState(() => _parsing = true);
    try {
      Uint8List bytes;
      if (_picked!.bytes != null) {
        bytes = _picked!.bytes!;
      } else if (_picked!.path != null) {
        bytes = await File(_picked!.path!).readAsBytes();
      } else {
        throw 'ไม่พบข้อมูลไฟล์';
      }

      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables.isNotEmpty ? excel.tables.values.first : null;
      if (table == null || table.rows.isEmpty) {
        throw 'ไฟล์ไม่มีข้อมูล';
      }

      // หา header (รองรับ: license_text, license_local, car_owner, note)
      int startRow = 0;
      final header = table.rows.first
          .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
          .toList();
      bool looksHeader = header.any(
        (h) =>
            ['license_text', 'license_local', 'car_owner', 'note'].contains(h),
      );

      int idxText = _findCol(header, 'license_text');
      int idxLocal = _findCol(header, 'license_local');
      int idxOwner = _findCol(header, 'car_owner');
      int idxNote = _findCol(header, 'note');

      if (looksHeader) startRow = 1;

      String cell(List<Data?> row, int i) {
        if (i < 0 || i >= row.length) return '';
        final v = row[i]?.value;
        return v == null ? '' : v.toString().trim();
      }

      final out = <Map<String, String>>[];
      for (int r = startRow; r < table.rows.length; r++) {
        final row = table.rows[r];
        final licenseText = idxText >= 0
            ? cell(row, idxText)
            : (row.isNotEmpty ? cell(row, 0) : '');
        final licenseLocal = idxLocal >= 0 ? cell(row, idxLocal) : '';
        final carOwner = idxOwner >= 0 ? cell(row, idxOwner) : '';
        final note = idxNote >= 0 ? cell(row, idxNote) : '';

        if ([
          licenseText,
          licenseLocal,
          carOwner,
          note,
        ].every((e) => e.isEmpty)) {
          continue;
        }

        out.add({
          'license_text': licenseText,
          'license_local': licenseLocal,
          'car_owner': carOwner,
          'note': note,
        });
      }

      setState(() => _previewRows = out);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  int _findCol(List<String> header, String key) {
    for (int i = 0; i < header.length; i++) {
      if (header[i] == key) return i;
    }
    return -1;
  }

  void _removePicked() {
    setState(() {
      _picked = null;
      _previewRows.clear();
    });
  }

  // กด Confirm → ส่งผลลัพธ์กลับไปหน้าหลัก
  void _confirm() {
    if (_previewRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีข้อมูลเพื่อนำเข้า')),
      );
      return;
    }
    Navigator.of(context).pop<List<Map<String, String>>>(_previewRows);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = !_parsing && _previewRows.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.white, // พื้นหลังขาวตามที่ขอ
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== Header =====
              Row(
                children: [
                  const Text(
                    'Import from Excel',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: downloadExample,
                    icon: const Icon(Icons.download),
                    label: const Text('Example Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF217346),
                      side: const BorderSide(color: Color(0xFF217346)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ===== Upload Frame (ตามรูป) =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white, // กรอบพื้นหลังขาว
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000), // เงาอ่อน
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: Color(0xFF2563EB),
                    ), // เทาแบบในรูป
                    const SizedBox(height: 10),
                    const Text(
                      'Choose a file',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Excel format (.xlsx / .xls), up to ~50MB',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // ปุ่ม Browse (Outlined เขียว Excel)
                    OutlinedButton(
                      onPressed: _parsing ? null : _pickFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                      child: const Text('Browse File'),
                    ),

                    // แถบไฟล์ที่อัปโหลดแล้ว (ชิปแบบในรูป)
                    if (_picked != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 20,
                              color: Color(0xFF475569),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _picked!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Uploaded',
                              style: TextStyle(color: Color(0xFF4CAF50)),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _removePicked,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ===== Preview rows / Loading =====
              Row(
                children: [
                  Text(
                    'Total rows: ${_previewRows.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_parsing) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // ===== Actions =====
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.red, 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canConfirm ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF217346),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Import'),
                    ),
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
