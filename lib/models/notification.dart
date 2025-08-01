import 'package:flutter/material.dart';

class NotificationItem {
  final String title;
  final String description;
  final String timeAgo;
  final String location;
  final IconData icon;
  final Color color;
  final bool unread;

  const NotificationItem({
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.location,
    required this.icon,
    required this.color,
    required this.unread,
  });
}
