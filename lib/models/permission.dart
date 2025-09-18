// lib/models/permission.dart
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

/// ===== Enums (string-based for app) =====
/// โครงสร้าง enum ฝั่งแอป (ผูกกับ DB ผ่านค่าพิมพ์เล็ก)
enum PermissionType { view, edit, owner }

enum MemberStatus {
  invited,     // เปลี่ยนจาก pending เป็น invited (ตาม DB)
  confirmed,
  revoked,     // อาจจะไม่มีใน DB แต่เก็บไว้สำหรับอนาคต
  expired,     // อาจจะไม่มีใน DB แต่เก็บไว้สำหรับอนาคต
  disabled,
  left,        // อาจจะไม่มีใน DB แต่เก็บไว้สำหรับอนาคต
  unknown,
}

/// --- Mapping: App <-> DB (lowercase only) ---
extension PermissionTypeX on PermissionType {
  /// label ที่ใช้ในแอป
  String get label {
    switch (this) {
      case PermissionType.owner:
        return 'owner';
      case PermissionType.edit:
        return 'edit';
      case PermissionType.view:
        return 'view';
    }
  }

  /// ค่าที่จะเก็บใน DB (บังคับเป็นพิมพ์เล็ก)
  String get dbValue => label;

  static PermissionType fromDb(String? v) {
    switch ((v ?? '').trim().toLowerCase()) {
      case 'owner':
        return PermissionType.owner;
      case 'edit':
        return PermissionType.edit;
      default:
        return PermissionType.view;
    }
  }
}

extension MemberStatusX on MemberStatus {
  String get label {
    switch (this) {
      case MemberStatus.invited:
        return 'invited';
      case MemberStatus.confirmed:
        return 'confirmed';
      case MemberStatus.revoked:
        return 'revoked';
      case MemberStatus.expired:
        return 'expired';
      case MemberStatus.disabled:
        return 'disabled';
      case MemberStatus.left:
        return 'left';
      case MemberStatus.unknown:
        return 'unknown';
    }
  }

  /// ค่าสำหรับ location_members table (member_status_enum)
  String get dbValue {
    switch (this) {
      case MemberStatus.invited:
        return 'invited';
      case MemberStatus.confirmed:
        return 'confirmed';
      case MemberStatus.disabled:
        return 'disabled';
      // กรณีที่ยังไม่มีใน DB ให้ใช้ค่าที่ใกล้เคียงที่สุด
      case MemberStatus.revoked:
      case MemberStatus.expired:
      case MemberStatus.left:
        return 'disabled'; // fallback ไปเป็น disabled
      case MemberStatus.unknown:
      return 'invited'; // default fallback
    }
  }

  /// ค่าสำหรับ permission_log table (permission_status_enum)
  String get logDbValue {
    switch (this) {
      case MemberStatus.invited:
        return 'pending'; // map invited -> pending สำหรับ log table
      case MemberStatus.confirmed:
        return 'confirmed';
      case MemberStatus.disabled:
        return 'disabled';
      case MemberStatus.expired:
        return 'expired';
      // กรณีที่ยังไม่มีใน DB ให้ใช้ค่าที่ใกล้เคียงที่สุด
      case MemberStatus.revoked:
      case MemberStatus.left:
        return 'disabled';
      case MemberStatus.unknown:
      return 'pending'; // default fallback
    }
  }

  static MemberStatus fromDb(String? v) {
    switch ((v ?? '').trim().toLowerCase()) {
      case 'invited':
        return MemberStatus.invited;
      case 'confirmed':
        return MemberStatus.confirmed;
      case 'disabled':
        return MemberStatus.disabled;
      default:
        return MemberStatus.unknown;
    }
  }

  static MemberStatus fromLogDb(String? v) {
    switch ((v ?? '').trim().toLowerCase()) {
      case 'pending':
        return MemberStatus.invited; // map pending -> invited จาก log table
      case 'confirmed':
        return MemberStatus.confirmed;
      case 'disabled':
        return MemberStatus.disabled;
      case 'expired':
        return MemberStatus.expired;
      default:
        return MemberStatus.unknown;
    }
  }

  /// สำหรับแปลงจากค่าใดๆ (String, MemberStatus, etc.)
  static MemberStatus fromAny(dynamic v) {
    if (v is MemberStatus) return v;
    if (v is String) return fromDb(v);
    return MemberStatus.unknown; // default
  }
}

/// ===== Models =====
class PermissionMember {
  final String memberId;
  final String locationId;
  final String email;
  final String? name;
  final PermissionType permission;
  final MemberStatus status;
  final DateTime? createdAt;

  const PermissionMember({
    required this.memberId,
    required this.locationId,
    required this.email,
    required this.permission,
    required this.status,
    this.name,
    this.createdAt,
  });

  factory PermissionMember.fromDb(Map<String, dynamic> row) {
    return PermissionMember(
      memberId: (row['member_id'] ?? '').toString(),
      locationId: (row['location_id'] ?? '').toString(),
      email: (row['member_email'] ?? '').toString().toLowerCase(),
      name: row['member_name']?.toString(),
      permission: PermissionTypeX.fromDb(row['member_permission']?.toString()),
      status: MemberStatusX.fromDb(row['member_status']?.toString()),
      createdAt: _parseTS(row['created_at']),
    );
  }

  Map<String, dynamic> toDb() => {
    'member_id': memberId,
    'location_id': locationId,
    'member_email': email.toLowerCase(),
    'member_name': name,
    'member_permission': permission.dbValue,
    'member_status': status.dbValue,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };

  PermissionMember copyWith({
    String? memberId,
    String? locationId,
    String? email,
    String? name,
    PermissionType? permission,
    MemberStatus? status,
    DateTime? createdAt,
  }) {
    return PermissionMember(
      memberId: memberId ?? this.memberId,
      locationId: locationId ?? this.locationId,
      email: (email ?? this.email).toLowerCase(),
      name: name ?? this.name,
      permission: permission ?? this.permission,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}