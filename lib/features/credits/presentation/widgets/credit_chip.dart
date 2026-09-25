import 'package:flutter/cupertino.dart';
import '../../../../core/design_system/design_system.dart';

/// Chip táctil accesible para visualización de saldo a favor o deuda de un cliente.
class CreditChip extends StatelessWidget {
  final double amount;
  final bool isCredit; // true: Saldo a favor (verde), false: Deuda (rojo)
  final VoidCallback? onTap;

  const CreditChip({
    super.key,
    required this.amount,
    required this.isCredit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (amount <= 0.0) return const SizedBox.shrink();

    final label = isCredit
        ? 'Saldo a favor: \$${amount.toStringAsFixed(2)}'
        : 'Deuda: \$${amount.toStringAsFixed(2)}';

    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AppChip(
            label: label,
            icon: isCredit ? CupertinoIcons.money_dollar_circle : CupertinoIcons.exclamationmark_circle,
            variant: isCredit ? AppChipVariant.success : AppChipVariant.error,
          ),
        ),
      ),
    );
  }
}
