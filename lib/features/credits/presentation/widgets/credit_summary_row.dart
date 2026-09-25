import 'package:flutter/widgets.dart';
import '../../../../core/design_system/design_system.dart';

/// Fila para resumir cifras monetarias con alineación tabular y accesibilidad WCAG.
class CreditSummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  final bool isBold;

  const CreditSummaryRow({
    super.key,
    required this.label,
    required this.amount,
    this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppPalette.textPrimary;
    final formatted = '\$${amount.toStringAsFixed(2)}';
    final semanticsText = '$label: ${amount.toStringAsFixed(2)} dólares';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppPalette.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Semantics(
            container: true,
            label: semanticsText,
            excludeSemantics: true,
            child: Text(
              formatted,
              style: AppTypography.moneyStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
