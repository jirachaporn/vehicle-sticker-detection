// camera_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../widgets/Camera/camera_box.dart';

class CameraPage extends StatefulWidget {
  final String locationId;
  const CameraPage({super.key, required this.locationId});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  List<CameraDescription> cameras = [];
  String warning = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCameras();
  }

  Future<void> loadCameras() async {
    setState(() => loading = true);
    try {
      final cams = await availableCameras();
      debugPrint('Found ${cams.length} cameras');

      if (cams.isEmpty) {
        setState(() {
          cameras = [];
          warning = 'Unable to connect to webcam';
          loading = false;
        });
        return;
      }

      List<CameraDescription> validCameras = cams.length > 2
          ? cams.sublist(0, 2)
          : cams;

      setState(() {
        cameras = validCameras;
        warning = cams.length > 2
            ? 'If more than 2 cameras are found, only the first 2 will be displayed.'
            : '';
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading cameras: $e');
      setState(() {
        cameras = [];
        warning = 'An error occurred while connecting the camera: $e';
        loading = false;
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
                  'Camera',
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
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (cameras.isEmpty)
              buildWarning('No camera connection')
            else ...[
              if (warning.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    warning,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              for (int i = 0; i < cameras.length; i++) ...[
                CameraFeedBox(
                  title: "Camera ${i + 1}",
                  camera: cameras[i],
                  cameraIndex: i, locationId: '', modelId: '', direction: '',
                ),
                const SizedBox(height: 20),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget buildWarning(String message) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 40),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.orange)),
        ],
      ),
    );
  }
}

