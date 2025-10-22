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

        // sort by status + date
        logs.sort((a, b) {
          int rank(String status) {
            switch (status) {
              case 'invited':
                return 0;
              case 'confirmed':
                return 1;
              case 'expired':
              case 'disabled':
                return 2;
              case 'revoked':
              case 'left':
                return 3;
              default:
                return 9;
            }
          }

          final r = rank(a['status'] ?? '') - rank(b['status'] ?? '');
          if (r != 0) return r;

          final aTs =
              DateTime.tryParse(a['created_at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTs =
              DateTime.tryParse(b['created_at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTs.compareTo(aTs);
        });

        return Column(
          children: [
            // Header
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
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Content
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Tooltip(
                            message: status,
                            child: buildStatusDot(status),
                          ),
                          const SizedBox(width: 16),

                          // Member Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      name ?? '-',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Permission badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              permission,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Timestamp
                          Text(
                            fmt(createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
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

  Widget buildStatusDot(String status, {double size = 12}) {
    Color color;
    switch (status) {
      case 'invited':
        color = Colors.amber;
        break;
      case 'confirmed':
        color = Colors.green;
        break;
      case 'expired':
        color = Colors.grey;
        break;
      case 'revoked':
      case 'left':
        color = Colors.red;
        break;
      case 'disabled':
        color = Colors.black45;
        break;
      default:
        color = Colors.blueGrey;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .15),
        border: Border.all(color: color, width: 2),
      ),
    );
  }

  String fmt(DateTime? dt) {
    if (dt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return DateFormat('hh:mm a').format(dt);
    } else if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(dt)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago ${DateFormat('HH:mm').format(dt)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    }
  }
}
