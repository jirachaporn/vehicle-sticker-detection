import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String createdAt;
  final String severity;
  final String locationId;
  final String imageUrl;
  final bool isRead;
  final String status;
  final Map<String, dynamic> meta;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.severity,
    required this.locationId,
    required this.imageUrl,
    required this.isRead,
    required this.status,
    required this.meta,
  });

  bool get unread => !isRead;
  String get description => message;
  String get timeAgo => createdAt.isNotEmpty ? createdAt : 'Just now';
  String get location => locationId;

  // yyyy-mm-dd hh:mm:ss
  String get formattedDate {
    try {
      final dateTime = DateTime.parse(createdAt);
      final localTime = dateTime.toLocal();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(localTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['notifications_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      createdAt: json['created_at'] ?? '',
      severity: json['severity'] ?? 'info',
      locationId: json['location_id'] ?? '',
      imageUrl: (json['image_url'] ?? '').replaceAll('"', ''),
      isRead: json['is_read'] ?? false,
      status: json['notification_status'] ?? '',
      meta: json['meta'] != null
          ? Map<String, dynamic>.from(json['meta'])
          : {},
    );
  }

  IconData get icon {
    switch (severity) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'critical':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color get color {
    switch (severity) {
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? createdAt,
    String? severity,
    String? locationId,
    String? imageUrl,
    bool? isRead,
    String? status,
    Map<String, dynamic>? meta,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      severity: severity ?? this.severity,
      locationId: locationId ?? this.locationId,
      imageUrl: imageUrl ?? this.imageUrl,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      meta: meta ?? this.meta,
    );
  }
}
