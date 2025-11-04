import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../providers/api_service.dart';
import '../widgets/notification_dialogs/delete_dialog.dart';
import '../widgets/notification_dialogs/details_dialog.dart';
import '../widgets/notification_dialogs/notification_card.dart';
import '../providers/snackbar_func.dart';

class NotificationPage extends StatefulWidget {
  final String locationId;
  final String? locationName;
  const NotificationPage({
    super.key,
    required this.locationId,
    required this.locationName,
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationItem> notifications = [];
  bool isLoading = true;
  bool hasError = false;
  String selectedSeverity = 'All';
  final ApiService api = ApiService();

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final data = await api.fetchNotifications(widget.locationId);
      setState(() {
        notifications = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("⚠️ Error loading notifications: $e");
    }
  }

  Future<void> markAllRead() async {
    try {
      await api.markAllRead(widget.locationId);
      setState(() {
        notifications = notifications.map((n) {
          if (selectedSeverity == 'All' || n.severity == selectedSeverity) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList();
      });
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
    }
  }

  void showDeleteDialog(NotificationItem item, locationName) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        item: item,
        onDelete: () async {
          try {
            await api.deleteNotification(item.id);
            showSuccessMessage(context, 'Delete Successfully!');
            if (mounted) {
              setState(() {
                notifications.remove(item);
              });
            }
          } catch (e) {
            debugPrint("Error deleting notification: $e");
          }
        },
      ),
    );
  }

  void showDetailsDialog(NotificationItem item) async {
    if (item.unread) {
      try {
        await api.markRead(item.id);
        setState(() {
          notifications = notifications.map((n) {
            if (n.id == item.id) {
              return n.copyWith(isRead: true);
            }
            return n;
          }).toList();
        });
      } catch (e) {
        debugPrint("Error marking notification as read: $e");
      }
      debugPrint(item.timeAgo);
    }

    await showDialog(
      context: context,
      builder: (_) =>
          DetailsDialog(item: item, locationName: widget.locationName),
    );
  }

  Widget buildNotificationCard(NotificationItem item) {
    return NotificationCard(
      item: item,
      onDelete: () => showDeleteDialog(item, widget.locationName),
      onTap: () => showDetailsDialog(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (notifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.notifications,
                  size: 32,
                  color: Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'No notifications',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    List<NotificationItem> filteredNotifications = notifications.where((n) {
      if (selectedSeverity == 'All') return true;
      return n.severity == selectedSeverity;
    }).toList();

    final unreadList = filteredNotifications.where((n) => n.unread).toList();
    final readList = filteredNotifications.where((n) => !n.unread).toList();

    return Padding(
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications, size: 32, color: Colors.black54),
                    if (unreadList.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${unreadList.length} unread notifications',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'info', 'warning', 'critical'].map((
                        severity,
                      ) {
                        final isSelected = selectedSeverity == severity;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? const Color(0xFF2563EB)
                                  : Colors.white,
                              foregroundColor: isSelected
                                  ? Colors.white
                                  : Colors.black,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedSeverity = severity;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                const SizedBox(width: 6),
                                Text(severity),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: markAllRead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Read All',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (unreadList.isNotEmpty) ...[
              const Text(
                'New',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (var item in unreadList) buildNotificationCard(item),
            ],
            if (readList.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Read',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (var item in readList) buildNotificationCard(item),
            ],
          ],
        ),
      ),
    );
  }
}
