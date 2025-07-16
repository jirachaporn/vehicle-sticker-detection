import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/sticker_model.dart';

class StickerCard extends StatelessWidget {
  final StickerModel model;
  final VoidCallback onActivate;

  const StickerCard({
    super.key,
    required this.model,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _getStatusColor(),
        border: Border.all(color: _getStatusBorderColor(), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _getStatusIcon(),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Images Grid
            SizedBox(
              height: 160,
              child: Row(
                children: model.images.take(5).map((image) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFE5E7EB),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uploaded: ${_formatDate(model.uploadDate)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (!model.isActive && model.status != StickerStatus.processing)
                  ElevatedButton(
                    onPressed: onActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Activate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (model.status) {
      case StickerStatus.active:
        return const Color(0xFFDCFCE7);
      case StickerStatus.processing:
        return const Color(0xFFFEF3C7);
      case StickerStatus.inactive:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusBorderColor() {
    switch (model.status) {
      case StickerStatus.active:
        return const Color(0xFF86EFAC);
      case StickerStatus.processing:
        return const Color(0xFFFDE047);
      case StickerStatus.inactive:
        return const Color(0xFFD1D5DB);
    }
  }

  Widget _getStatusIcon() {
    switch (model.status) {
      case StickerStatus.active:
        return const Icon(Icons.check, size: 16, color: Color(0xFF059669));
      case StickerStatus.processing:
        return const Icon(Icons.access_time, size: 16, color: Color(0xFFD97706));
      case StickerStatus.inactive:
        return const SizedBox.shrink();
    }
  }

  String _getStatusText() {
    switch (model.status) {
      case StickerStatus.active:
        return 'Active';
      case StickerStatus.processing:
        return 'Processing';
      case StickerStatus.inactive:
        return 'Inactive';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}