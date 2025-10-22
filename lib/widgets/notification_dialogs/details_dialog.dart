// lib/dialogs/details_dialog.dart
import 'package:flutter/material.dart';
import '../../models/notification_item.dart';

class DetailsDialog extends StatelessWidget {
  final NotificationItem item;

  const DetailsDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, color: item.color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(item.description, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            Text('location :  ${item.location}'),
            Text(
              item.timeAgo,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
