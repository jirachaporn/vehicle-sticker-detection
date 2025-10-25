import 'package:flutter/material.dart';

class DataTableViewImage {
  static void show(BuildContext context, String? url) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(5),
          title: const Text(
            'Preview',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 400),
            child: (url == null)
                ? const Center(child: Icon(Icons.image_not_supported_outlined, size: 48))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.grey,
                          strokeWidth: 2.5,
                        ),
                      ),
                      Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox.shrink();
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
