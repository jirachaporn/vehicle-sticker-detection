import 'dart:typed_data';
import 'package:flutter/material.dart';

class CameraStream extends StatelessWidget {
  final Stream<Uint8List>? stream;
  final bool isStreaming;

  const CameraStream({
    super.key,
    required this.stream,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    if (!isStreaming || stream == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Camera Offline',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<Uint8List>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Stream Error',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.shade200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image Error',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}