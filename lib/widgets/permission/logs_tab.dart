// lib/widgets/permission/logs_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';
import '../../models/permission.dart';

import 'empty_state.dart';
import 'status_dot.dart';

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
      // เดิม fetchMembers(...) -> ใช้ loadMembers(...)
      future: p.loadMembers(locationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snap.data!;
        final sorted = [...members]..sort((a, b) {
          int rank(MemberStatus s) {
            switch (s) {
              case MemberStatus.invited:
                return 0;
              case MemberStatus.confirmed:
                return 1;
              case MemberStatus.expired:
              case MemberStatus.disabled: // ✅ รองรับ disabled
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'สถานะสมาชิก/คำเชิญ (${sorted.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExpireSweep,
                    icon: const Icon(Icons.schedule),
                    label: const Text('เช็คคำเชิญที่หมดอายุ'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (sorted.isEmpty)
              const Expanded(
                child: EmptyState(
                  icon: Icons.event_note,
                  title: 'ยังไม่มีข้อมูลสมาชิก',
                  message: 'เมื่อมีการเชิญ/ยืนยัน/เพิกถอนจะแสดงที่นี่',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = sorted[i];
                    final permStr = m.permission.label; // owner/edit/view

                    // เดิม when = m.updatedAt ?? m.createdAt;
                    // ตอนนี้โมเดลมีแค่ createdAt -> ใช้ createdAt ไปก่อน
                    final when = m.createdAt;
                    final whenStr = _fmt(when);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: _statusBorderColor(m.status)),
                      ),
                      child: ListTile(
                        leading: StatusDot(status: m.status),
                        title: Text('${m.email} • $permStr'),
                        subtitle: Text(_subtitleFor(m, whenStr)),
                        trailing: Text(
                          whenStr,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  String _subtitleFor(PermissionMember m, String whenStr) {
    switch (m.status) {
      case MemberStatus.invited:
        return 'สถานะ: รอการยืนยัน • ชื่อ: ${m.name ?? "-"} • สร้างเมื่อ: $whenStr';
      case MemberStatus.confirmed:
        return 'สถานะ: ยืนยันแล้ว • ชื่อ: ${m.name ?? "-"} • อัปเดตล่าสุด: $whenStr';
      case MemberStatus.expired:
        return 'สถานะ: หมดอายุ • ชื่อ: ${m.name ?? "-"} • เวลา: $whenStr';
      case MemberStatus.disabled: // ✅ ใหม่
        return 'สถานะ: ปิดการใช้งาน • ชื่อ: ${m.name ?? "-"} • เวลา: $whenStr';
      case MemberStatus.revoked:
        return 'สถานะ: เพิกถอนแล้ว • ชื่อ: ${m.name ?? "-"} • เวลา: $whenStr';
      case MemberStatus.left:
        return 'สถานะ: ออกจากกลุ่มแล้ว • ชื่อ: ${m.name ?? "-"} • เวลา: $whenStr';
      case MemberStatus.unknown:
        return 'สถานะ: ไม่ทราบ • ชื่อ: ${m.name ?? "-"} • เวลา: $whenStr';
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  static Color _statusBorderColor(MemberStatus status) {
    switch (status) {
      case MemberStatus.invited:
        return Colors.amber.shade200;
      case MemberStatus.confirmed:
        return Colors.green.shade200;
      case MemberStatus.expired:
      case MemberStatus.disabled: // ✅ ใหม่
        return Colors.grey.shade300;
      case MemberStatus.revoked:
      case MemberStatus.left:
        return Colors.red.shade200;
      case MemberStatus.unknown:
        return Colors.grey.shade200;
    }
  }
}
