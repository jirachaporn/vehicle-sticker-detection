// ===================== import =====================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../snackbar/success_snackbar.dart';
import '../snackbar/fail_snackbar.dart';
import '../../models/location.dart';
import '../../providers/app_state.dart';
import 'excel_import_dialog.dart';

// ===================== ฟังก์ชัน (ไฟล์) =====================
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

void showFailMessage(BuildContext context, String errorMessage, dynamic error) {
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

// ===================== class (ตัวหลัก) =====================
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

// ===================== ตัวแปร/ฟังก์ชันใน class =====================
class _AddLicenseDialogState extends State<AddLicenseDialog> {
  final supa = Supabase.instance.client;
  final uuid = const Uuid();

  final List<_PlateRowData> _rows = <_PlateRowData>[_PlateRowData()];
  final List<String> _deletedIds = <String>[];

  bool _loading = false;
  bool _saving = false;

  bool get _canSave => _rows.isNotEmpty && _rows.every((r) => r.isValid);

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      loadExisting();
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> loadExisting() async {
    setState(() => _loading = true);
    try {
      final key = widget.locationLicense;
      if (key == null || key.isEmpty) {
        _rows
          ..clear()
          ..add(_PlateRowData());
        return;
      }

      final data = await supa
          .from('license_plate')
          .select('license_id, license_text, license_local, car_owner, note')
          .eq('location_license', key)
          .order('license_text', ascending: true);

      final list = (data as List).cast<Map<String, dynamic>>();
      _rows
        ..clear()
        ..addAll(
          list.isEmpty ? [_PlateRowData()] : list.map(_PlateRowData.fromMap),
        );
    } catch (e) {
      if (!mounted) return;
      showFailMessage(context, 'Load failed', 'Unable to load data');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePlates() async {
    setState(() => _saving = true);

    // ดึง appState ด้วย context ก่อน await ใด ๆ เพื่อเลี่ยง lint
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      // ===== โหมดแก้ไข =====
      if (widget.isEdit &&
          widget.locationLicense != null &&
          widget.initialLocation != null) {
        final currentLocationId = widget.initialLocation!.id;
        final currentLocationLicense = widget.locationLicense!;

        // UPDATE
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

        // INSERT ใหม่
        final newcomers = _rows
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
        if (newcomers.isNotEmpty) {
          await supa
              .from('license_plate')
              .insert(newcomers)
              .select('license_id');
        }

        // DELETE
        if (_deletedIds.isNotEmpty) {
          await supa
              .from('license_plate')
              .delete()
              .inFilter('license_id', _deletedIds);
        }

        // UPDATE locations ถ้ามีข้อมูลมา
        if (widget.locationData != null) {
          await supa
              .from('locations')
              .update(widget.locationData!)
              .eq('location_id', currentLocationId)
              .select('location_id');
        }
      }
      // ===== โหมดสร้างใหม่ (ให้ trigger gen location_license) =====
      else if (widget.locationData != null) {
        final newLocationId = uuid.v4();

        final locRow = {...widget.locationData!, 'location_id': newLocationId}
          ..remove('location_license');
        await supa.from('locations').insert(locRow);

        final licRes = await supa
            .from('locations')
            .select('location_license')
            .eq('location_id', newLocationId)
            .maybeSingle();

        final locationLicense = licRes?['location_license'] as String?;
        if (locationLicense == null) {
          throw Exception('ไม่พบ location_license (trigger ไม่ทำงาน?)');
        }

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
      // ===== เพิ่มป้ายใน location ที่มีอยู่ =====
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

      // รีโหลด state (ไม่ใช้ context เพิ่ม)
      await appState.loadLocations(appState.loggedInEmail);

      if (!mounted) return;
      final rootCtx = Navigator.of(context, rootNavigator: true).context;
      showSuccessMessage(rootCtx, 'Changes saved successfully!');

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showFailMessage(context, 'Save failed', 'Could not add license_plate');
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRow() => setState(() => _rows.add(_PlateRowData()));

  void _removeRow(int index) {
    if (_rows.length == 1) {
      showFailMessage(context, 'Cannot delete', 'At least 1 row is required');
      return;
    }
    final removed = _rows.removeAt(index);
    if (removed.licenseId != null) _deletedIds.add(removed.licenseId!);
    setState(() {});
  }

  // ===================== Widget หลัก =====================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: Color(0xFF2563EB),
            secondary: Color(0xFF2563EB),
          ),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
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

                        // ==== ปุ่มอัพโหลด Excel ====
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result =
                                await showDialog<List<Map<String, String>>>(
                                  context: context,
                                  builder: (_) => const ExcelImportDialog(),
                                );

                            if (result != null &&
                                result.isNotEmpty &&
                                mounted) {
                              setState(() {
                                _rows.addAll(
                                  result.map(
                                    (m) => _PlateRowData(
                                      licenseText: TextEditingController(
                                        text: m['license_text'] ?? '',
                                      ),
                                      licenseLocal: TextEditingController(
                                        text: m['license_local'] ?? '',
                                      ),
                                      carOwner: TextEditingController(
                                        text: m['car_owner'] ?? '',
                                      ),
                                      note: TextEditingController(
                                        text: m['note'] ?? '',
                                      ),
                                    ),
                                  ),
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Excel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(
                              0xFF217346,
                            ), // ตัวอักษร + ไอคอน
                            side: const BorderSide(
                              color: Color(0xFF217346),
                            ), // เส้นขอบ
                          ),
                        ),

                        const SizedBox(width: 8),

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

                    // Rows
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(_rows.length, (i) {
                            return _PlateNumberRow(
                              displayIndex: i + 1,
                              data: _rows[i],
                              onRemove: () => _removeRow(i),
                              onChanged: () => setState(() {}),
                            );
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF2563EB),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ButtonStyle(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(vertical: 16),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              foregroundColor: const WidgetStatePropertyAll(
                                Colors.red,
                              ),
                              side: const WidgetStatePropertyAll(
                                BorderSide(color: Colors.red),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),

                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF2563EB),
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

// ===================== Widget ย่อย =====================
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

  void dispose() {
    licenseText.dispose();
    licenseLocal.dispose();
    carOwner.dispose();
    note.dispose();
  }
}

class _PlateNumberRow extends StatelessWidget {
  final int displayIndex;
  final _PlateRowData data;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _PlateNumberRow({
    required this.displayIndex,
    required this.data,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          // ใช้ค่า radius ตรง ๆ กันเคสชื่อหาย
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

            // ปุ่มล่างสุด
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
