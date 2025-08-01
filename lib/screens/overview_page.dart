import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class OverviewPage extends StatelessWidget {
   final String locationId;
  OverviewPage({super.key, required this.locationId});

  final Map<String, dynamic> stats = {
    'totalVehicles': 124,
    'authorizedVehicles': 98,
    'unauthorizedVehicles': 26,
    'alerts': 5,
    'todayInOut': {'in': 45, 'out': 38},
    'recentActivity': [
      {'time': '00:00', 'count': 2},
      {'time': '03:00', 'count': 0},
      {'time': '06:00', 'count': 5},
      {'time': '09:00', 'count': 32},
      {'time': '12:00', 'count': 45},
      {'time': '15:00', 'count': 28},
      {'time': '18:00', 'count': 12},
      {'time': '21:00', 'count': 4},
    ],
    'dailyData': [
      {'day': 'Mon', 'count': 32},
      {'day': 'Tue', 'count': 45},
      {'day': 'Wed', 'count': 28},
      {'day': 'Thu', 'count': 38},
      {'day': 'Fri', 'count': 52},
      {'day': 'Sat', 'count': 18},
      {'day': 'Sun', 'count': 12},
    ],
    'weeklyData': List.generate(
      4,
      (i) => {'week': 'Week ${i + 1}', 'count': 150 + (i * 30)},
    ),
    'monthlyData': List.generate(6, (i) {
      final date = DateTime.now().subtract(Duration(days: 30 * (5 - i)));
      return {
        'month': DateFormat('MMM', 'en').format(date),
        'count': 500 + (i * 100),
      };
    }),
    'detectionAccuracy': 92,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: const [
                Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                SizedBox(width: 56, height: 56),
              ],
            ),
            _buildOverviewRow(),
            const SizedBox(height: 16),
            _buildChartsRow(),
            const SizedBox(height: 16),
            _buildBottomChartsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildStatBox(
          Icons.login,
          'In',
          stats['todayInOut']['in'].toString(),
          Colors.green,
        ),
        _buildStatBox(
          Icons.logout,
          'Out',
          stats['todayInOut']['out'].toString(),
          Colors.blue,
        ),
        _buildStatBox(
          Icons.verified,
          'Authorized',
          stats['authorizedVehicles'].toString(),
          Colors.green,
        ),
        _buildStatBox(
          Icons.warning,
          'Unauthorized',
          stats['unauthorizedVehicles'].toString(),
          Colors.red,
        ),
        _buildStatBox(
          Icons.directions_car,
          'Total Vehicles',
          stats['totalVehicles'].toString(),
          Colors.blue,
        ),
        // _buildStatBox(
        //   Icons.warning,
        //   'Unauthorized',
        //   stats['unauthorizedVehicles'].toString(),
        //   Colors.orange,
        // ),
        // _buildStatBox(
        //   Icons.notifications_active,
        //   'Alerts Today',
        //   stats['alerts'].toString(),
        //   Colors.red,
        // ),
      ],
    );
  }

  Widget _buildStatBox(IconData icon, String title, String value, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLineChart('Daily', stats['dailyData'], 'day'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLineChart('Weekly', stats['weeklyData'], 'week'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLineChart(
                  'Monthly',
                  stats['monthlyData'],
                  'month',
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildLineChart('Daily', stats['dailyData'], 'day'),
              const SizedBox(height: 12),
              _buildLineChart('Weekly', stats['weeklyData'], 'week'),
              const SizedBox(height: 12),
              _buildLineChart('Monthly', stats['monthlyData'], 'month'),
            ],
          );
        }
      },
    );
  }

  Widget _buildLineChart(String title, List<dynamic> data, String xField) {
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
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              series: <LineSeries<dynamic, String>>[
                LineSeries<dynamic, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d[xField],
                  yValueMapper: (d, _) => d['count'],
                  markerSettings: const MarkerSettings(isVisible: true),
                  color: Colors.deepPurple,
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(height: 350, child: _buildHourlyChart()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(height: 350, child: _buildDetectionPie()),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              SizedBox(height: 350, child: _buildHourlyChart()),
              const SizedBox(height: 16),
              SizedBox(height: 350, child: _buildDetectionPie()),
            ],
          );
        }
      },
    );
  }

  Widget _buildHourlyChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Activity (last 24 hours)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              series: <LineSeries<Map<String, dynamic>, String>>[
                LineSeries<Map<String, dynamic>, String>(
                  dataSource: stats['recentActivity'],
                  xValueMapper: (d, _) => d['time'],
                  yValueMapper: (d, _) => d['count'],
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

  Widget _buildDetectionPie() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Detection Distribution',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 250,
            child: SfCircularChart(
              legend: Legend(isVisible: true),
              series: <CircularSeries>[
                PieSeries<Map<String, dynamic>, String>(
                  dataSource: [
                    {
                      'type': 'Authorized',
                      'count': stats['authorizedVehicles'],
                      'color': Colors.green,
                    },
                    {
                      'type': 'Unauthorized',
                      'count': stats['unauthorizedVehicles'],
                      'color': Colors.orange,
                    },
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
            label: Text('Detection Accuracy: ${stats['detectionAccuracy']}%'),
            backgroundColor: Colors.blue.shade50,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
