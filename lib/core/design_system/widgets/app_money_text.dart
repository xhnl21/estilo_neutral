import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

enum MoneyNature { neutral, credit, debt }

enum MoneyCurrency { usd, bs }

/// Texto numérico formateado con cifras tabulares fijas para evitar desalineación contable.
class AppMoneyText extends StatelessWidget {
  final double amount;
  final MoneyCurrency currency;
  final MoneyNature nature;
  final double fontSize;
  final FontWeight fontWeight;

  const AppMoneyText({
    super.key,
    required this.amount,
    this.currency = MoneyCurrency.usd,
    this.nature = MoneyNature.neutral,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.w600,
  });

  Color _getColor() {
    switch (nature) {
      case MoneyNature.credit:
        return AppPalette.success;
      case MoneyNature.debt:
        return AppPalette.error;
      case MoneyNature.neutral:
        return AppPalette.textPrimary;
    }
  }

  String _formatAmount() {
    final prefix = currency == MoneyCurrency.usd ? r'$' : 'Bs. ';
    return '$prefix${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatAmount(),
      style: AppTypography.moneyStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: _getColor(),
      ),
    );
  }
}
