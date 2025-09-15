import 'package:flutter/material.dart';
import 'closeplaceholder.dart';

class PreviewCard extends StatelessWidget {
  final bool isOpen;
  final bool isOpening;
  final Widget child;
  final VoidCallback onRetryOpen;

  const PreviewCard({
    super.key, 
    required this.isOpen,
    required this.isOpening,
    required this.child,
    required this.onRetryOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias, // ให้ตัดตามมุมโค้ง (ลบขอบดำที่ล้น)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // คุมอัตราส่วนให้เหมือนวิดีโอ 16:9 (ช่วยลดขอบดำ)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isOpen
                  ? child
                  : ClosedPlaceholder(
                      isOpening: isOpening,
                      onRetryOpen: onRetryOpen,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
