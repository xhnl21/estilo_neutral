import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';

/// Detalle de una factura (hoja "ventas" + sus ítems en "venta_items"):
/// número de factura, cliente, lista de productos comprados (imagen, código,
/// cantidad, precio unitario, subtotal), monto total y fecha.
class FacturaDetallePage extends StatelessWidget {
  final String ventaId;
  final SheetsDataService dataService;

  const FacturaDetallePage({super.key, required this.ventaId, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataService,
      builder: (context, _) {
        final venta = dataService.ventas.where((v) => v.id == ventaId).firstOrNull;

        if (venta == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Factura #$ventaId')),
            body: const Center(child: Text('Esta factura no existe o fue anulada.')),
          );
        }

        final cliente = dataService.clientes.where((c) => c.id == venta.clienteId).firstOrNull;
        final items = dataService.itemsDeVenta(venta.id);
        final abonos = dataService.abonosDeVenta(venta.id).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
        final isPaid = venta.estado == EstadoVenta.pagada;

        return Scaffold(
          backgroundColor: AppPalette.surface,
          appBar: AppBar(
            backgroundColor: AppPalette.surface,
            elevation: 0,
            title: Text('Factura #${venta.id}'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: AppSpacing.pMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cliente: ${cliente?.nombre ?? venta.clienteId}', style: AppTypography.titleLarge.copyWith(fontSize: 15)),
                        AppChip(
                          label: isPaid ? 'Pagada' : 'Pendiente',
                          variant: isPaid ? AppChipVariant.success : AppChipVariant.warning,
                          icon: isPaid ? AppIcons.success : AppIcons.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${venta.fecha.toIso8601String().split('T').first} • Pago: ${dataService.metodoPagoNombre(venta.metodoPagoId)}',
                      style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
                    ),
                    Text(
                      'Tasa BCV: ${venta.tasaBcv.toStringAsFixed(2)} Bs.',
                      style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                headingLevel: 2,
                child: Text('Productos', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (items.isEmpty)
                const AppEmptyState(
                  title: 'Sin ítems',
                  description: 'Esta factura no tiene productos registrados.',
                  icon: CupertinoIcons.cart,
                )
              else
                ...items.map((item) {
                  final producto = dataService.productos.where((p) => p.id == item.itemId).firstOrNull;
                  final fotoUrl = producto?.fotoUrl;
                  final hasPhoto = fotoUrl != null && fotoUrl.isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: AppSpacing.pMd,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 54,
                              height: 54,
                              color: AppPalette.blue100,
                              child: hasPhoto
                                  ? Image.network(
                                      fotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: ExcludeSemantics(
                                          child: Icon(CupertinoIcons.photo, color: AppPalette.blue700, size: 22),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: ExcludeSemantics(
                                        child: Icon(CupertinoIcons.photo, color: AppPalette.blue700, size: 22),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  producto?.nombre ?? 'Producto eliminado',
                                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.itemId} • Cant: ${item.cantidad} × USD ${item.precioUsd.toStringAsFixed(2)}',
                                  style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          AppMoneyText(
                            amount: item.subtotalUsd,
                            currency: MoneyCurrency.usd,
                            fontWeight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: AppSpacing.pMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TotalRow(label: 'Total', amount: venta.totalPagarUsd, bold: true),
                    _TotalRow(label: 'Abonado', amount: venta.abonoUsd),
                    if (venta.deudaUsd > 0) _TotalRow(label: 'Deuda pendiente', amount: venta.deudaUsd, isDebt: true),
                  ],
                ),
              ),
              if (abonos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  headingLevel: 2,
                  child: Text('Historial de Abonos', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...abonos.map((abono) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: AppSpacing.pMd,
                        child: Row(
                          children: [
                            const ExcludeSemantics(
                              child: Icon(CupertinoIcons.money_dollar_circle, color: AppPalette.blue700, size: 22),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dataService.metodoPagoNombre(abono.metodoPagoId),
                                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Builder(builder: (context) {
                                    final tasa = dataService.tasaPorId(abono.tasaId);
                                    final tasaTexto = tasa != null
                                        ? 'Tasa ${tasa.fuente == 'manual' ? 'manual' : 'BCV'}: ${tasa.valor.toStringAsFixed(2)}'
                                        : 'Tasa no disponible';
                                    return Text(
                                      '${abono.fecha.toIso8601String().split('T').first} '
                                      '${abono.fecha.hour.toString().padLeft(2, '0')}:'
                                      '${abono.fecha.minute.toString().padLeft(2, '0')}'
                                      ' • $tasaTexto',
                                      style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            AppMoneyText(
                              amount: abono.monto,
                              currency: MoneyCurrency.usd,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final bool isDebt;

  const _TotalRow({required this.label, required this.amount, this.bold = false, this.isDebt = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? AppTypography.titleLarge.copyWith(fontSize: 14)
                : AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
          ),
          AppMoneyText(
            amount: amount,
            currency: MoneyCurrency.usd,
            nature: isDebt ? MoneyNature.debt : MoneyNature.neutral,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontSize: bold ? 15 : 13,
          ),
        ],
      ),
    );
  }
}
