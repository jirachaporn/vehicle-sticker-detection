// import 'package:flutter/material.dart';
// import '../models/detection_result.dart';

// class DetectionOverlay extends StatelessWidget {
//   final List<DetectionResult> detections;

//   const DetectionOverlay({
//     super.key,
//     required this.detections,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       painter: DetectionPainter(detections),
//       child: Container(),
//     );
//   }
// }

// class DetectionPainter extends CustomPainter {
//   final List<DetectionResult> detections;

//   DetectionPainter(this.detections);

//   @override
//   void paint(Canvas canvas, Size size) {
//     for (var detection in detections) {
//       _drawBoundingBox(canvas, size, detection);
//     }
//   }

//   void _drawBoundingBox(Canvas canvas, Size size, DetectionResult detection) {
//     final box = detection.boundingBox;
    
//     final rect = Rect.fromLTWH(
//       box.x * size.width,
//       box.y * size.height,
//       box.width * size.width,
//       box.height * size.height,
//     );

//     Color boxColor;
//     switch (detection.className.toLowerCase()) {
//       case 'license_plate':
//         boxColor = Colors.green;
//         break;
//       case 'sticker':
//         boxColor = Colors.blue;
//         break;
//       case 'vehicle':
//         boxColor = Colors.orange;
//         break;
//       default:
//         boxColor = Colors.red;
//     }

//     // วาด bounding box
//     final paint = Paint()
//       ..color = boxColor
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.0;

//     canvas.drawRect(rect, paint);

//     // วาดพื้นหลังสำหรับ label
//     final labelPaint = Paint()
//       ..color = boxColor.withOpacity(0.8)
//       ..style = PaintingStyle.fill;

//     final labelText = '${detection.className} ${(detection.confidence * 100).toStringAsFixed(1)}%';
//     final textPainter = TextPainter(
//       text: TextSpan(
//         text: labelText,
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 12,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//       textDirection: TextDirection.ltr,
//     );

//     textPainter.layout();

//     final labelRect = Rect.fromLTWH(
//       rect.left,
//       rect.top - textPainter.height - 4,
//       textPainter.width + 8,
//       textPainter.height + 4,
//     );

//     canvas.drawRect(labelRect, labelPaint);

//     // วาดข้อความ
//     textPainter.paint(
//       canvas,
//       Offset(rect.left + 4, rect.top - textPainter.height - 2),
//     );
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return true;
//   }
// }