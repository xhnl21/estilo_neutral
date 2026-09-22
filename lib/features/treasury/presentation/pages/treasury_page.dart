import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/environment_config.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../models/models.dart';
import '../../../../shared/shared.dart';

/// Vista de Tesorería — Compras de Divisas (hoja: compras_divisas)
/// Operaciones CRUD completas y Cero Polling.
class TreasuryPage extends StatefulWidget {
  final SheetsDataService dataService;

  const TreasuryPage({super.key, required this.dataService});

  @override
  State<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends State<TreasuryPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final compras = widget.dataService.comprasDivisas;
        final totalUsd = compras.fold<double>(0.0, (s, c) => s + c.capitalUsd);
        final totalComisiones = compras.fold<double>(0.0, (s, c) => s + c.comisionBinanceUsd);

        return AppScaffold(
          title: 'Tesorería',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'compras_divisas',
            userFriendlyText: '${compras.length} operaciones',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => widget.dataService.fetchAllSheets(),
              isLoading: widget.dataService.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_compras_divisas',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.plus_circle, size: 20),
            label: const Text('Nueva Compra', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showCompraDialog(context),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: widget.dataService.isLoading
                ? const TreasurySkeleton(key: ValueKey('treasury_skeleton'))
                : ListView(
                    key: const ValueKey('treasury_content'),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
            children: [
              // Tasas de referencia y resumen
              AppCard(
                padding: AppSpacing.pMd,
                mergeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CAPITAL ADQUIRIDO (USD)', style: AppTypography.labelSmall),
                        const AppChip(
                          label: 'BCV / Binance P2P',
                          variant: AppChipVariant.info,
                          icon: AppIcons.rate,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Comprado', style: AppTypography.bodyMedium),
                            AppMoneyText(
                              amount: totalUsd,
                              currency: MoneyCurrency.usd,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Comisiones Totales', style: AppTypography.bodyMedium),
                            AppMoneyText(
                              amount: totalComisiones,
                              currency: MoneyCurrency.usd,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              nature: MoneyNature.neutral,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Semantics(
                header: true,
                headingLevel: 2,
                child: Text('Historial de Compras de Divisas', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
              ),
              const SizedBox(height: AppSpacing.sm),

              if (compras.isEmpty)
                const AppEmptyState(
                  title: 'No hay compras de divisas registradas',
                  description: 'Registra una compra usando el botón "Nueva Compra".',
                  icon: CupertinoIcons.money_dollar,
                )
              else
                ...compras.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: AppSpacing.pMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.sm,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Orden: ${c.numeroOrden.isNotEmpty ? c.numeroOrden : c.id}',
                                        style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    AppChip(
                                      label: c.plataforma,
                                      variant: AppChipVariant.info,
                                    ),
                                  ],
                                ),
                                AppMoneyText(
                                  amount: c.capitalUsd,
                                  currency: MoneyCurrency.usd,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vendedor: ${c.vendedor} • Tasa BCV: ${c.tasaBcv} • Paralelo: ${c.tasaUsd}',
                              style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Fecha Compra: ${c.fechaCompra.toIso8601String().split('T').first} • Entrega: ${c.fechaEntrega.toIso8601String().split('T').first} • Com: USD ${c.comisionBinanceUsd.toStringAsFixed(2)}',
                              style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                  tooltip: 'Editar Compra',
                                  onPressed: () => _showCompraDialog(context, compra: c),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                  tooltip: 'Eliminar Compra',
                                  onPressed: () => _confirmDelete(context, c),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showCompraDialog(BuildContext context, {CompraDivisa? compra}) {
    final isEditing = compra != null;
    final id = isEditing ? compra.id : widget.dataService.nextCompraDivisaId;
    final ordenController = TextEditingController(text: compra?.numeroOrden ?? 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final capitalController = TextEditingController(text: compra?.capitalUsd.toStringAsFixed(2) ?? '100.00');
    final comisionController = TextEditingController(text: compra?.comisionBinanceUsd.toStringAsFixed(2) ?? '1.00');
    final plataformaController = TextEditingController(text: compra?.plataforma ?? 'Binance P2P');
    final vendedorController = TextEditingController(text: compra?.vendedor ?? 'CryptoTrader');
    final tasaBcvController = TextEditingController(text: compra?.tasaBcv.toStringAsFixed(2) ?? '474.00');
    final tasaUsdController = TextEditingController(text: compra?.tasaUsd.toStringAsFixed(2) ?? '480.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Editar Orden ($id)' : 'Registrar Compra de Divisas',
                    style: AppTypography.titleLarge.copyWith(fontSize: 17),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Número de Orden',
                      controller: ordenController,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Plataforma',
                      controller: plataformaController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Capital (USD)',
                      controller: capitalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Comisión (USD)',
                      controller: comisionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Vendedor / Contraparte',
                controller: vendedorController,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Tasa BCV',
                      controller: tasaBcvController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Tasa Efectiva USD',
                      controller: tasaUsdController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: isEditing ? 'Guardar Cambios' : 'Registrar Compra',
                      icon: CupertinoIcons.check_mark,
                      onPressed: () {
                        final c = CompraDivisa(
                          id: id,
                          fechaCompra: compra?.fechaCompra ?? DateTime.now(),
                          fechaEntrega: compra?.fechaEntrega ?? DateTime.now(),
                          capitalUsd: double.tryParse(capitalController.text.replaceAll(',', '.')) ?? 0.0,
                          comisionBinanceUsd: double.tryParse(comisionController.text.replaceAll(',', '.')) ?? 0.0,
                          numeroOrden: ordenController.text.trim(),
                          plataforma: plataformaController.text.trim(),
                          vendedor: vendedorController.text.trim(),
                          tasaBcv: double.tryParse(tasaBcvController.text.replaceAll(',', '.')) ?? 474.0,
                          tasaUsd: double.tryParse(tasaUsdController.text.replaceAll(',', '.')) ?? 480.0,
                          validacion: 'OK',
                        );

                        if (isEditing) {
                          widget.dataService.updateCompraDivisa(c);
                        } else {
                          widget.dataService.addCompraDivisa(c);
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CompraDivisa c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar orden de compra?'),
        content: Text('Se eliminará la orden ${c.numeroOrden} (${c.id}) por USD ${c.capitalUsd}.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              widget.dataService.deleteCompraDivisa(c.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
