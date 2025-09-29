// import
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../snackbar/success_snackbar.dart';
import '../snackbar/fail_snackbar.dart';
import '../../models/location.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import 'package:uuid/uuid.dart';

// ตัวแปร
const _kPrimary = Color(0xFF2563EB);
const _kRadius = 16.0;

// ฟังก์ชัน (utils เล็กๆ)
InputDecoration _fieldDec(String label, {String? hint}) {
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
      borderSide: const BorderSide(color: _kPrimary, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

// ===== แจ้งเตือนตามที่ให้มา =====
void showFailMessage(BuildContext context, String errorMessage, dynamic error) {
  final ctx = Navigator.of(context, rootNavigator: true).context;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      elevation: 0,
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

// ตัวหลัก
class AddLicenseDialog extends StatefulWidget {
  final String? locationLicense;
  final bool isEdit;
  final Map<String, dynamic>? locationData;
  final Location? initialLocation;

  const AddLicenseDialog({
    super.key,
    this.locationLicense,
    this.isEdit = false,
    this.locationData,
    this.initialLocation,
  });

  @override
  State<AddLicenseDialog> createState() => _AddLicenseDialogState();
}

// ตัวแปรของ State
class _AddLicenseDialogState extends State<AddLicenseDialog> {
  final supa = Supabase.instance.client;

  final List<_PlateRowData> _rows = [_PlateRowData()];
  final List<String> _deletedIds = [];
  bool _loading = false;
  bool _saving = false;
  final uuid = Uuid();

  bool get _canSave => _rows.isNotEmpty && _rows.every((r) => r.isValid);

  // ฟังก์ชัน
  @override
  void initState() {
    super.initState();
    if (widget.isEdit) loadExisting();
  }

  Future<void> loadExisting() async {
    setState(() => _loading = true);
    try {
      if (widget.locationLicense == null) {
        _rows
          ..clear()
          ..add(_PlateRowData());
        debugPrint('ℹ️ no key provided; add empty row');
        return;
      }
      String? license = widget.locationLicense!;
      
      // 2) ยิง query ด้วย location_license ที่ได้
      debugPrint('🔍 query by location_license: $license');
      final data = await supa
          .from('license_plate')
          .select('license_id, license_text, license_local, car_owner, note')
          .eq('location_license', license)
          .order('license_text', ascending: true);

      debugPrint('🔍 raw result: $data');

      // 3) แปลงและยัดลงฟอร์ม
      final list = (data as List).cast<Map<String, dynamic>>();
      _rows
        ..clear()
        ..addAll(
          list.isEmpty ? [_PlateRowData()] : list.map(_PlateRowData.fromMap),
        );

      debugPrint('📦 loaded plates: ${list.length}');
      if (list.isNotEmpty) debugPrint('👉 first: ${list.first}');
    } catch (e) {
      if (mounted) {
        showFailMessage(context, 'โหลดข้อมูลล้มเหลว', e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // แทนที่ฟังก์ชัน _savePlates ใน add_license_dialog.dart
  Future<void> _savePlates() async {
    debugPrint('🚀 _savePlates() started');
    debugPrint('🔍 _canSave: $_canSave');
    debugPrint('🔍 _rows.length: ${_rows.length}');

    if (!_canSave) {
      showFailMessage(
        context,
        'กรอกข้อมูลไม่ครบ',
        'กรอกข้อมูลให้ครบอย่างน้อย 1 แถว',
      );
      return;
    }

    setState(() => _saving = true);

    final supa = Supabase.instance.client;
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      // =================== โหมดแก้ไข ===================
      if (widget.isEdit &&
          widget.locationLicense != null &&
          widget.initialLocation != null) {
        final currentLocationId =
            widget.initialLocation!.id; // ใช้ field ตามโมเดลคุณ
        final currentLocationLicense = widget.locationLicense!;

        // UPDATE แถวเดิม
        for (final r in _rows.where((e) => e.licenseId != null)) {
          await supa
              .from('license_plate')
              .update({
                'location_license': currentLocationLicense,
                'license_text': r.licenseText.text.trim(),
                'license_local': r.licenseLocal.text.trim(),
                'car_owner': r.carOwner.text.trim(),
                'note': r.note.text.trim().isEmpty ? null : r.note.text.trim(),
              })
              .eq('license_id', r.licenseId!)
              .select('license_id');
        }

        // INSERT แถวใหม่
        final newRows = _rows
            .where((e) => e.licenseId == null)
            .map(
              (r) => {
                'location_license': currentLocationLicense,
                'license_text': r.licenseText.text.trim(),
                'license_local': r.licenseLocal.text.trim(),
                'car_owner': r.carOwner.text.trim(),
                'note': r.note.text.trim().isEmpty ? null : r.note.text.trim(),
              },
            )
            .toList();
        if (newRows.isNotEmpty) {
          await supa.from('license_plate').insert(newRows).select('license_id');
        }

        // DELETE แถวที่ลบ
        if (_deletedIds.isNotEmpty) {
          await supa
              .from('license_plate')
              .delete()
              .inFilter('license_id', _deletedIds)
              .select('license_id');
        }

        // UPDATE location (ถ้าส่งมา)
        if (widget.locationData != null) {
          await supa
              .from('locations')
              .update(widget.locationData!)
              .eq('location_id', currentLocationId)
              .select('location_id');
        }
      }
      // =================== โหมดสร้างใหม่ ===================
      else if (widget.locationData != null) {
        final supa = Supabase.instance.client;
        final String newLocationId = uuid.v4();

        // 1) INSERT locations (อย่าใส่ location_license — DB จะ gen LI0000xx เอง)
        final locRow = {...widget.locationData!, 'location_id': newLocationId};
        locRow.remove('location_license'); // กันลืม
        await supa.from('locations').insert(locRow); // ห้าม .select() ตรงนี้

        // 2) (ไม่ต้อง insert location_members) -> ให้ trigger handle_new_location ทำงานเอง

        // 3) ตอนนี้มีสิทธิ์ SELECT แล้ว (เพราะ trigger ใส่สมาชิกให้เรา)
        final licRes = await supa
            .from('locations')
            .select('location_license')
            .eq('location_id', newLocationId)
            .maybeSingle();

        final locationLicense = licRes?['location_license'] as String?;
        if (locationLicense == null) {
          throw Exception('ไม่พบ location_license (trigger ไม่ทำงาน?)');
        }

        // 4) INSERT license_plate ทั้งหมด โดยใช้ license จาก DB
        final plateRows = _rows
            .map(
              (r) => {
                'location_license': locationLicense,
                'license_text': r.licenseText.text.trim(),
                'license_local': r.licenseLocal.text.trim(),
                'car_owner': r.carOwner.text.trim(),
                'note': r.note.text.trim().isEmpty ? null : r.note.text.trim(),
              },
            )
            .toList();

        if (plateRows.isNotEmpty) {
          await supa.from('license_plate').insert(plateRows);
        }
      }
      // =================== เพิ่มป้ายทะเบียนให้ location ที่มีอยู่แล้ว ===================
      else if (!widget.isEdit && widget.locationLicense != null) {
        final plateRows = _rows
            .map(
              (r) => {
                'location_license': widget.locationLicense!,
                'license_text': r.licenseText.text.trim(),
                'license_local': r.licenseLocal.text.trim(),
                'car_owner': r.carOwner.text.trim(),
                'note': r.note.text.trim().isEmpty ? null : r.note.text.trim(),
              },
            )
            .toList();
        if (plateRows.isNotEmpty) {
          await supa.from('license_plate').insert(plateRows);
        }
      }

      // โหลดข้อมูลใหม่ + แจ้งผล
      await appState.loadLocations(appState.loggedInEmail);
      if (!mounted) return;
      final rootCtx = Navigator.of(context, rootNavigator: true).context;
      showSuccessMessage(
        rootCtx,
        widget.isEdit ? 'บันทึกการแก้ไขสำเร็จ!' : 'เพิ่มป้ายทะเบียนสำเร็จ!',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showFailMessage(context, 'เพิ่ม license_plate ไม่สำเร็จ', e.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRow() => setState(() => _rows.add(_PlateRowData()));

  void _removeRow(int index) {
    if (_rows.length == 1) {
      showFailMessage(context, 'ลบไม่ได้', 'ต้องมีอย่างน้อย 1 แถว');
      return;
    }
    final removed = _rows.removeAt(index);
    if (removed.licenseId != null) {
      _deletedIds.add(removed.licenseId!);
    }
    setState(() {});
  }

  void _moveUp(int i) {
    if (i <= 0) return;
    final item = _rows.removeAt(i);
    _rows.insert(i - 1, item);
    setState(() {});
  }

  void _moveDown(int i) {
    if (i >= _rows.length - 1) return;
    final item = _rows.removeAt(i);
    _rows.insert(i + 1, item);
    setState(() {});
  }

  // Widget build(Main)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: _kPrimary,
            secondary: _kPrimary,
          ),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _kPrimary, width: 2),
            ),
          ),
        ),
        child: Container(
          width: 760,
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Text(
                          widget.isEdit
                              ? 'Edit license plate'
                              : 'Add license plate',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_rows.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'close',
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'At least 1 row',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rows (numbered)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(_rows.length, (i) {
                            return _PlateNumberRow(
                              displayIndex: i + 1,
                              data: _rows[i],
                              onRemove: () => _removeRow(i),
                              onMoveUp: () => _moveUp(i),
                              onMoveDown: () => _moveDown(i),
                              onChanged: () => setState(() {}),
                            );
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Add row
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(foregroundColor: _kPrimary),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _saving
                                ? null
                                : (_canSave ? _savePlates : null),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
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

// วิดเจ็ตย่อยๆ
class _PlateRowData {
  final String? licenseId; // null = แถวใหม่
  final TextEditingController licenseText;
  final TextEditingController licenseLocal;
  final TextEditingController carOwner;
  final TextEditingController note;

  _PlateRowData({
    this.licenseId,
    TextEditingController? licenseText,
    TextEditingController? licenseLocal,
    TextEditingController? carOwner,
    TextEditingController? note,
  }) : licenseText = licenseText ?? TextEditingController(),
       licenseLocal = licenseLocal ?? TextEditingController(),
       carOwner = carOwner ?? TextEditingController(),
       note = note ?? TextEditingController();

  bool get isValid =>
      licenseText.text.trim().isNotEmpty &&
      licenseLocal.text.trim().isNotEmpty &&
      carOwner.text.trim().isNotEmpty;

  factory _PlateRowData.fromMap(Map<String, dynamic> m) {
    return _PlateRowData(
      licenseId: m['license_id'] as String?,
      licenseText: TextEditingController(
        text: (m['license_text'] as String?) ?? '',
      ),
      licenseLocal: TextEditingController(
        text: (m['license_local'] as String?) ?? '',
      ),
      carOwner: TextEditingController(text: (m['car_owner'] as String?) ?? ''),
      note: TextEditingController(text: (m['note'] as String?) ?? ''),
    );
  }
}

class _PlateNumberRow extends StatelessWidget {
  final int displayIndex;
  final _PlateRowData data;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onChanged;

  const _PlateNumberRow({
    required this.displayIndex,
    required this.data,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kRadius),
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
                          decoration: _fieldDec(
                            'เลขทะเบียน ',
                            hint: 'e.g. 1กก1234',
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: data.licenseLocal,
                          decoration: _fieldDec(
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
                          decoration: _fieldDec(
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
                          decoration: _fieldDec(
                            'หมายเหตุ',
                            hint: 'เช่น ห้อง B-1203',
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                    ],
                  ),
                  if (data.licenseId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ID: ${data.licenseId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ปุ่มของแถว
            Column(
              children: [
                IconButton(
                  tooltip: 'ย้ายขึ้น',
                  onPressed: onMoveUp,
                  icon: const Icon(Icons.arrow_upward, size: 20),
                ),
                IconButton(
                  tooltip: 'ย้ายลง',
                  onPressed: onMoveDown,
                  icon: const Icon(Icons.arrow_downward, size: 20),
                ),
                IconButton(
                  tooltip: 'ลบแถว',
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
