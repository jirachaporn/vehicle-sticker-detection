import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_manager.dart';
import '../providers/detection_manager.dart';
import '../widgets/Camera/camera_stream.dart';
import '../widgets/Camera/previewcard.dart';
import '../widgets/Camera/camera_button.dart';

class CameraPage extends StatefulWidget {
  final String locationId;
  const CameraPage({super.key, required this.locationId});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final cam = context.read<CameraManager>();
    if (!cam.isCameraOpen) {
      _opening = true;
      cam.openCamera().whenComplete(() {
        if (mounted) setState(() => _opening = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cam = context.watch<CameraManager>();
    final det = context.watch<DetectionManager>();

    // ถ้าเปิดสำเร็จแล้วให้แน่ใจว่าเอาโหลดดิ้งออก
    if (cam.isCameraOpen && _opening) {
      _opening = false;
    }

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
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                CameraButton(
                  cameraOn: cam.isCameraOpen,
                  detectOn: det.isRunning,
                  opening: _opening,
                  onToggleCamera: () async {
                    if (cam.isCameraOpen) {
                      await cam.closeCamera();
                    } else {
                      setState(() => _opening = true);
                      await cam.openCamera();
                      if (mounted) setState(() => _opening = false);
                    }
                  },
                  onToggleDetect: () {
                    if (det.isRunning) {
                      det.stop();
                    } else {
                      det.start();
                    }
                  },
                ),

                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1080,
                    maxHeight: 720,
                  ),
                  child: PreviewCard(
                    isOpen: cam.isCameraOpen,
                    isOpening: _opening,
                    child: const CameraStream(),
                    onRetryOpen: () async {
                      setState(() => _opening = true);
                      await cam.openCamera();
                      if (mounted) setState(() => _opening = false);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
