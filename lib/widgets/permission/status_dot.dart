// lib/widgets/permission/status_dot.dart
import 'package:flutter/material.dart';
import '../../models/permission.dart';

class StatusDot extends StatelessWidget {
  final MemberStatus status;

  const StatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case MemberStatus.invited:
        c = Colors.amber;
        break;
      case MemberStatus.confirmed:
        c = Colors.green;
        break;
      case MemberStatus.expired:
        c = Colors.grey;
        break;
      case MemberStatus.revoked:
      case MemberStatus.left:
        c = Colors.red;
        break;
      case MemberStatus.disabled: // ✅ แก้ให้รองรับ disabled
        c = Colors.black45;
        break;
      case MemberStatus.unknown:
        c = Colors.blueGrey;
        break;
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: c.withValues(alpha: 0.15),
      child: Icon(Icons.circle, size: 12, color: c),
    );
  }
}
