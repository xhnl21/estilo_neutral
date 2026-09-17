import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

enum AppChipVariant { info, success, warning, error }

/// Chip minimalista para estados contables o metadata de entidad.
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AppChipVariant variant;
  final String? semanticLabel;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppChipVariant.info,
    this.semanticLabel,
  });

  (Color bg, Color text) _getColors() {
    switch (variant) {
      case AppChipVariant.info:
        return (AppPalette.blue100, AppPalette.blue900);
      case AppChipVariant.success:
        return (const Color(0xFFE8F5E9), AppPalette.success);
      case AppChipVariant.warning:
        return (const Color(0xFFFFF3E0), AppPalette.warning);
      case AppChipVariant.error:
        return (const Color(0xFFFFEBEE), AppPalette.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, text) = _getColors();

    return Semantics(
      container: true,
      label: semanticLabel ?? 'Estado: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppSpacing.roundedPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(icon, size: 14, color: text),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
