enum UserRole { admin, manager, viewer }

class Permission {
  final String locationId;
  final bool canView;
  final bool canEdit;
  final bool canUpload;
  final bool canManage;

  Permission({
    required this.locationId,
    required this.canView,
    required this.canEdit,
    required this.canUpload,
    required this.canManage,
  });

  Permission copyWith({
    String? locationId,
    bool? canView,
    bool? canEdit,
    bool? canUpload,
    bool? canManage,
  }) {
    return Permission(
      locationId: locationId ?? this.locationId,
      canView: canView ?? this.canView,
      canEdit: canEdit ?? this.canEdit,
      canUpload: canUpload ?? this.canUpload,
      canManage: canManage ?? this.canManage,
    );
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final List<Permission> permissions;
  final String? avatar;
  final String? lastLogin;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    this.avatar,
    this.lastLogin,
    this.isActive = true,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    List<Permission>? permissions,
    String? avatar,
    String? lastLogin,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      avatar: avatar ?? this.avatar,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}