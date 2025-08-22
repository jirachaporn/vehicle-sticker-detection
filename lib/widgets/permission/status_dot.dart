import 'package:flutter/material.dart';
import '../../models/permission.dart';

class StatusDot extends StatelessWidget {
  final String status;
  const StatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case PermissionLogStatus.pending:
        c = Colors.amber;
        break;
      case PermissionLogStatus.confirmed:
        c = Colors.green;
        break;
      case PermissionLogStatus.expired:
        c = Colors.grey;
        break;
      case PermissionLogStatus.disabled:
        c = Colors.red;
        break;
      default:
        c = Colors.blueGrey;
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: c.withOpacity(0.15),
      child: Icon(Icons.circle, size: 12, color: c),
    );
  }
}
