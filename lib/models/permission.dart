// lib/models/permission.dart
import 'package:intl/intl.dart';


String formatLocal(DateTime? dt, {String pattern = 'yyyy-MM-dd HH:mm'}) {
  if (dt == null) return '-';
  return DateFormat(pattern).format(dt.toLocal());
}

enum PermissionType { view, edit, owner }

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

/// ===== Models =====
class PermissionMember {
  final String memberId;
  final String locationId;
  final String email;
  final String? name;
  final PermissionType permission;

  const PermissionMember({
    required this.memberId,
    required this.locationId,
    required this.email,
    required this.permission,
    this.name,
  });

  factory PermissionMember.fromDb(Map<String, dynamic> row) {
    return PermissionMember(
      memberId: (row['member_id'] ?? '').toString(),
      locationId: (row['location_id'] ?? '').toString(),
      email: (row['member_email'] ?? '').toString().toLowerCase(),
      name: row['member_name']?.toString(),
      permission: PermissionTypeX.fromDb(row['member_permission']?.toString()),
    );
  }

  Map<String, dynamic> toDb() => {
    'member_id': memberId,
    'location_id': locationId,
    'member_email': email.toLowerCase(),
    'member_name': name,
    'member_permission': permission.dbValue,
  };

  PermissionMember copyWith({
    String? memberId,
    String? locationId,
    String? email,
    String? name,
    PermissionType? permission,
  }) {
    return PermissionMember(
      memberId: memberId ?? this.memberId,
      locationId: locationId ?? this.locationId,
      email: (email ?? this.email).toLowerCase(),
      name: name ?? this.name,
      permission: permission ?? this.permission,
    );
  }
}
