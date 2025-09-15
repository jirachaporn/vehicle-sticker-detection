import 'package:flutter/material.dart';

class CameraButton extends StatelessWidget {
  final bool cameraOn;                // สถานะกล้องเปิดอยู่ไหม
  final bool detectOn;                // สถานะการตรวจจับกำลังทำงานไหม
  final bool opening;                 // ระหว่างกำลังเปิดกล้องอยู่ไหม (กันกดซ้ำ)
  final Future<void> Function()? onToggleCamera; // สลับเปิด/ปิดกล้อง
  final VoidCallback? onToggleDetect;           // สลับเริ่ม/หยุดตรวจจับ

  const CameraButton({
    super.key,
    required this.cameraOn,
    required this.detectOn,
    this.opening = false,
    this.onToggleCamera,
    this.onToggleDetect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: (onToggleCamera == null || opening) ? null : () async {
              await onToggleCamera!();
            },
            icon: opening
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(cameraOn ? Icons.videocam : Icons.videocam_off),
            label: Text(
              opening ? 'Opening...' : (cameraOn ? 'Off' : 'On'),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onToggleDetect,
            icon: Icon(detectOn ? Icons.stop_circle : Icons.play_circle),
            label: Text(detectOn ? 'Stop detection' : 'Start detection'),
          ),
          const Spacer(),
          StatusPills(cameraOn: cameraOn, detectOn: detectOn),
        ],
      ),
    );
  }
}

/// แคปซูลสถานะสั้น ๆ
class StatusPills extends StatelessWidget {
  final bool cameraOn;
  final bool detectOn;
  const StatusPills({super.key, required this.cameraOn, required this.detectOn});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    const ok = Colors.green;
    const no = Colors.red;

    Chip chip(IconData icon, String label, bool online) => Chip(
      avatar: Icon(icon, size: 18, color: on),
      label: Text(label),
      side: const BorderSide(color: Colors.transparent),
      backgroundColor: (online ? ok : no).withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: (online ? ok : no).shade700,
        fontWeight: FontWeight.w600,
      ),
    );

    return Wrap(
      spacing: 8,
      children: [
        chip(Icons.videocam, 'Camera', cameraOn),
        chip(Icons.analytics, 'Detection', detectOn),
      ],
    );
  }
}
