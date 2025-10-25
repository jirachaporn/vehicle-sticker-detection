import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

Widget BottomChartsRow(Map<String, dynamic> stats) {
  return LayoutBuilder(
    builder: (context, constraints) {
      bool isWide = constraints.maxWidth >= 900;
      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SizedBox(height: 350, child: HourlyChart(stats))),
            const SizedBox(width: 16),
            Expanded(child: SizedBox(height: 350, child: DetectionPie(stats))),
          ],
        );
      } else {
        return Column(
          children: [
            SizedBox(height: 350, child: HourlyChart(stats)),
            const SizedBox(height: 16),
            SizedBox(height: 350, child: DetectionPie(stats)),
          ],
        );
      }
    },
  );
}

Widget HourlyChart(Map<String, dynamic> stats) {
  final recentActivity = (stats['recentActivity'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vehicle Activity (last 24 hours)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: recentActivity.isEmpty
              ? const Center(child: Text('No data'))
              : SfCartesianChart(
                  primaryXAxis: CategoryAxis(),
                  series: <LineSeries<dynamic, String>>[
                    LineSeries<dynamic, String>(
                      dataSource: recentActivity,
                      xValueMapper: (d, _) => d['time']?.toString() ?? '',
                      yValueMapper: (d, _) => d['count'] ?? 0,
                      markerSettings: const MarkerSettings(isVisible: true),
                      color: Colors.orange,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

Widget DetectionPie(Map<String, dynamic> stats) {
  final authorizedVehicles = stats['authorizedVehicles'] ?? 0;
  final unauthorizedVehicles = stats['unauthorizedVehicles'] ?? 0;
  final detectionAccuracy = stats['detectionAccuracy'] ?? 0.0;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
    ),
    child: Column(
      children: [
        const Text('Detection Distribution', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 250,
          child: SfCircularChart(
            legend: Legend(isVisible: true),
            series: <CircularSeries>[
              PieSeries<Map<String, dynamic>, String>(
                dataSource: [
                  {'type': 'Authorized', 'count': authorizedVehicles, 'color': Colors.green},
                  {'type': 'Unauthorized', 'count': unauthorizedVehicles, 'color': Colors.orange},
                ],
                xValueMapper: (d, _) => d['type'],
                yValueMapper: (d, _) => d['count'],
                pointColorMapper: (d, _) => d['color'],
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Chip(
          label: Text('Detection Accuracy: ${detectionAccuracy is int ? detectionAccuracy : (detectionAccuracy as double).toStringAsFixed(2)}%'),
          backgroundColor: Colors.blue.shade50,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ],
    ),
  );
}
