// lib/widgets/permission/members_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';
import '../../models/permission.dart';
import '../snackbar/fail_snackbar.dart';
import '../snackbar/success_snackbar.dart';

/// ===== Snackbar helpers (ต้องรับ BuildContext) =====
void showFailMessage(BuildContext context, String title, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      elevation: 20,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: const Duration(seconds: 3),
      padding: EdgeInsets.zero,
      content: Align(
        alignment: Alignment.topRight,
        child: FailSnackbar(
          title: title,
          message: message,
          onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    ),
  );
}

void showSuccessMessage(BuildContext context, String message) {
  final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 90,
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          child: SuccessSnackbar(
            message: message,
            onClose: () => overlayEntry.remove(),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
}

/// ===== ปุ่มสถานะ =====
/// NOTE: enum เดิมไม่มี `disabled` ดังนั้นใช้ `revoked` แทน “ปิดใช้งาน”
class StatusButtons extends StatelessWidget {
  final MemberStatus status;
  final ValueChanged<MemberStatus> onTap;

  const StatusButtons({super.key, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    List<Widget> buttons;

    if (status == MemberStatus.invited || status == MemberStatus.invited) {
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
    } else if (status == MemberStatus.confirmed) {
      buttons = [
        TextButton(
          onPressed: () => onTap(MemberStatus.revoked), // เดิม: disabled
          child: const Text('ปิดใช้งาน'),
        ),
        TextButton(
          onPressed: () => onTap(MemberStatus.left),
          child: const Text('นำออก'),
        ),
      ];
    } else if (status == MemberStatus.revoked) {
      // เดิม: disabled
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
    } else if (status == MemberStatus.expired) {
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
    } else {
      buttons = [
        TextButton(
          onPressed: () => onTap(MemberStatus.left),
          child: const Text('ลบจากรายการ'),
        ),
      ];
    }

    return Row(children: buttons);
  }
}

/// ===== Card ที่มี hover effect =====
class HoverCard extends StatefulWidget {
  final Widget child;

  const HoverCard({super.key, required this.child});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              // แทนที่ withOpacity ที่ deprecated ด้วย withAlpha
              color: Colors.grey.withAlpha(
                ((isHovered ? 0.30 : 0.10) * 255).round(),
              ),
              blurRadius: isHovered ? 10 : 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// ===== Main Tab =====
class MembersTab extends StatefulWidget {
  final String locationId;
  final Future<void> Function()? onChanged;

  const MembersTab({super.key, required this.locationId, this.onChanged});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  bool loading = false;

  String formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      // เก็บ reference ก่อน async gap (หลีกเลี่ยงใช้ context หลัง await แบบไม่ guard)
      final provider = Provider.of<PermissionProvider>(context, listen: false);
      await provider.loadMembers(widget.locationId);
      if (widget.onChanged != null) {
        await widget.onChanged!.call();
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PermissionProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<PermissionMember>>(
        future: provider.loadMembers(widget.locationId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          final members = [...snapshot.data!]; // clone กัน side-effect
          // เรียงลำดับ members
          members.sort((a, b) {
            int getStatusPriority(MemberStatus s) {
              switch (s) {
                case MemberStatus.confirmed:
                  return 1;
                case MemberStatus.invited:
                  return 2;
                case MemberStatus.revoked:
                case MemberStatus.expired:
                  return 3;
                default:
                  return 4;
              }
            }

            final statusCompare =
                getStatusPriority(a.status) - getStatusPriority(b.status);
            if (statusCompare != 0) return statusCompare;

            final aDate = a.createdAt ?? DateTime(2000);
            final bDate = b.createdAt ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });

          return Column(
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Members (${members.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: loading ? null : refresh,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // List
              Expanded(
                child: members.isEmpty
                    ? const Center(child: Text('ไม่มีสมาชิก'))
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: HoverCard(
                              child: Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.blue.withAlpha(
                                      (0.15 * 255).round(),
                                    ),
                                    child: Text(
                                      member.email.isNotEmpty
                                          ? member.email[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // ข้อมูลสมาชิก
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.email,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text('ชื่อ: ${member.name ?? "-"}'),
                                        Text(
                                          'สถานะ: ${member.status.label} • ${formatDate(member.createdAt)}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Dropdown สิทธิ์
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withAlpha(
                                        (0.08 * 255).round(),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButton<PermissionType>(
                                      value: member.permission,
                                      underline: const SizedBox(),
                                      onChanged: (newPermission) async {
                                        if (newPermission == null) return;

                                        try {
                                          final sup =
                                              Provider.of<PermissionProvider>(
                                                context,
                                                listen: false,
                                              );
                                          await sup.upsertMember(
                                            locationId: widget.locationId,
                                            email: member.email,
                                            name: member.name,
                                            permission: newPermission,
                                            status: member.status,
                                          );
                                          if (!mounted) return;
                                          showSuccessMessage(
                                            context,
                                            'อัปเดตสิทธิ์เรียบร้อย',
                                          );
                                          await refresh();
                                        } catch (e) {
                                          if (!mounted) return;
                                          showFailMessage(
                                            context,
                                            'เกิดข้อผิดพลาด',
                                            e.toString(),
                                          );
                                        }
                                      },
                                      items: PermissionType.values
                                          .map(
                                            (type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type.label),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // ปุ่มสถานะ
                                  StatusButtons(
                                    status: member.status,
                                    onTap: (newStatus) async {
                                      try {
                                        final sup =
                                            Provider.of<PermissionProvider>(
                                              context,
                                              listen: false,
                                            );
                                        await sup.upsertMember(
                                          locationId: widget.locationId,
                                          email: member.email,
                                          name: member.name,
                                          permission: member.permission,
                                          status: newStatus,
                                        );
                                        if (!mounted) return;
                                        showSuccessMessage(
                                          context,
                                          'เปลี่ยนสถานะเรียบร้อย',
                                        );
                                        await refresh();
                                      } catch (e) {
                                        if (!mounted) return;
                                        showFailMessage(
                                          context,
                                          'เกิดข้อผิดพลาด',
                                          e.toString(),
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
      ),
    );
  }
}
