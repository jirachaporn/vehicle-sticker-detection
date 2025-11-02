import 'package:flutter/material.dart';
import '../widgets/overview/overview_row.dart';
import '../widgets/overview/overview_chart.dart';
import '../widgets/overview/overview_bottom_charts.dart';
import '../providers/api_service.dart';

class OverviewPage extends StatefulWidget {
  final String locationId;
  const OverviewPage({super.key, required this.locationId});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Map<String, dynamic> stats = {};
  bool isLoading = true;
  final ApiService api = ApiService();

  @override
  void initState() {
    super.initState();
    fetchOverviewData();
  }

  Future<void> fetchOverviewData() async {
    try {
      final data = await api.fetchOverviewData(widget.locationId);
      if (!mounted) return;

      if (data != null) {
        setState(() {
          stats = data;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error loading overview data: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

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
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(50),
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
            else if (stats.isEmpty)
              const Padding(
                padding: EdgeInsets.all(50),
                child: Text('No data available'),
              )
            else ...[
              OverviewRow(stats),
              const SizedBox(height: 16),
              ChartsRow(stats),
              const SizedBox(height: 16),
              BottomChartsRow(stats),
            ],
          ],
        ),
      ),
    );
  }
}
