import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/location.dart';
import '../../providers/app_state.dart';
import '../snackbar/fail_snackbar.dart';
import '../snackbar/success_snackbar.dart';

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
  Color _selectedColor = Colors.blue;

  final List<Color> _colorOptions = [
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
    }
  }

  bool _canSave() {
    return _nameController.text.isNotEmpty &&
        _addressController.text.isNotEmpty;
  }

  void _handleSave() async {
    final appState = context.read<AppState>();
    final isEdit = widget.initialLocation != null;

    final locationData = {
      "name": _nameController.text,
      "address": _addressController.text,
      "color": '0x${_selectedColor.value.toRadixString(16).toUpperCase()}',
      "description":
          _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      "owner_email": appState.loggedInEmail,
      "shared_with": widget.initialLocation?.sharedWith ?? [],
    };

    final url = isEdit
        ? 'http://127.0.0.1:5000/update_location/${widget.initialLocation!.id}'
        : 'http://127.0.0.1:5000/save_locations';

    try {
      final response = await (isEdit
          ? http.put(
              Uri.parse(url),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(locationData),
            )
          : http.post(
              Uri.parse(url),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(locationData),
            ));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await appState.loadLocations(appState.loggedInEmail);
        Navigator.of(context).pop();
        showSuccessMessage(context, isEdit
            ? 'Location updated successfully!'
            : 'Location added successfully!');
      } else {
        final error = jsonDecode(response.body);
        showFailMessage(context, 'Failed', error["message"] ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        showFailMessage(context, 'Error', e.toString());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void showFailMessage(BuildContext context, String errorMessage, dynamic error) {
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
            title: errorMessage,
            message: error,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      ),
    );
  }

  void showSuccessMessage(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SuccessSnackbar(
            message: message,
            onClose: () {
              if (overlayEntry.mounted) overlayEntry.remove();
            },
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  labelText: 'Location Name',
                  hintText: 'e.g., ABC Apartment',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Full address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Additional details',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Color',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _colorOptions.map((color) {
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
                                  color: _selectedColor == color
                                      ? Colors.black45
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            if (_selectedColor == color)
                              const Icon(Icons.check, color: Colors.white, size: 24),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSave() ? _handleSave : null,
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
                        children: [
                          Icon(Icons.save, size: 16),
                          SizedBox(width: 8),
                          Text('Save'),
                        ],
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
