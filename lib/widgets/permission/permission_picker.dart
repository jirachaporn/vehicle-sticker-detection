import 'package:flutter/material.dart';
import '../../models/permission.dart';

class PermissionPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const PermissionPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'สิทธิ์ที่ให้ *',
        prefixIcon: Icon(Icons.security_outlined),
      ),
      items: const [
        DropdownMenuItem(
          value: PermissionType.view,
          child: Text('Viewer (ดูอย่างเดียว)'),
        ),
        DropdownMenuItem(
          value: PermissionType.edit,
          child: Text('Editor (ดู+แก้ไข/อัปโหลด)'),
        ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
