import 'package:flutter/material.dart';

class Location {
  final String id;
  final String name;
  final String address;
  final String? description;
  final Color color;
  final String ownerEmail;
  final List<Map<String, dynamic>> sharedWith;
  final DateTime createdAt;

  Location({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.color,
    required this.ownerEmail,
    required this.sharedWith,
    required this.createdAt,
  });

  /// ✅ fromJson: แปลง JSON จาก backend (PostgreSQL) มาเป็น Object
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: (json['locations_id'] ?? json['location_id'] ?? json['id'])
          .toString(),
      name: json['location_name'] ?? json['name'] ?? 'Unnamed Location',
      address: json['address'] ?? '',
      description: json['description'],
      color: _parseColor(json['color']),
      ownerEmail: json['owner_email'] ?? '',
      sharedWith: List<Map<String, dynamic>>.from(json['shared_with'] ?? []),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    try {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value);
      }
    } catch (e) {
      debugPrint('❌ Error parsing created_at: $value → $e');
    }
    return DateTime(1970);
  }

  /// แปลงสี
  static Color _parseColor(dynamic colorValue) {
    try {
      if (colorValue == null) return const Color(0xFF4285F4);

      if (colorValue is int) {
        return Color(colorValue);
      }

      if (colorValue is String) {
        // ✅ รองรับ '0xFF1565C0' และ '#4285F4'
        if (colorValue.startsWith('0x')) {
          return Color(int.parse(colorValue));
        } else if (colorValue.startsWith('#')) {
          return Color(int.parse(colorValue.replaceFirst('#', '0xFF')));
        } else {
          return Color(int.parse(colorValue));
        }
      }
    } catch (e) {
      debugPrint('❌ Error parsing color: $colorValue → $e');
    }

    return const Color(0xFF4285F4); // fallback สีฟ้า
  }

  /// ✅ toJson: แปลง Object กลับเป็น JSON ที่ตรงกับ backend
  Map<String, dynamic> toJson() {
    int to8bit(double v) => (v * 255.0).round() & 0xff;

    int packColorARGB(Color color) {
      final a = to8bit(color.a);
      final r = to8bit(color.r);
      final g = to8bit(color.g);
      final b = to8bit(color.b);
      return (a << 24) | (r << 16) | (g << 8) | b;
    }

    return {
      'locations_id': id,
      'location_name': name,
      'address': address,
      'description': description,
      'color_location': packColorARGB(color),
      'owner_email': ownerEmail,
      'shared_with': sharedWith,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// ✅ ใช้สำหรับ clone object แล้วแก้บาง field
  Location copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    Color? color,
    String? ownerEmail,
    List<Map<String, dynamic>>? sharedWith,
    DateTime? createdAt,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      color: color ?? this.color,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      sharedWith: sharedWith ?? this.sharedWith,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
