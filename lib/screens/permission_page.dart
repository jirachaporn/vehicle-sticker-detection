// lib/pages/permission_page.dart
// ===== import =====
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../providers/permission_provider.dart';

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
  static final String? baseUrl = dotenv.env['API_BASE_URL'];

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

    final rawEmail = inviteEmailCtrl.text.trim();
    final email = rawEmail.toLowerCase();
    final name = inviteNameCtrl.text.trim();

    // 🔹 ตรวจสอบอีเมล
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(rawEmail)) {
      toast(context, 'Please enter a valid email');
      return;
    }

    setState(() => loadingInvite = true);

    try {
      // 1) ขอ permission_log_id สำหรับยืนยัน (บันทึกใน permission_log)
      final permissionLogId = await provider.invite(
        locationId: widget.locationId,
        inviteEmail: email,
        permission: invitePerm.toLowerCase(),
        inviteName: name.isEmpty ? null : name,
      );

      // 2) สร้างลิงก์ยืนยัน (ส่ง permission_log_id ตรงๆ)
      final baseUrlRaw = dotenv.env['SUPABASE_URL'] ?? '';
      final baseUrl = baseUrlRaw.replaceAll(RegExp(r'/$'), '');
      final confirmLink =
          '$baseUrl/functions/v1/confirm-permission?permissionLogId=$permissionLogId';

      // 3) ส่งอีเมลเชิญ
      await sendInviteEmail(
        toEmail: rawEmail,
        linkUrl: confirmLink,
        invitedName: name,
        locationName: widget.locationName,
      );

      if (!mounted) return;
      await copyToClipboardAndDialogSuccess(
        context,
        title: 'Invite sent successfully! 🎉',
        message:
            'Invitation link has been sent to $rawEmail\n\nLink: $confirmLink',
        copyText: confirmLink,
      );

      // เคลียร์ฟิลด์หลังส่ง
      inviteEmailCtrl.clear();
      inviteNameCtrl.clear();
      setState(() => invitePerm = 'view');
    } catch (e, st) {
      debugPrint('[handleInvite] error: $e\n$st');
      if (!mounted) return;
      toast(context, 'Failed to invite: ${e.toString()}');
    } finally {
      if (mounted) setState(() => loadingInvite = false);
    }
  }

  // ----- helpers -----
  Future<void> sendInviteEmail({
    required String toEmail,
    required String linkUrl,
    String? invitedName,
    String? locationName,
  }) async {
    final endpoint = Uri.parse('$baseUrl/permission/send-permission');

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
            const Color(0xFF2563EB).withValues(alpha: 0.1),
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
                LogsTab(locationId: widget.locationId),
              ],
            ),
    );
  }
}
