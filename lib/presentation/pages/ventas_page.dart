import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../core/router/route_paths.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';

/// Muestra la tasa que se va a aplicar al pago, junto al selector de método
/// de pago. Si la organización no tiene una tasa manual configurada, es
/// solo informativa (la BCV automática del día). Si sí la tiene, deja
/// elegir entre la BCV automática y la manual de la organización — la
/// elección queda guardada en el abono junto con el método y la fecha/hora.
class _TasaSelector extends StatelessWidget {
  final TasaRegistro? tasaAutomatica;
  final TasaRegistro? tasaManual;
  final bool usarManual;
  final ValueChanged<bool> onChanged;

  const _TasaSelector({
    required this.tasaAutomatica,
    required this.tasaManual,
    required this.usarManual,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (tasaManual == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: [
            const Icon(CupertinoIcons.info_circle, size: 14, color: AppPalette.blue900),
            const SizedBox(width: AppSpacing.xs),
            Text(
              tasaAutomatica != null
                  ? 'Tasa BCV del día: ${tasaAutomatica!.valor.toStringAsFixed(2)} Bs. / ${tasaAutomatica!.moneda}'
                  : 'Tasa BCV no disponible todavía',
              style: AppTypography.labelSmall.copyWith(
                color: AppPalette.blue900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TasaOptionTile(
            label: 'Tasa BCV automática',
            valor: tasaAutomatica?.valor,
            selected: !usarManual,
            onTap: () => onChanged(false),
          ),
          _TasaOptionTile(
            label: 'Tasa manual de la organización',
            valor: tasaManual?.valor,
            selected: usarManual,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _TasaOptionTile extends StatelessWidget {
  final String label;
  final double? valor;
  final bool selected;
  final VoidCallback onTap;

  const _TasaOptionTile({required this.label, required this.valor, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              size: 18,
              color: selected ? AppPalette.primary : AppPalette.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '$label${valor != null ? ': ${valor!.toStringAsFixed(2)} Bs.' : ''}',
                style: AppTypography.labelSmall.copyWith(
                  color: selected ? AppPalette.textPrimary : AppPalette.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de progreso mientras se registra un abono — no descartable
/// (ni tocando afuera ni con el botón de retroceso), para que el usuario no
/// lo cierre a mitad de camino pensando que quedó colgado.
class _ProcesandoPagoDialog extends StatelessWidget {
  const _ProcesandoPagoDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Procesando pago...', style: AppTypography.bodyMedium),
          ],
        ),
      ),
    );
  }
}

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
  void didUpdateWidget(covariant VentasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // StatefulShellRoute.indexedStack preserva el estado de la pestaña
    // Ventas entre visitas — al volver a navegar acá (ej. desde "Ver
    // Compras" en Clientes) con un ?cliente= distinto, Flutter reutiliza
    // este mismo State en vez de recrearlo, así que initState() no vuelve a
    // correr. Sin este chequeo, el filtro de cliente del primer ingreso
    // queda pegado para siempre y los clics posteriores en "Ver Compras"
    // no filtran nada.
    if (widget.clienteIdInicial != oldWidget.clienteIdInicial) {
      _filtroClienteId = widget.clienteIdInicial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataService;

    return ListenableBuilder(
      listenable: ds,
      builder: (context, _) {
        final ventas = ds.ventas.where((v) {
          if (_filtroClienteId != null && v.clienteId != _filtroClienteId) return false;
          if (_filterStatus == 'Pagada') return v.estado == EstadoVenta.pagada;
          if (_filterStatus == 'Pendiente') return v.estado == EstadoVenta.pendiente;
          return true;
        }).toList();

        final totalVentasUsd = ventas.fold<double>(0.0, (sum, v) => sum + v.totalPagarUsd);
        // Defensivo: deuda_usd viene de una fórmula del Sheet — se clamp acá
        // también, por si alguna fila vieja todavía no recalculó con el
        // MAX(0,...) nuevo. Un excedente (pago que superó el total de esa
        // factura) nunca debe aparecer mezclado como deuda negativa.
        final totalDeudaUsd = ventas.fold<double>(0.0, (sum, v) => sum + (v.deudaUsd > 0 ? v.deudaUsd : 0.0));
        final totalExcedenteUsd = ventas.fold<double>(0.0, (sum, v) => sum + v.excedenteUsd);

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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                        child: DropdownButtonFormField<String?>(
                          // Sin este key, si _filtroClienteId cambia desde
                          // afuera (ej. didUpdateWidget al llegar por otro
                          // "Ver Compras" mientras esta pestaña ya estaba
                          // viva), el FormField interno no vuelve a leer
                          // initialValue y la selección visible queda
                          // desactualizada aunque el filtro real sí cambió.
                          key: ValueKey('cliente_filter_$_filtroClienteId'),
                          initialValue: _filtroClienteId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por cliente',
                            prefixIcon: Icon(CupertinoIcons.person_fill, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Todos los clientes')),
                            // Deduplicado por id: un dato sucio en clientes
                            // (id repetido) no debería tumbar este dropdown.
                            ...{for (final c in ds.clientes) c.id: c}.values.map(
                                  (c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
                                ),
                          ],
                          onChanged: (val) => setState(() => _filtroClienteId = val),
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
                      // Solo se muestra si de verdad hay un excedente (algún
                      // cliente abonó más de lo que costaba una factura
                      // puntual) — no es un estado normal, así que no ocupa
                      // espacio en pantalla cuando no aplica.
                      if (totalExcedenteUsd > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                          child: AppCard(
                            padding: AppSpacing.pMd,
                            mergeSemantics: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('EXCEDENTE', style: AppTypography.labelSmall.copyWith(color: AppPalette.success)),
                                AppMoneyText(
                                  amount: totalExcedenteUsd,
                                  currency: MoneyCurrency.usd,
                                  nature: MoneyNature.credit,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ],
                            ),
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
                                    metodoPagoNombre: ds.metodoPagoNombre(v.metodoPagoId),
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
    final abonoController = TextEditingController(text: '0.00');
    final metodosActivos = ds.metodosPagoActivos;
    var selectedMetodoPago = metodosActivos.isNotEmpty ? metodosActivos.first.id : '';
    var usarTasaManual = false;
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
            final tasaSeleccionada = usarTasaManual
                ? ds.tasaManualOrganizacion(ds.currentOrganizacionId ?? '')
                : ds.tasaVigenteEnMonedaBase;
            final totalBs = totalCarrito * (tasaSeleccionada?.valor ?? 0.0);

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
                    DropdownButtonFormField<String>(
                      initialValue: metodosActivos.any((m) => m.id == selectedMetodoPago)
                          ? selectedMetodoPago
                          : (metodosActivos.isNotEmpty ? metodosActivos.first.id : null),
                      decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                      items: metodosActivos
                          .map((mp) => DropdownMenuItem(value: mp.id, child: Text(mp.nombre)))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedMetodoPago = val ?? metodosActivos.first.id),
                    ),
                    _TasaSelector(
                      tasaAutomatica: ds.tasaVigenteEnMonedaBase,
                      tasaManual: ds.tasaManualOrganizacion(ds.currentOrganizacionId ?? ''),
                      usarManual: usarTasaManual,
                      onChanged: (val) => setModalState(() => usarTasaManual = val),
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
                                metodoPagoId: selectedMetodoPago,
                                abonoUsd: abono,
                                usarTasaManual: usarTasaManual,
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
    var selectedMetodoPago = metodosActivos.isNotEmpty ? metodosActivos.first.id : '';
    var usarTasaManual = false;

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
                initialValue: metodosActivos.any((m) => m.id == selectedMetodoPago)
                    ? selectedMetodoPago
                    : (metodosActivos.isNotEmpty ? metodosActivos.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Método de Pago para Abono',
                  border: OutlineInputBorder(),
                ),
                items: metodosActivos
                    .map((mp) => DropdownMenuItem(value: mp.id, child: Text(mp.nombre)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedMetodoPago = val ?? metodosActivos.first.id),
              ),
              _TasaSelector(
                tasaAutomatica: ds.tasaVigenteEnMonedaBase,
                tasaManual: ds.tasaManualOrganizacion(ds.currentOrganizacionId ?? ''),
                usarManual: usarTasaManual,
                onChanged: (val) => setDialogState(() => usarTasaManual = val),
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
              onPressed: () async {
                final monto = double.tryParse(abonoController.text.replaceAll(',', '.')) ?? 0.0;
                if (monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresá un monto válido para abonar.')),
                  );
                  return;
                }

                Navigator.pop(ctx); // cierra el diálogo de abono

                // Diálogo de progreso mientras se sincroniza con Google
                // Sheets — no se puede cerrar tocando afuera ni con el
                // botón de retroceso, para que el usuario no piense que
                // falló y lo intente de nuevo mientras el pedido sigue en
                // curso (evita abonos duplicados).
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  useRootNavigator: true, // ver por qué en el pop de abajo
                  builder: (_) => const _ProcesandoPagoDialog(),
                );

                final ok = await ds.registrarAbono(
                  v.id,
                  monto,
                  metodoPagoId: selectedMetodoPago,
                  usarTasaManual: usarTasaManual,
                );

                if (!context.mounted) return;
                // showDialog empuja el diálogo de progreso al Navigator
                // raíz (useRootNavigator: true, su default) — pero
                // Navigator.pop(context) a secas resuelve el Navigator MÁS
                // CERCANO, que acá adentro de un StatefulShellRoute es el
                // Navigator de la propia rama "Ventas", no el raíz. Sin
                // rootNavigator: true, esto no cerraba el diálogo sino que
                // sacaba a Ventas de su propia rama (sin nada debajo),
                // tumbando go_router con "no pages left to show".
                Navigator.of(context, rootNavigator: true).pop(); // cierra "Procesando pago..."

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Pago registrado' : 'No se pudo registrar el pago. Probá de nuevo.'),
                    backgroundColor: ok ? AppPalette.success : AppPalette.error,
                  ),
                );
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
  final String metodoPagoNombre;
  final int cantidadItems;
  final VoidCallback onTap;
  final VoidCallback? onAbono;
  final VoidCallback onDelete;

  const _VentaCard({
    required this.venta,
    required this.cliente,
    required this.metodoPagoNombre,
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
                'Pago: $metodoPagoNombre • Tasa BCV: ${venta.tasaBcv} • Fecha: ${venta.fecha.toIso8601String().split('T').first}',
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
