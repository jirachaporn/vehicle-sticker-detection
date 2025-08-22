// lib/widgets/location_card.dart
import 'package:flutter/material.dart';
import '../../models/location.dart';

/// LocationCard (คุม overflow ในจอเล็ก + ปุ่มแก้ไข/ลบบนมุมขวาบนเหมือนเดิม)
class LocationCard extends StatefulWidget {
  final Location location;
  final VoidCallback onTap;
  final String loggedInEmail;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const LocationCard({
    super.key,
    required this.location,
    required this.onTap,
    required this.loggedInEmail,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  bool isHovered = false;

  bool get isOwner => widget.location.ownerEmail == widget.loggedInEmail;

  bool get canEdit {
    if (isOwner) return true;
    final shared = widget.location.sharedWith;
    return shared.any(
      (item) =>
          item['email'] == widget.loggedInEmail && item['permission'] == 'edit',
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final bool compact = c.maxWidth < 340;

        // ขนาดส่วน header + ไอคอน
        final double headerHeight = compact ? 112 : 120;
        final double iconBox      = compact ? 48  : 56;
        final double iconSize     = compact ? 22  : 26;

        // ฟอนต์ข้อความ
        final double titleFont    = compact ? 14 : 16;
        final double addrFont     = compact ? 12 : 13;
        final double descFont     = (compact ? 12 : 13) - 1;

        // ระยะห่างในโซนข้อความ
        final EdgeInsets contentPad = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 12,
        );

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit:  (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Card(
              elevation: isHovered ? 8 : 2,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // ── เนื้อหาหลัก ───────────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header สี + ไอคอน
                      Container(
                        height: headerHeight,
                        color: widget.location.color,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width:  iconBox,
                            height: iconBox,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(isHovered ? 0.35 : 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.apartment, color: Colors.white, size: iconSize),
                          ),
                        ),
                      ),

                      // โซนข้อความ (กัน overflow เอง, ไม่ scroll)
                      Expanded(
                        child: Padding(
                          padding: contentPad,
                          child: _AutoScaleInfo(
                            name: widget.location.name,
                            address: widget.location.address,
                            description: widget.location.description,
                            titleFont: titleFont,
                            addrFont: addrFont,
                            descFont: descFont,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── ปุ่มแก้ไข/ลบ “มุมขวาบน” เหมือนตำแหน่งเดิม ───────────
                  if (canEdit || isOwner)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            _floatingActionIcon(
                              tooltip: 'Edit Location',
                              icon: Icons.edit,
                              onTap: widget.onEdit,
                            ),
                          if (isOwner) const SizedBox(width: 6),
                          if (isOwner)
                            _floatingActionIcon(
                              tooltip: 'Delete Location',
                              icon: Icons.delete,
                              onTap: widget.onDelete,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ปุ่มลอยเล็ก ๆ สีขาวโปร่ง เพื่อให้เห็นชัดบน header
  Widget _floatingActionIcon({
    required String tooltip,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
    );
  }
}

/// ทำให้ข้อความ “พอดีกับพื้นที่ที่เหลือ” เสมอ:
/// 1) จำกัดบรรทัด: ชื่อ 1, ที่อยู่ 2, คำอธิบาย 1
/// 2) ถ้าพื้นที่ไม่พอ → ตัดคำอธิบาย → ลดที่อยู่เหลือ 1 → เหลือ 0
/// 3) ถ้ายังไม่พออีก → ย่อทั้งบล็อกด้วย FittedBox(BoxFit.scaleDown)
class _AutoScaleInfo extends StatelessWidget {
  final String name;
  final String address;
  final String? description;
  final double titleFont;
  final double addrFont;
  final double descFont;

  const _AutoScaleInfo({
    required this.name,
    required this.address,
    required this.description,
    required this.titleFont,
    required this.addrFont,
    required this.descFont,
  });

  double _lineH(double font, double factor) => font * factor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, inner) {
        final double budget = inner.maxHeight; // ความสูงที่เหลือจริง ๆ

        bool hasDesc = description != null && description!.trim().isNotEmpty;
        int addrLines = 2;

        const double gapTitle = 4.0;
        const double gapDesc  = 4.0;

        double need(bool withDesc, int addrLs) {
          final titleH = _lineH(titleFont, 1.20);             // ชื่อ 1 บรรทัด
          final addrH  = _lineH(addrFont,  1.25) * addrLs;    // ที่อยู่ 1–2 บรรทัด
          final descH  = withDesc ? _lineH(descFont, 1.20) : 0.0;
          final gaps   = gapTitle + (withDesc ? gapDesc : 0.0);
          return titleH + addrH + descH + gaps;
        }

        // ลดเนื้อหาให้อยู่ในงบ
        double needed = need(hasDesc, addrLines);
        if (needed > budget && hasDesc) {
          hasDesc = false;
          needed = need(hasDesc, addrLines);
        }
        if (needed > budget && addrLines > 1) {
          addrLines = 1;
          needed = need(hasDesc, addrLines);
        }
        if (needed > budget && addrLines > 0) {
          addrLines = 0;
          needed = need(hasDesc, addrLines);
        }

        // เนื้อหาตามบรรทัดที่ตัดสินได้
        final content = Column(
          mainAxisSize: MainAxisSize.min, // ไม่ดันเกินพื้นที่
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                fontSize: titleFont,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.20,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),

            if (addrLines > 0) ...[
              const SizedBox(height: gapTitle),
              Text(
                address,
                maxLines: addrLines,
                overflow: TextOverflow.ellipsis,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: TextStyle(
                  fontSize: addrFont,
                  color: Colors.grey.shade700,
                  height: 1.25,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],

            if (hasDesc) ...[
              const SizedBox(height: gapDesc),
              Text(
                description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: TextStyle(
                  fontSize: descFont,
                  color: Colors.black54,
                  height: 1.20,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ],
        );

        // กัน sub-pixel overflow (0.x–3px) ด้วยการย่อทั้งบล็อกลงเล็กน้อยเมื่อจำเป็น
        return FittedBox(
          alignment: Alignment.topLeft,
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: inner.maxWidth),
            child: content,
          ),
        );
      },
    );
  }
}
