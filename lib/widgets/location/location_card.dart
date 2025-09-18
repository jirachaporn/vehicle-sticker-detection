// lib/widgets/location_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/location.dart';
import '../../providers/permission_provider.dart';

class LocationCard extends StatefulWidget {
  final Location location;
  final VoidCallback onTap;
  // คงพารามิเตอร์ไว้เพื่อความเข้ากันได้ แต่ไม่ใช้เช็คสิทธิ์
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

  bool _isOwner = false;
  bool _canEdit = false;
  bool _loadingPerm = true;

  @override
  void initState() {
    super.initState();
    // โหลดหลังเฟรมแรก เพื่อให้ context อยู่ใต้ Provider แน่ๆ
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPermissions());
  }

  @override
  void didUpdateWidget(covariant LocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.id != widget.location.id ||
        oldWidget.loggedInEmail.toLowerCase() !=
            widget.loggedInEmail.toLowerCase()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPermissions());
    }
  }

  Future<void> _loadPermissions() async {
    if (!mounted) return;
    setState(() => _loadingPerm = true);
    try {
      final perm = context.read<PermissionProvider>();
      final String locationId = widget.location.id;

      await perm.loadMembers(locationId);

      final bool isOwner = perm.isOwner(locationId);
      final bool canEdit = perm.canEdit(locationId);

      if (!mounted) return;
      setState(() {
        _isOwner = isOwner;
        _canEdit = canEdit;
      });
    } catch (e) {
      debugPrint('PERM error: $e');
      if (!mounted) return;
      setState(() {
        _isOwner = false;
        _canEdit = false;
      });
    } finally {
      if (mounted) setState(() => _loadingPerm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final bool compact = c.maxWidth < 340;

        final double headerHeight = compact ? 112 : 120;
        final double iconBox = compact ? 48 : 56;
        final double iconSize = compact ? 22 : 26;

        final double titleFont = compact ? 14 : 16;
        final double addrFont = compact ? 13 : 14;
        final double descFont = (compact ? 13 : 14) - 1;

        final EdgeInsets contentPad = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 12,
        );

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
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
                  // เนื้อหา
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: headerHeight,
                        color: widget.location.color,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: iconBox,
                            height: iconBox,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isHovered ? 0.35 : 0.25,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.apartment,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                        ),
                      ),
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

                  // ปุ่มมุมขวาบน (จะแสดงเมื่อโหลดสิทธิ์เสร็จ และได้สิทธิ์จริง)
                  if (!_loadingPerm && (_canEdit || _isOwner))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit: แสดงเมื่อ canEdit (รวม owner แล้ว)
                          if (_canEdit)
                            _floatingActionIcon(
                              tooltip: 'Edit Location',
                              icon: Icons.edit,
                              onTap: widget.onEdit,
                            ),
                          if (_isOwner) const SizedBox(width: 6),
                          // Delete: เฉพาะ owner เท่านั้น
                          if (_isOwner)
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

  Widget _floatingActionIcon({
    required String tooltip,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

/// ====== _AutoScaleInfo ======

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
        final double budget = inner.maxHeight;

        bool hasDesc = description != null && description!.trim().isNotEmpty;
        int addrLines = 2;

        const double gapTitle = 4.0;
        const double gapDesc = 4.0;

        double need(bool withDesc, int addrLs) {
          final titleH = _lineH(titleFont, 1.20);
          final addrH = _lineH(addrFont, 1.25) * addrLs;
          final descH = withDesc ? _lineH(descFont, 1.20) : 0.0;
          final gaps = gapTitle + (withDesc ? gapDesc : 0.0);
          return titleH + addrH + descH + gaps;
        }

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

        final content = Column(
          mainAxisSize: MainAxisSize.min,
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
                fontWeight: FontWeight.w700,
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
                  color: Colors.black,
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
                  color: Colors.grey.shade600,
                  height: 1.20,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ],
        );

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
