import 'package:flutter/material.dart';

class Location {
  final String id;
  final String name;
  final String address;
  final Color color;
  final String? description;

  Location({
    required this.id,
    required this.name,
    required this.address,
    required this.color,
    this.description,
  });

  /// ✅ fromJson: แปลง JSON จาก backend (MongoDB) มาเป็น Object
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      address: json['address'],
      color: Color(
        int.tryParse(json['color'].toString()) ??
            0xFF000000, // fallback ถ้า parse ไม่ได้
      ),
      description: json['description'],
    );
  }

  /// ✅ toJson: แปลง Object กลับเป็น JSON (ใช้กับ POST/PUT)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'color':
          ((color.a * 255).round() << 24) |
          ((color.r * 255).round() << 16) |
          ((color.g * 255).round() << 8) |
          (color.b * 255).round(),
      'description': description,
    };
  }

  /// ✅ copyWith: ใช้สำหรับ clone object แล้วแก้บาง field
  Location copyWith({
    String? id,
    String? name,
    String? address,
    Color? color,
    String? description,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      color: color ?? this.color,
      description: description ?? this.description,
    );
  }
}
