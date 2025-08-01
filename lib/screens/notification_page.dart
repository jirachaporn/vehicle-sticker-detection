import 'package:flutter/material.dart';
import '../models/notification.dart';

class NotificationPage extends StatefulWidget {
   final String locationId;
  const NotificationPage({super.key, required this.locationId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationItem> notifications = [
    NotificationItem(
      title: 'Unauthorized Vehicle Detected',
      description:
          'Vehicle with license plate XYZ-789 detected in restricted area',
      timeAgo: '2 minutes ago',
      location: 'Zone A - Gate 1',
      icon: Icons.warning_amber_rounded,
      color: Colors.orange,
      unread: true,
    ),
    NotificationItem(
      title: 'Vehicle Registration Complete',
      description: 'New vehicle ABC-123 successfully registered in the system',
      timeAgo: '15 minutes ago',
      location: 'Zone B - Registration',
      icon: Icons.check_circle_outline,
      color: Colors.green,
      unread: true,
    ),
    NotificationItem(
      title: 'System Maintenance Scheduled',
      description: 'Routine maintenance scheduled for tonight at 2:00 AM',
      timeAgo: '1 hour ago',
      location: 'System Wide',
      icon: Icons.info_outline,
      color: Colors.blue,
      unread: false,
    ),
    NotificationItem(
      title: 'Camera Offline',
      description: 'Camera CAM-05 in Zone C has gone offline',
      timeAgo: '2 hours ago',
      location: 'Zone C',
      icon: Icons.warning_amber_rounded,
      color: Colors.red,
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadList = notifications.where((n) => n.unread).toList();
    final readList = notifications.where((n) => !n.unread).toList();

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
                  alignment: Alignment.topRight,
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(
                        Icons.notifications,
                        size: 32,
                        color: Colors.black54,
                      ),
                    ),
                    if (unreadList.isNotEmpty)
                      const Positioned(
                        right: 12,
                        top: 12,
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: Colors.red,
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
            if (unreadList.isNotEmpty) ...[
              const Text(
                'New',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (var item in unreadList) _buildNotificationCard(item),
            ],
            if (readList.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Read',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              for (var item in readList) _buildNotificationCard(item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    return _HoverableNotificationCard(
      item: item,
      onDelete: () => _confirmDelete(item),
      onTap: () => _showDetailsDialog(item),
    );
  }

  void _showDetailsDialog(NotificationItem item) {
    if (item.unread) {
      setState(() {
        final index = notifications.indexOf(item);
        if (index != -1) {
          notifications[index] = NotificationItem(
            title: item.title,
            description: item.description,
            timeAgo: item.timeAgo,
            location: item.location,
            icon: item.icon,
            color: item.color,
            unread: false,
          );
        }
      });
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
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
                const SizedBox(height: 20),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailItem(Icons.location_on, item.location),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.access_time, item.timeAgo),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFFC62828),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  void _confirmDelete(NotificationItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this notification? This action is permanent.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: Colors.grey),
              foregroundColor: Colors.black,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => notifications.remove(item));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 16),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableNotificationCard extends StatefulWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HoverableNotificationCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  State<_HoverableNotificationCard> createState() =>
      _HoverableNotificationCardState();
}

class _HoverableNotificationCardState
    extends State<_HoverableNotificationCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: isHovered ? Colors.grey.shade50 : Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isHovered ? 0.08 : 0.03),
                blurRadius: isHovered ? 12 : 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 32, color: item.color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (item.unread)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                        IconButton(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.timeAgo}    Location: ${item.location}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
