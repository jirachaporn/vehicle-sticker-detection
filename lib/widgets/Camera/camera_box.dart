

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_manager.dart';

class CameraBox extends StatelessWidget {
  final String title;
  final int cameraIndex;

  const CameraBox({super.key, required this.title, required this.cameraIndex});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<CameraManager>();
    final controller =
        manager.controllers[cameraIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:  0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Color(0xFF119928)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Camera preview
          Container(
            height: 700, // กำหนดความสูงของกล้อง
            width: double.infinity, // กำหนดความกว้างของกล้องให้เต็ม
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: controller == null || !controller.value.isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: controller.value.previewSize!.width,
                      height: controller.value.previewSize!.height,
                      child: CameraPreview(controller),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
