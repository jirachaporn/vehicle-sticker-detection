// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import '../../providers/api_service.dart';

// class CameraFeedBox extends StatefulWidget {
//   final String title;
//   final CameraDescription camera;
//   final int cameraIndex;
//   final String locationId;
//   final String modelId;
//   final String direction;

//   const CameraFeedBox({
//     super.key,
//     required this.title,
//     required this.camera,
//     required this.cameraIndex,
//     required this.locationId,
//     required this.modelId,
//     required this.direction,
//   });

//   @override
//   State<CameraFeedBox> createState() => _CameraFeedBoxState();
// }

// class _CameraFeedBoxState extends State<CameraFeedBox> {
//   CameraController? controller;
//   bool isDetecting = false;
//   Map<String, dynamic>? detectionResult;
//   Timer? snapshotTimer;

//   @override
//   void initState() {
//     super.initState();
//     initializeCamera();
//   }

//   Future<void> initializeCamera() async {
//     try {
//       // ถ้ามี controller เก่า ให้ dispose ก่อน
//       if (controller != null) {
//         await controller!.dispose();
//         controller = null;
//       }

//       controller = CameraController(
//         widget.camera,
//         ResolutionPreset.medium,
//         enableAudio: false,
//       );

//       await controller!.initialize();
//       if (!controller!.value.isInitialized) return;

//       // ใช้ snapshot แทน imageStream สำหรับ Windows
//       snapshotTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
//         if (isDetecting ||
//             controller == null ||
//             !controller!.value.isInitialized) {
//           return;
//         }

//         isDetecting = true;
//         try {
//           final file = await controller!.takePicture();
//           final bytes = await file.readAsBytes();

//           final result = await ApiService.detectVehicleFrom(
//             bytes,
//             locationId: widget.locationId,
//             modelId: widget.modelId,
//             direction: widget.direction,
//           );

//           if (!mounted) return;
//           setState(() {
//             detectionResult = result;
//           });
//         } catch (e) {
//           debugPrint('Error detecting vehicle: $e');
//         } finally {
//           isDetecting = false;
//         }
//       });

//       if (mounted) setState(() {});
//     } catch (e) {
//       debugPrint('Error initializing camera ${widget.cameraIndex}: $e');
//     }
//   }

//   @override
//   void dispose() {
//     snapshotTimer?.cancel();
//     controller?.dispose();
//     controller = null;
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.1),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header + result
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.grey[100],
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(12),
//                 topRight: Radius.circular(12),
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     const Icon(Icons.videocam, color: Color(0xFF119928)),
//                     const SizedBox(width: 8),
//                     Text(
//                       widget.title,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const Spacer(),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           // Camera preview
//           Container(
//             height: 400,
//             width: double.infinity,
//             decoration: const BoxDecoration(
//               color: Colors.black,
//               borderRadius: BorderRadius.only(
//                 bottomLeft: Radius.circular(12),
//                 bottomRight: Radius.circular(12),
//               ),
//             ),
//             child: ClipRRect(
//               borderRadius: const BorderRadius.only(
//                 bottomLeft: Radius.circular(12),
//                 bottomRight: Radius.circular(12),
//               ),
//               child: controller == null || !controller!.value.isInitialized
//                   ? const Center(
//                       child: CircularProgressIndicator(color: Colors.white),
//                     )
//                   : CameraPreview(controller!),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_manager.dart';
import 'package:camera/camera.dart';

class CameraBox extends StatelessWidget {
  final String title;

  const CameraBox({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<CameraManager>();
    final controller = manager.controller;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:  0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Color(0xFF119928)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Camera preview
          Container(
            height: 400,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: controller == null || !controller.value.isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : CameraPreview(controller),
          ),
        ],
      ),
    );
  }
}
