import 'dart:async';

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
  Map<int, bool> ocrBusy = {};

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
          if (!controller.value.isInitialized || disposing) continue;

          // ถ่ายรูปตรวจรถ
          final image = await controller.takePicture();
          final bytes = await image.readAsBytes();

          debugPrint('📸 ตรวจจับรถ กล้อง $index ($direction)');
          final result = await ApiService.detectVehicleFrom(bytes);

          if (result == null || result['status'] != 'car_detected') {
            debugPrint('❌ ไม่พบรถ (กล้อง $index)');
            continue;
          }
          await Future.delayed(const Duration(milliseconds: 200));

          // ✅ กัน OCR ซ้อน (สำคัญที่สุด)
          if (ocrBusy[index] == true) {
            debugPrint('⏳ OCR ของกล้อง $index กำลังทำงาน → ข้าม');
            continue;
          }

          ocrBusy[index] = true; // ✅ ล็อกไว้ก่อนเริ่ม
          debugPrint('🚗 พบรถที่กล้อง $index ($direction) → เริ่ม OCR');

          unawaited(
            runOCR(
              controller: controller,
              direction: direction!,
              locationId: locationId!,
              modelId: modelId!,
              index: index,
            ),
          );

        } catch (e) {
          if (e.toString().contains('Disposed CameraController')) {
            debugPrint('⚠ กล้อง $index ถูก dispose → ข้าม');
            continue;
          }
          debugPrint('❌ DetectLoop Error ($direction): $e');
        }
      }
    }
  }

  Future<void> runOCR({
    required CameraController controller,
    required String direction,
    required String locationId,
    required String modelId,
    required int index,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final ocrImage = await controller.takePicture();
      final ocrBytes = await ocrImage.readAsBytes();

      debugPrint("🔍 ส่ง OCR ($direction)");
      await ApiService.detect_OCR(
        ocrBytes,
        locationId: locationId,
        modelId: modelId,
        direction: direction,
      );
      debugPrint("✅ OCR สำเร็จ ($direction)");
    } catch (e) {
      debugPrint("❌ OCR Error ($direction): $e");
    } finally {
      ocrBusy[index] = false; 
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
