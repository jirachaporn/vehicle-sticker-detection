// lib/widgets/permission/members_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';
import '../../models/permission.dart';

class MembersTab extends StatefulWidget {
  final String locationId;
  final Future<void> Function()? onChanged;

  const MembersTab({super.key, required this.locationId, this.onChanged});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  bool loading = false;

  Future<void> _refresh(PermissionProvider p) async {
    setState(() => loading = true);
    try {
      await p.loadMembers(widget.locationId);
      if (widget.onChanged != null) await widget.onChanged!();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PermissionProvider>();

    return FutureBuilder<List<PermissionMember>>(
      future: p.loadMembers(widget.locationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = [...snap.data!];
        members.sort((a, b) {
          int rank(MemberStatus s) {
            switch (s) {
              case MemberStatus.confirmed:
                return 0;
              case MemberStatus.invited:
              case MemberStatus.pending:
                return 1;
              case MemberStatus.disabled:
              case MemberStatus.expired:
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

          final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Text(
                    'สมาชิกทั้งหมด (${members.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'รีเฟรช',
                    onPressed: loading ? null : () => _refresh(p),
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: members.isEmpty
                  ? const Center(child: Text('ยังไม่มีสมาชิก'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: members.length,
                      itemBuilder: (context, i) {
                        final m = members[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    (m.email.isNotEmpty ? m.email[0] : '?')
                                        .toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('ชื่อ: ${m.name ?? "-"}'),
                                      const SizedBox(height: 2),
                                      Text(
                                        'สถานะ: ${m.status.label} • เวลา: ${_fmt(m.createdAt)}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // เปลี่ยนสิทธิ์แบบง่าย ๆ
                                DropdownButton<PermissionType>(
                                  value: m.permission,
                                  onChanged: (val) async {
                                    if (val == null) return;
                                    try {
                                      await p.upsertMember(
                                        locationId: widget.locationId,
                                        email: m.email,
                                        name: m.name,
                                        permission: val,
                                        status: m.status, // คงสถานะเดิม
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'อัปเดตสิทธิ์ ${m.email} เป็น ${val.label} แล้ว',
                                          ),
                                        ),
                                      );
                                      await _refresh(p);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'อัปเดตสิทธิ์ไม่สำเร็จ: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  items: PermissionType.values
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t.label),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(width: 8),
                                // ปุ่มสถานะง่าย ๆ (ตามสถานะปัจจุบัน)
                                _StatusButtons(
                                  status: m.status,
                                  onTap: (newStatus) async {
                                    try {
                                      await p.upsertMember(
                                        locationId: widget.locationId,
                                        email: m.email,
                                        name: m.name,
                                        permission: m.permission,
                                        status: newStatus,
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'อัปเดตสถานะ ${m.email} เป็น ${newStatus.label} แล้ว',
                                          ),
                                        ),
                                      );
                                      await _refresh(p);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'เปลี่ยนสถานะไม่สำเร็จ: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
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
}

class _StatusButtons extends StatelessWidget {
  final MemberStatus status;
  final ValueChanged<MemberStatus> onTap;

  const _StatusButtons({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    List<Widget> buttons;

    switch (status) {
      case MemberStatus.pending:
      case MemberStatus.invited:
        buttons = [
          TextButton(
            onPressed: () => onTap(MemberStatus.confirmed),
            child: const Text('ยืนยัน'),
          ),
          TextButton(
            onPressed: () => onTap(MemberStatus.revoked),
            child: const Text('เพิกถอน'),
          ),
        ];
        break;

      case MemberStatus.confirmed:
        buttons = [
          TextButton(
            onPressed: () => onTap(MemberStatus.disabled),
            child: const Text('ปิดใช้งาน'),
          ),
          TextButton(
            onPressed: () => onTap(MemberStatus.left),
            child: const Text('นำออก'),
          ),
        ];
        break;

      case MemberStatus.disabled:
        buttons = [
          TextButton(
            onPressed: () => onTap(MemberStatus.confirmed),
            child: const Text('เปิดใช้งาน'),
          ),
          TextButton(
            onPressed: () => onTap(MemberStatus.left),
            child: const Text('นำออก'),
          ),
        ];
        break;

      case MemberStatus.expired:
        buttons = [
          TextButton(
            onPressed: () => onTap(MemberStatus.confirmed),
            child: const Text('ทำเป็นยืนยันแล้ว'),
          ),
          TextButton(
            onPressed: () => onTap(MemberStatus.left),
            child: const Text('นำออก'),
          ),
        ];
        break;

      case MemberStatus.revoked:
      case MemberStatus.left:
      case MemberStatus.unknown:
        buttons = [
          TextButton(
            onPressed: () => onTap(MemberStatus.left),
            child: const Text('ลบจากรายการ'),
          ),
        ];
        break;
    }

    return Row(children: buttons);
  }
}
