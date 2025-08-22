import 'package:flutter/material.dart';

class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double? childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.childAspectRatio,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive columns based on screen width
        int crossAxisCount;
        double spacing;
        double aspectRatio;

        if (constraints.maxWidth >= 1400) {
          // Extra large screens
          crossAxisCount = 4;
          spacing = 32;
          aspectRatio = childAspectRatio ?? 1.8;
        } else if (constraints.maxWidth >= 1024) {
          // Large screens (desktop)
          crossAxisCount = 3;
          spacing = 24;
          aspectRatio = childAspectRatio ?? 1.6;
        } else if (constraints.maxWidth >= 768) {
          // Medium screens (tablet landscape)
          crossAxisCount = 2;
          spacing = 20;
          aspectRatio = childAspectRatio ?? 1.5;
        } else if (constraints.maxWidth >= 480) {
          // Small screens (tablet portrait)
          crossAxisCount = 2;
          spacing = 16;
          aspectRatio = childAspectRatio ?? 1.4;
        } else {
          // Extra small screens (mobile)
          crossAxisCount = 1;
          spacing = 12;
          aspectRatio = childAspectRatio ?? 2.0;
        }

        return GridView.builder(
          padding: EdgeInsets.all(spacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

// Alternative: Using ResponsiveGridView with your existing code
class LocationGridView extends StatelessWidget {
  final List<dynamic> locations;
  final Function(dynamic) onLocationTap;
  final Widget Function(dynamic, Function()) cardBuilder;

  const LocationGridView({
    super.key,
    required this.locations,
    required this.onLocationTap,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive columns
        int getCrossAxisCount() {
          if (constraints.maxWidth >= 1400) return 4;
          if (constraints.maxWidth >= 1024) return 3;
          if (constraints.maxWidth >= 768) return 2;
          if (constraints.maxWidth >= 480) return 2;
          return 1;
        }

        double getSpacing() {
          if (constraints.maxWidth >= 1024) return 32;
          if (constraints.maxWidth >= 768) return 24;
          if (constraints.maxWidth >= 480) return 20;
          return 16;
        }

        double getAspectRatio() {
          if (constraints.maxWidth >= 1400) return 1.4;  // Extra large: 4 columns - สูงมาก
          if (constraints.maxWidth >= 1024) return 1.3;  // Desktop: 3 columns - สูงมาก
          if (constraints.maxWidth >= 768) return 1.3;   // Tablet landscape: 2 columns - สูงมาก
          if (constraints.maxWidth >= 480) return 1.2;   // Tablet portrait: 2 columns - สูงมาก
          return 1.1;                                     // Mobile: 1 column - สูงมาก
        }

        final crossAxisCount = getCrossAxisCount();
        final spacing = getSpacing();
        final aspectRatio = getAspectRatio();

        return GridView.builder(
          padding: EdgeInsets.all(spacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final location = locations[index];
            return cardBuilder(location, () => onLocationTap(location));
          },
        );
      },
    );
  }
}