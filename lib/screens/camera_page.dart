import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// พอยต์แบ็คเอนด์
const String kMobileDesktopBase = 'http://127.0.0.1:5000';
const String kWebBase = 'http://localhost:5000';
String _backendBase() => kIsWeb ? kWebBase : kMobileDesktopBase;

/// FPS ที่จะดึงเฟรม
const double _fps = 8;
Duration get _interval => Duration(milliseconds: (1000 / _fps).round());

class CameraPage extends StatefulWidget {
  final String locationId;
  const CameraPage({super.key, required this.locationId});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final _db = Supabase.instance.client;

  bool _starting = false;
  bool _running = false;
  String? _error;

  // โมเดล/ภาพอ้างอิง
  String? _modelName;
  String? _modelUrl;
  List<String> _imageUrls = [];

  // เฟรมสด
  Uint8List? _frameBytes;
  Timer? _timer;
  Timer? _watchdog;
  int _tick = 0;

  // ดีบักเน็ตเวิร์ค
  String? _lastUrl;
  int? _lastStatus;
  String? _lastCT;
  int? _lastLen;
  String? _lastHttpErr;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    await _loadActiveModel();
    await _startCamera();
  }

  Future<void> _loadActiveModel() async {
    try {
      final res = await _db
          .from('model')
          .select('model_name, model_url, image_urls')
          .eq('location_id', widget.locationId)
          .eq('is_active', true)
          .limit(1);

      if (res.isNotEmpty) {
        final row = res.first;
        setState(() {
          _modelName = (row['model_name'] ?? '') as String;
          _modelUrl = (row['model_url'] ?? '') as String;
          final imgs = row['image_urls'];
          _imageUrls =
              (imgs is List) ? imgs.whereType<String>().toList() : <String>[];
        });
      } else {
        setState(() {
          _modelName = null;
          _modelUrl = null;
          _imageUrls = [];
          _error = 'ไม่พบโมเดลที่ Active สำหรับ Location นี้';
        });
      }
    } catch (e) {
      setState(() => _error = 'โหลดโมเดลล้มเหลว: $e');
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse('${_backendBase()}/start-camera'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'location_id': widget.locationId}),
      );

      if (res.statusCode == 200) {
        setState(() => _running = true);

        // เริ่มลูปทันที
        _startLoop();

        // ยิงครั้งแรกให้แน่ใจว่า tick เด้ง
        Future.microtask(_fetch);

        // ถ้ายังไม่เด้งใน 2 วิ ให้รีสตาร์ทลูป
        _watchdog?.cancel();
        _watchdog = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (_running && _tick == 0) {
            debugPrint('Watchdog: no tick yet -> restart loop');
            _startLoop();
            Future.microtask(_fetch);
          }
        });
      } else {
        setState(() {
          _running = false;
          _error = _extractError(res.body) ?? 'Start camera failed';
        });
      }
    } catch (e) {
      setState(() {
        _running = false;
        _error = 'Start error: $e';
      });
    } finally {
      setState(() => _starting = false);
    }
  }

  void _startLoop() {
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer.periodic(_interval, (_) => _fetch());
  }

  Future<void> _fetch() async {
    if (!_running) return;

    // ❗ ปลอดภัยบน Web: ห้ามใช้ (1<<32) เพราะบน JS = 0
    final rnd = Random().nextInt(0x3fffffff) + 1; // 1..1073741823

    final url =
        '${_backendBase()}/frame?_=${DateTime.now().millisecondsSinceEpoch}&r=$rnd';

    setState(() {
      _tick++;
      _lastUrl = url;
      _lastHttpErr = null;
    });

    try {
      // ไม่ส่ง header พิเศษ เพื่อตัด preflight
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      _lastStatus = resp.statusCode;
      _lastCT = resp.headers['content-type'];
      _lastLen = resp.bodyBytes.length;

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      if (resp.bodyBytes.isEmpty) {
        throw Exception('bytes = 0');
      }

      setState(() => _frameBytes = resp.bodyBytes);
    } catch (e) {
      setState(() => _lastHttpErr = e.toString());
    }
  }

  String? _extractError(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['error'] != null) return m['error'].toString();
      if (m is Map && m['message'] != null) return m['message'].toString();
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.videocam, size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'Camera Monitoring',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  _statusChip(),
                ],
              ),
              const SizedBox(height: 12),

              _buildModelPanel(),
              const SizedBox(height: 16),

              if (_error != null) _errorBox(_error!),
              const SizedBox(height: 12),

              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _frameBytes == null
                          ? const Center(
                              child: Text(
                                'กำลังดึงภาพ...',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _frameBytes!,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              _netDebugPanel(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _startCamera();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Restart stream'),
      ),
    );
  }

  Widget _statusChip() {
    if (_starting) {
      return const Chip(
        avatar: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('Starting...'),
      );
    }
    if (_running) {
      return const Chip(
        avatar: Icon(Icons.check_circle, color: Colors.green),
        label: Text('Running'),
        backgroundColor: Color(0xFFE8F5E9),
      );
    }
    return const Chip(
      avatar: Icon(Icons.pause_circle_filled, color: Colors.orange),
      label: Text('Idle'),
      backgroundColor: Color(0xFFFFF3E0),
    );
  }

  Widget _buildModelPanel() {
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F1FF),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.purpleAccent.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Active Model',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Name: ',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Expanded(
                  child: Text(
                    _modelName ?? '-',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('URL: ',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Expanded(
                  child: Text(
                    _modelUrl?.isNotEmpty == true ? _modelUrl! : '-',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_imageUrls.isNotEmpty)
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final u = _imageUrls[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 1.6,
                        child: Image.network(
                          u,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              const Text(
                'ยังไม่มีรูปอ้างอิง (image_urls) จาก Cloudinary',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _loadActiveModel();
              await _startCamera();
            },
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Widget _netDebugPanel() {
    final style =
        TextStyle(color: Colors.black.withOpacity(0.75), fontSize: 12);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DefaultTextStyle(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Network Debug',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('tick: $_tick'),
            Text('GET: ${_lastUrl ?? "-"}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('status: ${_lastStatus ?? "-"}'),
            Text('content-type: ${_lastCT ?? "-"}'),
            Text('length: ${_lastLen ?? "-"}'),
            if (_lastHttpErr != null) Text('error: $_lastHttpErr'),
          ],
        ),
      ),
    );
  }
}
