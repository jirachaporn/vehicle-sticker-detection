// lib/widgets/plate_row.dart
import 'package:flutter/material.dart';

class PlateRow extends StatelessWidget {
  final int displayIndex;
  final PlateRowData data;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const PlateRow({
    super.key,
    required this.displayIndex,
    required this.data,
    required this.onRemove,
    required this.onChanged,
  });

  InputDecoration fieldDec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 2),
              color: Color(0x0F000000),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // เลขลำดับ
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Text(
                '$displayIndex',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),

            // ฟอร์ม
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: data.licenseText,
                          decoration: fieldDec(
                            'เลขทะเบียน *',
                            hint: 'e.g. 1กก1234',
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: data.licenseLocal,
                          decoration: fieldDec(
                            'จังหวัด *',
                            hint: 'e.g. กรุงเทพมหานคร',
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: data.carOwner,
                          decoration: fieldDec(
                            'ชื่อเจ้าของ *',
                            hint: 'e.g. นายเอ',
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: data.note,
                          decoration: fieldDec(
                            'หมายเหตุ',
                            hint: 'เช่น ห้อง B-1203',
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Delete row',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlateRowData {
  final String? licenseId; // null = แถวใหม่
  final TextEditingController licenseText;
  final TextEditingController licenseLocal;
  final TextEditingController carOwner;
  final TextEditingController note;
  int onLicense; // <-- เพิ่มตรงนี้

  PlateRowData({
    this.licenseId,
    TextEditingController? licenseText,
    TextEditingController? licenseLocal,
    TextEditingController? carOwner,
    TextEditingController? note,
    this.onLicense = 1, // default 1
  }) : licenseText = licenseText ?? TextEditingController(),
       licenseLocal = licenseLocal ?? TextEditingController(),
       carOwner = carOwner ?? TextEditingController(),
       note = note ?? TextEditingController();

  bool get isValid =>
      licenseText.text.trim().isNotEmpty &&
      licenseLocal.text.trim().isNotEmpty &&
      carOwner.text.trim().isNotEmpty;

  factory PlateRowData.fromMap(Map<String, dynamic> m) {
    return PlateRowData(
      licenseId: m['license_id'] as String?,
      licenseText: TextEditingController(text: m['license_text'] ?? ''),
      licenseLocal: TextEditingController(text: m['license_local'] ?? ''),
      carOwner: TextEditingController(text: m['car_owner'] ?? ''),
      note: TextEditingController(text: m['note'] ?? ''),
      onLicense: (m['on_license'] as int?) ?? 1, 
    );
  }

  void dispose() {
    licenseText.dispose();
    licenseLocal.dispose();
    carOwner.dispose();
    note.dispose();
  }
}
