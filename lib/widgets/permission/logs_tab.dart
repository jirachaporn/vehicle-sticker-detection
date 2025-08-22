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

    return FutureBuilder<List<PermissionLog>>(
      future: p.listLogs(locationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'เหตุการณ์ล่าสุด (${logs.length})',
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
            if (logs.isEmpty)
              const Expanded(
                child: EmptyState(
                  icon: Icons.event_note,
                  title: 'ยังไม่มีประวัติ',
                  message: 'เมื่อมีการเชิญ/ยืนยัน/เพิกถอนจะแสดงที่นี่',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final lg = logs[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: _statusBorderColor(lg.status)),
                      ),
                      child: ListTile(
                        leading: StatusDot(status: lg.status),
                        title: Text('${lg.invitedEmail} • ${lg.permission}'),
                        subtitle: Text(_logSubtitle(lg)),
                        trailing: Text(
                          DateFormat('yyyy-MM-dd HH:mm')
                              .format(lg.createdAt.toLocal()),
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

  String _logSubtitle(PermissionLog l) {
    switch (l.status) {
      case PermissionLogStatus.pending:
        return 'สถานะ: รอการยืนยัน • ผู้เชิญ: ${l.invitedByEmail} • หมดอายุ: ${_fmt(l.expiredAt)}';
      case PermissionLogStatus.confirmed:
        return 'สถานะ: ยืนยันแล้ว • ผู้เชิญ: ${l.invitedByEmail} • ยืนยัน: ${_fmt(l.confirmAt)}';
      case PermissionLogStatus.expired:
        return 'สถานะ: หมดอายุ • ผู้เชิญ: ${l.invitedByEmail} • เวลา: ${_fmt(l.expiredAt)}';
      case PermissionLogStatus.disabled:
        return 'สถานะ: เพิกถอนแล้ว • ผู้เชิญ: ${l.invitedByEmail} • เวลา: ${_fmt(l.disabledAt)}';
    }
    return '';
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  static Color _statusBorderColor(String status) {
    switch (status) {
      case PermissionLogStatus.pending:
        return Colors.amber.shade200;
      case PermissionLogStatus.confirmed:
        return Colors.green.shade200;
      case PermissionLogStatus.expired:
        return Colors.grey.shade300;
      case PermissionLogStatus.disabled:
        return Colors.red.shade200;
      default:
        return Colors.grey.shade200;
    }
  }
}
