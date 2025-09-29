import 'package:flutter/material.dart';

class Location {
  final String id;
  final String name;
  final String address;
  final String? description;
  final Color color;
  final DateTime createdAt;
  final String location_license;

  Location({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.color,
    required this.createdAt,
    required this.location_license,
  });

  // ===== helpers =====
  static DateTime _parseDate(dynamic v) {
    try {
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
    } catch (e) {
      debugPrint('❌ created_at parse fail: $v → $e');
    }
    return DateTime(1970);
  }

  static Color _parseColor(dynamic v) {
    try {
      if (v == null) return const Color(0xFF4285F4);
      if (v is int) return Color(v);
      if (v is String) {
        // รองรับ '0xFF1565C0', '#4285F4', '4278231232'
        if (v.startsWith('0x')) return Color(int.parse(v));
        if (v.startsWith('#')) return Color(int.parse(v.replaceFirst('#', '0xFF')));
        return Color(int.parse(v));
      }
    } catch (e) {
      debugPrint('❌ color parse fail: $v → $e');
    }
    return const Color(0xFF4285F4);
  }

  String _toWebHex(Color c) {
    // ใช้แบบที่ขอไว้: toARGB32() → ตัดเอา RGB เป็น #RRGGBB
    final argb = c.toARGB32();
    final rgb = (argb & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return '#$rgb';
  }

  // ===== fromJson: ดึงให้ครอบคลุมคีย์ของตารางจริง =====
  factory Location.fromJson(Map<String, dynamic> json) {
    // id
    final id =
        (json['location_id'] ?? json['locations_id'] ?? json['id'])
            ?.toString() ??
        '';

    // ชุดคีย์ที่ถูกต้องตามตาราง
    final name = (json['location_name'] ?? json['name'] ?? 'Unnamed Location')
        .toString();
    final address = (json['location_address'] ?? json['address'] ?? '')
        .toString();
    final description =
        (json['location_description'] ?? json['description']) as String?;

    // สี: รองรับทั้ง 'location_color' (ถูก) และ 'color' (ตกค้าง)
    final colorRaw = json['location_color'] ?? json['color'];
    final color = _parseColor(colorRaw);

   

    final createdAt = _parseDate(json['created_at']);

    // สำคัญ: ดึง location_license จากคอลัมน์จริง
    final license = (json['location_license'] ?? '').toString();

    return Location(
      id: id,
      name: name,
      address: address,
      description: description,
      color: color,
      createdAt: createdAt,
      location_license: license,
    );
  }

  // ===== toJson: เขียนกลับด้วยคีย์ที่ตรงตาราง =====
  Map<String, dynamic> toJson() {
    return {
      'location_id': id,
      'location_name': name,
      'location_address': address,
      'location_description': description,
      'location_color': _toWebHex(color),
      'created_at': createdAt.toIso8601String(),
      'location_license': location_license,
    };
  }

  Location copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    Color? color,
    List<Map<String, dynamic>>? sharedWith,
    DateTime? createdAt,
    String? location_license,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      location_license: location_license ?? this.location_license,
    );
  }
}
