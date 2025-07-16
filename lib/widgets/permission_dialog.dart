import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/user.dart';

class PermissionDialog extends StatefulWidget {
  final User user;

  const PermissionDialog({super.key, required this.user});

  @override
  State<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<PermissionDialog> {
  late User _editingUser;

  @override
  void initState() {
    super.initState();
    _editingUser = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'จัดการสิทธิ์ผู้ใช้',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_editingUser.name} (${_editingUser.email})',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'บทบาท: ${_getRoleText(_editingUser.role)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRoleDescription(_editingUser.role),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'สิทธิ์การเข้าถึงสถานที่',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Consumer<AppState>(
                builder: (context, appState, child) {
                  return SingleChildScrollView(
                    child: Table(
                      border: TableBorder.all(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'สถานที่',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'ดู',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'แก้ไข',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'อัพโหลด',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'จัดการ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ...appState.locations.map((location) {
                          final permission = _editingUser.permissions
                              .where((p) => p.locationId == location.id)
                              .firstOrNull ??
                              Permission(
                                locationId: location.id,
                                canView: false,
                                canEdit: false,
                                canUpload: false,
                                canManage: false,
                              );

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: location.color,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            location.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            location.address,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Checkbox(
                                    value: permission.canView,
                                    onChanged: (value) => _updatePermission(
                                      location.id,
                                      'canView',
                                      value ?? false,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Checkbox(
                                    value: permission.canEdit,
                                    onChanged: permission.canView
                                        ? (value) => _updatePermission(
                                              location.id,
                                              'canEdit',
                                              value ?? false,
                                            )
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Checkbox(
                                    value: permission.canUpload,
                                    onChanged: permission.canView
                                        ? (value) => _updatePermission(
                                              location.id,
                                              'canUpload',
                                              value ?? false,
                                            )
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Checkbox(
                                    value: permission.canManage,
                                    onChanged: permission.canView &&
                                            _editingUser.role != UserRole.viewer
                                        ? (value) => _updatePermission(
                                              location.id,
                                              'canManage',
                                              value ?? false,
                                            )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('ปิด'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 16),
                        SizedBox(width: 8),
                        Text('บันทึกการเปลี่ยนแปลง'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updatePermission(String locationId, String permissionType, bool value) {
    setState(() {
      final existingIndex = _editingUser.permissions
          .indexWhere((p) => p.locationId == locationId);

      if (existingIndex >= 0) {
        final existing = _editingUser.permissions[existingIndex];
        _editingUser.permissions[existingIndex] = Permission(
          locationId: locationId,
          canView: permissionType == 'canView' ? value : existing.canView,
          canEdit: permissionType == 'canEdit' ? value : existing.canEdit,
          canUpload: permissionType == 'canUpload' ? value : existing.canUpload,
          canManage: permissionType == 'canManage' ? value : existing.canManage,
        );
      } else {
        _editingUser.permissions.add(Permission(
          locationId: locationId,
          canView: permissionType == 'canView' ? value : false,
          canEdit: permissionType == 'canEdit' ? value : false,
          canUpload: permissionType == 'canUpload' ? value : false,
          canManage: permissionType == 'canManage' ? value : false,
        ));
      }
    });
  }

  void _handleSave() {
    context.read<AppState>().updateUser(_editingUser);
    Navigator.of(context).pop();
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'ผู้ดูแลระบบ';
      case UserRole.manager:
        return 'ผู้จัดการ';
      case UserRole.viewer:
        return 'ผู้ดู';
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'มีสิทธิ์เต็มในการจัดการระบบทั้งหมด';
      case UserRole.manager:
        return 'สามารถจัดการข้อมูลและอัพโหลดได้';
      case UserRole.viewer:
        return 'สามารถดูข้อมูลได้อย่างเดียว';
    }
  }
}