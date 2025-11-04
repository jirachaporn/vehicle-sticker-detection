import 'package:flutter/material.dart';

class BuilLocationMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCollapsed;

  const BuilLocationMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isCollapsed,
  });

  @override
  State<BuilLocationMenuItem> createState() => _BuilLocationMenuItemState();
}

class _BuilLocationMenuItemState extends State<BuilLocationMenuItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget menuItem = MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 8 : 12,
            vertical: 12,
          ),
          margin: EdgeInsets.only(left: widget.isCollapsed ? 0 : 16),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFF1D4ED8)
                : isHovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.isCollapsed
              ? Center(child: Icon(widget.icon, color: Colors.white, size: 20))
              : Row(
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.isActive)
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 16,
                      ),
                  ],
                ),
        ),
      ),
    );

    if (widget.isCollapsed) {
      return Tooltip(
        message: widget.label,
        waitDuration: const Duration(seconds: 1),
        child: menuItem,
      );
    }
    return menuItem;
  }
}
