import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'api_service.dart';

class CameraManager extends ChangeNotifier {
  Map<int, CameraController> controllers = {};
  bool isInitialized = false;
  String? locationId;
  String? modelId;
  bool detecting = false;

  Future<void> init(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) return;

    final filteredCams = cameras.where((cam) {
      return !cam.name.toLowerCase().contains('hp wide vision');
    }).toList();

    // ใช้ได้สูงสุด 2 กล้อง
    final camsToUse = filteredCams.length > 2
        ? filteredCams.sublist(0, 2)
        : filteredCams;

    if (camsToUse.isEmpty) {
      debugPrint('No external webcam found after filtering');
      return;
    }

    // ปิดการใช้งานกล้องเก่าทุกตัว
    for (var controller in controllers.values) {
      await controller.dispose();
    }
    controllers.clear();

    // สร้างและ initialize กล้องใหม่
    for (var i = 0; i < camsToUse.length; i++) {
      final camera = camsToUse[i];
      final controller = CameraController(camera, ResolutionPreset.medium);
      await controller.initialize();
      controllers[i] = controller;
      debugPrint('Initialized camera $i: ${camera.name}');
    }

    isInitialized = true;
    notifyListeners();
  }

  void updateLocationAndModel({String? location, String? model}) {
    locationId = location;
    modelId = model;
    notifyListeners();
  }

  void startDetection() {
    if (!isInitialized || locationId == null || modelId == null) return;
    if (detecting) return;
    detecting = true;
    detectLoop();
  }

  void stopDetection() {
    detecting = false;
    for (var controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
  }

  void detectLoop() async {
    while (detecting && locationId != null && modelId != null) {
      try {
        for (var entry in controllers.entries) {
          final index = entry.key;
          final controller = entry.value;

          if (controller.value.isInitialized) {
            final image = await controller.takePicture();
            final bytes = await image.readAsBytes();
            final direction = index == 0 ? 'in' : 'out';
            await ApiService.detectVehicleFrom(
              bytes,
              locationId: locationId!,
              modelId: modelId!,
              direction: direction,
            );

            debugPrint(
              'Camera $index sent detection with direction: $direction',
            );
          }
        }
      } catch (e) {
        debugPrint('Camera detection error: $e');
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    stopDetection();
    super.dispose();
  }
}