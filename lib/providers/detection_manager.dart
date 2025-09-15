import 'dart:async';
import 'package:flutter/foundation.dart';

/// ยิงงาน background เป็นรอบ ๆ (ไม่วาด overlay)
class DetectionManager extends ChangeNotifier {
  final Future<void> Function() _tick;
  Timer? _timer;
  bool _isRunning = false;
  Duration interval;

  DetectionManager({
    required Future<void> Function() onTick,
    this.interval = const Duration(milliseconds: 500),
  }) : _tick = onTick;

  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _runTick();
    _timer = Timer.periodic(interval, (_) => _runTick());
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    notifyListeners();
  }

  Future<void> _runTick() async {
    if (!_isRunning) return;
    try {
      await _tick();
    } catch (e) {
      if (kDebugMode) {
        print('Detection tick error: $e');
      }
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
