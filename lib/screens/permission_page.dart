// lib/pages/permission_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../providers/permission_provider.dart';
import '../models/permission.dart';

// Tabs
import '../widgets/permission/members_tab.dart';
import '../widgets/permission/invite_tab.dart';
import '../widgets/permission/logs_tab.dart';
import '../widgets/permission/dialogs.dart';

class PermissionPage extends StatefulWidget {
  final String locationId;
  final String? locationName;

  const PermissionPage({
    super.key,
    required this.locationId,
    this.locationName,
  });

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _inviteEmailCtrl = TextEditingController();
  final _inviteNameCtrl = TextEditingController();

  String _invitePerm = 'view';

  bool _loading = false;
  bool _loadingInvite = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    _tab.dispose();
    _inviteEmailCtrl.dispose();
    _inviteNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // เติมสมาชิกของ location นี้เข้าคาเช่
      await context.read<PermissionProvider>().loadMembers(
        widget.locationId,
      ); // ✅
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                (widget.locationName ?? 'Permissions'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 56, height: 56),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Column(
              children: [
                TabBar(
                  controller: _tab,
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: Colors.black54,
                  overlayColor: WidgetStateProperty.all(
                    const Color(0x332563EB),
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Members'),
                    Tab(text: 'Invite'),
                    Tab(text: 'Logs'),
                  ],
                ),

                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 37, 100, 235),
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tab,
                          children: [
                            MembersTab(
                              locationId: widget.locationId,
                              onChanged: _refreshAll,
                            ),
                            InviteTab(
                              locationId: widget.locationId,
                              inviteEmailCtrl: _inviteEmailCtrl,
                              inviteNameCtrl: _inviteNameCtrl,
                              invitePerm: _invitePerm,
                              onPermChanged: (v) =>
                                  setState(() => _invitePerm = v),
                              loading: _loadingInvite,
                              onSubmit: () async {
                                await _handleInvite();
                              },
                            ),
                            LogsTab(
                              locationId: widget.locationId,
                              onExpireSweep: _handleExpireSweep,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInvite() async {
    final provider = context.read<PermissionProvider>();

    // raw สำหรับแสดงผล / email สำหรับใช้กับ DB
    final rawEmail = _inviteEmailCtrl.text.trim();
    final email = rawEmail.toLowerCase();
    final name = _inviteNameCtrl.text.trim();

    // 0) ตรวจอีเมล
    if (!_isEmail(rawEmail)) {
      _toast(context, 'กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }

    setState(() => _loadingInvite = true);

    try {
      // 1) เพิ่ม/อัปเดตสมาชิกเป็นสถานะ invited
      final permType = PermissionTypeX.fromDb(_invitePerm); // enum ของแอป
      await provider.upsertMember(
        locationId: widget.locationId,
        email: email, // ใช้ lower-case เขียน DB
        name: name.isEmpty ? null : name,
        permission: permType,
        status: MemberStatus.invited, // รอยืนยัน
      );

      // 2) ขอ token สำหรับยืนยัน (ให้ provider.invite สร้าง base64url)
      final token = await provider.invite(
        locationId: widget.locationId,
        inviteEmail: email, // lower-case
        permission: _invitePerm.toLowerCase(), // 'view' | 'edit' | 'owner'
        inviteName: name.isEmpty ? null : name,
      );

      // 3) สร้างลิงก์ยืนยัน (encode token กันอักขระพิเศษ)
      final baseUrlRaw =
          dotenv.env['SUPABASE_URL'] ??
          'https://<your-project-ref>.supabase.co';
      final baseUrl = baseUrlRaw.replaceAll(RegExp(r'/$'), '');
      final encodedToken = Uri.encodeComponent(token);
      final confirmLink =
          '$baseUrl/functions/v1/confirm-permission?token=$encodedToken';

      // 4) ส่งอีเมลเชิญ
      await _sendInviteEmail(
        toEmail: rawEmail, // แสดงตามที่กรอก
        linkUrl: confirmLink,
        invitedName: name,
        locationName: widget.locationName,
      );

      // 5) แจ้งสำเร็จ + คัดลอกลิงก์
      if (!mounted) return;
      await copyToClipboardAndDialogSuccess(
        context,
        title: 'เชิญสมาชิกสำเร็จ! 🎉',
        message:
            'ส่งลิงก์ยืนยันไปที่อีเมล $rawEmail แล้ว\n\nลิงก์: $confirmLink',
        copyText: confirmLink,
      );

      // 6) เคลียร์ฟอร์ม
      _inviteEmailCtrl.clear();
      _inviteNameCtrl.clear();
      setState(() => _invitePerm = 'view');

      // 7) รีเฟรชรายชื่อ
      await provider.loadMembers(widget.locationId);
    } catch (e, st) {
      debugPrint('[_handleInvite] error: $e\n$st');
      if (!mounted) return;
      _toast(context, 'เชิญไม่สำเร็จ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loadingInvite = false);
    }
  }

  Future<void> _handleExpireSweep() async {
    _toast(context, 'ยังไม่รองรับการสแกนคำเชิญหมดอายุในเวอร์ชันนี้');
  }

  // ----- helpers -----
  Future<void> _sendInviteEmail({
    required String toEmail,
    required String linkUrl,
    String? invitedName,
    String? locationName,
  }) async {
    // ปรับเป็น backend จริงของคุณ
    final endpoint = Uri.parse('http://127.0.0.1:5000/send-permission-email');

    final res = await http.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'to_email': toEmail,
        'link_url': linkUrl,
        'invited_name': invitedName ?? '',
        'location_name': locationName ?? 'Unknown',
        'subject': 'ยืนยันสิทธิ์เข้าถึง ${locationName ?? ''}'.trim(),
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('ส่งอีเมลล้มเหลว: ${res.body}');
    }
  }

  bool _isEmail(String v) {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(v);
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
