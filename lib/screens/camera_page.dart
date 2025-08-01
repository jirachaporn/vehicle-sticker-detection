import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/camera_stream.dart';
import '../models/camera_Info.dart';

class CameraPage extends StatefulWidget {
   final String locationId;
  const CameraPage({super.key, required this.locationId});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  List<CameraInfo> availableCameras = [];
  Map<int, bool> cameraStreamingStatus = {};
  bool isLoading = true;
  String? errorMessage;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _stopAllStreams();
    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final cameras = await _getAvailableCameras();

      setState(() {
        availableCameras = cameras;
        for (var cam in cameras) {
          cameraStreamingStatus[cam.id] = false;
        }
        isLoading = false;
      });

      
      await _refreshCameraStatuses();
      await _startAllStreams();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to initialize cameras: $e';
      });
    }
  }

  Future<void> _startAllStreams() async {
  for (var camera in availableCameras) {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/cameras/${camera.id}/start'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            cameraStreamingStatus[camera.id] = true;
          });
        }
      }
    } catch (e) {
      print('Error starting camera ${camera.id}: $e');
    }
  }
}

  Future<List<CameraInfo>> _getAvailableCameras() async {
    final response = await http
        .get(Uri.parse('http://127.0.0.1:5000/api/cameras/list'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((camera) => CameraInfo.fromJson(camera)).toList();
    } else {
      throw Exception('Failed to get cameras: ${response.statusCode}');
    }
  }

  Future<void> _refreshCameraStatuses() async {
    for (var camera in availableCameras) {
      try {
        final response = await http
            .get(
              Uri.parse(
                'http://127.0.0.1:5000/api/cameras/${camera.id}/status',
              ),
            )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            cameraStreamingStatus[camera.id] = data['active'] ?? false;
          });
        }
      } catch (e) {
        print('Error checking camera ${camera.id} status: $e');
      }
    }
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (availableCameras.isNotEmpty) {
        _refreshCameraStatuses();
      }
    });
  }

  Future<void> _toggleCameraStreaming(int cameraId) async {
    final isStreaming = cameraStreamingStatus[cameraId] ?? false;
    final action = isStreaming ? 'stop' : 'start';

    setState(() {
      cameraStreamingStatus[cameraId] = !isStreaming;
    });

    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:5000/api/cameras/$cameraId/$action'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSnackBar(
            'Camera ${isStreaming ? 'stopped' : 'started'} successfully',
            Colors.green,
          );
        } else {
          throw Exception(data['message'] ?? 'Unknown error');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        cameraStreamingStatus[cameraId] = isStreaming;
      });

      _showSnackBar(
        'Failed to ${isStreaming ? 'stop' : 'start'} camera: $e',
        Colors.red,
      );
    }
  }

  Future<void> _stopAllStreams() async {
    for (var cameraId in cameraStreamingStatus.keys) {
      if (cameraStreamingStatus[cameraId] == true) {
        try {
          await http
              .post(
                Uri.parse('http://127.0.0.1:5000/api/cameras/$cameraId/stop'),
              )
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          print('Error stopping camera $cameraId: $e');
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // void _showErrorDialog(String message) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Row(
  //         children: [
  //           Icon(Icons.error_outline, color: Colors.red.shade600),
  //           const SizedBox(width: 8),
  //           const Text('Error'),
  //         ],
  //       ),
  //       content: Text(message),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('OK'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Camera Monitoring',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: isLoading ? null : _initializeCameras,
          label: Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Initializing cameras...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCameras,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (availableCameras.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Cameras Detected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check camera connections and try again',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return _buildCameraGrid();
  }

  Widget _buildCameraGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth >= 1200) {
          crossAxisCount = availableCameras.length > 4 ? 3 : 2;
        } else if (constraints.maxWidth >= 800) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 16 / 9,
          ),
          itemCount: availableCameras.length,
          itemBuilder: (context, index) {
            final camera = availableCameras[index];
            return _buildCameraCard(camera);
          },
        );
      },
    );
  }

  Widget _buildCameraCard(CameraInfo camera) {
    final isStreaming = cameraStreamingStatus[camera.id] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCameraHeader(camera, isStreaming),
          Expanded(
            child: CameraStream(
              isStreaming: isStreaming,
              cameraUrl: 'http://127.0.0.1:5000/video/${camera.id}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraHeader(CameraInfo camera, bool isStreaming) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camera.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Camera ID: ${camera.id}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isStreaming ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isStreaming ? 'LIVE' : 'OFF',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isStreaming
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              isStreaming ? Icons.stop_circle : Icons.play_circle_filled,
              color: isStreaming ? Colors.red.shade600 : Colors.green.shade600,
              size: 28,
            ),
            tooltip: isStreaming ? 'Stop Stream' : 'Start Stream',
            onPressed: () => _toggleCameraStreaming(camera.id),
          ),
        ],
      ),
    );
  }
}
