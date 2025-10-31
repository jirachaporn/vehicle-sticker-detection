import 'package:flutter/material.dart';

Widget OverviewRow(Map<String, dynamic> stats) {
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      StatBox(Icons.login, 'Today In', stats['todayInOut']?['in']?.toString() ?? '0', Colors.green),
      StatBox(Icons.logout, 'Today Out', stats['todayInOut']?['out']?.toString() ?? '0', Colors.blue),
      StatBox(Icons.verified, 'Authorized', stats['authorizedVehicles']?.toString() ?? '0', Colors.green),
      StatBox(Icons.warning, 'Unauthorized', stats['unauthorizedVehicles']?.toString() ?? '0', Colors.red),
      StatBox(Icons.directions_car, 'Total Vehicles', stats['totalVehicles']?.toString() ?? '0', Colors.blue),
    ],
  );
}

Widget StatBox(IconData icon, String title, String value, Color color) {
  return Container(
    width: 160,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
    ),
    child: Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
}
