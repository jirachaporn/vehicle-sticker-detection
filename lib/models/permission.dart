// enum UserRole { admin, manager, viewer }

// class Permission {
//   final String locationId;
//   final bool canView;
//   final bool canEdit;
//   final bool canUpload;
//   final bool canManage;

//   Permission({
//     required this.locationId,
//     required this.canView,
//     required this.canEdit,
//     required this.canUpload,
//     required this.canManage,
//   });

//   Permission copyWith({
//     String? locationId,
//     bool? canView,
//     bool? canEdit,
//     bool? canUpload,
//     bool? canManage,
//   }) {
//     return Permission(
//       locationId: locationId ?? this.locationId,
//       canView: canView ?? this.canView,
//       canEdit: canEdit ?? this.canEdit,
//       canUpload: canUpload ?? this.canUpload,
//       canManage: canManage ?? this.canManage,
//     );
//   }
// }

// class User {
//   final String id;
//   final String name;
//   final String email;
//   final UserRole role;
//   final List<Permission> permissions;
//   final String? avatar;
//   final String? lastLogin;
//   final bool isActive;

//   User({
//     required this.id,
//     required this.name,
//     required this.email,
//     required this.role,
//     required this.permissions,
//     this.avatar,
//     this.lastLogin,
//     this.isActive = true,
//   });

//   User copyWith({
//     String? id,
//     String? name,
//     String? email,
//     UserRole? role,
//     List<Permission>? permissions,
//     String? avatar,
//     String? lastLogin,
//     bool? isActive,
//   }) {
//     return User(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       email: email ?? this.email,
//       role: role ?? this.role,
//       permissions: permissions ?? this.permissions,
//       avatar: avatar ?? this.avatar,
//       lastLogin: lastLogin ?? this.lastLogin,
//       isActive: isActive ?? this.isActive,
//     );
//   }

  
// }

// lib/models/permission.dart
// ✅ Models + Utilities สำหรับระบบ Permission
// - ใช้กับตาราง: location_members, permission_log
// - มี helper เช็คสิทธิ์: isOwner, hasEditPermission, hasViewPermission
// - ไม่มีการอ้างอิงถึงรูปภาพ (ตามข้อกำหนดล่าสุด)

import 'package:intl/intl.dart';

/// ===== Utilities =====
DateTime? _parseTS(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

String formatLocal(DateTime? dt, {String pattern = 'yyyy-MM-dd HH:mm'}) {
  if (dt == null) return '-';
  return DateFormat(pattern).format(dt.toLocal());
}

/// ===== Enums (string-based) =====
class PermissionType {
  static const view = 'view';
  static const edit = 'edit';
  static const all = [view, edit];
}

class MemberStatus {
  static const confirmed = 'confirmed';
  static const disabled = 'disabled';
  static const all = [confirmed, disabled];
}

class PermissionLogStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const expired = 'expired';
  static const disabled = 'disabled';
  static const all = [pending, confirmed, expired, disabled];
}

/// ===== Models =====

/// แทนแถวในตาราง `location_members` (สิทธิ์ปัจจุบัน)
class PermissionMember {
  final String id;
  final String locationId;
  final String email;         // member_email
  final String? name;         // member_name
  final String permission;    // 'view' | 'edit'
  final String status;        // 'confirmed' | 'disabled'
  final DateTime? invitedAt;
  final DateTime? confirmAt;
  final DateTime? disabledAt;

  const PermissionMember({
    required this.id,
    required this.locationId,
    required this.email,
    this.name,
    required this.permission,
    required this.status,
    this.invitedAt,
    this.confirmAt,
    this.disabledAt,
  });

  factory PermissionMember.fromMap(Map<String, dynamic> m) {
    return PermissionMember(
      id: m['id'] as String,
      locationId: m['location_id'] as String,
      email: m['member_email'] as String,
      name: m['member_name'] as String?,
      permission: m['permission'] as String,
      status: m['status'] as String,
      invitedAt: _parseTS(m['invited_at']),
      confirmAt: _parseTS(m['confirm_at']),
      disabledAt: _parseTS(m['disabled_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'member_email': email,
        'member_name': name,
        'permission': permission,
        'status': status,
        'invited_at': invitedAt?.toUtc().toIso8601String(),
        'confirm_at': confirmAt?.toUtc().toIso8601String(),
        'disabled_at': disabledAt?.toUtc().toIso8601String(),
      };

  PermissionMember copyWith({
    String? id,
    String? locationId,
    String? email,
    String? name,
    String? permission,
    String? status,
    DateTime? invitedAt,
    DateTime? confirmAt,
    DateTime? disabledAt,
  }) {
    return PermissionMember(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      email: email ?? this.email,
      name: name ?? this.name,
      permission: permission ?? this.permission,
      status: status ?? this.status,
      invitedAt: invitedAt ?? this.invitedAt,
      confirmAt: confirmAt ?? this.confirmAt,
      disabledAt: disabledAt ?? this.disabledAt,
    );
  }
}

/// แทนแถวในตาราง `permission_log` (ประวัติทุกเหตุการณ์)
class PermissionLog {
  final String id;                 // permission_log_id
  final String locationId;
  final String invitedEmail;
  final String? invitedName;
  final String permission;         // 'view' | 'edit'
  final String status;             // 'pending' | 'confirmed' | 'expired' | 'disabled'
  final String invitedByEmail;
  final DateTime createdAt;
  final DateTime? confirmAt;
  final DateTime? expiredAt;
  final DateTime? disabledAt;

  const PermissionLog({
    required this.id,
    required this.locationId,
    required this.invitedEmail,
    this.invitedName,
    required this.permission,
    required this.status,
    required this.invitedByEmail,
    required this.createdAt,
    this.confirmAt,
    this.expiredAt,
    this.disabledAt,
  });

  factory PermissionLog.fromMap(Map<String, dynamic> m) {
    return PermissionLog(
      id: m['permission_log_id'] as String,
      locationId: m['location_id'] as String,
      invitedEmail: m['invited_email'] as String,
      invitedName: m['invited_name'] as String?,
      permission: m['permission'] as String,
      status: m['status'] as String,
      invitedByEmail: m['invited_by_email'] as String,
      createdAt: _parseTS(m['created_at']) ?? DateTime.now(),
      confirmAt: _parseTS(m['confirm_at']),
      expiredAt: _parseTS(m['expired_at']),
      disabledAt: _parseTS(m['disabled_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'permission_log_id': id,
        'location_id': locationId,
        'invited_email': invitedEmail,
        'invited_name': invitedName,
        'permission': permission,
        'status': status,
        'invited_by_email': invitedByEmail,
        'created_at': createdAt.toUtc().toIso8601String(),
        'confirm_at': confirmAt?.toUtc().toIso8601String(),
        'expired_at': expiredAt?.toUtc().toIso8601String(),
        'disabled_at': disabledAt?.toUtc().toIso8601String(),
      };

  PermissionLog copyWith({
    String? id,
    String? locationId,
    String? invitedEmail,
    String? invitedName,
    String? permission,
    String? status,
    String? invitedByEmail,
    DateTime? createdAt,
    DateTime? confirmAt,
    DateTime? expiredAt,
    DateTime? disabledAt,
  }) {
    return PermissionLog(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      invitedName: invitedName ?? this.invitedName,
      permission: permission ?? this.permission,
      status: status ?? this.status,
      invitedByEmail: invitedByEmail ?? this.invitedByEmail,
      createdAt: createdAt ?? this.createdAt,
      confirmAt: confirmAt ?? this.confirmAt,
      expiredAt: expiredAt ?? this.expiredAt,
      disabledAt: disabledAt ?? this.disabledAt,
    );
  }
}

/// ===== Helper functions สำหรับเช็คสิทธิ์ =====

/// เช็คว่าเป็น Owner ของ location หรือไม่
bool isOwner({
  required String loggedInEmail,
  required String ownerEmail,
}) {
  if (loggedInEmail.isEmpty || ownerEmail.isEmpty) return false;
  return loggedInEmail.toLowerCase() == ownerEmail.toLowerCase();
}

/// เช็คว่า user มีสิทธิ์ EDIT หรือไม่ (Owner = ผ่านอัตโนมัติ)
bool hasEditPermission({
  required String loggedInEmail,
  required String ownerEmail,
  required List<PermissionMember> members, // จากตาราง location_members
}) {
  if (isOwner(loggedInEmail: loggedInEmail, ownerEmail: ownerEmail)) {
    return true;
  }
  final email = loggedInEmail.toLowerCase();
  for (final m in members) {
    if (m.email.toLowerCase() == email &&
        m.status == MemberStatus.confirmed &&
        m.permission == PermissionType.edit) {
      return true;
    }
  }
  return false;
}

/// เช็คว่า user มีสิทธิ์ VIEW หรือไม่ (Owner/Editor = ผ่าน, Viewer = confirmed ก็ผ่าน)
bool hasViewPermission({
  required String loggedInEmail,
  required String ownerEmail,
  required List<PermissionMember> members,
}) {
  if (isOwner(loggedInEmail: loggedInEmail, ownerEmail: ownerEmail)) {
    return true;
  }
  final email = loggedInEmail.toLowerCase();
  for (final m in members) {
    if (m.email.toLowerCase() == email && m.status == MemberStatus.confirmed) {
      // ทั้ง 'view' และ 'edit' ที่ confirmed ถือว่าเห็นได้
      return true;
    }
  }
  return false;
}
