import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/design_system/tokens/icons.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_chip.dart';
import '../../../../core/design_system/widgets/app_money_text.dart';
import '../../application/dtos/sale_dto.dart';

/// Ítem de lista de venta minimalista con AppCard, AppMoneyText y AppChip.
class SaleListItem extends StatelessWidget {
  final SaleDto sale;
  final VoidCallback? onTap;

  const SaleListItem({
    super.key,
    required this.sale,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = sale.estado.trim().toLowerCase() == 'pagada';
    final hasDebt = sale.deudaUsd > 0.001;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: AppCard(
        onTap: onTap,
        padding: AppSpacing.pMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono de estado en contenedor circular sutil
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPaid ? const Color(0xFFE8F5E9) : AppPalette.blue100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid ? AppIcons.success : AppIcons.sale,
                size: 20,
                color: isPaid ? AppPalette.success : AppPalette.blue700,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Información descriptiva
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Venta #${sale.id}',
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 15,
                          color: AppPalette.blue900,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        label: isPaid ? 'Pagada' : 'Pendiente',
                        variant: isPaid ? AppChipVariant.success : AppChipVariant.warning,
                        icon: isPaid ? AppIcons.success : AppIcons.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${sale.customerId} • ${sale.paymentMethod} • ${sale.date}',
                    style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                  ),
                  if (hasDebt) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Deuda: ',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppPalette.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppMoneyText(
                          amount: sale.deudaUsd,
                          currency: MoneyCurrency.usd,
                          nature: MoneyNature.debt,
                          fontSize: 12,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Cifras numéricas con alineación tabular
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppMoneyText(
                  amount: sale.totalPagarUsd,
                  currency: MoneyCurrency.usd,
                  nature: MoneyNature.neutral,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 2),
                AppMoneyText(
                  amount: sale.montoBs,
                  currency: MoneyCurrency.bs,
                  nature: MoneyNature.neutral,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
