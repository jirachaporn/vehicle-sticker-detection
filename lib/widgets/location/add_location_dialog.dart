// add_location_dialog.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/location.dart';
import 'package:uuid/uuid.dart';
import 'license/add_license_dialog.dart';

class AddLocationDialog extends StatefulWidget {
  final Location? initialLocation;

  const AddLocationDialog({super.key, this.initialLocation});

  @override
  State<AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<AddLocationDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  Color? _selectedColor;

  final uuid = const Uuid();
  final supa = Supabase.instance.client;

  final List<Color> _colorOptions = const [
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFF303F9F),
    Color(0xFFEF6C00),
    Color(0xFFAD1457),
    Color(0xFF00897B),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation;
    if (initial != null) {
      _nameController.text = initial.name;
      _addressController.text = initial.address;
      _descriptionController.text = initial.description ?? '';
      _selectedColor = initial.color;
    } else {
      _selectedColor = null;
    }
  }

  bool canSave() {
    return _nameController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty &&
        _selectedColor != null;
  }

  String toWebHex(Color c) {
    final argb = c.toARGB32();
    final rgb = (argb & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return '#$rgb';
  }

  Future<void> handleNext() async {
    if (!canSave()) return;

    final isEdit = widget.initialLocation != null;

    // เตรียมข้อมูล location (ยังไม่บันทึก)
    final locationData = {
      'location_name': _nameController.text.trim(),
      'location_address': _addressController.text.trim(),
      'location_color': toWebHex(_selectedColor!),
      'location_description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    };
    if (!mounted) return;

    Navigator.of(context).pop();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddLicenseDialog(
        locationLicense: isEdit
            ? widget.initialLocation!.location_license
            : null,
        isEdit: isEdit,
        locationData: locationData,
        initialLocation: widget.initialLocation,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialLocation != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    isEdit ? 'Edit Location' : 'Add New Location',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  label: RichText(
                    text: TextSpan(
                      text: 'Location Name',
                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      children: const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  hintText: 'e.g., ABC Apartment',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  label: RichText(
                    text: TextSpan(
                      text: 'Address',
                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      children: const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  hintText: 'Full address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  label: RichText(
                    text: TextSpan(
                      text: 'Description',
                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      children: const [
                        TextSpan(
                          text: ' (optional)',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  hintText: 'Additional details',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Color',
                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      children: const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _colorOptions.map((color) {
                      final selected = _selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? Colors.black45
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 40),

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
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canSave() ? handleNext : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2042BD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [SizedBox(width: 8), Text('Next')],
                      ),
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
