import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/environment_config.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../models/models.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../controllers/sales_controller.dart';

/// Pantalla de Ventas (hoja: ventas)
/// CRUD completo, cálculo automático de deuda, amortizaciones y Cero Polling.
class SalesPage extends StatefulWidget {
  final SalesController controller;
  final SheetsDataService? dataService;

  const SalesPage({super.key, required this.controller, this.dataService});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  String _filterStatus = 'Todos'; // 'Todos', 'Pagada', 'Pendiente'

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataService;
    if (ds == null) {
      return const Center(child: Text('Servicio de datos no disponible'));
    }

    return ListenableBuilder(
      listenable: ds,
      builder: (context, _) {
        final ventas = ds.ventas.where((v) {
          if (_filterStatus == 'Pagada') return v.estado == EstadoVenta.pagada;
          if (_filterStatus == 'Pendiente') return v.estado == EstadoVenta.pendiente;
          return true;
        }).toList();

        final totalVentasUsd = ds.ventas.fold<double>(0.0, (sum, v) => sum + v.totalPagarUsd);
        final totalDeudaUsd = ds.ventas.fold<double>(0.0, (sum, v) => sum + v.deudaUsd);

        return AppScaffold(
          title: 'Ventas',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'ventas',
            userFriendlyText: '${ds.ventas.length} transacciones registradas',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => ds.fetchAllSheets(),
              isLoading: ds.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.cart_badge_plus, size: 20),
            label: const Text('Nueva Venta', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showNewSaleDialog(context, ds),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: ds.isLoading && ds.ventas.isEmpty
                ? const SalesSkeleton(key: ValueKey('sales_skeleton'))
                : Column(
                    key: const ValueKey('sales_content'),
                    children: [
                      // Métricas consolidadas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: AppSpacing.pMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FACTURACIÓN TOTAL', style: AppTypography.labelSmall),
                            const SizedBox(height: 4),
                            AppMoneyText(
                              amount: totalVentasUsd,
                              currency: MoneyCurrency.usd,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppCard(
                        padding: AppSpacing.pMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DEUDA PENDIENTE', style: AppTypography.labelSmall.copyWith(color: AppPalette.error)),
                            const SizedBox(height: 4),
                            AppMoneyText(
                              amount: totalDeudaUsd,
                              currency: MoneyCurrency.usd,
                              nature: MoneyNature.debt,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filtros rápidos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Row(
                  children: ['Todos', 'Pagada', 'Pendiente'].map((st) {
                    final isSel = _filterStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: isSel,
                        selectedColor: AppPalette.blue100,
                        labelStyle: TextStyle(
                          color: isSel ? AppPalette.blue900 : AppPalette.textSecondary,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _filterStatus = st);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Lista de ventas
              Expanded(
                child: ventas.isEmpty
                    ? const AppEmptyState(
                        title: 'No hay ventas registradas',
                        description: 'Pulsa "Nueva Venta" para asentar la primera transacción.',
                        icon: CupertinoIcons.cart,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                        itemCount: ventas.length,
                        itemBuilder: (context, index) {
                          final v = ventas[index];
                          final isPaid = v.estado == EstadoVenta.pagada;
                          final hasDebt = v.deudaUsd > 0;

                          return Padding(
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
                                              'Venta #${v.id}',
                                              style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          AppChip(
                                            label: isPaid ? 'Pagada' : 'Pendiente',
                                            variant: isPaid ? AppChipVariant.success : AppChipVariant.warning,
                                            icon: isPaid ? AppIcons.success : AppIcons.warning,
                                          ),
                                        ],
                                      ),
                                      AppMoneyText(
                                        amount: v.totalPagarUsd,
                                        currency: MoneyCurrency.usd,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cliente: ${v.clienteId} • Ítem: ${v.itemId} (Cant: ${v.cantidad})',
                                    style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Text(
                                    'Pago: ${v.tipoPago.label} • Tasa BCV: ${v.tasaBcv} • Fecha: ${v.fecha.toIso8601String().split('T').first}',
                                    style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (hasDebt) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: AppSpacing.xs,
                                      runSpacing: 2,
                                      children: [
                                        Text(
                                          'Abonado: USD ${v.abonoUsd.toStringAsFixed(2)} | ',
                                          style: AppTypography.labelSmall.copyWith(fontSize: 12),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Deuda: ',
                                              style: AppTypography.labelSmall.copyWith(
                                                color: AppPalette.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            AppMoneyText(
                                              amount: v.deudaUsd,
                                              currency: MoneyCurrency.usd,
                                              nature: MoneyNature.debt,
                                              fontSize: 12,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (hasDebt)
                                        TextButton.icon(
                                          icon: const Icon(CupertinoIcons.money_dollar, size: 16),
                                          label: const Text('Registrar Abono'),
                                          onPressed: () => _showAbonoDialog(context, ds, v),
                                        ),
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                        tooltip: 'Anular/Eliminar Venta',
                                        onPressed: () => _confirmDelete(context, ds, v),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showNewSaleDialog(BuildContext context, SheetsDataService ds) {
    if (ds.clientes.isEmpty || ds.productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requieren clientes y productos registrados previamente.')),
      );
      return;
    }

    var selectedCliente = ds.clientes.first.id;
    var selectedProducto = ds.productos.first.id;
    final cantidadController = TextEditingController(text: '1');
    final tasaBcvController = TextEditingController(text: '474.00');
    final tasaUsdController = TextEditingController(text: '30.00');
    final abonoController = TextEditingController(text: '0.00');
    var selectedTipoPago = TipoPago.efectivo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final producto = ds.productos.firstWhere((p) => p.id == selectedProducto);
            final cant = int.tryParse(cantidadController.text) ?? 1;
            final totalUsd = producto.precioUsd * cant;
            final tasaBcv = double.tryParse(tasaBcvController.text) ?? 474.0;
            final totalBs = totalUsd * tasaBcv;

            return Padding(
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
                        Text('Registrar Venta (${ds.nextVentaId})', style: AppTypography.titleLarge.copyWith(fontSize: 17)),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCliente,
                      decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                      items: ds.clientes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.nombre} (${c.id})'))).toList(),
                      onChanged: (val) => setModalState(() => selectedCliente = val!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProducto,
                      decoration: const InputDecoration(labelText: 'Producto / Prenda', border: OutlineInputBorder()),
                      items: ds.productos.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.nombre} - USD ${p.precioUsd} (Stock: ${p.cantidad})'))).toList(),
                      onChanged: (val) => setModalState(() => selectedProducto = val!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Cantidad',
                            controller: cantidadController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Tasa BCV (Bs./USD)',
                            controller: tasaBcvController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<TipoPago>(
                      initialValue: selectedTipoPago,
                      decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                      items: TipoPago.values.map((tp) => DropdownMenuItem(value: tp, child: Text(tp.label))).toList(),
                      onChanged: (val) => setModalState(() => selectedTipoPago = val!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Abono Inicial en USD (Total a pagar: USD ${totalUsd.toStringAsFixed(2)})',
                      controller: abonoController,
                      hint: '0.00 para crédito total',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: AppSpacing.pSm,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total: USD ${totalUsd.toStringAsFixed(2)}', style: AppTypography.titleLarge.copyWith(fontSize: 14)),
                          Text('Equivalente: ${totalBs.toStringAsFixed(2)} Bs.', style: AppTypography.bodyMedium),
                        ],
                      ),
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
                            label: 'Guardar Venta',
                            icon: CupertinoIcons.cart_fill,
                            onPressed: () {
                              final abono = double.tryParse(abonoController.text.replaceAll(',', '.')) ?? totalUsd;
                              final deuda = (totalUsd - abono).clamp(0.0, double.infinity);
                              final nuevaVenta = Venta(
                                id: ds.nextVentaId,
                                fecha: DateTime.now(),
                                clienteId: selectedCliente,
                                itemId: selectedProducto,
                                cantidad: cant,
                                tasaBcv: tasaBcv,
                                tasaUsd: double.tryParse(tasaUsdController.text) ?? 30.0,
                                tipoPago: selectedTipoPago,
                                comisionPagoMovilBs: 0.0,
                                montoBs: totalBs,
                                montoUsd: totalUsd,
                                abonoUsd: abono,
                                deudaUsd: deuda,
                                totalPagarUsd: totalUsd,
                                validacion: 'OK',
                                estado: deuda == 0 ? EstadoVenta.pagada : EstadoVenta.pendiente,
                              );
                              ds.addVenta(nuevaVenta);
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAbonoDialog(BuildContext context, SheetsDataService ds, Venta v) {
    final abonoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abono a Venta #${v.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deuda actual: USD ${v.deudaUsd.toStringAsFixed(2)}', style: AppTypography.titleLarge.copyWith(color: AppPalette.error, fontSize: 14)),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Monto a Abonar (USD)',
              controller: abonoController,
              hint: 'Ej: 10.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            child: const Text('Aplicar Abono'),
            onPressed: () {
              final monto = double.tryParse(abonoController.text.replaceAll(',', '.')) ?? 0.0;
              if (monto > 0) {
                ds.registrarAbono(v.id, monto);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SheetsDataService ds, Venta v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Anular venta?'),
        content: Text('Se anulará la venta #${v.id} y se registrará en la bitácora de auditoría.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Anular'),
            onPressed: () {
              ds.deleteVenta(v.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
