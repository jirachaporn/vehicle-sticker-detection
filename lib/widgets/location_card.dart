import 'package:flutter/material.dart';
import '../models/location.dart';

class LocationCard extends StatefulWidget {
  final Location location;
  final VoidCallback onTap;

  const LocationCard({super.key, required this.location, required this.onTap});

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine card height based on available width
        final double cardHeight = constraints.maxWidth < 200 ? 160 : 180;
        final double iconContainerSize = constraints.maxWidth < 200 ? 48 : 64;
        final double iconSize = constraints.maxWidth < 200 ? 20 : 28;
        final double titleFontSize = constraints.maxWidth < 200 ? 14 : 16;
        final double addressFontSize = constraints.maxWidth < 200 ? 11 : 13;
        final double headerHeight = constraints.maxWidth < 200 ? 100 : 120;

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: cardHeight,
              transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
              child: Card(
                elevation: isHovered ? 8 : 2,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // Header with icon
                      Container(
                        height: headerHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: widget.location.color,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: iconContainerSize,
                            height: iconContainerSize,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                isHovered ? 0.35 : 0.25,
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

                      // Content area
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth < 200 ? 12 : 16,
                            vertical: constraints.maxWidth < 200 ? 8 : 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Location name
                              Text(
                                widget.location.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: titleFontSize,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              SizedBox(
                                height: constraints.maxWidth < 200 ? 2 : 4,
                              ),

                              // Location address
                              Expanded(
                                child: Text(
                                  widget.location.address,
                                  style: TextStyle(
                                    fontSize: addressFontSize,
                                    color: Colors.grey.shade600,
                                    height: 1.3,
                                  ),
                                  maxLines: constraints.maxWidth < 200 ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
