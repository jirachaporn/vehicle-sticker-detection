import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/annotation/annotation_card.dart';
import '../widgets/annotation/annotation_dialog.dart';

class AnnotationPage extends StatefulWidget {
  const AnnotationPage({super.key});

  @override
  State<AnnotationPage> createState() => _AnnotationPageState();
}

class _AnnotationPageState extends State<AnnotationPage> {
  final supa = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> models = [];

  // สถานะที่มีในระบบ
  final List<String> statusList = ['all', 'processing', 'ready', 'failed'];

  // ค่าเริ่มต้นให้เลือก "all" เสมอ และจะไม่รีเซ็ตเป็น null
  String statusFilter = 'all';

  // ตัวนับแต่ละสถานะ
  Map<String, int> counts = {
    'all': 0,
    'processing': 0,
    'ready': 0,
    'failed': 0,
  };

  Color statusColor(String s) {
    switch (s) {
      case 'processing':
        return const Color(0xFFF0B917);
      case 'failed':
        return const Color(0xFFD12E2B);
      case 'ready':
        return const Color(0xFF268D2B);
      default:
        return const Color(0xFF1E63E9); // all
    }
  }

  @override
  void initState() {
    super.initState();
    _reloadPage();
  }

  Future<void> _reloadPage() async {
    if (!mounted) return;
    setState(() => loading = true);
    await _fetchModels();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _fetchModels() async {
    // ดึงข้อมูลจากตาราง model
    final data = await supa
        .from('model')
        .select(
          'model_id, model_name, image_urls, sticker_status, model_url, location_id, created_at',
        )
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> list = [];
    final next = {'all': 0, 'processing': 0, 'ready': 0, 'failed': 0};

    for (final row in data) {
      final m = Map<String, dynamic>.from(row as Map);

      // แปลง image_urls ให้เป็น List<String> ง่ายๆ
      final raw = m['image_urls'];
      List<String> urls = [];
      if (raw is List) {
        urls = raw.map((e) => e.toString()).toList();
      } else if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            urls = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          // ถ้า parse ไม่ได้ ปล่อยว่าง
        }
      }
      m['image_urls'] = urls;

      // ลดรูปสถานะให้เป็นตัวพิมพ์เล็ก
      final s = (m['sticker_status'] ?? 'processing')
          .toString()
          .toLowerCase()
          .trim();
      m['sticker_status'] = s;

      // นับจำนวน
      next['all'] = (next['all'] ?? 0) + 1;
      if (next.containsKey(s)) {
        next[s] = (next[s] ?? 0) + 1;
      }

      list.add(m);
    }

    if (!mounted) return;
    setState(() {
      models = list;
      counts = next;
    });
  }

  // กรองรายการง่ายๆ
  List<Map<String, dynamic>> get filteredModels {
    if (statusFilter == 'all') return models;
    return models
        .where((m) => (m['sticker_status'] ?? '').toString() == statusFilter)
        .toList();
  }

  Future<void> _openDialog(Map<String, dynamic> m) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnnotationDialog(
        modelId: m['model_id'].toString(),
        modelName: (m['model_name'] ?? '').toString(),
        imageUrls: (m['image_urls'] as List).cast<String>(),
        stickerStatus: (m['sticker_status'] ?? 'processing').toString(),
        modelUrl: m['model_url'] as String?,
        createdAt: DateTime.tryParse('${m['created_at']}'),
      ),
    );
    if (changed == true) {
      await _reloadPage();
    }
  }

  String _label(String s) =>
      s == 'all' ? 'All' : '${s[0].toUpperCase()}${s.substring(1)}';

  // วาดชิปตัวกรองแบบง่ายๆ
  Widget _buildStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusList.map((s) {
          final isSelected = statusFilter == s;
          final base = statusColor(s);
          final selectedColor = base;
          final unselectedColor = Colors.grey.shade200;
          final cnt = counts[s] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_label(s)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$cnt',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (_) {
                // ถ้ากดซ้ำอันเดิม -> ไม่ทำอะไร
                if (!isSelected) {
                  setState(() => statusFilter = s);
                }
              },
              showCheckmark: isSelected,
              checkmarkColor: Colors.white,
              selectedColor: selectedColor,
              backgroundColor: unselectedColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? base : Colors.grey.shade400,
                ),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ส่วนรายการการ์ดแบบง่ายๆ
  Widget _buildCards() {
    if (loading) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (models.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('ยังไม่มีข้อมูลโมเดลในระบบ'),
      );
    }

    final items = filteredModels;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items.map((m) {
          final urls = (m['image_urls'] as List).cast<String>();
          return AnnotationCard(
            modelName: (m['model_name'] ?? '').toString(),
            imageUrls: urls,
            onTap: () => _openDialog(m),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // หัวข้อ
            const Text(
              'Annotation',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // แถวตัวกรอง + ปุ่ม reload
            Row(
              children: [
                Expanded(child: _buildStatusChips()),
                IconButton(
                  tooltip: 'Reload',
                  onPressed: loading ? null : _reloadPage,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // เนื้อหา: การ์ด
            _buildCards(),
          ],
        ),
      ),
    );
  }
}
