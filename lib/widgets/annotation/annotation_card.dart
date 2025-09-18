// lib/widgets/annotation/annotation_card.dart
import 'package:flutter/material.dart';

class AnnotationCard extends StatelessWidget {
  const AnnotationCard({
    super.key,
    required this.modelName,
    required this.imageUrls,
    this.onTap,

    // ✅ ขนาด (ปรับได้): ทำให้การ์ดใหญ่ขึ้นตามต้องการ
    this.cardWidth = 380,
    this.headerHeight = 44,
    this.thumbSize = 108,
    this.maxPreview = 2,
  });

  final String modelName;
  final List<String> imageUrls;
  final VoidCallback? onTap;

  // ---- Size controls
  final double cardWidth;
  final double headerHeight;
  final double thumbSize;
  final int maxPreview;

  @override
  Widget build(BuildContext context) {
    final thumbs = imageUrls.take(maxPreview).toList();
    final remain = imageUrls.length - thumbs.length;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              offset: Offset(0, 6),
              color: Color(0x15000000),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E63E9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                modelName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Thumbs row
            Row(
              children: [
                for (final url in thumbs) ...[
                  _Thumb(url: url, size: thumbSize),
                  const SizedBox(width: 12),
                ],
                if (remain > 0) _MoreBadge(label: '+$remain', size: thumbSize),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFE6E6E6),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported_outlined, size: 20),
        ),
      ),
    );
  }
}

class _MoreBadge extends StatelessWidget {
  const _MoreBadge({required this.label, required this.size});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF6B6B6B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
