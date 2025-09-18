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
  bool _loading = true;
  List<Map<String, dynamic>> _models = [];

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    await _logWhoAmI(); // ✅ เช็คว่าเป็น admin แล้วหรือยัง
    await _fetchAllModels(); // ✅ ดึง "ทุกรายการ" จาก model
  }

  Future<void> _logWhoAmI() async {
    final s = supa.auth.currentSession;
    debugPrint('Auth uid=${s?.user.id} email=${s?.user.email}');
    final isAdmin = await supa.rpc('is_admin'); // ต้องมีฟังก์ชันนี้ใน DB
    debugPrint('is_admin() => $isAdmin');
  }

  Future<void> _fetchAllModels() async {
    try {
      final List<dynamic> data = await supa
          .from('model')
          .select(
            'model_id, model_name, image_urls, sticker_status, model_url, location_id, created_at',
          )
          .order('created_at', ascending: false); // ❌ ไม่มี .eq() ใดๆ

      final rows = data.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        // image_urls -> List<String>
        final raw = m['image_urls'];
        List<String> urls = [];
        if (raw is List) {
          urls = raw.map((x) => x.toString()).toList();
        } else if (raw is String) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              urls = decoded.map((x) => x.toString()).toList();
            }
          } catch (_) {}
        }
        m['image_urls'] = urls;
        return m;
      }).toList();

      if (!mounted) return;
      setState(() {
        _models = rows;
        _loading = false;
      });

      debugPrint('Fetched models: ${rows.length}');
      if (rows.isNotEmpty) debugPrint('First row: ${rows.first}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('โหลดโมเดลล้มเหลว: $e')));
    }
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
    if (changed == true) await _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // ✅ จาก center -> start
          children: [
            Row(
              children: [
                const Text(
                  'Annotation',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Reload',
                  onPressed: _loading ? null : _reloadAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 26),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_models.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('ยังไม่มีข้อมูลโมเดลในระบบ'),
              )
            else
              SizedBox(
                // ✅ ให้กินความกว้างทั้งแถว แล้วจัดซ้าย
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.start, // ✅ จัดซ้าย
                  runAlignment: WrapAlignment.start, // ✅ จัดซ้ายทุกบรรทัด
                  crossAxisAlignment: WrapCrossAlignment.start,
                  spacing: 24,
                  runSpacing: 24,
                  children: _models.map((m) {
                    final urls = (m['image_urls'] as List).cast<String>();
                    return AnnotationCard(
                      modelName: (m['model_name'] ?? '').toString(),
                      imageUrls: urls,
                      onTap: () => _openDialog(m),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
