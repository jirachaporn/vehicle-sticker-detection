// lib/widgets/permission/logs_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';
import '../../models/permission.dart';

class LogsTab extends StatelessWidget {
  final String locationId;
  final Future<void> Function() onExpireSweep;

  const LogsTab({
    super.key,
    required this.locationId,
    required this.onExpireSweep,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PermissionProvider>();

    return FutureBuilder<List<PermissionMember>>(
      future: p.loadMembers(locationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snap.data!;
        final sorted = [...members]
          ..sort((a, b) {
            int rank(MemberStatus s) {
              switch (s) {
                case MemberStatus.invited:
                  return 0;
                case MemberStatus.confirmed:
                  return 1;
                case MemberStatus.expired:
                case MemberStatus.disabled:
                  return 2;
                case MemberStatus.revoked:
                case MemberStatus.left:
                  return 3;
                case MemberStatus.unknown:
                  return 9;
              }
            }

            final r = rank(a.status) - rank(b.status);
            if (r != 0) return r;
            final aTs = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTs = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTs.compareTo(aTs);
          });

        return Column(
          children: [
            // Header Section
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
                    child: Icon(
                      Icons.history,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Membership Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total ${sorted.length}',
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

            // Content Section
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final m = sorted[i];
                    final permStr = m.permission.label;
                    final when = m.createdAt;
                    final whenStr = fmt(when);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Status Dot
                            buildStatusDot(m.status),
                            const SizedBox(width: 16),

                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Email
                                  Text(
                                    m.email,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Details Row
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      // Name
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'name',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.person_outline,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            m.name ?? '-',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Permission Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                permStr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Timestamp
                            Text(
                              whenStr,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
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

  Widget buildStatusDot(MemberStatus status, {double size = 12}) {
    // กำหนดสีตามสถานะ
    Color color;
    switch (status) {
      case MemberStatus.invited:
        color = Colors.amber;
        break;
      case MemberStatus.confirmed:
        color = Colors.green;
        break;
      case MemberStatus.expired:
        color = Colors.grey;
        break;
      case MemberStatus.revoked:
      case MemberStatus.left:
        color = Colors.red;
        break;
      case MemberStatus.disabled:
        color = Colors.black45;
        break;
      case MemberStatus.unknown:
        color = Colors.blueGrey;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2), // พื้นหลังอ่อน
        border: Border.all(color: color, width: 2),
      ),
    );
  }

  String fmt(DateTime? dt) {
    if (dt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  }
}
