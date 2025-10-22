// lib/widgets/notification_dialogs/delete_dialog.dart
import 'package:flutter/material.dart';
import '../../models/notification_item.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onDelete;

  const DeleteConfirmationDialog({
    super.key,
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text('Are you sure you want to delete this notification?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onDelete();
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
