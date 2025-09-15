// camera_manager.dart - เพิ่มการจัดการ generation เพื่อป้องกันภาพเก่า

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class CameraManager extends ChangeNotifier {
  final ApiService api;
  String locationId;

  CameraManager({
    required this.api,
    required this.locationId,
  });

  bool _isCameraOpen = false;
  bool get isCameraOpen => _isCameraOpen;

  bool _busy = false;
  bool get isBusy => _busy;

  int _cameraGeneration = 0;
  int get cameraGeneration => _cameraGeneration;

  void updateLocation(String newLocationId) {
    if (newLocationId.isEmpty || newLocationId == locationId) return;
    locationId = newLocationId;
  }

  Future<void> openCamera() async {
    if (_busy || _isCameraOpen) return;
    _busy = true; 
    notifyListeners();

    try {
      // รอให้กล้องเก่าปิดสมบูรณ์ก่อน (ถ้ามี)
      if (_isCameraOpen) {
        await closeCamera();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ok = await api.startCamera(locationId);
      if (ok) {
        _isCameraOpen = true;
        _cameraGeneration++; // เพิ่ม generation ทุกครั้งที่เปิดใหม่
        debugPrint('📷 Camera opened, generation: $_cameraGeneration');
      }
    } catch (e) {
      debugPrint('❌ openCamera error: $e');
      _isCameraOpen = false;
    } finally {
      _busy = false; 
      notifyListeners();
    }
  }

  Future<void> closeCamera() async {
    if (_busy || !_isCameraOpen) return;
    _busy = true; 
    notifyListeners();

    try {
      final ok = await api.stopCamera();
      if (ok) {
        _isCameraOpen = false;
        debugPrint('📷 Camera closed');
      }
    } catch (e) {
      debugPrint('❌ closeCamera error: $e');
    } finally {
      _busy = false; 
      notifyListeners();
    }
  }

  Future<void> restartCamera() async {
    debugPrint('🔄 Restarting camera...');
    await closeCamera();
    await Future.delayed(const Duration(milliseconds: 200));
    await openCamera();
  }

  @override
  void dispose() {
    // ปิดกล้องแบบไม่รอผล เพื่อไม่บล็อค dispose
    unawaited(closeCamera());
    super.dispose();
  }
}