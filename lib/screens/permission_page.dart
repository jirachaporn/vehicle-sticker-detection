// lib/pages/permission_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

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

  /// เก็บสิทธิ์ในฟอร์มแบบ String ให้ตรงกับ InviteTab เดิม: "owner" | "edit" | "view"
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
      await context.read<PermissionProvider>().loadMembers(widget.locationId); // ✅
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();
    final isOwner = perm.isOwner(widget.locationId);
    final canEdit = perm.canEdit(widget.locationId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationName ?? 'Permissions'),
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
            onPressed: _loading ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
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
                // InviteTab ใช้ String
                InviteTab(
                  locationId: widget.locationId,
                  inviteEmailCtrl: _inviteEmailCtrl,
                  inviteNameCtrl: _inviteNameCtrl,
                  invitePerm: _invitePerm, // "owner" | "edit" | "view"
                  onPermChanged: (v) => setState(() => _invitePerm = v),
                  loading: _loadingInvite,
                  onSubmit: () async {
                    // อนุญาตเฉพาะ owner/editor
                    if (!(isOwner || canEdit)) {
                      _toast(context, 'คุณไม่มีสิทธิ์เชิญสมาชิก');
                      return;
                    }
                    await _handleInvite();
                  },
                ),
                LogsTab(
                  locationId: widget.locationId,
                  onExpireSweep: _handleExpireSweep, // จะเป็น toast "ยังไม่รองรับ"
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

    // แปลง String -> PermissionType ด้วย fromDb (รองรับ 'owner' | 'edit' | 'view')
    final permType = PermissionTypeX.fromDb(_invitePerm); // ✅

    setState(() => _loadingInvite = true);
    try {
      // 1) บันทึกคำเชิญ (สถานะ invited)
      await provider.upsertMember(
        locationId: widget.locationId,
        email: email,
        name: name,
        permission: permType,
        status: MemberStatus.invited, // ✅ เก็บสถานะคำเชิญ
      );

      // 2) สร้างลิงก์ยืนยันแบบง่าย (ถ้ามี endpoint ยืนยันจริงค่อยปรับ)
      final link =
          'https://example.com/confirm-permission?location_id=${Uri.encodeComponent(widget.locationId)}&email=${Uri.encodeComponent(email)}';

      // 3) ส่งอีเมลผ่าน backend (ถ้าไม่มี endpoint นี้ ให้คอมเมนต์ทิ้งได้)
      await _sendInviteEmail(
        toEmail: email,
        linkUrl: link,
        invitedName: name,
        locationName: widget.locationName,
      );

      if (!mounted) return;

      await copyToClipboardAndDialogSuccess(
        context,
        title: 'ส่งคำเชิญสำเร็จ',
        message: 'คัดลอกลิงก์ยืนยันไว้ให้:\n$link',
        copyText: link,
      );

      // ล้างฟอร์ม
      _inviteEmailCtrl.clear();
      _inviteNameCtrl.clear();
      setState(() => _invitePerm = 'view');

      // reload รายชื่อสมาชิก
      await provider.loadMembers(widget.locationId); // ✅
    } catch (e) {
      if (!mounted) return;
      _toast(context, 'เชิญไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loadingInvite = false);
    }
  }

  Future<void> _handleExpireSweep() async {
    // ตอนนี้ยังไม่มี markExpiredInvites ใน PermissionProvider
    _toast(context, 'ยังไม่รองรับการสแกนคำเชิญหมดอายุในเวอร์ชันนี้');
    // ถ้าต้องการ ให้เพิ่มเมธอดใน PermissionProvider แล้วค่อยเรียกใช้ที่นี่
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
