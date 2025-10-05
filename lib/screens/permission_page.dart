// lib/pages/permission_page.dart
// ===== import =====
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
import '../widgets/permission/dialogs_invit.dart';

// ===== class =====
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

// ===== ตัวแปร/ฟังก์ชันใน class =====
class _PermissionPageState extends State<PermissionPage>
    with SingleTickerProviderStateMixin {
  // --- state ---
  late TabController tab;
  final inviteEmailCtrl = TextEditingController();
  final inviteNameCtrl = TextEditingController();
  String invitePerm = 'view';
  bool loading = false;
  bool loadingInvite = false;

  // --- life cycle ---
  @override
  void initState() {
    super.initState();
    tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshAll());
  }

  @override
  void dispose() {
    tab.dispose();
    inviteEmailCtrl.dispose();
    inviteNameCtrl.dispose();
    super.dispose();
  }

  // --- actions ---
  Future<void> refreshAll() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      await context.read<PermissionProvider>().loadMembers(widget.locationId);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> handleInvite() async {
    final provider = context.read<PermissionProvider>();

    // raw สำหรับแสดงผล / email สำหรับใช้กับ DB
    final rawEmail = inviteEmailCtrl.text.trim();
    final email = rawEmail.toLowerCase();
    final name = inviteNameCtrl.text.trim();

    // 0) ตรวจอีเมล
    if (!isEmail(rawEmail)) {
      toast(context, 'Please enter a valid email');
      return;
    }

    setState(() => loadingInvite = true);

    try {
      // 1) เพิ่ม/อัปเดตสมาชิกเป็นสถานะ invited
      final permType = PermissionTypeX.fromDb(invitePerm);
      await provider.upsertMember(
        locationId: widget.locationId,
        email: email,
        name: name.isEmpty ? null : name,
        permission: permType,
        status: MemberStatus.invited,
      );

      // 2) ขอ token สำหรับยืนยัน (ให้ provider.invite สร้าง base64url)
      final token = await provider.invite(
        locationId: widget.locationId,
        inviteEmail: email, // lower-case
        permission: invitePerm.toLowerCase(), // 'view' | 'edit' | 'owner'
        inviteName: name.isEmpty ? null : name,
      );

      // 3) สร้างลิงก์ยืนยัน (encode token กันอักขระพิเศษ)
      final baseUrlRaw = dotenv.env['SUPABASE_URL'] ?? '';
      final baseUrl = baseUrlRaw.replaceAll(RegExp(r'/$'), '');
      final encodedToken = Uri.encodeComponent(token);
      final confirmLink =
          '$baseUrl/functions/v1/confirm-permission?token=$encodedToken';

      // 4) ส่งอีเมลเชิญ
      await sendInviteEmail(
        toEmail: rawEmail, // แสดงตามที่กรอก
        linkUrl: confirmLink,
        invitedName: name,
        locationName: widget.locationName,
      );

      // 5) แจ้งสำเร็จ + คัดลอกลิงก์
      if (!mounted) return;
      await copyToClipboardAndDialogSuccess(
        context,
        title: 'Invite sent successfully! 🎉',
        message:
            'Invitation link has been sent to $rawEmail\n\nLink: $confirmLink',
        copyText: confirmLink,
      );

      // 6) เคลียร์ฟอร์ม
      inviteEmailCtrl.clear();
      inviteNameCtrl.clear();
      setState(() => invitePerm = 'view');

      // 7) รีเฟรชรายชื่อ
      await provider.loadMembers(widget.locationId);
    } catch (e, st) {
      debugPrint('[handleInvite] error: $e\n$st');
      if (!mounted) return;
      toast(context, 'Failed to invite: ${e.toString()}');
    } finally {
      if (mounted) setState(() => loadingInvite = false);
    }
  }

  Future<void> handleExpireSweep() async {
    toast(context, 'Expired invitation sweep is not supported in this version');
  }

  // ----- helpers -----
  Future<void> sendInviteEmail({
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
        'subject': 'Confirm access to ${locationName ?? ''}'.trim(),
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to send email: ${res.body}');
    }
  }

  bool isEmail(String v) {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(v);
  }

  void toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===== Widget หลัก =====
  @override
  Widget build(BuildContext context) {
    final title = widget.locationName ?? 'Permissions';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: tab,
          indicatorColor: const Color(0xFF2563EB),
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.black54,
          overlayColor: WidgetStateProperty.all(
            const Color(0xFF2563EB).withValues(alpha:  0.1),
          ),
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Invite'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : TabBarView(
              controller: tab,
              children: [
                // ===== Widget ย่อย =====
                MembersTab(
                  locationId: widget.locationId,
                  onChanged: refreshAll,
                ),
                InviteTab(
                  locationId: widget.locationId,
                  inviteEmailCtrl: inviteEmailCtrl,
                  inviteNameCtrl: inviteNameCtrl,
                  invitePerm: invitePerm,
                  onPermChanged: (v) => setState(() => invitePerm = v),
                  loading: loadingInvite,
                  onSubmit: handleInvite,
                ),
                LogsTab(
                  locationId: widget.locationId,
                  onExpireSweep: handleExpireSweep,
                ),
              ],
            ),
    );
  }
}
