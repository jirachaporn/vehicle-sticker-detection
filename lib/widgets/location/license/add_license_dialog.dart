// lib/widgets/location/license/add_license_dialog.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/location.dart';
import '../../../providers/app_state.dart';
import '../../../providers/snackbar_func.dart';
import 'excel_import_dialog.dart';
import '../license/plate_row.dart';

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

class _AddLicenseDialogState extends State<AddLicenseDialog> {
  final supa = Supabase.instance.client;
  final uuid = const Uuid();

  List<PlateRowData> _rows = <PlateRowData>[PlateRowData()];
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
          ..add(PlateRowData());
        return;
      }

      final data = await supa
          .from('license_plate')
          .select(
            'license_id, license_text, license_local, car_owner, note, on_license',
          )
          .eq('location_license', key)
          .order('on_license', ascending: true);

      final list = (data as List).cast<Map<String, dynamic>>();
      _rows
        ..clear()
        ..addAll(
          list.isEmpty
              ? [PlateRowData()]
              : list.map((m) => PlateRowData.fromMap(m)),
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
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      if (widget.isEdit &&
          widget.locationLicense != null &&
          widget.initialLocation != null) {
        final currentLocationId = widget.initialLocation!.id;
        final currentLocationLicense = widget.locationLicense!;

        // UPDATE แถวเก่า
        for (final r in _rows.where((e) => e.licenseId != null)) {
          await supa
              .from('license_plate')
              .update({
                'location_license': currentLocationLicense,
                'license_text': r.licenseText.text.trim(),
                'license_local': r.licenseLocal.text.trim(),
                'car_owner': r.carOwner.text.trim(),
                'note': r.note.text.trim().isEmpty ? null : r.note.text.trim(),
                'on_license': r.onLicense,
              })
              .eq('license_id', r.licenseId!)
              .select('license_id');
        }

        // INSERT แถวใหม่
        final newcomersRows = _rows.where((e) => e.licenseId == null).toList();
        if (newcomersRows.isNotEmpty) {
          final newcomers = newcomersRows
              .map(
                (r) => {
                  'location_license': currentLocationLicense,
                  'license_text': r.licenseText.text.trim(),
                  'license_local': r.licenseLocal.text.trim(),
                  'car_owner': r.carOwner.text.trim(),
                  'note': r.note.text.trim().isEmpty
                      ? null
                      : r.note.text.trim(),
                  'on_license': r.onLicense,
                },
              )
              .toList();
          await supa
              .from('license_plate')
              .insert(newcomers)
              .select('license_id');
        }

        // DELETE แถวที่ถูกลบ
        if (_deletedIds.isNotEmpty) {
          await supa
              .from('license_plate')
              .delete()
              .inFilter('license_id', _deletedIds);
        }

        // UPDATE location ถ้ามี
        if (widget.locationData != null) {
          await supa
              .from('locations')
              .update(widget.locationData!)
              .eq('location_id', currentLocationId)
              .select('location_id');
        }
      }
      // สร้าง location ใหม่
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
        if (locationLicense == null) throw Exception('ไม่พบ location_license');

        final plateRows = _rows.map((r) {
          return {
            'location_license': locationLicense,
            'license_text': r.licenseText.text.trim(),
            'license_local': r.licenseLocal.text.trim(),
            'car_owner': r.carOwner.text.trim(),
            'note': r.note.text.trim().isEmpty ? null : r.note.text.trim(),
            'on_license': r.onLicense,
          };
        }).toList();

        if (plateRows.isNotEmpty) {
          await supa.from('license_plate').insert(plateRows);
        }
      }
      // เพิ่มป้ายใน location ที่มีอยู่
      else if (!widget.isEdit && widget.locationLicense != null) {
        final currentLocationLicense = widget.locationLicense!;
        final plateRows = _rows.map((r) {
          return {
            'location_license': currentLocationLicense,
            'license_text': r.licenseText.text.trim(),
            'license_local': r.licenseLocal.text.trim(),
            'car_owner': r.carOwner.text.trim(),
            'note': r.note.text.trim().isEmpty ? null : r.note.text.trim(),
            'on_license': r.onLicense,
          };
        }).toList();

        if (plateRows.isNotEmpty) {
          await supa.from('license_plate').insert(plateRows);
        }
      }

      await appState.loadLocations(appState.loggedInEmail);

      if (!mounted) return;
      final rootCtx = Navigator.of(context, rootNavigator: true).context;
      showSuccessMessage(rootCtx, 'Changes saved successfully!');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showFailMessage(context, 'Save failed', 'Could not add license_plate');
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRow() {
    setState(() {
      final maxOnLicense = _rows.isEmpty
          ? 0
          : _rows.map((r) => r.onLicense).reduce((a, b) => a > b ? a : b);
      _rows.add(PlateRowData(onLicense: maxOnLicense + 1));
    });
  }

  void _removeRow(int index) {
    if (_rows.length == 1) {
      showFailMessage(context, 'Cannot delete', 'At least 1 row is required');
      return;
    }
    final removed = _rows.removeAt(index);
    if (removed.licenseId != null) _deletedIds.add(removed.licenseId!);

    // ปรับเลข onLicense ใหม่เรียงต่อเนื่อง
    for (int i = 0; i < _rows.length; i++) {
      _rows[i].onLicense = i + 1;
    }

    setState(() {});
  }

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
            primary: const Color(0xFF2563EB),
            secondary: const Color(0xFF2563EB),
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
                                final maxOnLicense = _rows.isEmpty
                                    ? 0
                                    : _rows
                                          .map((r) => r.onLicense)
                                          .reduce((a, b) => a > b ? a : b);

                                if (_rows.isEmpty ||
                                    _rows.every(
                                      (r) =>
                                          r.licenseText.text.isEmpty &&
                                          r.licenseLocal.text.isEmpty &&
                                          r.carOwner.text.isEmpty &&
                                          r.note.text.isEmpty,
                                    )) {
                                  int nextLicense = 1;
                                  _rows = result
                                      .map(
                                        (m) => PlateRowData(
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
                                          onLicense: nextLicense++,
                                        ),
                                      )
                                      .toList();
                                } else {
                                  int nextLicense = maxOnLicense + 1;
                                  _rows.addAll(
                                    result.map(
                                      (m) => PlateRowData(
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
                                        onLicense: nextLicense++,
                                      ),
                                    ),
                                  );
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Excel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF217346),
                            side: const BorderSide(color: Color(0xFF217346)),
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
                            final row = _rows[i];
                            return PlateRow(
                              displayIndex: row.onLicense,
                              data: row,
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
                          foregroundColor: const Color(0xFF2563EB),
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
                              shape: const WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
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
                              backgroundColor: const Color(0xFF2563EB),
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
