// lib/widgets/permission/members_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/permission_provider.dart';
import '../../models/permission.dart';
import '../../providers/snackbar_func.dart';

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

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<PermissionMember>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('Loading failed: ${snap.error}'));
          }

          final members = snap.data ?? [];

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
                                    'permission: ${m.permission.label}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                      await provider.updatePermission(
                                        locationId: widget.locationId,
                                        email: m.email,
                                        memberName: m.name,
                                        newPermission: val,
                                      );
                                      if (!mounted) return;
                                      showSuccessMessage(
                                        context,'Permissions updated successfully',
                                      );
                                      await refresh();
                                    } catch (e) {
                                      if (!mounted) return;
                                      showFailMessage(context,'Error', e);
                                    }
                                  },
                                  validator: (_) => null,
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (!isOwner)
                              disableBtn(() async {
                                try {
                                  await provider.updatePermission(
                                    locationId: widget.locationId,
                                    email: m.email,
                                    memberName: m.name,
                                    newPermission: m.permission,
                                  );

                                  if (!mounted) return;
                                  showSuccessMessage(
                                    context,'Member disabled and logged',
                                  );
                                  await refresh();
                                } catch (e) {
                                  if (!mounted) return;
                                  showFailMessage(context,'Error', e);
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
