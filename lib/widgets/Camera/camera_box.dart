import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../providers/api_service.dart';

class CameraFeedBox extends StatefulWidget {
  final String title;
  final CameraDescription camera;
  final int cameraIndex;
  final String locationId;
  final String modelId;
  final String direction;

  const CameraFeedBox({
    super.key,
    required this.title,
    required this.camera,
    required this.cameraIndex,
    required this.locationId,
    required this.modelId,
    required this.direction,
  });

  @override
  State<CameraFeedBox> createState() => _CameraFeedBoxState();
}

class _CameraFeedBoxState extends State<CameraFeedBox> {
  CameraController? _controller;
  bool _isDetecting = false;
  Map<String, dynamic>? _detectionResult;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(
        widget.camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!_controller!.value.isInitialized) return;

      // เริ่ม ImageStream สำหรับตรวจจับแบบ realtime
      _controller!.startImageStream((image) async {
        if (!_isDetecting) {
          _isDetecting = true;

          try {
            Uint8List jpegBytes = ApiService.convertYUV420ToJpeg(image);

            // เรียก API ส่งไป backend
            var result = await ApiService.detectVehicleFrom(
              jpegBytes,
              locationId: widget.locationId,
              modelId: widget.modelId,
              direction: widget.direction,
            );

            if (mounted) {
              setState(() {
                _detectionResult = result;
              });
            }
          } catch (e) {
            debugPrint('Error detecting vehicle: $e');
          } finally {
            _isDetecting = false;
          }
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera ${widget.cameraIndex}: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                if (_detectionResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Detected: ${_detectionResult!['count']} vehicles',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Camera preview
          Container(
            height: 400,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: _controller == null || !_controller!.value.isInitialized
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : CameraPreview(_controller!),
            ),
          ),
        ],
      ),
    );
  }
}
