import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'api_service.dart';

class CameraManager extends ChangeNotifier {
  Map<int, CameraController> controllers = {};
  Map<int, String> directions = {};
  Map<int, bool> ocrBusy = {};
  bool isInitialized = false;
  bool detecting = false;
  bool disposing = false;
  bool _initializing = false;

  String? locationId;
  String? modelId;

  Future<void> init(List<CameraDescription> cameras) async {
    debugPrint("init()");
    if (_initializing) {
      debugPrint("⛔ init() skipped (already initializing)");
      return;
    }
    _initializing = true;

    try {
      if (disposing) {
        debugPrint("⏳ Waiting for disposing...");
        while (disposing) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      detecting = false;

      await disposeAllControllers();
      await Future.delayed(const Duration(milliseconds: 150));

      if (cameras.isEmpty) return;

      final filtered = cameras
          .where((cam) => !cam.name.toLowerCase().contains('hp wide vision'))
          .toList();

      final camsToUse = filtered.length > 2 ? filtered.sublist(0, 2) : filtered;
      if (camsToUse.isEmpty) {
        debugPrint("No usable cameras");
        return;
      }

      for (var i = 0; i < camsToUse.length; i++) {
        final cam = camsToUse[i];

        final ctrl = CameraController(
          cam,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await ctrl.initialize();

        controllers[i] = ctrl;
        directions[i] = (i == 0 ? 'in' : 'out');
        ocrBusy[i] = false;

        debugPrint("✅ Camera $i (${directions[i]}) initialized: ${cam.name}");
      }

      isInitialized = true;
      notifyListeners();
    } finally {
      _initializing = false;
    }
  }

  void updateLocationAndModel({String? location, String? model}) {
    locationId = location;
    modelId = model;
    notifyListeners();
  }

  void startDetection() {
    if (!isInitialized) return;
    if (locationId == null || modelId == null) return;
    if (detecting) return;

    debugPrint("🚦 startDetection()");
    disposing = false;
    detecting = true;
    detectLoop();
  }

  Future<void> stopDetection() async {
    if (disposing) return;

    debugPrint("🛑 stopDetection()");
    detecting = false;
    disposing = true;

    await disposeAllControllers();

    disposing = false;
    notifyListeners();
  }

  Future<void> disposeAllControllers() async {
    for (final ctrl in controllers.values) {
      try {
        await ctrl.dispose();
      } catch (_) {}
    }

    controllers.clear();
    directions.clear();
    ocrBusy.clear();
    isInitialized = false;
  }

  Future<void> detectLoop() async {
    debugPrint("🔄 detectLoop START");

    while (detecting && !disposing && locationId != null && modelId != null) {
      final camIds = controllers.keys.toList();
      for (final index in camIds) {
        if (!detecting || disposing) break;

        final controller = controllers[index];
        final direction = directions[index];

        if (controller == null || direction == null) continue;
        if (!controller.value.isInitialized) continue;

        try {
          final pic = await controller.takePicture();
          final bytes = await pic.readAsBytes();

          debugPrint("📸 detect car cam $index ($direction)");
          final result = await ApiService.detectVehicleFrom(bytes);

          if (result == null || result['status'] != 'car_detected') continue;

          await Future.delayed(const Duration(milliseconds: 800));

          if (ocrBusy[index] == true) continue;

          ocrBusy[index] = true;
          unawaited(runOCR(index, direction, controller));
        } catch (e) {
          if (e.toString().contains("Disposed CameraController")) continue;
          debugPrint("❌ detectLoop error cam $index: $e");
        }
      }
    }

    debugPrint("⏹ detectLoop EXIT");
  }

  Future<void> runOCR(
    int index,
    String direction,
    CameraController controller,
  ) async {
    try {
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();

      debugPrint("🔍 OCR ($direction)");
      await ApiService.detect_OCR(
        bytes,
        locationId: locationId!,
        modelId: modelId!,
        direction: direction,
      );

      debugPrint("✅ OCR Done ($direction)");
    } catch (e) {
      debugPrint("❌ OCR Error ($direction): $e");
    } finally {
      ocrBusy[index] = false;
    }
  }

  @override
  Future<void> dispose() async {
    await stopDetection();
    super.dispose();
  }
}
