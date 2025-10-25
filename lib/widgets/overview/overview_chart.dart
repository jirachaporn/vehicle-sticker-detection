import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

Widget ChartsRow(Map<String, dynamic> stats) {
  return LayoutBuilder(
    builder: (context, constraints) {
      bool isWide = constraints.maxWidth >= 900;
      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LineChart('Daily', stats['dailyData'] ?? [], 'day'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LineChart(
                'Weekly',
                stats['weeklyData'] ?? [],
                'week',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LineChart(
                'Monthly',
                stats['monthlyData'] ?? [],
                'month',
              ),
            ),
          ],
        );
      } else {
        return Column(
          children: [
            LineChart('Daily', stats['dailyData'] ?? [], 'day'),
            const SizedBox(height: 12),
            LineChart('Weekly', stats['weeklyData'] ?? [], 'week'),
            const SizedBox(height: 12),
            LineChart('Monthly', stats['monthlyData'] ?? [], 'month'),
          ],
        );
      }
    },
  );
}

Widget LineChart(String title, List<dynamic> data, String xField) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
      ],
    ),
    child: Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 200,
          child: data.isEmpty
              ? const Center(child: Text('No data'))
              : SfCartesianChart(
                  primaryXAxis: CategoryAxis(),
                  series: <LineSeries<dynamic, String>>[
                    LineSeries<dynamic, String>(
                      dataSource: data,
                      xValueMapper: (d, _) => d[xField]?.toString() ?? '',
                      yValueMapper: (d, _) => d['count'] ?? 0,
                      markerSettings: const MarkerSettings(isVisible: true),
                      color: Colors.deepPurple,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}
