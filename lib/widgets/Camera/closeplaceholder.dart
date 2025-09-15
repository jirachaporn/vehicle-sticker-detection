
import 'package:flutter/material.dart';

class ClosedPlaceholder extends StatelessWidget {
  final bool isOpening;
  final VoidCallback onRetryOpen;
  const ClosedPlaceholder({super.key, 
    required this.isOpening,
    required this.onRetryOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      // พื้นหลังโทนกลาง ๆ ให้ดูเรียบร้อย
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            isOpening ? 'Turning on...' : 'Camera off',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}