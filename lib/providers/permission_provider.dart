

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission.dart';

class PermissionProvider with ChangeNotifier {
  final supa = Supabase.instance.client;

  String get currentEmail => supa.auth.currentUser?.email ?? '';

  // -------- LOADERS --------
  Future<bool> isOwner(String locationId) async {
    final r = await supa
        .from('locations')
        .select('owner_email')
        .eq('locations_id', locationId)
        .maybeSingle();
    if (r == null) return false;
    final owner = (r['owner_email'] ?? '').toString().toLowerCase();
    return owner == (currentEmail.toLowerCase());
  }

  Future<List<PermissionMember>> listMembers(String locationId) async {
    final r = await supa
        .from('location_members')
        .select()
        .eq('location_id', locationId)
        .order('confirm_at', ascending: false);
    return List<Map<String, dynamic>>.from(r)
        .map(PermissionMember.fromMap)
        .toList();
  }

  Future<List<PermissionLog>> listLogs(String locationId) async {
    final r = await supa
        .from('permission_log')
        .select()
        .eq('location_id', locationId)
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(r)
        .map(PermissionLog.fromMap)
        .toList();
  }

  // -------- ACTIONS --------
  /// ส่งคำเชิญ (สร้าง log = pending) — ยังไม่เพิ่มลง location_members จนกว่าจะยืนยัน
  Future<String> invite({
    required String locationId,
    required String inviteEmail,
    required String permission, // 'view'|'edit'
    String? inviteName,
    Duration expireIn = const Duration(hours: 24),
  }) async {
    final owner = currentEmail;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final expiredIso =
        DateTime.now().toUtc().add(expireIn).toIso8601String();

    final insert = await supa.from('permission_log').insert({
      'location_id': locationId,
      'invited_email': inviteEmail.toLowerCase(),
      'invited_name': inviteName,
      'permission': permission,
      'status': PermissionLogStatus.pending,
      'invited_by_email': owner,
      'created_at': nowIso,
      'expired_at': expiredIso,
    }).select('permission_log_id').single();

    final token = insert['permission_log_id'] as String;
    notifyListeners();
    return token;
  }

  /// ผู้ถูกเชิญยืนยันด้วย token → เรียก RPC ใน DB
  Future<void> confirmByToken(String token) async {
    await supa.rpc('rpc_confirm_permission', params: {'p_token': token});
    notifyListeners();
  }

  /// เปลี่ยนสิทธิ์ของสมาชิกที่ยืนยันแล้ว
  Future<void> changePermission({
    required String locationId,
    required String memberEmail,
    required String newPermission, // 'view'|'edit'
  }) async {
    final email = memberEmail.toLowerCase();
    await supa.from('location_members').update({
      'permission': newPermission,
    }).match({
      'location_id': locationId,
      'member_email': email,
    });

    // เขียน log ประกอบ (ถือเป็น confirmed event)
    await supa.from('permission_log').insert({
      'location_id': locationId,
      'invited_email': email,
      'invited_name': null,
      'permission': newPermission,
      'status': PermissionLogStatus.confirmed,
      'invited_by_email': currentEmail,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'confirm_at': DateTime.now().toUtc().toIso8601String(),
    });

    notifyListeners();
  }

  /// เพิกถอนสิทธิ์ (confirmed → disabled)
  Future<void> revoke({
    required String locationId,
    required String memberEmail,
  }) async {
    final email = memberEmail.toLowerCase();
    final now = DateTime.now().toUtc().toIso8601String();

    await supa.from('location_members').update({
      'status': MemberStatus.disabled,
      'disabled_at': now,
    }).match({
      'location_id': locationId,
      'member_email': email,
    });

    await supa.from('permission_log').insert({
      'location_id': locationId,
      'invited_email': email,
      'permission': PermissionType.view, // บันทึกเหตุการณ์
      'status': PermissionLogStatus.disabled,
      'invited_by_email': currentEmail,
      'created_at': now,
      'disabled_at': now,
    });

    notifyListeners();
  }

  /// Re-invite: สร้าง log ใหม่ (pending) ให้คนเดิม
  Future<String> reInvite({
    required String locationId,
    required String inviteEmail,
    required String permission,
    String? inviteName,
  }) async {
    final token = await invite(
      locationId: locationId,
      inviteEmail: inviteEmail,
      permission: permission,
      inviteName: inviteName,
    );
    return token;
  }

  /// เรียก cron/ฟังก์ชันหมดอายุคำเชิญที่ค้าง (optional)
  Future<void> markExpiredInvites() async {
    await supa.rpc('rpc_expire_pending_invites');
    notifyListeners();
  }

  // -------- HELPERS (wrappers) --------

  /// Owner = สิทธิ์ทุกอย่าง
  Future<bool> hasEditPermission(String locationId) async {
    final owner = await isOwner(locationId);
    if (owner) return true;
    final email = currentEmail.toLowerCase();
    final members = await listMembers(locationId);
    for (final m in members) {
      if (m.email.toLowerCase() == email &&
          m.status == MemberStatus.confirmed &&
          m.permission == PermissionType.edit) {
        return true;
      }
    }
    return false;
  }

  Future<bool> hasViewPermission(String locationId) async {
    final owner = await isOwner(locationId);
    if (owner) return true;
    final email = currentEmail.toLowerCase();
    final members = await listMembers(locationId);
    for (final m in members) {
      if (m.email.toLowerCase() == email &&
          m.status == MemberStatus.confirmed) {
        return true; // ทั้ง view และ edit ที่ confirmed เห็นได้
      }
    }
    return false;
  }
}
