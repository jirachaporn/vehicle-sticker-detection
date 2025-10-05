// lib/widgets/permission/members_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';
import '../../models/permission.dart';
import '../snackbar/fail_snackbar.dart';
import '../snackbar/success_snackbar.dart';

class MembersTab extends StatefulWidget {
  final String locationId;
  final Future<void> Function()? onChanged;

  const MembersTab({super.key, required this.locationId, this.onChanged});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  bool loading = false;
  Future<List<PermissionMember>>? future;

  @override
  void initState() {
    super.initState();
    future = context.read<PermissionProvider>().loadMembers(widget.locationId);
  }

  String fmt(DateTime? d) =>
      d == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(d);

  void showSuccessMessage(String message) {
    final nav = Navigator.of(context, rootNavigator: true);
    final overlay = nav.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 90,
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          child: SuccessSnackbar(
            message: message,
            onClose: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (entry.mounted) entry.remove();
    });
  }

  void showFailMessage(String errorMessage, dynamic error) {
    final nav = Navigator.of(context, rootNavigator: true);
    final overlay = nav.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 50,
          child: FailSnackbar(
            title: errorMessage,
            message: error,
            onClose: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (entry.mounted) entry.remove();
    });
  }

  int rank(MemberStatus s) {
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

  List<PermissionMember> sort(List<PermissionMember> items) {
    final list = [...items];
    list.sort((a, b) {
      final c = rank(a.status) - rank(b.status);
      if (c != 0) return c;
      final ad = a.createdAt ?? DateTime(2000);
      final bd = b.createdAt ?? DateTime(2000);
      return bd.compareTo(ad);
    });
    return list;
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      future = context.read<PermissionProvider>().loadMembers(
        widget.locationId,
      );
    });
    try {
      await future;
      if (widget.onChanged != null) await widget.onChanged!.call();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  //
  Widget disableBtn(VoidCallback onPressed) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.red.shade200),
        ),
      ),
      onPressed: onPressed,
      child: const Text('Disable'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PermissionProvider>();

    if (future == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // BG ขาวทั้งแท็บ
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<PermissionMember>>(
        future: future!,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('loading failed: ${snap.error}'));
          }

          final members = sort(snap.data ?? []);

          return Column(
            children: [
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
              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final isOwner = m.permission == PermissionType.owner;

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey.shade200,
                              child: Text(
                                m.email.isNotEmpty
                                    ? m.email[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('name: ${m.name ?? "-"}'),
                                  Text(
                                    'status: ${m.status.label} • ${fmt(m.createdAt)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ===== Permission (owner = ชิปเทา; อื่นๆ = ดรอปดาวสไตล์ที่ให้) =====
                            if (isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'owner',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                width: 170,
                                child: DropdownButtonFormField<PermissionType>(
                                  value: m.permission,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.black54,
                                  ),
                                  iconSize: 24,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Permission',
                                    labelStyle: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade400,
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  items: PermissionType.values
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(
                                            t.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) async {
                                    if (val == null) return;
                                    try {
                                      await provider.upsertMember(
                                        locationId: widget.locationId,
                                        email: m.email,
                                        name: m.name,
                                        permission: val,
                                        status: m.status,
                                      );
                                      if (!mounted) return;
                                      showSuccessMessage(
                                        'Permissions updated successfully',
                                      );
                                      await refresh();
                                    } catch (e) {
                                      if (!mounted) return;
                                      showFailMessage('Error', e);
                                    }
                                  },
                                  validator: (_) => null,
                                ),
                              ),

                            const SizedBox(width: 8),

                            //  ปุ่ม Disable
                            if (!isOwner)
                              disableBtn(() async {
                                try {
                                  await provider.upsertMember(
                                    locationId: widget.locationId,
                                    email: m.email,
                                    name: m.name,
                                    permission: m.permission,
                                    status: MemberStatus.revoked,
                                  );
                                  if (!mounted) return;
                                  showSuccessMessage(
                                    'Status updated: disabled',
                                  );
                                  await refresh();
                                } catch (e) {
                                  if (!mounted) return;
                                  showFailMessage('Error', e);
                                }
                              }),
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
