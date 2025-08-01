import 'package:flutter/material.dart';

class CameraStream extends StatefulWidget {
  final bool isStreaming;
  final String cameraUrl;

  const CameraStream({
    super.key,
    required this.isStreaming,
    required this.cameraUrl,
  });

  @override
  State<CameraStream> createState() => _CameraStreamState();
}

class _CameraStreamState extends State<CameraStream> {
  String? _currentImageUrl;

  @override
  void didUpdateWidget(CameraStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    // อัพเดท URL เมื่อ isStreaming เปลี่ยน
    if (widget.isStreaming != oldWidget.isStreaming) {
      if (widget.isStreaming) {
        _updateImageUrl();
      } else {
        _currentImageUrl = null;
      }
    }
  }

  void _updateImageUrl() {
    if (widget.isStreaming) {
      setState(() {
        _currentImageUrl = '${widget.cameraUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: widget.isStreaming && _currentImageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentImageUrl!,
                key: ValueKey(_currentImageUrl),
                fit: BoxFit.contain,  // เปลี่ยนจาก cover เป็น contain
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                headers: {
                  "Cache-Control": "no-cache, no-store, must-revalidate",
                  "Pragma": "no-cache",
                  "Expires": "0",
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    // รีเฟรช URL ทุกๆ 100ms เมื่อโหลดเสร็จ
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted && widget.isStreaming) {
                        _updateImageUrl();
                      }
                    });
                    return child;
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connecting to camera...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Image load error: $error');
                  return _buildErrorState();
                },
              ),
            )
          : widget.isStreaming
              ? _buildLoadingState()
              : _buildOfflineState(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text(
            'Initializing camera...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Camera Offline',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 8),
          Text(
            'Connection Error',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Failed to load camera stream',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              if (widget.isStreaming) {
                _updateImageUrl();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade700,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}