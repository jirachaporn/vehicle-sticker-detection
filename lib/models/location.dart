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
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
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
      print('❌ Error parsing color: $colorValue → $e');
    }

    return const Color(0xFF4285F4); // fallback สีฟ้า
  }

  /// ✅ toJson: แปลง Object กลับเป็น JSON ที่ตรงกับ backend
  Map<String, dynamic> toJson() {
    return {
      'locations_id': id,
      'location_name': name,
      'address': address,
      'description': description,
      'color_location':
          ((color.alpha << 24) |
          (color.red << 16) |
          (color.green << 8) |
          color.blue),
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

// import 'package:flutter/material.dart';

// class Location {
//   final String id;
//   final String name;
//   final String address;
//   final Color color;
//   final String? description;

//   Location({
//     required this.id,
//     required this.name,
//     required this.address,
//     required this.color,
//     this.description,
//   });

//   /// ✅ fromJson: แปลง JSON จาก backend (PostgreSQL) มาเป็น Object
//   factory Location.fromJson(Map<String, dynamic> json) {
//     return Location(
//       id: json['locations_id'].toString(),
//       name: json['name'] ?? 'Unnamed Location',
//       address: json['address'] ?? '',
//       color: _parseColor(json['color']),
//       description: json['description'],
//     );
//   }

//   static Color _parseColor(dynamic colorValue) {
//     try {
//       if (colorValue == null) return const Color(0xFF4285F4);

//       if (colorValue is int) {
//         return Color(colorValue);
//       }

//       if (colorValue is String) {
//         final parsed = int.parse(colorValue);
//         return Color(parsed);
//       }
//     } catch (e) {
//       print('❌ Error parsing color: $colorValue → $e');
//     }

//     return const Color(0xFF4285F4);
//   }

//   /// ✅ toJson: แปลง Object กลับเป็น JSON (ใช้กับ POST/PUT)
//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'name': name,
//       'address': address,
//       'color':
//           ((color.a * 255).round() << 24) |
//           ((color.r * 255).round() << 16) |
//           ((color.g * 255).round() << 8) |
//           (color.b * 255).round(),
//       'description': description,
//     };
//   }

//   /// ✅ copyWith: ใช้สำหรับ clone object แล้วแก้บาง field
//   Location copyWith({
//     String? id,
//     String? name,
//     String? address,
//     Color? color,
//     String? description,
//   }) {
//     return Location(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       address: address ?? this.address,
//       color: color ?? this.color,
//       description: description ?? this.description,
//     );
//   }
// }
