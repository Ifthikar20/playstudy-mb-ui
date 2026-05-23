import 'package:flutter/material.dart';

/// PlayStudy logo. Renders assets/images/main-logo.png once it's added to
/// the repo; until then it falls back to a branded placeholder so the build
/// never breaks on a missing asset.
class AppLogo extends StatelessWidget {
  final double size;
  final double radius;
  const AppLogo({super.key, this.size = 72, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/main-logo.png',
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _Fallback(size: size, radius: radius),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final double size;
  final double radius;
  const _Fallback({required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.school_outlined, color: Colors.white, size: size * 0.5),
    );
  }
}
