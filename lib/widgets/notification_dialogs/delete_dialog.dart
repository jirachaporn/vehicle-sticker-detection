import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../providers/api_service.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onDelete;

  const DeleteConfirmationDialog({
    super.key,
    required this.item,
    required this.onDelete,
  });

  Future<void> deleteNotification(BuildContext context, String notificationId) async {
    final api = ApiService();
    try {
      final response = await api.deleteNotification(notificationId);

      if (response) {
        onDelete();  // ลบ item จาก UI
      } else {
        throw Exception('Failed to delete notification');
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // ปิด Dialog ถ้าคำสั่งล้มเหลว
      }
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to delete notification. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 12,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon ตรงกลางด้านบน
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.red.withValues(alpha: 0.2),
              child: Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm Delete',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to delete this notification?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      deleteNotification(context, item.id);  // ลบ notification
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: const Text('Delete', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
