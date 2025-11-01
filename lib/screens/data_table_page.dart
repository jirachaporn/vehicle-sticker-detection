import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DataTablePage extends StatefulWidget {
  final String locationId;
  const DataTablePage({super.key, required this.locationId});

  @override
  State<DataTablePage> createState() => _DataTablePageState();
}

class _DataTablePageState extends State<DataTablePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _vScrollCtrl = ScrollController();

  String selectedStatus = 'All';
  bool loading = false;
  String? errorText;
  List<Map<String, dynamic>> detections = [];

  @override
  void initState() {
    super.initState();
    fetchDetections();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  // ดึงข้อมูลจาก API
  Future<void> fetchDetections() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    final Uri url = Uri.parse(
      'http://127.0.0.1:8000/table/${widget.locationId}/records',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          detections = List<Map<String, dynamic>>.from(data['items'] ?? []);
        });
      } else {
        setState(
          () => errorText = 'Failed to load data (${response.statusCode})',
        );
      }
    } catch (e, stackTrace) {
      setState(() => errorText = e.toString());
      debugPrint('Error: $errorText');
      debugPrint('StackTrace: $stackTrace');
    } finally {
      setState(() => loading = false);
    }
  }

  // ฟิลเตอร์การค้นหาและกรองสถานะ
  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return detections.where((d) {
      final lp = (d['license_plate'] ?? '').toString().toLowerCase();
      final typecar = (d['type_car'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || lp.contains(q) || typecar.contains(q);

      // ฟิลเตอร์ตามสถานะ
      final dir = (d['direction']?.toString() ?? '').toLowerCase();
      final status = statusOfRow(
        direction: dir,
        isSticker: d['sticker'] == true,
      ).$1;
      final matchStatus = selectedStatus == 'All' || selectedStatus == status;

      return matchSearch && matchStatus;
    }).toList();
  }

  (String, Color) statusOfRow({String? direction, required bool isSticker}) {
    final dir = (direction ?? '').toLowerCase();
    if (!isSticker) return ('Alert', const Color(0xFFE53935));
    if (dir == 'out') return ('Exited', const Color(0xFF9E9E9E));
    if (dir == 'in') return ('OK', const Color(0xFF1E88E5));
    return ('OK', const Color(0xFF1E88E5));
  }

  // build หลัก
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
                  'Vehicle Table Data',
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
            const SizedBox(height: 16),
            buildFilters(),
            const SizedBox(height: 16),
            Container(
              height: 520,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : (errorText != null)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Load failed\n$errorText',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : buildTable(),
            ),
          ],
        ),
      ),
    );
  }

  // ตารางข้อมูล
  Widget buildTable() {
    final data = _filtered;
    if (data.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No records found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      controller: _vScrollCtrl,
      child: SingleChildScrollView(
        controller: _vScrollCtrl,
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            columnSpacing: 22,
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dividerThickness: 0.6,
            columns: const [
              DataColumn(label: Text("VEHICLE ID")),
              DataColumn(label: Text("LICENSE PLATE")),
              DataColumn(label: Text("PROVINCE")),
              DataColumn(label: Text("TYPE")),
              DataColumn(label: Text("COLOR")),
              DataColumn(label: Text("STATUS")),
              DataColumn(label: Text("TIMESTAMP")),
              DataColumn(label: Text("IMAGE")),
            ],
            rows: data.map((d) {
              final vehId = shortId(d['detections_id']);
              final lp = (d['license_plate'] ?? '-').toString();
              final province = (d['province'] ?? '-').toString();
              final typecar = (d['type_car'] ?? '-').toString();
              final color = (d['vehicle_color'] ?? '-').toString();
              final ts = fmtTime(d['timestamp']);
              final imgUrl = d['actions']?.toString();

              // คำนวณ status
              final dir = (d['direction']?.toString() ?? '').toLowerCase();
              final statusInfo = statusOfRow(
                direction: dir,
                isSticker: d['sticker'] == true,
              );

              return DataRow(
                cells: [
                  DataCell(Text(vehId, style: const TextStyle(fontSize: 13))),
                  DataCell(Text(lp, style: const TextStyle(fontSize: 13))),
                  DataCell(
                    Text(province, style: const TextStyle(fontSize: 13)),
                  ),
                  DataCell(Text(typecar, style: const TextStyle(fontSize: 13))),
                  DataCell(Text(color, style: const TextStyle(fontSize: 13))),
                  DataCell(statusChip(statusInfo.$1, statusInfo.$2)),
                  DataCell(Text(ts, style: const TextStyle(fontSize: 13))),
                  DataCell(
                    IconButton(
                      tooltip: 'View image',
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                      onPressed: () => viewImage(imgUrl),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // viewImage ฟังก์ชันสำหรับการแสดงภาพ
  void viewImage(String? url) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(5),
          title: const Text(
            'Preview',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
            child: (url == null || url.isEmpty)
                ? const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 48),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) {
                      return const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48),
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // utils
  String fmtTime(dynamic v) {
    if (v == null) return '-';
    try {
      final dt = v is DateTime ? v : DateTime.parse(v.toString());
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
    } catch (_) {
      return v.toString();
    }
  }

  String shortId(dynamic v) {
    final s = v?.toString() ?? '-';
    if (s == '-') return s;
    return s.length <= 8
        ? s
        : '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  Widget statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ฟิลเตอร์การค้นหา
  Widget buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search License Plate or Type',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: selectedStatus,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black54,
              ),
              iconSize: 24,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Status Filter',
                labelStyle: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 2,
                  ),
                ),
              ),
              items: ['All', 'OK', 'Alert', 'Exited'].map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedStatus = val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
