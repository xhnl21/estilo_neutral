import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../models/models.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../controllers/sales_controller.dart';

/// Pantalla de detalle de una venta para demostración de deep linking (/ventas/:id).
class SaleDetailPage extends StatelessWidget {
  final String saleId;
  final SalesController controller;
  final SheetsDataService dataService;

  const SaleDetailPage({
    super.key,
    required this.saleId,
    required this.controller,
    required this.dataService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataService,
      builder: (context, _) {
        final venta = dataService.ventas.cast<Venta?>().firstWhere(
              (v) => v?.id == saleId,
              orElse: () => null,
            );

        return Scaffold(
          backgroundColor: AppPalette.surface,
          appBar: AppBar(
            backgroundColor: AppPalette.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.arrow_left, color: AppPalette.blue900),
              onPressed: () => context.canPop() ? context.pop() : context.go(RoutePaths.ventas),
            ),
            title: Text(
              'Detalle de Venta #$saleId',
              style: AppTypography.titleLarge.copyWith(fontSize: 16),
            ),
            shape: const Border(
              bottom: BorderSide(color: AppPalette.divider, width: 1),
            ),
          ),
          body: venta == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.search, size: 48, color: AppPalette.textSecondary),
                      const SizedBox(height: AppSpacing.md),
                      Text('No se encontró la venta con ID: "$saleId"', style: AppTypography.headlineMedium),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Volver a Ventas',
                        icon: CupertinoIcons.arrow_left,
                        onPressed: () => context.go(RoutePaths.ventas),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Venta #${venta.id}',
                                style: AppTypography.titleLarge.copyWith(fontSize: 16),
                              ),
                              AppChip(
                                label: venta.estado == EstadoVenta.pagada ? 'Pagada' : 'Pendiente',
                                variant: venta.estado == EstadoVenta.pagada
                                    ? AppChipVariant.success
                                    : AppChipVariant.warning,
                              ),
                            ],
                          ),
                          const Divider(height: AppSpacing.lg),
                          _infoRow('Fecha:', venta.fecha.toIso8601String().split('T').first),
                          _infoRow('Cliente ID:', venta.clienteId),
                          _infoRow('Producto ID:', venta.itemId),
                          _infoRow('Cantidad:', '${venta.cantidad}'),
                          _infoRow('Tipo de Pago:', venta.tipoPago.name),
                          _infoRow('Tasa BCV:', '${venta.tasaBcv} Bs./USD'),
                          _infoRow('Total Pagado USD:', '\$${venta.totalPagarUsd.toStringAsFixed(2)}'),
                          _infoRow('Abono USD:', '\$${venta.abonoUsd.toStringAsFixed(2)}'),
                          _infoRow('Deuda Restante:', '\$${venta.deudaUsd.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
          ),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

}
