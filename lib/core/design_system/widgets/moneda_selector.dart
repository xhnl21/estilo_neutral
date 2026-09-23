import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Selector de moneda base (USD/EUR) — dos "pills" con la paleta oficial
/// del sistema (blue900 para la moneda seleccionada). Con [onChanged] nulo
/// queda en modo de solo lectura (informativo, no tocable) — se usa así al
/// registrar un pago/abono, donde la moneda ya viene definida por la
/// organización y no se cambia por transacción.
class MonedaSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String>? onChanged;
  final String? label;

  const MonedaSelector({super.key, required this.value, this.onChanged, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Expanded(
              child: _MonedaPill(
                label: 'USD',
                selected: value == 'USD',
                onTap: onChanged == null ? null : () => onChanged!('USD'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MonedaPill(
                label: 'EUR',
                selected: value == 'EUR',
                onTap: onChanged == null ? null : () => onChanged!('EUR'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonedaPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _MonedaPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.blue900 : AppPalette.divider,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: selected ? Colors.white : AppPalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
