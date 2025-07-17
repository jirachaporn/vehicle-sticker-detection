class CameraInfo {
  final int id;
  final String name;
  final String devicePath;
  final bool isActive;

  CameraInfo({
    required this.id,
    required this.name,
    required this.devicePath,
    required this.isActive,
  });

  factory CameraInfo.fromJson(Map<String, dynamic> json) {
    return CameraInfo(
      id: json['id'],
      name: json['name'] ?? 'Camera ${json['id']}',
      devicePath: json['device_path'] ?? '',
      isActive: json['is_active'] ?? false,
    );
  }
}
