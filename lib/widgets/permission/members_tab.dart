import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';
import '../../models/permission.dart';

import 'perm_chip.dart';
import 'empty_state.dart';
import 'dialogs.dart';

class MembersTab extends StatefulWidget {
  final String locationId;
  final Future<void> Function() onChanged;
  const MembersTab({
    super.key,
    required this.locationId,
    required this.onChanged,
  });

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PermissionProvider>();

    return FutureBuilder<List<PermissionMember>>(
      future: p.listMembers(widget.locationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snap.data!;
        if (members.isEmpty) {
          return const EmptyState(
            icon: Icons.group_outlined,
            title: 'ยังไม่มีสมาชิก',
            message: 'เชิญเพื่อนร่วมทีมที่แท็บ “เพิ่มคำเชิญ”',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, i) {
            final m = members[i];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: m.status == MemberStatus.disabled
                      ? Colors.red.shade100
                      : Colors.grey.shade200,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(child: Text(_avatarText(m))),
                title: Text(
                  m.email,
                  style: TextStyle(
                    decoration: m.status == MemberStatus.disabled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(_memberSubText(m)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PermChip(permission: m.permission, compact: true),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'จัดการ',
                      onSelected: (value) => _handleAction(value, m),
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[];
                        if (m.status == MemberStatus.confirmed) {
                          if (m.permission == PermissionType.view) {
                            items.add(const PopupMenuItem(
                              value: 'to_edit',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('เปลี่ยนเป็น Editor'),
                              ),
                            ));
                          } else {
                            items.add(const PopupMenuItem(
                              value: 'to_view',
                              child: ListTile(
                                leading: Icon(Icons.visibility),
                                title: Text('เปลี่ยนเป็น Viewer'),
                              ),
                            ));
                          }
                          items.add(const PopupMenuItem(
                            value: 'revoke',
                            child: ListTile(
                              leading: Icon(Icons.block),
                              title: Text('เพิกถอนสิทธิ์'),
                            ),
                          ));
                        }
                        return items;
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: members.length,
        );
      },
    );
  }

  Future<void> _handleAction(String action, PermissionMember m) async {
    final provider = context.read<PermissionProvider>();
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (action == 'to_edit') {
        await provider.changePermission(
          locationId: widget.locationId,
          memberEmail: m.email,
          newPermission: PermissionType.edit,
        );
        if (!mounted) return;
        toast(context, 'อัปเดตสิทธิ์เป็น Editor แล้ว');
      } else if (action == 'to_view') {
        await provider.changePermission(
          locationId: widget.locationId,
          memberEmail: m.email,
          newPermission: PermissionType.view,
        );
        if (!mounted) return;
        toast(context, 'อัปเดตสิทธิ์เป็น Viewer แล้ว');
      } else if (action == 'revoke') {
        final confirm = await confirmDialog(
          context,
          title: 'เพิกถอนสิทธิ์',
          message: 'ต้องการเพิกถอนสิทธิ์ของ\n${m.email} ใช่ไหม?',
          confirmText: 'เพิกถอน',
          confirmColor: Colors.red,
        );
        if (confirm != true) return;
        await provider.revoke(
          locationId: widget.locationId,
          memberEmail: m.email,
        );
        if (!mounted) return;
        toast(context, 'เพิกถอนสิทธิ์แล้ว');
      }
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      toast(context, 'ทำไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _avatarText(PermissionMember m) {
    if ((m.name ?? '').isNotEmpty) {
      return m.name!.trim().substring(0, 1).toUpperCase();
    }
    return m.email.isNotEmpty ? m.email.substring(0, 1).toUpperCase() : '?';
  }

  String _memberSubText(PermissionMember m) {
    final created = m.invitedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(m.invitedAt!.toLocal())
        : '-';
    final confirmed = m.confirmAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(m.confirmAt!.toLocal())
        : '-';

    if (m.status == MemberStatus.disabled) {
      final disabled = m.disabledAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(m.disabledAt!.toLocal())
          : '-';
      return 'สถานะ: ปิดใช้งาน • เชิญ: $created • ปิด: $disabled';
    }
    return 'สถานะ: ยืนยันแล้ว • เชิญ: $created • ยืนยัน: $confirmed';
  }
}
