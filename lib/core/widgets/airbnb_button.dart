import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Airbnb-style primary CTA: full-width by default, brand gradient fill,
/// bold white label, generous tap target, and a built-in loading state.
class AirbnbButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final IconData? icon;

  const AirbnbButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: loading
          ? const SizedBox(
              key: ValueKey('loading'),
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          onTap: enabled ? onPressed : null,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: ThemeColors.brandGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            ),
            child: Container(
              width: expand ? double.infinity : null,
              height: 54,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action: outlined, brand-colored label. Pairs with [AirbnbButton].
class AirbnbSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;

  const AirbnbSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        onTap: onPressed,
        child: Container(
          width: expand ? double.infinity : null,
          height: 54,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: theme.colorScheme.onSurface),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
