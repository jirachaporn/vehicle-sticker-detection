import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../providers/permission_provider.dart';
import '../models/permission.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Widgets แยกย่อย
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
  String _invitePerm = PermissionType.view;
  bool _loadingInvite = false;
  bool _loading = false;

  Future<void> _loadAll(PermissionProvider p) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await Future.wait([
        // แม้จะไม่แสดง Owner แล้ว แต่ยัง preload ไว้ได้หาก provider ใช้ cache ที่อื่น
        p.isOwner(widget.locationId),
        p.listMembers(widget.locationId),
        p.listLogs(widget.locationId),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    final p = context.read<PermissionProvider>();
    await _loadAll(p);
    if (mounted) setState(() {});
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1), // ✅ เพิ่มตรงนี้
      appBar: AppBar(
        title: Text(
          'Permissions · ${widget.locationName ?? widget.locationId}',
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'สมาชิก'),
            Tab(text: 'เพิ่มคำเชิญ'),
            Tab(text: 'ประวัติ (Logs)'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _loading ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                  onPermChanged: (v) => setState(() => _invitePerm = v),
                  loading: _loadingInvite,
                  onSubmit: () async {
                    await _handleInvite();
                  },
                ),
                LogsTab(
                  locationId: widget.locationId,
                  onExpireSweep: () async {
                    await _handleExpireSweep();
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _handleInvite() async {
    final provider = context.read<PermissionProvider>();
    final email = _inviteEmailCtrl.text.trim();
    final name = _inviteNameCtrl.text.trim().isEmpty
        ? null
        : _inviteNameCtrl.text.trim();

    if (!_isEmail(email)) {
      _toast(context, 'กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }

    setState(() => _loadingInvite = true);
    try {
      // 1) ขอ token สำหรับคำเชิญ (logic เดิมของคุณ)
      final token = await provider.invite(
        locationId: widget.locationId,
        inviteEmail: email,
        permission: _invitePerm,
        inviteName: name,
      );

      // 2) ประกอบลิงก์ยืนยันให้ชัดเจน (ชี้ไปยัง Supabase Function ของคุณ)
      final baseUrl = dotenv.env['SUPABASE_FUNCTION_URL']?.trim();
      final uri = (baseUrl == null || baseUrl.isEmpty)
          ? '${dotenv.env['SUPABASE_URL']}/functions/v1'
          : baseUrl;
      final link = '$uri/confirm-permission?token=$token';

      // 3) ส่งลิงก์ไปทางอีเมลให้ผู้รับ "กดจากเมล์"
      await _sendInviteEmail(
        toEmail: email,
        linkUrl: link,
        invitedName: name,
        locationName: widget.locationName,
      );

      if (!mounted) return;

      // (ออปชัน Dev) คัดลอกลิงก์ไว้เผื่อดีบัก/ทดสอบเร็ว
      await copyToClipboardAndDialogSuccess(
        context,
        title: 'ส่งคำเชิญสำเร็จ',
        message:
            'ลิงก์ยืนยันถูกส่งไปยังอีเมลผู้รับแล้ว\n\n(สำหรับทดสอบ) คัดลอกลิงก์ไว้ให้ด้วย:\n$link',
        copyText: link,
      );

      // ล้างฟอร์ม
      _inviteEmailCtrl.clear();
      _inviteNameCtrl.clear();
      if (!mounted) return;
      setState(() => _invitePerm = PermissionType.view);

      // reload ข้อมูล
      await _loadAll(provider);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _toast(context, 'เชิญไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loadingInvite = false);
    }
  }

  Future<void> _handleExpireSweep() async {
    final provider = context.read<PermissionProvider>();
    try {
      await provider.markExpiredInvites();
      if (!mounted) return;
      _toast(context, 'อัปเดตคำเชิญหมดอายุแล้ว');

      await _loadAll(provider);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _toast(context, 'ไม่สำเร็จ: $e');
    }
  }

  /// ===== ส่งอีเมลด้วยการเรียก API หลังบ้าน (/send-permission-email) =====
  Future<void> _sendInviteEmail({
    required String toEmail,
    required String linkUrl,
    String? invitedName,
    String? locationName,
  }) async {
    final base = 'http://127.0.0.1:5000';
    final endpoint = Uri.parse('$base/send-permission-email');

    final res = await http.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'to_email': toEmail,
        'link_url': linkUrl,
        'invited_name': invitedName ?? '',
        'location_name': locationName ?? ' Unknow',
        'subject': 'ยืนยันสิทธิ์เข้าถึง ${locationName ?? ''}'.trim(),
      }),
    );

    if (res.statusCode != 200) {
      debugPrint('ส่งอีเมลล้มเหลว: ${res.body}');
      throw Exception('ส่งอีเมลล้มเหลว: ${res.body}');
    }
  }
}

/// ===== Utilities (local) =====
bool _isEmail(String v) {
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return re.hasMatch(v);
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
