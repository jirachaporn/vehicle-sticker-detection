// lib/providers/permission_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission.dart';

class PermissionProvider with ChangeNotifier {
  final supa = Supabase.instance.client;

  String get currentEmail {
    final e = (supa.auth.currentUser?.email ?? '').toLowerCase();
    return e.isNotEmpty ? e : 'vdowduang@gmail.com'; // DEV fallback
  }

  // ===== Cache =====
  final Map<String, List<PermissionMember>> _cacheByLocation = {};
  List<PermissionMember> membersFor(String locationId) =>
      _cacheByLocation[locationId] ?? const [];

  // ===== Mapping (จาก models/permission.dart) =====
  String toDbPermission(PermissionType t) => t.dbValue; // 'view'|'edit'|'owner'
  String toDbStatus(MemberStatus s) =>
      s.dbValue; // 'invited'|'confirmed'|'disabled'
  String toLogDbStatus(MemberStatus s) =>
      s.logDbValue; // 'pending'|'confirmed'|'expired'|'disabled'

  // ===== Permission checks =====
  bool isOwner(String locationId) {
    final members = membersFor(locationId);
    final currentUser = members.firstWhere(
      (m) => m.email == currentEmail && m.status == MemberStatus.confirmed,
      orElse: () => PermissionMember(
        memberId: '',
        locationId: '',
        email: '',
        permission: PermissionType.view,
        status: MemberStatus.unknown,
      ),
    );
    return currentUser.permission == PermissionType.owner;
  }

  bool canEdit(String locationId) {
    final members = membersFor(locationId);
    final currentUser = members.firstWhere(
      (m) => m.email == currentEmail && m.status == MemberStatus.confirmed,
      orElse: () => PermissionMember(
        memberId: '',
        locationId: '',
        email: '',
        permission: PermissionType.view,
        status: MemberStatus.unknown,
      ),
    );
    return currentUser.permission == PermissionType.owner ||
        currentUser.permission == PermissionType.edit;
  }

  bool canView(String locationId) {
    final members = membersFor(locationId);
    return members.any(
      (m) => m.email == currentEmail && m.status == MemberStatus.confirmed,
    );
  }

  PermissionType? getUserPermission(String locationId) {
    final members = membersFor(locationId);
    final currentUser = members.firstWhere(
      (m) => m.email == currentEmail && m.status == MemberStatus.confirmed,
      orElse: () => PermissionMember(
        memberId: '',
        locationId: '',
        email: '',
        permission: PermissionType.view,
        status: MemberStatus.unknown,
      ),
    );
    if (currentUser.status == MemberStatus.unknown) return null;
    return currentUser.permission;
  }

  // ===== Data ops =====
  Future<List<PermissionMember>> loadMembers(String locationId) async {
    try {
      final res = await supa
          .from('location_members')
          .select('*')
          .eq('location_id', locationId)
          .order('member_email', ascending: true);

      final items = (res as List<dynamic>? ?? [])
          .map((e) => PermissionMember.fromDb(e as Map<String, dynamic>))
          .toList();

      _cacheByLocation[locationId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      debugPrint('❌ loadMembers error: $e');
      rethrow;
    }
  }

  Future<void> upsertMember({
    required String locationId,
    required String email,
    String? name,
    required PermissionType permission,
    MemberStatus status = MemberStatus.confirmed,
  }) async {
    final lowerEmail = email.toLowerCase();
    final payload = {
      'location_id': locationId,
      'member_email':
          lowerEmail, // ✅ DB จะสร้าง member_email_lc เอง (GENERATED ALWAYS)
      'member_name': name,
      'member_permission': toDbPermission(permission), // 'view'|'edit'|'owner'
      'member_status': toDbStatus(status), // 'invited'|'confirmed'|'disabled'
    };

    try {
      debugPrint('🔍 upsertMember payload: $payload');
      final res = await supa
          .from('location_members')
          .upsert(payload, onConflict: 'location_id,member_email_lc')
          .select()
          .maybeSingle();
      debugPrint('✅ upsertMember success: $res');
      await loadMembers(locationId);
    } on PostgrestException catch (e) {
      debugPrint('❌ upsertMember PostgrestException: ${e.message}');
      debugPrint('❌ Error details: ${e.details}');
      debugPrint('❌ Error code: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('❌ upsertMember error: $e');
      rethrow;
    }
  }

  Future<void> updatePermission({
    required String locationId,
    required String email,
    required PermissionType permission,
  }) async {
    final lowerEmail = email.toLowerCase();
    try {
      final res = await supa
          .from('location_members')
          .update({'member_permission': toDbPermission(permission)})
          .eq('location_id', locationId)
          .eq('member_email_lc', lowerEmail); // ✅ match ด้วยคอลัมน์ lc
      debugPrint('✅ updatePermission: $res');
      await loadMembers(locationId);
    } catch (e) {
      debugPrint('❌ updatePermission error: $e');
      rethrow;
    }
  }

  Future<void> updateStatus({
    required String locationId,
    required String email,
    required MemberStatus status,
  }) async {
    final lowerEmail = email.toLowerCase();
    try {
      final res = await supa
          .from('location_members')
          .update({
            'member_status': toDbStatus(status),
          }) // 'invited'|'confirmed'|'disabled'
          .eq('location_id', locationId)
          .eq('member_email_lc', lowerEmail); // ✅ match ด้วยคอลัมน์ lc
      debugPrint('✅ updateStatus: $res');
      await loadMembers(locationId);
    } catch (e) {
      debugPrint('❌ updateStatus error: $e');
      rethrow;
    }
  }

  Future<void> removeMember({
    required String locationId,
    required String email,
  }) async {
    final lowerEmail = email.toLowerCase();
    try {
      final res = await supa
          .from('location_members')
          .delete()
          .eq('location_id', locationId)
          .eq('member_email_lc', lowerEmail); // ✅ match ด้วยคอลัมน์ lc
      debugPrint('✅ removeMember: $res');
      await loadMembers(locationId);
    } catch (e) {
      debugPrint('❌ removeMember error: $e');
      rethrow;
    }
  }

  Future<List<PermissionMember>> listByPermissions({
    required String locationId,
    required List<PermissionType> permissions,
  }) async {
    final ors = permissions
        .map((p) => 'member_permission.eq.${toDbPermission(p)}')
        .join(',');
    try {
      final res = await supa
          .from('location_members')
          .select('*')
          .eq('location_id', locationId)
          .or(ors);

      final items = (res as List<dynamic>? ?? [])
          .map((e) => PermissionMember.fromDb(e as Map<String, dynamic>))
          .toList();
      return items;
    } catch (e) {
      debugPrint('❌ listByPermissions error: $e');
      rethrow;
    }
  }

  /// ===== Create/refresh invite (idempotent) and return token =====
  Future<String> invite({
    required String locationId,
    required String inviteEmail,
    required String permission, // 'view' | 'edit' | 'owner'
    String? inviteName,
  }) async {
    final emailLc = inviteEmail.trim().toLowerCase();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1) หา pending เดิม
    final existing = await supa
        .from('permission_log')
        .select('permission_log_id, permission, invited_name')
        .eq('location_id', locationId)
        .eq('invited_email', emailLc) // ✅ เก็บ invited_email แบบ LC ในตาราง
        .eq('status', 'pending') // ✅ permission_status_enum
        .maybeSingle();

    String logId;
    if (existing != null) {
      // 2) อัปเดตของเดิมถ้าค่าเปลี่ยน
      logId = existing['permission_log_id'] as String;
      final updates = <String, dynamic>{};
      if ((existing['permission'] as String?) != permission) {
        updates['permission'] = permission;
      }
      if ((existing['invited_name'] as String?) != inviteName) {
        updates['invited_name'] = inviteName;
      }
      if (updates.isNotEmpty) {
        updates['created_at'] = nowIso;
        await supa
            .from('permission_log')
            .update(updates)
            .eq('permission_log_id', logId);
      }
    } else {
      // 3) ยังไม่มี pending -> insert ใหม่
      final ins = await supa
          .from('permission_log')
          .insert({
            'location_id': locationId,
            'invited_email': emailLc,
            'invited_name': (inviteName ?? '').trim().isEmpty
                ? null
                : inviteName!.trim(),
            'permission': permission, // permission_enum
            'status': 'pending', // ✅ ใช้ enum ของ log
            'invited_by_email': currentEmail,
            'created_at': nowIso,
          })
          .select('permission_log_id')
          .single();
      logId = ins['permission_log_id'] as String;
    }

    // 4) สร้าง token (base64url no padding) — ใส่ permissionLogId ด้วย
    final payload = <String, dynamic>{
      'email': emailLc,
      'locationId': locationId,
      'permission': permission,
      'name': inviteName,
      'permissionLogId': logId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    final jsonStr = jsonEncode(payload);
    final token = base64Url.encode(utf8.encode(jsonStr)).replaceAll('=', '');
    return token;
  }

  /// ===== (Optional) Confirm invite locally from token (rarely used) =====
  Future<bool> confirmInvite(String token) async {
    try {
      final payload = _decodeBase64UrlToJson(token);
      final emailLc = (payload['email'] as String).toLowerCase();
      final locationId = payload['locationId'] as String;
      final permDb = payload['permission'] as String;
      final logId = payload['permissionLogId'] as String?;
      final issuedAtMs = (payload['ts'] ?? payload['timestamp']) as int;

      // หมดอายุ 7 วัน
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
      if (nowMs - issuedAtMs > sevenDaysMs) {
        await supa
            .from('permission_log')
            .update({
              'status': 'expired',
              'expired_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('location_id', locationId)
            .eq('invited_email', emailLc)
            .eq('status', 'pending');
        return false;
      }

      // อัปเดต log -> confirmed (ใช้ logId ถ้ามี แม่นสุด)
      if (logId != null && logId.isNotEmpty) {
        await supa
            .from('permission_log')
            .update({
              'status': 'confirmed',
              'confirm_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('permission_log_id', logId);
      } else {
        await supa
            .from('permission_log')
            .update({
              'status': 'confirmed',
              'confirm_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('location_id', locationId)
            .eq('invited_email', emailLc)
            .eq('status', 'pending');
      }

      // upsert ลง location_members -> confirmed
      await supa
          .from('location_members')
          .upsert({
            'location_id': locationId,
            'member_email': emailLc, // DB สร้าง member_email_lc เอง
            'member_permission': permDb,
            'member_status': 'confirmed',
          }, onConflict: 'location_id,member_email_lc')
          .select()
          .maybeSingle();

      await loadMembers(locationId);
      return true;
    } catch (e, st) {
      debugPrint('❌ confirmInvite error: $e\n$st');
      return false;
    }
  }

  // ===== Helpers =====
  Map<String, dynamic> _decodeBase64UrlToJson(String token) {
    // normalize: remove spaces, add padding, decode
    String clean = token.replaceAll(RegExp(r'\s'), '');
    // (optional) percent decode-like scenarios are handled server-side; assume clean here
    final pad = clean.length % 4 == 0 ? '' : '=' * (4 - (clean.length % 4));
    final bytes = base64Url.decode(clean + pad);
    final jsonStr = utf8.decode(bytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
