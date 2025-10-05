// import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ตัวหลัก
class DataTablePage extends StatefulWidget {
  final String locationId;
  const DataTablePage({super.key, required this.locationId});

  @override
  State<DataTablePage> createState() => _DataTablePageState();
}

class _DataTablePageState extends State<DataTablePage> {
  // ตัวแปร
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _vScrollCtrl = ScrollController();

  // All | OK | Exited | Alert
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

  Future<void> fetchDetections() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final res = await supabase
          .from('detections')
          .select()
          .eq('location_id', widget.locationId)
          .order('detected_at', ascending: false);
      setState(() => detections = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      setState(() => errorText = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  // กรองข้อมูล
  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();

    return detections.where((d) {
      final p = parsePlate(d['detected_plate']);
      final lp = (p['lp_number'] ?? '').toString().toLowerCase();
      final brand = (p['vehicle_brand'] ?? '').toString().toLowerCase();
      final type = (p['vehicle_body_type'] ?? '').toString().toLowerCase();
      final matchSearch =
          q.isEmpty || lp.contains(q) || brand.contains(q) || type.contains(q);

      // map เป็นสถานะแบบใหม่: OK | Exited | Alert
      final dir = (d['direction']?.toString() ?? '').toLowerCase(); // in|out
      final isSticker = d['is_sticker'] == true;

      final status = statusOfRow(direction: dir, isSticker: isSticker).$1;

      final matchStatus = selectedStatus == 'All' || selectedStatus == status;

      return matchSearch && matchStatus;
    }).toList();
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
                  ? Center(child: Text('Load failed\n$errorText'))
                  : buildTable(),
            ),
          ],
        ),
      ),
    );
  }

  // วิดเจ็ตย่อย

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
          // Search Field
          Expanded(
            flex: 8,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search License or Type',
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
          // Status Filter Dropdown (All | OK | Exited | Alert)
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: selectedStatus,
              isExpanded: true, // 👈 กันข้อความล้น
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
                  // 👈 label เป็นสีดำ
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 2,
                  ),
                ),
              ),
              items: const ['All', 'OK', 'Exited', 'Alert']
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s,
                      child: Text(
                        s,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => selectedStatus = v);
              },
              validator: (_) => null,
            ),
          ),
        ],
      ),
    );
  }

  // ตาราง
  Widget buildTable() {
    final data = _filtered;
    if (data.isEmpty) return const Center(child: Text('No records'));

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
              DataColumn(label: Text("TYPE")),
              DataColumn(label: Text("STATUS")),
              DataColumn(label: Text("TIMESTAMP")),
              DataColumn(label: Text("CONFIDENCE")),
              DataColumn(label: Text("IMAGE")),
            ],
            rows: data.map((d) {
              final plate = parsePlate(d['detected_plate']);
              final vehId = shortId(d['detections_id']);
              final lp = (plate['lp_number'] ?? '-').toString();
              final bodyType = (plate['vehicle_brand'] ?? '-').toString();
              final ts = fmtTime(d['detected_at']);
              final conf = (plate['conf'] is num)
                  ? '${(plate['conf'] as num).toStringAsFixed(1)}%'
                  : '-';

              final status = statusOfRow(
                direction: d['direction']?.toString(),
                isSticker: d['is_sticker'] == true,
              );
              final imgUrl = firstImageUrl(d['image_path']);

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      vehId,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(
                    Text(
                      lp,
                      style: const TextStyle(
                        color: Color(0xFF1E88E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text(bodyType)),
                  DataCell(statusChip(status.$1, status.$2)),
                  DataCell(Text(ts)),
                  DataCell(Text(conf)),
                  DataCell(
                    IconButton(
                      tooltip: 'View image',
                      icon: const Icon(Icons.remove_red_eye_outlined),
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

  // utils
  Map<String, dynamic> parsePlate(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? m : {};
    } catch (_) {
      return {};
    }
  }

  String? firstImageUrl(dynamic imagePath) {
    try {
      if (imagePath == null) return null;
      if (imagePath is String) {
        final s = imagePath.trim();
        if (s.isEmpty) return null;
        if (s.startsWith('[')) {
          final list = jsonDecode(s);
          if (list is List && list.isNotEmpty) {
            final v = list.first;
            return v is String ? v : null;
          }
          return null;
        }
        return s;
      }
      if (imagePath is List && imagePath.isNotEmpty) {
        final v = imagePath.first;
        return v is String ? v : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String fmtTime(dynamic v) {
    if (v == null) return '-';
    try {
      final dt = v is DateTime ? v : DateTime.parse(v.toString());
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
    } catch (_) {
      return '-';
    }
  }

  // แปลงสถานะ: ไม่มีป้าย = Alert (แดง), out = Exited (เทา), in = OK (ฟ้า)
  (String, Color) statusOfRow({String? direction, required bool isSticker}) {
    final dir = (direction ?? '').toLowerCase();

    if (!isSticker) return ('Alert', const Color(0xFFE53935)); // แดง
    if (dir == 'out') return ('Exited', const Color(0xFF9E9E9E)); // เทา
    if (dir == 'in') return ('OK', const Color(0xFF1E88E5)); // ฟ้า

    // เผื่อกรณีอื่น ๆ ถือเป็น OK (ฟ้า)
    return ('OK', const Color(0xFF1E88E5));
  }

  String shortId(dynamic v) {
    final s = v?.toString() ?? '-';
    if (s.length <= 8) return s;
    return '${s.substring(0, 3)}${s.substring(s.length - 3)}';
  }

  // วิดเจ็ตย่อย
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
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

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
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 400),
            child: (url == null)
                ? const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 48),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
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
}
