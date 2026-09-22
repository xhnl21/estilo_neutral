import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../core/router/route_paths.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';

/// Un renglón del carrito mientras se arma una factura nueva (estado local
/// del formulario, no persistido hasta guardar la venta completa).
class _CartLine {
  final String productoId;
  final String nombre;
  final int cantidad;
  final double precioUsd;

  const _CartLine({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUsd,
  });

  double get subtotal => cantidad * precioUsd;
}

/// Pantalla de Ventas (hoja: ventas, header de factura + hoja "venta_items").
/// Una venta puede tener varios ítems (relación 1:N venta→ítems), como una
/// factura real con múltiples renglones.
class VentasPage extends StatefulWidget {
  final SheetsDataService dataService;

  /// Si se pasa, la lista arranca filtrada a las facturas de ese cliente
  /// (navegación desde "Ver compras" en Clientes).
  final String? clienteIdInicial;

  const VentasPage({super.key, required this.dataService, this.clienteIdInicial});

  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  String _filterStatus = 'Todos'; // 'Todos', 'Pagada', 'Pendiente'
  String? _filtroClienteId;

  @override
  void initState() {
    super.initState();
    _filtroClienteId = widget.clienteIdInicial;
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataService;

    return ListenableBuilder(
      listenable: ds,
      builder: (context, _) {
        final clienteFiltrado = _filtroClienteId == null
            ? null
            : ds.clientes.where((c) => c.id == _filtroClienteId).firstOrNull;

        final ventas = ds.ventas.where((v) {
          if (_filtroClienteId != null && v.clienteId != _filtroClienteId) return false;
          if (_filterStatus == 'Pagada') return v.estado == EstadoVenta.pagada;
          if (_filterStatus == 'Pendiente') return v.estado == EstadoVenta.pendiente;
          return true;
        }).toList();

        final totalVentasUsd = ventas.fold<double>(0.0, (sum, v) => sum + v.totalPagarUsd);
        final totalDeudaUsd = ventas.fold<double>(0.0, (sum, v) => sum + v.deudaUsd);

        return AppScaffold(
          title: 'Ventas',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'ventas',
            userFriendlyText: '${ds.ventas.length} facturas registradas',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => ds.fetchAllSheets(),
              isLoading: ds.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_ventas',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.cart_badge_plus, size: 20),
            label: const Text('Nueva Venta', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showNewSaleDialog(context, ds),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: ds.isLoading
                ? const SalesSkeleton(key: ValueKey('sales_skeleton'))
                : Column(
                    key: const ValueKey('sales_content'),
                    children: [
                      if (clienteFiltrado != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InputChip(
                              label: Text('Cliente: ${clienteFiltrado.nombre}'),
                              avatar: const Icon(CupertinoIcons.person_fill, size: 16),
                              onDeleted: () => setState(() => _filtroClienteId = null),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppCard(
                                padding: AppSpacing.pMd,
                                mergeSemantics: true,
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
                                mergeSemantics: true,
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
                      Expanded(
                        child: ventas.isEmpty
                            ? const AppEmptyState(
                                title: 'No hay ventas registradas',
                                description: 'Pulsa "Nueva Venta" para asentar la primera factura.',
                                icon: CupertinoIcons.cart,
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                                itemCount: ventas.length,
                                itemBuilder: (context, index) {
                                  final v = ventas[index];
                                  return _VentaCard(
                                    venta: v,
                                    cliente: ds.clientes.where((c) => c.id == v.clienteId).firstOrNull,
                                    cantidadItems: ds.itemsDeVenta(v.id).length,
                                    onTap: () => context.push(RoutePaths.buildSaleDetailPath(v.id)),
                                    onAbono: v.deudaUsd > 0 ? () => _showAbonoDialog(context, ds, v) : null,
                                    onDelete: () => _confirmDelete(context, ds, v),
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

    var selectedCliente = _filtroClienteId ?? ds.clientes.first.id;
    var selectedProducto = ds.productos.first.id;
    final cantidadController = TextEditingController(text: '1');
    final tasaBcvController = TextEditingController(text: '474.00');
    final tasaUsdController = TextEditingController(text: '30.00');
    final abonoController = TextEditingController(text: '0.00');
    final metodosActivos = ds.metodosPagoActivos;
    var selectedMetodoPago = metodosActivos.isNotEmpty ? metodosActivos.first.nombre : 'Efectivo';
    final carrito = <_CartLine>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Defensivo: si el Inventario real tiene productos con el mismo
            // id duplicado (dato sucio, no debería pasar), un dropdown con
            // dos ítems del mismo value revienta con un assertion error. Se
            // deduplica por id, quedándose con la primera aparición.
            final productosUnicos = <String, Producto>{};
            for (final p in ds.productos) {
              productosUnicos.putIfAbsent(p.id, () => p);
            }
            final productosParaElegir = productosUnicos.values.toList();
            final producto = productosParaElegir.firstWhere((p) => p.id == selectedProducto);
            final totalCarrito = carrito.fold<double>(0.0, (s, l) => s + l.subtotal);
            final tasaBcv = double.tryParse(tasaBcvController.text) ?? 474.0;
            final totalBs = totalCarrito * tasaBcv;

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
                        Expanded(
                          child: Text(
                            'Registrar Venta (${ds.nextVentaId})',
                            style: AppTypography.titleLarge.copyWith(fontSize: 17),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                    const SizedBox(height: AppSpacing.md),
                    Text('Agregar productos', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProducto,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Producto / Prenda', border: OutlineInputBorder()),
                      items: productosParaElegir
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  '${p.nombre} - USD ${p.precioUsd.toStringAsFixed(2)} (Stock: ${p.cantidad})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
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
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AppOutlinedButton(
                          label: 'Agregar',
                          onPressed: () {
                            final cant = int.tryParse(cantidadController.text) ?? 0;
                            if (cant < 1) return;
                            if (cant > producto.cantidad) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Solo hay ${producto.cantidad} en stock de ${producto.nombre}.')),
                              );
                              return;
                            }
                            setModalState(() {
                              carrito.add(_CartLine(
                                productoId: producto.id,
                                nombre: producto.nombre,
                                cantidad: cant,
                                precioUsd: producto.precioUsd,
                              ));
                              cantidadController.text = '1';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (carrito.isEmpty)
                      Text(
                        'Todavía no agregaste ningún producto.',
                        style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                      )
                    else
                      ...carrito.asMap().entries.map((entry) {
                        final line = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: AppCard(
                            padding: AppSpacing.pSm,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${line.nombre} × ${line.cantidad} — USD ${line.subtotal.toStringAsFixed(2)}',
                                    style: AppTypography.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(CupertinoIcons.trash, size: 16, color: AppPalette.error),
                                  onPressed: () => setModalState(() => carrito.removeAt(entry.key)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Tasa BCV (Bs./USD)',
                            controller: tasaBcvController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Tasa USD paralelo',
                            controller: tasaUsdController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: metodosActivos.any((m) => m.nombre == selectedMetodoPago)
                          ? selectedMetodoPago
                          : (metodosActivos.isNotEmpty ? metodosActivos.first.nombre : null),
                      decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                      items: metodosActivos
                          .map((mp) => DropdownMenuItem(value: mp.nombre, child: Text(mp.nombre)))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedMetodoPago = val ?? 'Efectivo'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Abono Inicial en USD (Total: USD ${totalCarrito.toStringAsFixed(2)})',
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
                          Text('Total: USD ${totalCarrito.toStringAsFixed(2)}', style: AppTypography.titleLarge.copyWith(fontSize: 14)),
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
                            onPressed: () async {
                              if (carrito.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Agregá al menos un producto al carrito.')),
                                );
                                return;
                              }
                              final abono = double.tryParse(abonoController.text.replaceAll(',', '.')) ?? totalCarrito;
                              Navigator.pop(ctx);
                              await ds.addVenta(
                                clienteId: selectedCliente,
                                items: carrito
                                    .map((l) => (productoId: l.productoId, cantidad: l.cantidad, precioUsd: l.precioUsd))
                                    .toList(),
                                tasaBcv: tasaBcv,
                                tasaUsd: double.tryParse(tasaUsdController.text) ?? 30.0,
                                metodoPago: selectedMetodoPago,
                                abonoUsd: abono,
                              );
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
    final metodosActivos = ds.metodosPagoActivos;
    var selectedMetodoPago = metodosActivos.isNotEmpty ? metodosActivos.first.nombre : 'Efectivo';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Abono a Venta #${v.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deuda actual: USD ${v.deudaUsd.toStringAsFixed(2)}',
                style: AppTypography.titleLarge.copyWith(color: AppPalette.error, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: metodosActivos.any((m) => m.nombre == selectedMetodoPago)
                    ? selectedMetodoPago
                    : (metodosActivos.isNotEmpty ? metodosActivos.first.nombre : null),
                decoration: const InputDecoration(
                  labelText: 'Método de Pago para Abono',
                  border: OutlineInputBorder(),
                ),
                items: metodosActivos
                    .map((mp) => DropdownMenuItem(value: mp.nombre, child: Text(mp.nombre)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedMetodoPago = val ?? 'Efectivo'),
              ),
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
                  ds.registrarAbono(v.id, monto, metodoPago: selectedMetodoPago);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SheetsDataService ds, Venta v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Anular venta?'),
        content: Text('Se anulará la factura #${v.id}, se repondrá el stock de sus ítems y se registrará en la bitácora de auditoría.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Anular'),
            onPressed: () async {
              Navigator.pop(ctx);
              await ds.deleteVenta(v.id);
            },
          ),
        ],
      ),
    );
  }
}

class _VentaCard extends StatelessWidget {
  final Venta venta;
  final Cliente? cliente;
  final int cantidadItems;
  final VoidCallback onTap;
  final VoidCallback? onAbono;
  final VoidCallback onDelete;

  const _VentaCard({
    required this.venta,
    required this.cliente,
    required this.cantidadItems,
    required this.onTap,
    required this.onAbono,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = venta.estado == EstadoVenta.pagada;
    final hasDebt = venta.deudaUsd > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                          'Factura #${venta.id}',
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
                    amount: venta.totalPagarUsd,
                    currency: MoneyCurrency.usd,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Cliente: ${cliente?.nombre ?? venta.clienteId} • $cantidadItems ítem${cantidadItems == 1 ? '' : 's'}',
                style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                'Pago: ${venta.tipoPago.label} • Tasa BCV: ${venta.tasaBcv} • Fecha: ${venta.fecha.toIso8601String().split('T').first}',
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
                      'Abonado: USD ${venta.abonoUsd.toStringAsFixed(2)} | ',
                      style: AppTypography.labelSmall.copyWith(fontSize: 12),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Deuda: ',
                          style: AppTypography.labelSmall.copyWith(color: AppPalette.error, fontWeight: FontWeight.w600),
                        ),
                        AppMoneyText(
                          amount: venta.deudaUsd,
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
                  if (onAbono != null)
                    TextButton.icon(
                      icon: const Icon(CupertinoIcons.money_dollar, size: 16),
                      label: const Text('Registrar Abono'),
                      onPressed: onAbono,
                    ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                    tooltip: 'Anular/Eliminar Venta',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
