import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'api_service.dart';

class CameraManager extends ChangeNotifier {
  Map<int, CameraController> controllers = {};
  Map<int, String> directions = {};
  bool isInitialized = false;
  String? locationId;
  String? modelId;
  bool detecting = false;
  bool disposing = false;

  Future<void> init(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) return;

    final filteredCams = cameras.where((cam) {
      return !cam.name.toLowerCase().contains('hp wide vision');
    }).toList();

    final camsToUse = filteredCams.length > 2
        ? filteredCams.sublist(0, 2)
        : filteredCams;

    if (camsToUse.isEmpty) {
      debugPrint('No external webcam found after filtering');
      return;
    }

    // ปิดกล้องเก่าทั้งหมดก่อนสร้างใหม่
    await disposeAllControllers();

    // สร้างกล้องใหม่และตั้ง direction
    for (var i = 0; i < camsToUse.length; i++) {
      final camera = camsToUse[i];
      final controller = CameraController(camera, ResolutionPreset.medium);
      await controller.initialize();
      controllers[i] = controller;

      final dir = i == 0 ? 'in' : 'out';
      directions[i] = dir;

      debugPrint('Initialized camera $i ($dir): ${camera.name}');
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
    disposing = false;
    detectLoop();
  }

  Future<void> stopDetection() async {
    detecting = false;
    disposing = true;
    await disposeAllControllers();
    disposing = false;
  }

  Future<void> disposeAllControllers() async {
    for (var controller in controllers.values) {
      try {
        if (controller.value.isInitialized) {
          await controller.dispose();
        }
      } catch (e) {
        debugPrint('⚠️ Error disposing controller: $e');
      }
    }
    controllers.clear();
    directions.clear();
  }

  Future<void> detectLoop() async {
    debugPrint('\n=== detectLoop STARTED ===');
    while (detecting && !disposing && locationId != null && modelId != null) {
      for (var entry in controllers.entries) {
        if (!detecting || disposing) break;

        final index = entry.key;
        final controller = entry.value;
        final direction = directions[index];
        try {
          if (controller.value.isInitialized && !disposing) {
            final image = await controller.takePicture();
            final bytes = await image.readAsBytes();

            await ApiService.detectVehicleFrom(
              bytes,
              locationId: locationId!,
              modelId: modelId!,
              direction: direction!,
            );
          }
        } catch (e) {
          if (e.toString().contains('Disposed CameraController')) {
            debugPrint('Camera $index ($direction) was disposed mid-detection');
            detecting = false;
            break;
          } else {
            debugPrint('Camera detection error ($direction): $e');
          }
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    detecting = false;
    disposing = true;
    await disposeAllControllers();
    disposing = false;
    super.dispose();
  }
}
