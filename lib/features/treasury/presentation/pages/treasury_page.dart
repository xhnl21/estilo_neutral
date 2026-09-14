import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/design_system/tokens/icons.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_chip.dart';
import '../../../../core/design_system/widgets/app_money_text.dart';
import '../../../../core/design_system/widgets/app_refresh_button.dart';
import '../../../../core/design_system/widgets/app_scaffold.dart';

/// Vista de Tesorería — Compras de Divisas y Tasas Cambiarias.
/// Estilo minimalista, CupertinoIcons y Cero Polling.
class TreasuryPage extends StatefulWidget {
  const TreasuryPage({super.key});

  @override
  State<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends State<TreasuryPage> {
  bool _isLoading = false;

  void _refreshData() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _showNewPurchaseDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text('Nueva Compra de Divisas', style: AppTypography.titleLarge),
        message: Text(
          'Registro de adquisición cambiaria con verificación de tasa BCV y comisiones.',
          style: AppTypography.bodyMedium,
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Operación registrada para auditoría.')),
              );
            },
            child: Text('Registrar Compra USD', style: TextStyle(color: AppPalette.blue700)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancelar', style: TextStyle(color: AppPalette.blue900)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tesorería',
      actions: [
        AppRefreshButton(
          isRefreshing: _isLoading,
          onRefresh: _refreshData,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewPurchaseDialog,
        tooltip: 'Nueva compra de divisas',
        backgroundColor: AppPalette.blue700,
        child: const Icon(AppIcons.add, color: AppPalette.surface, size: 24),
      ),
      body: RefreshIndicator(
        color: AppPalette.blue700,
        backgroundColor: AppPalette.surface,
        onRefresh: () async => _refreshData(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Tarjeta de Tasas Cambiarias Activas
            AppCard(
              padding: AppSpacing.pLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TASAS DE REFERENCIA',
                        style: AppTypography.labelSmall.copyWith(letterSpacing: 0.5),
                      ),
                      const AppChip(
                        label: 'BCV Oficial',
                        variant: AppChipVariant.info,
                        icon: AppIcons.rate,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tasa BCV (Bs./USD)', style: AppTypography.bodyMedium),
                          const SizedBox(height: 2),
                          Text(
                            '474.00 Bs.',
                            style: AppTypography.moneyStyle(
                              fontSize: 18,
                              color: AppPalette.blue900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Tasa Paralelo (Bs./USD)', style: AppTypography.bodyMedium),
                          const SizedBox(height: 2),
                          Text(
                            '480.00 Bs.',
                            style: AppTypography.moneyStyle(
                              fontSize: 18,
                              color: AppPalette.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'Historial de Compras de Divisas',
              style: AppTypography.titleLarge.copyWith(
                fontSize: 16,
                color: AppPalette.blue900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Registro representativo
            AppCard(
              padding: AppSpacing.pMd,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppPalette.blue100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.purchase,
                      size: 20,
                      color: AppPalette.blue700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compra #cd0000001',
                          style: AppTypography.titleLarge.copyWith(
                            fontSize: 15,
                            color: AppPalette.blue900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tasa: 474.00 Bs. • Val: OK',
                          style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppMoneyText(
                        amount: 50.00,
                        currency: MoneyCurrency.usd,
                        nature: MoneyNature.credit,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '23,700.00 Bs',
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
