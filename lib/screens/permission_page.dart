import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/permission.dart';
import '../widgets/add_user_dialog.dart';
import '../widgets/permission_dialog.dart';

class PermissionPage extends StatelessWidget {
   final String locationId;
  const PermissionPage({super.key, required this.locationId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'จัดการผู้ใช้',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'จัดการสิทธิ์การเข้าถึงข้อมูลสถานที่',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มผู้ใช้'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Expanded(
            child: Card(
              child: Consumer<AppState>(
                builder: (context, appState, child) {
                  return SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 32,
                      headingRowHeight: 60,
                      dataRowMinHeight: 80,
                      dataRowMaxHeight: 80,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'ผู้ใช้',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'บทบาท',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'สิทธิ์เข้าถึง',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'เข้าใช้ล่าสุด',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'สถานะ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'การจัดการ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                      rows: appState.users.map((user) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue.shade500,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(user.role),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getRoleText(user.role),
                                  style: TextStyle(
                                    color: _getRoleTextColor(user.role),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${user.permissions.length} สถานที่',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            DataCell(
                              Text(
                                user.lastLogin ?? 'ยังไม่เคยเข้าใช้',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: user.isActive
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  user.isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
                                  style: TextStyle(
                                    color: user.isActive
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () =>
                                    _showPermissionDialog(context, user),
                                child: const Text('จัดการสิทธิ์'),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddUserDialog());
  }

  void _showPermissionDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => PermissionDialog(user: user),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red.shade100;
      case UserRole.manager:
        return Colors.blue.shade100;
      case UserRole.viewer:
        return Colors.green.shade100;
    }
  }

  Color _getRoleTextColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red.shade800;
      case UserRole.manager:
        return Colors.blue.shade800;
      case UserRole.viewer:
        return Colors.green.shade800;
    }
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
}
