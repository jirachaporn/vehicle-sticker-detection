import 'package:flutter/material.dart';
import 'package:myproject/providers/app_state.dart';
import 'package:provider/provider.dart';
import '../../models/location.dart';
import '../../providers/permission_provider.dart';

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

  bool _isOwner = false;
  bool _canEdit = false;
  bool _isAdmin = false;
  bool _loadingPerm = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadPermissions());
  }

  @override
  void didUpdateWidget(covariant LocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.id != widget.location.id ||
        oldWidget.loggedInEmail.toLowerCase() !=
            widget.loggedInEmail.toLowerCase()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => loadPermissions());
    }
  }

  Future<void> loadPermissions() async {
    if (!mounted) return;
    setState(() => _loadingPerm = true);
    try {
      final perm = context.read<PermissionProvider>();
      final String locationId = widget.location.id;

      await perm.loadMembers(locationId);

      final bool isOwner = perm.isOwner(locationId);
      final bool canEdit = perm.canEdit(locationId);

      bool adminRole = false;
      try {
        adminRole = context.read<AppState>().isAdmin;
      } catch (_) {
        adminRole = false;
      }

      if (!mounted) return;
      setState(() {
        _isOwner = isOwner;
        _canEdit = canEdit;
        _isAdmin = adminRole;
      });
    } catch (e) {
      debugPrint('permission error: $e');
      if (!mounted) return;
      setState(() {
        _isOwner = false;
        _canEdit = false;
        _isAdmin = false;
      });
    } finally {
      if (mounted) setState(() => _loadingPerm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    height: 120,
                    color: widget.location.color,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: isHovered ? 0.35 : 0.25,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.apartment,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.location.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.location.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          if (widget.location.description != null &&
                              widget.location.description!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.location.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ปุ่มมุมขวาบน
              if (_isAdmin || (!_loadingPerm && (_canEdit || _isOwner)))
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isAdmin || _canEdit)
                        _floatingActionIcon(
                          tooltip: 'Edit Location',
                          icon: Icons.edit,
                          onTap: widget.onEdit,
                        ),
                      if (_isAdmin || _isOwner) const SizedBox(width: 6),
                      if (_isAdmin || _isOwner)
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
  }

  Widget _floatingActionIcon({
    required String tooltip,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: .35),
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
