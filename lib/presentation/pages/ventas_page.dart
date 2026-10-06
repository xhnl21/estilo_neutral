import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/di/injection.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../core/router/route_paths.dart';
import '../../features/credits/credits.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/abono/abono_cubit.dart';
import '../cubits/abono/abono_state.dart';
import '../cubits/nueva_venta/nueva_venta_cubit.dart';
import '../cubits/nueva_venta/nueva_venta_state.dart';
import '../cubits/ventas/ventas_cubit.dart';
import '../cubits/ventas/ventas_state.dart';

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
            Expanded(
              child: Text(
                tasaAutomatica != null
                    ? 'Tasa BCV del día: ${tasaAutomatica!.valor.toStringAsFixed(2)} Bs. / ${tasaAutomatica!.moneda}'
                    : 'Tasa BCV no disponible todavía',
                style: AppTypography.labelSmall.copyWith(
                  color: AppPalette.blue900,
                  fontWeight: FontWeight.w600,
                ),
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


/// Pantalla de Ventas (hoja: ventas, header de factura + hoja "venta_items").
/// Una venta puede tener varios ítems (relación 1:N venta→ítems), como una
/// factura real con múltiples renglones.
class VentasPage extends StatelessWidget {
  final SheetsDataService dataService;
  final String? clienteIdInicial;

  const VentasPage({super.key, required this.dataService, this.clienteIdInicial});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VentasCubit(
        dataService: dataService,
        initialClienteId: clienteIdInicial,
      ),
      child: _VentasView(
        dataService: dataService,
        clienteIdInicial: clienteIdInicial,
      ),
    );
  }
}

class _VentasView extends StatefulWidget {
  final SheetsDataService dataService;
  final String? clienteIdInicial;

  const _VentasView({required this.dataService, this.clienteIdInicial});

  @override
  State<_VentasView> createState() => _VentasViewState();
}

class _VentasViewState extends State<_VentasView> {
  @override
  void didUpdateWidget(covariant _VentasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clienteIdInicial != oldWidget.clienteIdInicial) {
      context.read<VentasCubit>().setFiltroCliente(widget.clienteIdInicial);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataService;

    // Si cambia la lista de clientes con el menú del filtro abierto, se
    // cierra: un menú abierto no actualiza sus opciones.
    return MultiBlocListener(
      listeners: [
        BlocListener<VentasCubit, VentasState>(
          listenWhen: (prev, curr) => prev.clientesVersion != curr.clientesVersion,
          listener: (context, _) => _cerrarMenusDesactualizados(context),
        ),
        // Resultado de anular una venta (éxito o el error real de Sheets).
        BlocListener<VentasCubit, VentasState>(
          listenWhen: (prev, curr) =>
              (curr.actionSuccessMessage != null && prev.actionSuccessMessage != curr.actionSuccessMessage) ||
              (curr.status == VentasStatus.failure && curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
          listener: (context, state) {
            final error = state.status == VentasStatus.failure ? state.errorMessage : null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error ?? state.actionSuccessMessage!),
                backgroundColor: error != null ? AppPalette.error : AppPalette.success,
              ),
            );
          },
        ),
      ],
      child: _buildContent(context, ds),
    );
  }

  Widget _buildContent(BuildContext context, SheetsDataService ds) {
    return BlocBuilder<VentasCubit, VentasState>(
      builder: (context, state) {
        final cubit = context.read<VentasCubit>();
        final ventas = state.filteredVentas;

        final totalVentasUsd = ventas.fold<double>(0.0, (sum, v) => sum + v.totalPagarUsd);
        final totalDeudaUsd = ventas.fold<double>(0.0, (sum, v) => sum + (v.deudaUsd > 0 ? v.deudaUsd : 0.0));
        final allAvailableCredits = ServiceLocator().creditsDataSource.credits.where((c) => c.isAvailable);
        final totalSaldoAFavorUsd = state.filtroClienteId != null
            ? allAvailableCredits.where((c) => c.clienteId == state.filtroClienteId).fold<double>(0.0, (sum, c) => sum + c.saldoUsd)
            : allAvailableCredits.fold<double>(0.0, (sum, c) => sum + c.saldoUsd);

        return AppScaffold(
          title: 'Ventas',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'ventas',
            userFriendlyText: '${state.ventas.length} facturas registradas',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == VentasStatus.loading,
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
            child: (state.status == VentasStatus.loading && state.ventas.isEmpty)
                ? const SalesSkeleton(key: ValueKey('sales_skeleton'))
                : Column(
                    key: const ValueKey('sales_content'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey('cliente_filter_${state.filtroClienteId}'),
                          initialValue: state.clientes.any((c) => c.id == state.filtroClienteId)
                              ? state.filtroClienteId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por cliente',
                            prefixIcon: Icon(CupertinoIcons.person_fill, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Todos los clientes')),
                            ...{for (final c in state.clientes) c.id: c}.values.map(
                                  (c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
                                ),
                          ],
                          onChanged: (val) => cubit.setFiltroCliente(val),
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
                      if (totalSaldoAFavorUsd > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                          child: AppCard(
                            padding: AppSpacing.pMd,
                            mergeSemantics: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('SALDO A FAVOR DISPONIBLE', style: AppTypography.labelSmall.copyWith(color: AppPalette.success)),
                                AppMoneyText(
                                  amount: totalSaldoAFavorUsd,
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
                            final isSel = state.filterStatus == st;
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
                                  if (val) cubit.setFilterStatus(st);
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
                          : ListView(
                              key: const ValueKey('sales_list'),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                              children: [
                                ExpansionPanelList(
                                  elevation: 1,
                                  expandedHeaderPadding: const EdgeInsets.symmetric(vertical: 4),
                                  expansionCallback: (panelIndex, isExpanded) {
                                    final v = ventas[panelIndex];
                                    cubit.toggleExpanded(v.id);
                                  },
                                  children: ventas.map<ExpansionPanel>((v) {
                                    final cliente = state.clientes.where((c) => c.id == v.clienteId).firstOrNull;
                                    final availableCredits = ServiceLocator().creditsDataSource.credits.where((c) => c.clienteId == v.clienteId && c.isAvailable).toList();
                                    final saldoAFavor = availableCredits.fold<double>(0.0, (sum, c) => sum + c.saldoUsd);
                                    final pagadaConCredito = ds.abonosDeVenta(v.id).any((a) => a.metodoPagoId == 'mp00000009');
                                    final isPaid = v.estado == EstadoVenta.pagada;
                                    final hasDebt = v.deudaUsd > 0;
                                    final isExpanded = state.expandedVentaId == v.id;
                                    final metodoPagoNombre = ds.metodoPagoNombre(v.metodoPagoId);
                                    final cantidadItems = ds.itemsDeVenta(v.id).length;

                                    return ExpansionPanel(
                                      isExpanded: isExpanded,
                                      canTapOnHeader: true,
                                      backgroundColor: AppPalette.surface,
                                      headerBuilder: (context, isHeaderExpanded) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                          child: Row(
                                            children: [
                                              ExcludeSemantics(
                                                child: CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: isPaid
                                                      ? AppPalette.blue100
                                                      : const Color(0xFFFFEBEE),
                                                  child: Icon(
                                                    isPaid ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.clock_fill,
                                                    color: isPaid ? AppPalette.success : AppPalette.error,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: AppSpacing.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            'Factura #${v.id}',
                                                            style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                                            maxLines: isHeaderExpanded ? null : 1,
                                                            overflow: isHeaderExpanded ? null : TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: AppSpacing.xs),
                                                        AppChip(
                                                          label: isPaid
                                                              ? (pagadaConCredito ? 'Pagada con saldo' : 'Pagada')
                                                              : 'Pendiente',
                                                          variant: isPaid ? AppChipVariant.success : AppChipVariant.warning,
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 8,
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        Text(
                                                          '👤 ${cliente?.nombre ?? v.clienteId}',
                                                          style: AppTypography.labelSmall.copyWith(
                                                            color: AppPalette.textSecondary,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        AppMoneyText(
                                                          amount: v.totalPagarUsd,
                                                          currency: MoneyCurrency.usd,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                        if (hasDebt)
                                                          Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                'Debe: ',
                                                                style: AppTypography.labelSmall.copyWith(
                                                                  color: AppPalette.error,
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                              AppMoneyText(
                                                                amount: v.deudaUsd,
                                                                currency: MoneyCurrency.usd,
                                                                nature: MoneyNature.debt,
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      body: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Divider(color: AppPalette.divider),
                                            const SizedBox(height: 4),
                                            SelectableText.rich(
                                              TextSpan(
                                                style: AppTypography.bodyMedium.copyWith(fontSize: 13, height: 1.5),
                                                children: [
                                                  const TextSpan(text: '👤 Cliente: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: '${cliente?.nombre ?? v.clienteId} (${v.clienteId})'),
                                                  const TextSpan(text: '\n📦 Cantidad de prendas: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: '$cantidadItems ítem${cantidadItems == 1 ? '' : 's'}'),
                                                  const TextSpan(text: '\n💳 Método de pago: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: metodoPagoNombre),
                                                  const TextSpan(text: '\n📈 Tasa BCV: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: 'VES ${v.tasaBcv.toStringAsFixed(2)}'),
                                                  const TextSpan(text: '\n📅 Fecha: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: v.fecha.toIso8601String().split('T').first),
                                                  const TextSpan(text: '\n💵 Total a pagar: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: 'USD ${v.totalPagarUsd.toStringAsFixed(2)} (Bs. ${(v.totalPagarUsd * v.tasaBcv).toStringAsFixed(2)})'),
                                                  const TextSpan(text: '\n💰 Abonado: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: 'USD ${v.abonoUsd.toStringAsFixed(2)}'),
                                                  const TextSpan(text: '\n⚠️ Deuda restante: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: 'USD ${v.deudaUsd.toStringAsFixed(2)}', style: TextStyle(color: hasDebt ? AppPalette.error : AppPalette.textPrimary, fontWeight: FontWeight.w600)),
                                                  if (v.excedenteUsd > 0) ...[
                                                    const TextSpan(text: '\n✨ Excedente/Sobrepago: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                    TextSpan(text: 'USD ${v.excedenteUsd.toStringAsFixed(2)}', style: const TextStyle(color: AppPalette.success)),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            if (saldoAFavor > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8.0),
                                                child: Row(
                                                  children: [
                                                    Text('Saldo disponible del cliente: ', style: AppTypography.labelSmall),
                                                    CreditChip(amount: saldoAFavor, isCredit: true),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: AppSpacing.xs,
                                              runSpacing: AppSpacing.xs,
                                              children: [
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.blue700,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.doc_text, size: 16),
                                                  label: const Text('Ver detalle'),
                                                  onPressed: () => context.push(RoutePaths.buildSaleDetailPath(v.id)),
                                                ),
                                                if (hasDebt && saldoAFavor > 0)
                                                  ApplyCreditButton(
                                                    applicableAmount: saldoAFavor < v.deudaUsd ? saldoAFavor : v.deudaUsd,
                                                    onPressed: () {
                                                      // Sin usuario identificado no se firma la operación (no se inventa un autor).
                                                      if (ds.currentUsuarioEmail == null) {
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                          content: Text('No hay un usuario identificado: no se puede aplicar el crédito.'),
                                                          backgroundColor: AppPalette.error,
                                                        ));
                                                        return;
                                                      }
                                                      final cubit = ApplyCreditCubit(
                                                        repository: ServiceLocator().creditRepository,
                                                        dataService: ds,
                                                      );
                                                      ApplyCreditSheet.show(
                                                        context,
                                                        cubit: cubit,
                                                        clienteId: v.clienteId,
                                                        clienteNombre: cliente?.nombre ?? v.clienteId,
                                                        ventaId: v.id,
                                                        deudaVenta: v.deudaUsd,
                                                        totalCreditoDisponible: saldoAFavor,
                                                        origenVentaId: availableCredits.firstOrNull?.origenVentaId,
                                                        userEmail: ds.currentUsuarioEmail!,
                                                      );
                                                    },
                                                  ),
                                                if (hasDebt)
                                                  OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      visualDensity: VisualDensity.compact,
                                                      foregroundColor: AppPalette.blue700,
                                                      side: const BorderSide(color: AppPalette.border),
                                                    ),
                                                    icon: const Icon(CupertinoIcons.money_dollar, size: 16),
                                                    label: const Text('Abonar'),
                                                    onPressed: () => _showAbonoDialog(v),
                                                  ),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.error,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.trash, size: 16),
                                                  label: const Text('Anular'),
                                                  onPressed: () => _confirmDelete(context, ds, v),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
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

    final initialClienteId = context.read<VentasCubit>().state.filtroClienteId ?? ds.clientes.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BlocProvider(
        create: (_) => NuevaVentaCubit(dataService: ds, initialClienteId: initialClienteId),
        child: const _NuevaVentaBottomSheet(),
      ),
    );
  }

  void _showAbonoDialog(Venta v) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider(
        create: (_) => AbonoCubit(dataService: widget.dataService, ventaId: v.id),
        child: const _AbonoDialog(),
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
              await context.read<VentasCubit>().anularVenta(v.id);
            },
          ),
        ],
      ),
    );
  }
}


/// Diálogo "Abono a Venta". Solo el `TextEditingController` vive en el widget
/// (estado visual efímero); deuda, métodos de pago, tasas, selección,
/// validación y guardado viven en [AbonoCubit].
class _AbonoDialog extends StatefulWidget {
  const _AbonoDialog();

  @override
  State<_AbonoDialog> createState() => _AbonoDialogState();
}

class _AbonoDialogState extends State<_AbonoDialog> {
  final TextEditingController _abonoController = TextEditingController();

  @override
  void dispose() {
    _abonoController.dispose();
    super.dispose();
  }

  void _mostrarResultado(BuildContext context, ResultadoAbono resultado) {
    final (mensaje, color) = switch (resultado) {
      ResultadoAbono.registrado => ('Pago registrado', AppPalette.success),
      ResultadoAbono.rechazado => ('No se pudo registrar el pago. Probá de nuevo.', AppPalette.error),
      ResultadoAbono.sinConfirmar => (
          'No se pudo confirmar si el pago quedó guardado. Se recargaron los datos: '
              'revisá el historial de la factura antes de reintentar.',
          AppPalette.warning,
        ),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: Duration(seconds: resultado == ResultadoAbono.sinConfirmar ? 6 : 3),
      ),
    );
  }

  /// El monto supera la deuda: el excedente quedaría como saldo a favor del
  /// cliente, así que se pide confirmación explícita antes de guardarlo.
  Future<void> _confirmarExcedente(BuildContext context, double excedente) async {
    final cubit = context.read<AbonoCubit>();
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('El monto supera la deuda'),
        content: Text(
          'Sobran USD ${excedente.toStringAsFixed(2)}. Esa diferencia quedará como saldo a favor '
          'del cliente, para usar en otras facturas. ¿Registrar el pago igual?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Corregir monto')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );
    if (aceptar == true) {
      cubit.registrar(_abonoController.text, excedenteConfirmado: true);
    } else {
      cubit.excedenteDescartado();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Un menú de métodos de pago abierto no actualiza sus opciones.
        BlocListener<AbonoCubit, AbonoState>(
          listenWhen: (prev, curr) => prev.metodosPagoVersion != curr.metodosPagoVersion,
          listener: (context, _) => _cerrarMenusDesactualizados(context),
        ),
        BlocListener<AbonoCubit, AbonoState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status && curr.status == AbonoStatus.terminado,
          listener: (context, state) {
            _mostrarResultado(context, state.resultado!);
            Navigator.of(context).pop();
          },
        ),
        BlocListener<AbonoCubit, AbonoState>(
          listenWhen: (prev, curr) =>
              curr.excedentePorConfirmar != null && prev.excedentePorConfirmar != curr.excedentePorConfirmar,
          listener: (context, state) => _confirmarExcedente(context, state.excedentePorConfirmar!),
        ),
        BlocListener<AbonoCubit, AbonoState>(
          listenWhen: (prev, curr) => curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppPalette.error),
            );
            context.read<AbonoCubit>().mensajeMostrado();
          },
        ),
      ],
      child: BlocBuilder<AbonoCubit, AbonoState>(
        builder: (context, state) => _buildDialogo(context, state),
      ),
    );
  }

  Widget _buildDialogo(BuildContext context, AbonoState state) {
    final cubit = context.read<AbonoCubit>();
    final isProcessing = state.isProcessing;
    final venta = state.venta;

    return PopScope(
      canPop: !isProcessing,
      child: AlertDialog(
        title: Text('Abono a Venta #${venta?.id ?? cubit.ventaId}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                venta == null
                    ? 'Esta factura ya no existe.'
                    : 'Deuda actual: USD ${venta.deudaUsd.toStringAsFixed(2)}',
                style: AppTypography.titleLarge.copyWith(color: AppPalette.error, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.metodosPago.isEmpty)
                Text(
                  'No hay métodos de pago activos. Activá uno en Métodos de Pago.',
                  style: AppTypography.bodyMedium.copyWith(color: AppPalette.error),
                )
              else
                // La key recrea el campo cuando la selección la cambia el
                // Cubit (DropdownButtonFormField solo lee initialValue al crearse).
                DropdownButtonFormField<String>(
                  key: ValueKey('abono_metodo_${state.selectedMetodoPagoId}'),
                  initialValue: state.selectedMetodoPagoId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago para Abono',
                    border: OutlineInputBorder(),
                  ),
                  items: state.metodosPago
                      .map((mp) => DropdownMenuItem(value: mp.id, child: Text(mp.nombre, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: isProcessing
                      ? null
                      : (val) {
                          if (val != null) cubit.seleccionarMetodo(val);
                        },
                ),
              _TasaSelector(
                tasaAutomatica: state.tasaAutomatica,
                tasaManual: state.tasaManual,
                usarManual: state.usarTasaManual,
                onChanged: isProcessing ? (_) {} : cubit.setUsarTasaManual,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Monto a Abonar (USD)',
                controller: _abonoController,
                hint: 'Ej: 10.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                readOnly: isProcessing,
                errorText: state.errorMonto,
                onChanged: (_) => cubit.montoCambiado(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isProcessing ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: isProcessing || venta == null || state.metodosPago.isEmpty
                ? null
                : () => cubit.registrar(_abonoController.text),
            child: isProcessing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text('Procesando...'),
                    ],
                  )
                : const Text('Aplicar Abono'),
          ),
        ],
      ),
    );
  }
}

/// Cierra los menús desplegables abiertos (DropdownRoute, PopupMenu) que
/// estén por encima de [context]. Un menú abierto copia sus opciones al
/// abrirse y no se actualiza: si el catálogo cambió (p. ej. se editó o
/// eliminó un cliente desde otra pestaña) mostraría datos viejos. No cierra
/// bottom sheets ni diálogos.
void _cerrarMenusDesactualizados(BuildContext context) {
  Navigator.of(context).popUntil(
    (route) => route is! PopupRoute || route is ModalBottomSheetRoute || route is RawDialogRoute,
  );
}

/// Formulario "Registrar Venta". Solo los `TextEditingController` viven en el
/// widget (estado visual efímero); catálogos, selección, carrito y guardado
/// viven en [NuevaVentaCubit], que se mantiene sincronizado con
/// [SheetsDataService] mientras el modal está abierto.
class _NuevaVentaBottomSheet extends StatefulWidget {
  const _NuevaVentaBottomSheet();

  @override
  State<_NuevaVentaBottomSheet> createState() => _NuevaVentaBottomSheetState();
}

class _NuevaVentaBottomSheetState extends State<_NuevaVentaBottomSheet> {
  final TextEditingController _cantidadController = TextEditingController(text: '1');
  final TextEditingController _abonoController = TextEditingController(text: '0.00');

  @override
  void dispose() {
    _cantidadController.dispose();
    _abonoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NuevaVentaCubit, NuevaVentaState>(
      listenWhen: (prev, curr) =>
          prev.clientesVersion != curr.clientesVersion ||
          prev.productosVersion != curr.productosVersion ||
          prev.metodosPagoVersion != curr.metodosPagoVersion,
      listener: (context, _) => _cerrarMenusDesactualizados(context),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return BlocConsumer<NuevaVentaCubit, NuevaVentaState>(
      listenWhen: (prev, curr) => curr.message != null && prev.message != curr.message,
      listener: (context, state) {
        final color = switch (state.messageType) {
          NuevaVentaMessageType.success => AppPalette.success,
          NuevaVentaMessageType.warning => AppPalette.warning,
          NuevaVentaMessageType.error => AppPalette.error,
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: color, content: Text(state.message!)),
        );
        if (state.status == NuevaVentaStatus.success) {
          Navigator.of(context).pop();
        } else {
          context.read<NuevaVentaCubit>().messageShown();
        }
      },
      builder: (context, state) {
        final cubit = context.read<NuevaVentaCubit>();
        final isProcessing = state.isSubmitting;
        final totalCarrito = state.totalCarrito;

        return PopScope(
          canPop: !isProcessing,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
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
                          'Registrar Venta (${state.nextVentaId})',
                          style: AppTypography.titleLarge.copyWith(fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                        onPressed: isProcessing ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // La key recrea el campo cuando la selección cambia desde
                  // el Cubit (DropdownButtonFormField solo lee `initialValue`
                  // al crearse). Las opciones se actualizan en cada rebuild;
                  // un menú ya abierto lo cierra el BlocListener de arriba.
                  DropdownButtonFormField<String>(
                    key: ValueKey('venta_cliente_${state.selectedClienteId}'),
                    initialValue: state.selectedClienteId,
                    isExpanded: true,
                    hint: const Text('Seleccioná un cliente'),
                    decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                    items: state.clientes
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.nombre} (${c.id})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: isProcessing
                        ? null
                        : (val) {
                            if (val != null) cubit.selectCliente(val);
                          },
                  ),
                  if (state.deudaCliente > 0 || state.saldoCliente > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 4,
                        children: [
                          if (state.deudaCliente > 0)
                            CreditChip(amount: state.deudaCliente, isCredit: false),
                          if (state.saldoCliente > 0)
                            CreditChip(amount: state.saldoCliente, isCredit: true),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Agregar productos', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    key: ValueKey('venta_producto_${state.selectedProductoId}'),
                    initialValue: state.selectedProductoId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Producto / Prenda', border: OutlineInputBorder()),
                    items: state.productos
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.nombre} - USD ${p.precioUsd.toStringAsFixed(2)} (Stock: ${p.cantidad})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) cubit.selectProducto(val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Cantidad',
                          controller: _cantidadController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppOutlinedButton(
                        label: 'Agregar',
                        onPressed: () {
                          if (cubit.addToCart(_cantidadController.text)) {
                            _cantidadController.text = '1';
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (state.carrito.isEmpty)
                    Text(
                      'Todavía no agregaste ningún producto.',
                      style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                    )
                  else
                    ...state.carrito.asMap().entries.map((entry) {
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
                                onPressed: () => cubit.removeFromCart(entry.key),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    key: ValueKey('venta_metodo_${state.selectedMetodoPagoId}'),
                    initialValue: state.selectedMetodoPagoId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                    items: state.metodosPago
                        .map((mp) => DropdownMenuItem(value: mp.id, child: Text(mp.nombre, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) cubit.selectMetodoPago(val);
                    },
                  ),
                  _TasaSelector(
                    tasaAutomatica: state.tasaAutomatica,
                    tasaManual: state.tasaManual,
                    usarManual: state.usarTasaManual,
                    onChanged: cubit.setUsarTasaManual,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Abono Inicial en USD (Total: USD ${totalCarrito.toStringAsFixed(2)})',
                    controller: _abonoController,
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
                        Text('Equivalente: ${state.totalBs.toStringAsFixed(2)} Bs.', style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppOutlinedButton(
                          label: 'Cancelar',
                          onPressed: isProcessing ? null : () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: isProcessing ? 'Guardando...' : 'Guardar Venta',
                          icon: isProcessing ? null : CupertinoIcons.cart_fill,
                          onPressed: isProcessing ? null : () => cubit.submit(_abonoController.text),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
