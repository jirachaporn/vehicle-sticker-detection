import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/sticker_model.dart';

class StickerCard extends StatelessWidget {
  final StickerModel model;
  final VoidCallback onActivate;

  const StickerCard({super.key, required this.model, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallCard = constraints.maxWidth < 400;
        final cardPadding = isSmallCard ? 16.0 : 24.0;
        final imageHeight = isSmallCard ? 100.0 : 160.0;

        return Container(
          decoration: BoxDecoration(
            color: _getStatusColor(),
            border: Border.all(color: _getStatusBorderColor(), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(isSmallCard),

                SizedBox(height: isSmallCard ? 12 : 16),

                // Images Grid - ปรับให้ responsive
                _buildImageGrid(imageHeight),

                SizedBox(height: isSmallCard ? 12 : 16),

                // Footer
                _buildFooter(isSmallCard),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isSmallCard) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            model.name,
            style: TextStyle(
              fontSize: isSmallCard ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getStatusIcon(),
            const SizedBox(width: 8),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: isSmallCard ? 12 : 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageGrid(double imageHeight) {
    return SizedBox(
      height: imageHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageCount = model.images.length;
          final displayCount = imageCount > 5 ? 5 : imageCount;

          if (displayCount == 0) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No images',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
              ),
            );
          }

          final imageSpacing = 8.0;
          final totalSpacing = imageSpacing * (displayCount - 1);
          final availableWidth = constraints.maxWidth - totalSpacing;
          final imageWidth = availableWidth / displayCount;

          return Row(
            children: List.generate(displayCount, (index) {
              final isLast = index == displayCount - 1;
              final hasMoreImages = imageCount > 5;

              return Container(
                width: imageWidth,
                margin: EdgeInsets.only(right: isLast ? 0 : imageSpacing),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: model.images[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFE5E7EB),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFE5E7EB),
                            child: const Center(
                              child: Icon(
                                Icons.error,
                                color: Color(0xFF9CA3AF),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Overlay สำหรับรูปที่เหลือ
                      if (isLast && hasMoreImages)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '+${imageCount - 5}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: imageHeight < 120 ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildFooter(bool isSmallCard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < 300;

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uploaded: ${_formatDate(model.uploadDate)}',
                style: TextStyle(
                  fontSize: isSmallCard ? 12 : 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              if (!model.isActive && model.status != StickerStatus.processing)
                const SizedBox(height: 8),
              if (!model.isActive && model.status != StickerStatus.processing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallCard ? 10 : 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Activate',
                      style: TextStyle(
                        fontSize: isSmallCard ? 12 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Uploaded: ${_formatDate(model.uploadDate)}',
                style: TextStyle(
                  fontSize: isSmallCard ? 12 : 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            if (!model.isActive && model.status != StickerStatus.processing)
              const SizedBox(width: 8),
            if (!model.isActive && model.status != StickerStatus.processing)
              ElevatedButton(
                onPressed: onActivate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallCard ? 12 : 16,
                    vertical: isSmallCard ? 6 : 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Activate',
                  style: TextStyle(
                    fontSize: isSmallCard ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _getStatusColor() {
    switch (model.status) {
      case StickerStatus.ready:
        return const Color(0xFFE0F2FE); // light blue
      case StickerStatus.processing:
        return const Color(0xFFFEF3C7); // light yellow
      case StickerStatus.failed:
        return const Color(0xFFFEE2E2); // light red
    }
  }

  Color _getStatusBorderColor() {
    switch (model.status) {
      case StickerStatus.ready:
        return const Color(0xFF60A5FA); // blue border
      case StickerStatus.processing:
        return const Color(0xFFFCD34D); // yellow border
      case StickerStatus.failed:
        return const Color(0xFFF87171); // red border
    }
  }

  Widget _getStatusIcon() {
    switch (model.status) {
      case StickerStatus.ready:
        return const Icon(
          Icons.check_circle,
          size: 16,
          color: Color(0xFF2563EB),
        );
      case StickerStatus.processing:
        return const Icon(
          Icons.access_time,
          size: 16,
          color: Color(0xFFD97706),
        );
      case StickerStatus.failed:
        return const Icon(Icons.error, size: 16, color: Color(0xFFDC2626));
    }
  }

  String _getStatusText() {
    switch (model.status) {
      case StickerStatus.ready:
        return 'Ready';
      case StickerStatus.processing:
        return 'Processing';
      case StickerStatus.failed:
        return 'Failed';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
