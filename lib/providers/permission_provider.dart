
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission.dart';

class PermissionProvider with ChangeNotifier {
  final supa = Supabase.instance.client;

  String get currentEmail {
    final e = (supa.auth.currentUser?.email ?? '').toLowerCase();
    return e.isNotEmpty ? e : 'vdowduang@gmail.com';
  }

  final Map<String, List<PermissionMember>> cacheByLocation = {};
  List<PermissionMember> membersFor(String locationId) =>
      cacheByLocation[locationId] ?? [];

  String toDbPermission(PermissionType t) => t.dbValue;
  bool isOwner(String locationId) => membersFor(
    locationId,
  ).any((m) => m.email == currentEmail && m.permission == PermissionType.owner);

  bool canEdit(String locationId) {
    final perm = getUserPermission(locationId);
    return perm == PermissionType.owner || perm == PermissionType.edit;
  }

  bool canView(String locationId) =>
      membersFor(locationId).any((m) => m.email == currentEmail);

  PermissionType? getUserPermission(String locationId) => membersFor(locationId)
      .firstWhere(
        (m) => m.email == currentEmail,
        orElse: () => PermissionMember(
          memberId: '',
          locationId: '',
          email: '',
          permission: PermissionType.view,
        ),
      )
      .permission;

  Future<List<PermissionMember>> loadMembers(String locationId) async {
    try {
      final res = await supa
          .from('location_members')
          .select(
            'member_id, location_id, member_email, member_name, member_permission',
          )
          .eq('location_id', locationId)
          .order('member_email', ascending: true);

      final items = (res as List<dynamic>? ?? [])
          .map((e) => PermissionMember.fromDb(e as Map<String, dynamic>))
          .toList();

      cacheByLocation[locationId] = items;
      return items;
    } catch (e) {
      debugPrint('❌ loadMembers error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> loadLogs(String locationId) async {
    try {
      final res = await supa
          .from('permission_log')
          .select('*')
          .eq('location_id', locationId)
          .order('created_at', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ loadLogs error: $e');
      rethrow;
    }
  }

  Future<void> insertLog({
    required String locationId,
    required String invitedEmail,
    String? invitedName,
    required PermissionType permission,
    required String status,
  }) async {
    final nowThai = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 7))
        .toIso8601String();
    try {
      await supa.from('permission_log').insert({
        'location_id': locationId,
        'member_email': invitedEmail.toLowerCase(),
        'member_name': (invitedName ?? '').trim().isEmpty
            ? 'Unknown'
            : invitedName!.trim(),
        'permission': permission.name,
        'status': status,
        'by_email': currentEmail,
        'created_at': nowThai,
      });
    } catch (e) {
      debugPrint('❌ insertLog error: $e');
    }
  }

  Future<void> upsertMember({
    required String locationId,
    required String email,
    String? name,
    required PermissionType permission,
  }) async {
    final lowerEmail = email.toLowerCase();
    final payload = {
      'location_id': locationId,
      'member_email': lowerEmail,
      'member_name': (name ?? '').trim().isEmpty ? 'Unknown' : name!.trim(),
      'member_permission': toDbPermission(permission),
    };

    try {
      final res = await supa
          .from('location_members')
          .upsert(payload, onConflict: 'location_id,member_email')
          .select()
          .maybeSingle();

      debugPrint('✅ upsertMember success: $res');
      await loadMembers(locationId);

      await insertLog(
        locationId: locationId,
        invitedEmail: email,
        invitedName: name,
        permission: permission,
        status: 'added',
      );
    } catch (e) {
      debugPrint('❌ upsertMember error: $e');
      rethrow;
    }
  }

  Future<void> updatePermission({
    required String locationId,
    required String email,
    required PermissionType newPermission,
    String? memberName,
  }) async {
    final lowerEmail = email.toLowerCase();
    try {
      await supa
          .from('location_members')
          .update({'member_permission': toDbPermission(newPermission)})
          .eq('location_id', locationId)
          .eq('member_email', lowerEmail);

      await loadMembers(locationId);

      await insertLog(
        locationId: locationId,
        invitedEmail: email,
        invitedName: memberName,
        permission: newPermission,
        status: 'updatepermission',
      );
    } catch (e) {
      debugPrint('❌ updatePermission error: $e');
      rethrow;
    }
  }

  Future<void> disableMember({
    required String locationId,
    required String email,
    required String name,
    required PermissionType permission,
    required String byEmail,
  }) async {
    await supa
        .from('location_members')
        .delete()
        .eq('location_id', locationId)
        .eq('member_email', email);

    await insertLog(
      locationId: locationId,
      invitedEmail: email,
      invitedName: name,
      permission: permission,
      status: 'disabled',
    );
  }

  Future<String> invite({
    required String locationId,
    required String inviteEmail,
    required String permission,
    String? inviteName,
  }) async {
    final emailLc = inviteEmail.trim().toLowerCase();

    // 🔹 ตรวจสอบอีเมล
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(emailLc)) {
      throw Exception("Invalid email address");
    }

    final nowIso = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 7))
        .toIso8601String();

    // ตรวจสอบซ้ำใน location_members
    final existing = await supa
        .from('location_members')
        .select('member_email')
        .eq('location_id', locationId)
        .eq('member_email', emailLc)
        .maybeSingle();

    if (existing != null) {
      throw Exception("This email is already a member of this location.");
    }

    // insert ลง permission_log
    final ins = await supa
        .from('permission_log')
        .insert({
          'location_id': locationId,
          'member_email': emailLc,
          'member_name': (inviteName ?? '').trim().isEmpty
              ? 'Unknown'
              : inviteName!.trim(),
          'permission': permission,
          'status': 'invited',
          'by_email': currentEmail,
          'created_at': nowIso,
        })
        .select('permission_log_id')
        .single();

    // ✅ return permission_log_id ตรงๆ
    return ins['permission_log_id'] as String;
  }

  Future<bool> confirmInvite(String permissionLogId) async {
    try {
      final existing = await supa
          .from('permission_log')
          .select('member_email, member_name, location_id, permission')
          .eq('permission_log_id', permissionLogId)
          .maybeSingle();

      if (existing == null) {
        debugPrint('confirmInvite error: invitation not found');
        return false;
      }

      final emailLc = (existing['member_email'] as String).toLowerCase();
      final locationId = existing['location_id'] as String;
      final name = existing['member_name'] as String?;
      final permDb = existing['permission'] as String;

      // เช็คซ้ำก่อน insert
      final already = await supa
          .from('location_members')
          .select('member_email')
          .eq('member_email', emailLc)
          .eq('location_id', locationId)
          .maybeSingle();

      if (already != null) {
        debugPrint('ℹconfirmInvite: already confirmed');
        return true;
      }

      await supa.from('location_members').insert({
        'location_id': locationId,
        'member_email': emailLc,
        'member_name': name ?? 'Unknown',
        'member_permission': permDb,
      });

      await loadMembers(locationId);
      return true;
    } catch (e, st) {
      debugPrint('❌ confirmInvite error: $e\n$st');
      return false;
    }
  }
}
