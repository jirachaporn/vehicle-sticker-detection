import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';

class LogsTab extends StatelessWidget {
  final String locationId;

  const LogsTab({super.key, required this.locationId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PermissionProvider>();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.loadLogs(locationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snap.data!;
        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No activity logs available",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        // Sort logs by date (newest to oldest)
        logs.sort((a, b) {
          final aTs =
              DateTime.tryParse(a['created_at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTs =
              DateTime.tryParse(b['created_at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTs.compareTo(aTs); // From newest to oldest
        });

        return Column(
          children: [
            // Header with reload button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.history, color: Colors.blue.shade600),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Membership Logs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total ${logs.length} entries',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      provider.loadLogs(locationId); // Reload logs on press
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Content
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    final email = log['member_email'] ?? '';
                    final name = log['member_name'];
                    final permission = log['permission'] ?? '';
                    final status = log['status'] ?? '';
                    final createdAt = log['created_at'] != null
                        ? DateTime.tryParse(log['created_at'])
                        : null;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                status,
                              ).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Member Info - better organized
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      name ?? 'No name',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getStatusText(status, permission),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Right side - permission and time
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Permission badge - simpler
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  permission,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatTime(createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'invited':
        return Colors.blue;
      case 'updatepermission':
        return Colors.orange;
      case 'disabled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'invited':
        return Icons.mail_outline;
      case 'updatepermission':
        return Icons.edit_outlined;
      case 'disabled':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status, String permission) {
    final permissionText = _getPermissionText(permission);

    switch (status) {
      case 'invited':
        return 'Invited with permission $permissionText';
      case 'updatepermission':
        return 'Changed permission to $permissionText';
      case 'disabled':
        return 'Account disabled';
      default:
        return 'Unknown';
    }
  }

  String _getPermissionText(String permission) {
    switch (permission.toLowerCase()) {
      case 'edit':
        return 'Edit';
      case 'view':
        return 'View';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      default:
        return permission;
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('dd/MM/yy').format(dt);
    }
  }
}
