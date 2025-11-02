import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_manager.dart';
import '../providers/app_state.dart';
import '../widgets/Camera/camera_box.dart';

class CameraPage extends StatefulWidget {
  final String locationId;

  const CameraPage({super.key, required this.locationId});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
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
      final allCams = await availableCameras();
      if (allCams.isEmpty) {
        setState(() {
          warning = 'No camera detected';
          loading = false;
        });
        return;
      }

      final manager = context.read<CameraManager>();
      await manager.init(allCams);

      // เช็คว่า init สำเร็จหรือไม่
      if (!manager.isInitialized) {
        setState(() {
          warning = 'Please connect external webcam';
          loading = false;
        });
        return;
      }

      final appState = context.read<AppState>();
      final modelId = appState.getActiveModelFor(widget.locationId);
      manager.updateLocationAndModel(
        location: widget.locationId,
        model: modelId,
      );
      manager.startDetection();

      setState(() => loading = false);
    } catch (e) {
      debugPrint('Error loading cameras: $e');
      setState(() {
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
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
            else
              Consumer<CameraManager>(
                builder: (context, manager, _) {
                  if (!manager.isInitialized || manager.controllers.isEmpty) {
                    return Center(
                      child: Text(
                        warning.isEmpty
                            ? 'Please connect external webcam'
                            : warning,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    );
                  }

                  return Column(
                    children: [
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

                      // แสดงกล้องตามจำนวนที่ เชื่อม 1 - 2 สูงสุดแค่ 2
                      for (int i = 0; i < manager.controllers.length; i++) ...[
                        CameraBox(title: "Camera ${i + 1}", cameraIndex: i),
                        const SizedBox(height: 20),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
