import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'api_service.dart';

class CameraManager extends ChangeNotifier {
  Map<int, CameraController> controllers = {};
  bool isInitialized = false;
  String? locationId;
  String? modelId;
  bool _detecting = false;

  Future<void> init(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) return;

    // 🎯 กรอง HP Wide Vision ออกก่อน
    final filteredCams = cameras.where((cam) {
      return !cam.name.toLowerCase().contains('hp wide vision');
    }).toList();

    // ✅ ใช้ได้สูงสุด 2 กล้อง
    final camsToUse = filteredCams.length > 2
        ? filteredCams.sublist(0, 2)
        : filteredCams;

    if (camsToUse.isEmpty) {
      debugPrint('⚠️ No external webcam found after filtering');
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
      debugPrint('✅ Initialized camera $i: ${camera.name}');
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
    if (_detecting) return;
    _detecting = true;
    _detectLoop();
  }

  void stopDetection() {
    _detecting = false;
    for (var controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
  }

  void _detectLoop() async {
    while (_detecting && locationId != null && modelId != null) {
      try {
        for (var controller in controllers.values) {
          if (controller.value.isInitialized) {
            final image = await controller.takePicture();
            final bytes = await image.readAsBytes();

            await ApiService.detectVehicleFrom(
              bytes,
              locationId: locationId!,
              modelId: modelId!,
              direction: 'in',
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