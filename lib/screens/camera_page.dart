import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/camera_stream.dart';
import '../widgets/detection_overlay.dart';
// import '../widgets/camera_controls.dart';
import '../models/camera_Info.dart';
import '../models/detection_result.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  List<CameraInfo> availableCameras = [];
  Map<int, StreamController<Uint8List>> cameraStreams = {};
  Map<int, List<DetectionResult>> detectionResults = {};
  bool isLoading = true;
  bool isStreaming = false;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  @override
  void dispose() {
    _stopAllStreams();
    _detectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      setState(() => isLoading = true);
      final cameras = await _getAvailableCameras();
      setState(() {
        availableCameras = cameras;
        isLoading = false;
      });
      for (var camera in cameras) {
        cameraStreams[camera.id] = StreamController<Uint8List>.broadcast();
        detectionResults[camera.id] = [];
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to initialize cameras: $e');
    }
  }

  Future<List<CameraInfo>> _getAvailableCameras() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/api/cameras/list'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['cameras'] as List)
            .map((camera) => CameraInfo.fromJson(camera))
            .toList();
      } else {
        throw Exception('Failed to get cameras: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> _stopAllStreams() async {
    setState(() => isStreaming = false);
    _detectionTimer?.cancel();
    for (var controller in cameraStreams.values) {
      await controller.close();
    }
    try {
      await http.post(Uri.parse('http://127.0.0.1:5000/api/cameras/stop_all'));
    } catch (e) {
      print('Error stopping streams: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              const Text(
                'Camera Monitoring',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _initializeCameras, // ฟังก์ชัน Refresh
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // _buildCameraStatus(), // ถ้าต้องการเพิ่ม กลับมาได้
          const SizedBox(height: 24),
          Expanded(child: _buildCameraGridSection()),
        ],
      ),
    );
  }

  Widget _buildCameraGridSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Initializing cameras...'),
                    ],
                  ),
                )
              : availableCameras.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No cameras detected',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check camera connections',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildCameraGrid(),
        );
      },
    );
  }

  Widget _buildCameraGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth >= 1200) {
          crossAxisCount = availableCameras.length > 4 ? 3 : 2;
        } else if (constraints.maxWidth >= 800) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 16 / 9,
          ),
          itemCount: availableCameras.length,
          itemBuilder: (context, index) {
            final camera = availableCameras[index];
            return _buildCameraCard(camera);
          },
        );
      },
    );
  }

  Widget _buildCameraCard(CameraInfo camera) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.videocam, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    camera.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isStreaming
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isStreaming ? 'LIVE' : 'OFF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isStreaming
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                CameraStream(
                  stream: cameraStreams[camera.id]?.stream,
                  isStreaming: isStreaming,
                ),
                if (detectionResults[camera.id]?.isNotEmpty == true)
                  DetectionOverlay(detections: detectionResults[camera.id]!),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Detections: ${detectionResults[camera.id]?.length ?? 0}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
