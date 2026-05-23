import 'package:flutter/material.dart';

/// Airbnb-style listing card: white background, soft shadow, rounded corners,
/// optional image/gradient header.
class AirbnbCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  const AirbnbCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? Theme.of(context).colorScheme.surface
          : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A gradient "image" header for cards that don't have a real image yet.
/// Picks a color based on a seed so each card looks distinct.
class GradientHeader extends StatelessWidget {
  final String seed;
  final IconData icon;
  final double height;
  final Widget? overlay;
  const GradientHeader({
    super.key,
    required this.seed,
    required this.icon,
    this.height = 140,
    this.overlay,
  });

  static const _palettes = [
    [Color(0xFF007AFF), Color(0xFF5856D6)],
    [Color(0xFFFF2D55), Color(0xFFFF9500)],
    [Color(0xFF22C55E), Color(0xFF14B8A6)],
    [Color(0xFFA855F7), Color(0xFFEC4899)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF0EA5E9), Color(0xFF6366F1)],
  ];

  List<Color> get _colors {
    final i = seed.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length;
    return _palettes[i];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(icon,
                size: 160, color: Colors.white.withOpacity(0.18)),
          ),
          if (overlay != null) overlay!,
        ]),
      ),
    );
  }
}
