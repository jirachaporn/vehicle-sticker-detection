import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../providers/permission_provider.dart';

class NotificationCard extends StatefulWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NotificationCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool isHovered = false;

  // ฟังก์ชั่นที่ใช้เช็คสิทธิ์ใน AppState
  bool _isAdmin = false;
  bool _canEdit = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    // ตรวจสอบสิทธิ์จาก AppState และ PermissionProvider
    final appState = context.read<AppState>();
    final permProvider = context.read<PermissionProvider>();

    setState(() {
      _isAdmin = appState.isAdmin; // เช็คสิทธิ์ admin
      _canEdit = appState.canEditWith(permProvider); // เช็คสิทธิ์ edit
      _isOwner = appState.isOwnerWith(permProvider); // เช็คสิทธิ์ owner
    });
  }

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
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isHovered ? 0.1 : 0.05),
                blurRadius: isHovered ? 8 : 3,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(item.icon, color: item.color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              if (_isAdmin || _isOwner || _canEdit)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
