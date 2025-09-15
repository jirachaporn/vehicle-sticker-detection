// camera_stream.dart - แก้ไขปัญหาการกระพิบของภาพ

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/api_service.dart';
import '../../providers/camera_manager.dart';

class CameraStream extends StatefulWidget {
  const CameraStream({super.key});

  @override
  State<CameraStream> createState() => _CameraStreamState();
}

class _CameraStreamState extends State<CameraStream>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _refreshTimer;
  String? _currentImageUrl;
  String? _nextImageUrl;
  int _generation = 0;
  int _frameCount = 0;
  bool _firstFrameLoaded = false;
  bool _isLoadingNext = false;
  
  // Widget สำหรับแสดงภาพปัจจุบัน
  Widget? _currentImageWidget;

  @override
  void initState() {
    super.initState();
    _startRefreshing();
  }

  void _startRefreshing() {
    _refreshTimer?.cancel();
    
    // รีเซ็ตสถานะเมื่อเริ่มใหม่
    _generation++;
    _frameCount = 0;
    _firstFrameLoaded = false;
    _isLoadingNext = false;
    _currentImageUrl = null;
    _nextImageUrl = null;
    _currentImageWidget = null;
    
    // อัปเดตทุก 100ms (10 FPS) เพื่อลดการกระพิบ
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (mounted) {
          final cam = context.read<CameraManager>();
          if (cam.isCameraOpen) {
            _prepareNextFrame();
          } else {
            timer.cancel();
          }
        }
      },
    );
  }

  void _prepareNextFrame() {
    if (!mounted || _isLoadingNext) return;

    _frameCount++;
    
    // เพิ่ม timestamp และ generation เพื่อบังคับให้ได้ภาพใหม่
    final now = DateTime.now().millisecondsSinceEpoch;
    final minTs = _firstFrameLoaded ? 
        (now - 1000) / 1000.0 : // หลังเฟรมแรก ยอมรับภาพที่เก่าไม่เกิน 1 วินาที
        now / 1000.0;           // เฟรมแรก ต้องใหม่กว่าตอนนี้
    
    final newUrl = '${ApiService.baseUrl}/frame_raw'
        '?ts=$now'
        '&min_ts=$minTs'
        '&min_gen=$_generation'
        '&frame=$_frameCount';

    if (newUrl != _nextImageUrl && newUrl != _currentImageUrl) {
      _nextImageUrl = newUrl;
      _isLoadingNext = true;
      
      // Pre-load ภาพใหม่โดยไม่แสดงผล
      _preloadImage(newUrl);
    }
  }

  void _preloadImage(String url) {
    final ImageProvider imageProvider = NetworkImage(
      url,
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );

    final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        if (mounted && url == _nextImageUrl) {
          // สร้าง widget ใหม่สำหรับภาพที่โหลดเสร็จแล้ว
          final newWidget = Image.network(
            url,
            fit: BoxFit.cover,
            headers: const {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
            errorBuilder: _buildErrorWidget,
          );

          setState(() {
            _currentImageUrl = url;
            _currentImageWidget = newWidget;
            _firstFrameLoaded = true;
            _isLoadingNext = false;
          });
        }
        stream.removeListener(listener);
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        debugPrint('❌ Image preload error: $error');
        if (mounted) {
          setState(() {
            _isLoadingNext = false;
          });
        }
        stream.removeListener(listener);
      },
    );
    
    stream.addListener(listener);
  }

  Widget _buildErrorWidget(BuildContext context, Object error, StackTrace? stackTrace) {
    return Container(
      color: Colors.red[900],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 8),
            Text(
              'Failed to load camera feed',
              style: TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final cam = context.watch<CameraManager>();

    // ถ้าเปิดกล้องใหม่ ให้เริ่ม refresh ใหม่
    if (cam.isCameraOpen && _refreshTimer?.isActive != true) {
      Future.microtask(() => _startRefreshing());
    }

    if (!cam.isCameraOpen) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, size: 64, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Camera is off',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16/9,
        child: _currentImageWidget ?? Container(
          color: Colors.grey[800],
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text(
                  'Loading camera...',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}