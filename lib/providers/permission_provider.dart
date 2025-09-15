// lib/providers/permission_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission.dart';

/// ปรับให้คุยกับ DB ด้วยสตริงพิมพ์เล็กทั้งหมด
class PermissionProvider with ChangeNotifier {
  final supa = Supabase.instance.client;

  /// email ผู้ล็อกอินปัจจุบัน
  String get currentEmail {
    final e = (supa.auth.currentUser?.email ?? '').toLowerCase();
    return e.isNotEmpty ? e : 'vdowduang@gmail.com'; // DEV fallback
  }

  /// cache รายสมาชิกต่อ location
  final Map<String, List<PermissionMember>> _cacheByLocation = {};
  List<PermissionMember> membersFor(String locationId) =>
      _cacheByLocation[locationId] ?? const [];

  /// ====== Mapping helper สำหรับ DB (กันเคสตัวพิมพ์) ======
  String toDbPermission(PermissionType t) => t.dbValue;
  String toDbStatus(MemberStatus s) => s.dbValue;

  /// ====== Permission Check Methods ======

  /// เช็คว่าผู้ใช้ปัจจุบันเป็น owner ของ location นี้หรือไม่
  bool isOwner(String locationId) {
    final members = membersFor(locationId);
    final currentUser = members.firstWhere(
      (member) =>
          member.email == currentEmail &&
          member.status == MemberStatus.confirmed,
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

  /// เช็คว่าผู้ใช้ปัจจุบันสามารถแก้ไขได้หรือไม่ (owner หรือ edit)
  bool canEdit(String locationId) {
    final members = membersFor(locationId);
    final currentUser = members.firstWhere(
      (member) =>
          member.email == currentEmail &&
          member.status == MemberStatus.confirmed,
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

  /// เช็คว่าผู้ใช้ปัจจุบันสามารถดูได้หรือไม่ (owner, edit, หรือ view)
  bool canView(String locationId) {
    final members = membersFor(locationId);
    return members.any(
      (member) =>
          member.email == currentEmail &&
          member.status == MemberStatus.confirmed,
    );
  }

  /// เช็คสิทธิ์แบบละเอียด - คืนค่า PermissionType หรือ null ถ้าไม่มีสิทธิ์
  PermissionType? getUserPermission(String locationId) {
    final members = membersFor(locationId);
    final currentUser = members.firstWhere(
      (member) =>
          member.email == currentEmail &&
          member.status == MemberStatus.confirmed,
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

  /// ดึงสมาชิกของ location (owner/edit/view)
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

  /// เพิ่มสมาชิก/แก้สิทธิ์
  Future<void> upsertMember({
    required String locationId,
    required String email,
    String? name,
    required PermissionType permission,
    MemberStatus status = MemberStatus.confirmed,
  }) async {
    final payload = {
      'location_id': locationId,
      'member_email': email.toLowerCase(),
      'member_name': name,
      'member_permission': toDbPermission(permission), // ✅ lowercase
      'member_status': toDbStatus(status), // ✅ lowercase
    };

    try {
      await supa
          .from('location_members')
          .upsert(payload, onConflict: 'location_id,member_email');
      await loadMembers(locationId);
    } catch (e) {
      debugPrint('❌ upsertMember error: $e');
      rethrow;
    }
  }

  /// เปลี่ยน permission ของสมาชิก
  Future<void> updatePermission({
    required String locationId,
    required String email,
    required PermissionType permission,
  }) async {
    try {
      await supa
          .from('location_members')
          .update({
            'member_permission': toDbPermission(permission),
          }) // ✅ lowercase
          .eq('location_id', locationId)
          .eq('member_email', email.toLowerCase());
      await loadMembers(locationId);
    } catch (e) {
      debugPrint('❌ updatePermission error: $e');
      rethrow;
    }
  }

  /// เปลี่ยนสถานะสมาชิก
  Future<void> updateStatus({
    required String locationId,
    required String email,
    required MemberStatus status,
  }) async {
    try {
      await supa
          .from('location_members')
          .update({'member_status': toDbStatus(status)}) // ✅ lowercase
          .eq('location_id', locationId)
          .eq('member_email', email.toLowerCase());
      await loadMembers(locationId);
    } catch (e) {
      debugPrint('❌ updateStatus error: $e');
      rethrow;
    }
  }

  /// ลบสมาชิก
  Future<void> removeMember({
    required String locationId,
    required String email,
  }) async {
    try {
      await supa
          .from('location_members')
          .delete()
          .eq('location_id', locationId)
          .eq('member_email', email.toLowerCase());
      await loadMembers(locationId);
    } catch (e) {
      debugPrint('❌ removeMember error: $e');
      rethrow;
    }
  }

  /// ดึงเฉพาะสมาชิกที่มีสิทธิ์ตามชุดที่กำหนด (หลีกเลี่ยง .in_ ที่บางเวอร์ชันไม่มี)
  Future<List<PermissionMember>> listByPermissions({
    required String locationId,
    required List<PermissionType> permissions,
  }) async {
    // ทำเป็น OR string เช่น member_permission.eq.view,member_permission.eq.edit
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
}
