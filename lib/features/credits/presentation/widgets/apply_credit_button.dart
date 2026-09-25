import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';

/// Botón secundario para activar la compensación de saldo a favor contra deuda.
class ApplyCreditButton extends StatelessWidget {
  final double applicableAmount;
  final bool isLoading;
  final VoidCallback? onPressed;

  const ApplyCreditButton({
    super.key,
    required this.applicableAmount,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = applicableAmount > 0.0 && !isLoading && onPressed != null;
    final labelText = isLoading
        ? 'Aplicando…'
        : 'Aplicar saldo a favor (\$${applicableAmount.toStringAsFixed(2)})';

    return Tooltip(
      message: isEnabled
          ? 'Compensar deuda con saldo a favor disponible'
          : 'El cliente no tiene saldo a favor disponible.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: OutlinedButton.icon(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.blue700,
            side: BorderSide(
              color: isEnabled ? AppPalette.blue700 : AppPalette.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: isLoading
              ? const CupertinoActivityIndicator(radius: 8)
              : const Icon(CupertinoIcons.money_dollar_circle, size: 18),
          label: Text(
            labelText,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isEnabled ? AppPalette.blue700 : AppPalette.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}
