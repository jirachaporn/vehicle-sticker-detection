import 'package:flutter/material.dart';
import '../../models/permission.dart';

class PermChip extends StatelessWidget {
  final String permission;
  final bool compact;
  const PermChip({super.key, required this.permission, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isEdit = permission == PermissionType.edit;

    return Chip(
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      label: Text(
        isEdit ? 'Editor' : 'Viewer',
        style: TextStyle(
          color: isEdit ? Colors.white : Colors.blueGrey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: isEdit ? Colors.blue : Colors.blueGrey.shade100,
      avatar: Icon(
        isEdit ? Icons.edit : Icons.visibility,
        size: compact ? 16 : 18,
        color: isEdit ? Colors.white : Colors.black54,
      ),
      side: BorderSide(
        color: isEdit ? Colors.blue : Colors.blueGrey.shade200,
      ),
    );
  }
}
