import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'api_service.dart';

class CameraManager extends ChangeNotifier {
  CameraController? controller;
  bool isInitialized = false;
  String? locationId;
  String? modelId;
  bool _detecting = false;

  Future<void> init(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) return;
    if (controller != null) {
      await controller!.dispose(); // Dispose old camera
      controller = null;
      isInitialized = false;
    }

    controller = CameraController(cameras.first, ResolutionPreset.medium);
    await controller!.initialize();
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
    controller?.dispose(); // Properly dispose the controller
    controller = null;
  }

  void _detectLoop() async {
    while (_detecting && locationId != null && modelId != null) {
      if (controller != null && controller!.value.isInitialized) {
        try {
          final image = await controller!.takePicture();
          final bytes = await image.readAsBytes();

          await ApiService.detectVehicleFrom(
            bytes,
            locationId: locationId!,
            modelId: modelId!,
            direction: 'in',
          );
        } catch (e) {
          debugPrint('Camera detection error: $e');
        }
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
