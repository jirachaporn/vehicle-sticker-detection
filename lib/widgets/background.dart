import 'package:flutter/material.dart';

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    paint.color = const Color(0xFF2546BE);
    canvas.drawCircle(center, 900, paint);

    paint.color = const Color(0xFF2A4CC8);
    canvas.drawCircle(center, 600, paint);

    paint.color = const Color(0xFF3254D0);
    canvas.drawCircle(center, 300, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
