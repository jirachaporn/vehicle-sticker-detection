import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';
import 'permission_picker.dart';
import 'section_card.dart';
// import 'dialogs.dart';

class InviteTab extends StatelessWidget {
  final String locationId;
  final TextEditingController inviteEmailCtrl;
  final TextEditingController inviteNameCtrl;
  final String invitePerm;
  final ValueChanged<String> onPermChanged;
  final bool loading;
  final Future<void> Function() onSubmit;

  const InviteTab({
    super.key,
    required this.locationId,
    required this.inviteEmailCtrl,
    required this.inviteNameCtrl,
    required this.invitePerm,
    required this.onPermChanged,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<PermissionProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'เชิญสมาชิกใหม่',
                subtitle:
                    'กรอกอีเมลของผู้ที่จะเข้าถึงสถานที่นี้ และเลือกสิทธิ์ที่ต้องการ ระบบจะส่งอีเมลพร้อมลิงก์ยืนยันให้โดยอัตโนมัติ',
                child: Column(
                  children: [
                    TextField(
                      controller: inviteEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'อีเมลผู้ถูกเชิญ *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: inviteNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อ (ถ้ามี)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PermissionPicker(
                      value: invitePerm,
                      onChanged: onPermChanged,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: loading ? null : onSubmit,
                        icon: const Icon(Icons.send),
                        label: loading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Text('ส่งคำเชิญ'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionCard(
                title: 'วิธีใช้งานลิงก์ยืนยัน',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1) ระบบจะส่งอีเมลพร้อมลิงก์ยืนยันให้ผู้ถูกเชิญ'),
                    Text(
                        '2) เมื่อกดลิงก์ → Edge Function/RPC จะทำการยืนยันและเพิ่มสมาชิกให้อัตโนมัติ'),
                    Text('3) สถานะและประวัติจะปรากฏในแท็บ สมาชิก/Logs'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
