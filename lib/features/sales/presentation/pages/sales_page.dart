import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/design_system/tokens/icons.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_empty_state.dart';
import '../../../../core/design_system/widgets/app_error_state.dart';
import '../../../../core/design_system/widgets/app_loading_state.dart';
import '../../../../core/design_system/widgets/app_money_text.dart';
import '../../../../core/design_system/widgets/app_refresh_button.dart';
import '../../../../core/design_system/widgets/app_scaffold.dart';
import '../controllers/sales_controller.dart';
import '../widgets/sale_list_item.dart';

/// Pantalla del Bounded Context de Ventas — Estilo Neutral.
/// Diseñada con estética minimalista, CupertinoIcons y política estricta de CERO POLLING.
class SalesPage extends StatefulWidget {
  final SalesController controller;

  const SalesPage({super.key, required this.controller});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  @override
  void initState() {
    super.initState();
    // Carga inicial bajo demanda puntual (cero polling)
    widget.controller.loadSales();
  }

  void _showNewSaleModal(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text('Nueva Venta', style: AppTypography.titleLarge),
        message: Text(
          'Registro operativo sincronizado con Google Sheets.',
          style: AppTypography.bodyMedium,
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Formulario de nueva venta listo para capturar.'),
                ),
              );
            },
            child: Text('Registrar Venta Directa', style: TextStyle(color: AppPalette.blue700)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancelar', style: TextStyle(color: AppPalette.blue900)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final isLoading = state is SalesLoading;

        return AppScaffold(
          title: 'Ventas',
          actions: [
            AppRefreshButton(
              isRefreshing: isLoading,
              onRefresh: () => widget.controller.onRefreshButtonPressed(),
            ),
          ],
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showNewSaleModal(context),
            tooltip: 'Registrar nueva venta',
            backgroundColor: AppPalette.blue700,
            child: const Icon(AppIcons.add, color: AppPalette.surface, size: 24),
          ),
          body: _buildBody(state),
        );
      },
    );
  }

  Widget _buildBody(SalesState state) {
    if (state is SalesLoading) {
      return const AppLoadingState(message: 'Consultando ventas en Google Sheets...');
    }

    if (state is SalesError) {
      return AppErrorState(
        message: state.userFriendlyMessage,
        onRetry: () => widget.controller.onRefreshButtonPressed(),
      );
    }

    if (state is SalesSuccess) {
      if (state.sales.isEmpty) {
        return AppEmptyState(
          title: 'No hay ventas registradas',
          subtitle: 'Comienza creando una nueva venta o actualiza la hoja.',
          icon: AppIcons.sale,
          actionLabel: 'Actualizar',
          onAction: () => widget.controller.onRefreshButtonPressed(),
        );
      }

      // Cálculo de totales para encabezado de métricas sintético
      final totalUsd = state.sales.fold<double>(0.0, (acc, s) => acc + s.totalPagarUsd);
      final totalDeuda = state.sales.fold<double>(0.0, (acc, s) => acc + s.deudaUsd);

      return RefreshIndicator(
        color: AppPalette.blue700,
        backgroundColor: AppPalette.surface,
        onRefresh: () => widget.controller.onRefreshButtonPressed(),
        child: ListView(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 80),
          children: [
            // Resumen superior sutil (1 sola sombra suave o borde sutil)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppCard(
                padding: AppSpacing.pLg,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL FACTURADO',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppPalette.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppMoneyText(
                          amount: totalUsd,
                          currency: MoneyCurrency.usd,
                          nature: MoneyNature.neutral,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppPalette.divider,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'DEUDA PENDIENTE',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppPalette.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppMoneyText(
                          amount: totalDeuda,
                          currency: MoneyCurrency.usd,
                          nature: totalDeuda > 0 ? MoneyNature.debt : MoneyNature.credit,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Encabezado de lista
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transacciones Recientes',
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 16,
                      color: AppPalette.blue900,
                    ),
                  ),
                  Text(
                    '${state.sales.length} registros',
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Lista de ventas
            ...state.sales.map((sale) => SaleListItem(sale: sale)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
