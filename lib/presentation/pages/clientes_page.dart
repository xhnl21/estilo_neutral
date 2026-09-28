import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/di/injection.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../core/router/route_paths.dart';
import '../../core/utils/logger.dart';
import '../../features/credits/credits.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/clientes/clientes_cubit.dart';
import '../cubits/clientes/clientes_state.dart';

/// Vista de Clientes (hoja: clientes)
/// Implementada con arquitectura BLoC/Cubit, reactividad pura y CERO setState().
class ClientesPage extends StatelessWidget {
  final SheetsDataService dataService;

  const ClientesPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ClientesCubit(dataService: dataService),
      child: const _ClientesView(),
    );
  }
}

class _ClientesView extends StatelessWidget {
  const _ClientesView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClientesCubit, ClientesState>(
      listenWhen: (prev, curr) =>
          curr.actionSuccessMessage != null &&
          prev.actionSuccessMessage != curr.actionSuccessMessage,
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppPalette.success,
              content: Text(state.actionSuccessMessage!),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<ClientesCubit>();
        final clientes = state.filteredClientes;

        return AppScaffold(
          title: 'Clientes',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'clientes',
            userFriendlyText: '${state.clientes.length} registros',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == ClientesStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_clientes',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.person_badge_plus, size: 20),
            label: const Text(
              'Nuevo Cliente',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => _showClienteDialog(context),
          ),
          body: Column(
            children: [
              // Barra de búsqueda con reactividad por Cubit (Cero setState)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: AppTextField(
                  label: 'Buscar cliente',
                  hint: 'Nombre, teléfono (+58...) o ID...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => cubit.search(val),
                ),
              ),

              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: AppCard(
                    padding: AppSpacing.pSm,
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.warning,
                          size: 16,
                          color: AppPalette.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppPalette.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Lista reactiva de clientes con Skeleton progresivo
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: state.status == ClientesStatus.loading
                      ? const ClientesListSkeleton(
                          key: ValueKey('clientes_skeleton'),
                        )
                      : clientes.isEmpty
                          ? const AppEmptyState(
                              key: ValueKey('clientes_empty'),
                              title: 'No hay clientes registrados',
                              description:
                                  'Usa el botón "Nuevo Cliente" para registrar uno.',
                              icon: CupertinoIcons.person_2,
                            )
                          : ListView(
                              key: const ValueKey('clientes_list'),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                80,
                              ),
                              children: [
                                ExpansionPanelList(
                                  elevation: 1,
                                  expandedHeaderPadding: const EdgeInsets.symmetric(vertical: 4),
                                  expansionCallback: (panelIndex, isExpanded) {
                                    final cliente = clientes[panelIndex];
                                    cubit.toggleExpanded(cliente.id);
                                  },
                                  children: clientes.map<ExpansionPanel>((cliente) {
                                    final ventasDelCliente = cubit.dataService.ventas
                                        .where((v) => v.clienteId == cliente.id);
                                    final deudaReal = ventasDelCliente.fold<double>(
                                        0.0, (sum, v) => sum + (v.deudaUsd > 0 ? v.deudaUsd : 0.0));
                                    final hasDebt = deudaReal > 0;
                                    final clientCredits = ServiceLocator().creditsDataSource.credits.where((c) => c.clienteId == cliente.id && c.isAvailable).toList();
                                    final totalCredito = clientCredits.fold<double>(0.0, (sum, c) => sum + c.saldoUsd);
                                    final hasCreditLedger = ServiceLocator().creditsDataSource.credits.any((c) => c.clienteId == cliente.id);
                                    final excedente = ventasDelCliente.fold<double>(0.0, (sum, v) => sum + v.excedenteUsd);
                                    final saldoAFavor = hasCreditLedger ? totalCredito : (totalCredito > 0 ? totalCredito : excedente);
                                    final isExpanded = state.expandedClienteId == cliente.id;

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
                                                  backgroundColor: hasDebt
                                                      ? const Color(0xFFFFEBEE)
                                                      : AppPalette.blue100,
                                                  child: Icon(
                                                    CupertinoIcons.person_fill,
                                                    color: hasDebt
                                                        ? AppPalette.error
                                                        : AppPalette.blue700,
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
                                                    Text(
                                                      cliente.nombre,
                                                      style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                                      maxLines: isHeaderExpanded ? null : 1,
                                                      overflow: isHeaderExpanded ? null : TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 8,
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        Text(
                                                          'ID: ${cliente.id}',
                                                          style: AppTypography.labelSmall.copyWith(
                                                            color: AppPalette.textSecondary,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        if (hasDebt)
                                                          Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                'Deuda: ',
                                                                style: AppTypography.labelSmall.copyWith(
                                                                  color: AppPalette.error,
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                              AppMoneyText(
                                                                amount: deudaReal,
                                                                currency: MoneyCurrency.usd,
                                                                nature: MoneyNature.debt,
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ],
                                                          ),
                                                        if (saldoAFavor > 0)
                                                          CreditChip(
                                                            amount: saldoAFavor,
                                                            isCredit: true,
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
                                            // Detalle completo sin recortar textos
                                            SelectableText.rich(
                                              TextSpan(
                                                style: AppTypography.bodyMedium.copyWith(fontSize: 13, height: 1.5),
                                                children: [
                                                  const TextSpan(text: '📞 Teléfono: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: cliente.telefono.isNotEmpty ? cliente.telefono : 'No registrado'),
                                                  const TextSpan(text: '\n✉️ Email: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: cliente.email.isNotEmpty ? cliente.email : 'No registrado'),
                                                  const TextSpan(text: '\n📅 Fecha Registro: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: cliente.fechaRegistro.toIso8601String().split('T').first),
                                                  const TextSpan(text: '\n🏢 Organización: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                                  TextSpan(text: cliente.organizacionId),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Deuda Total: ',
                                                      style: AppTypography.labelSmall.copyWith(
                                                        color: hasDebt ? AppPalette.error : AppPalette.textSecondary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    AppMoneyText(
                                                      amount: deudaReal,
                                                      currency: MoneyCurrency.usd,
                                                      nature: hasDebt ? MoneyNature.debt : MoneyNature.neutral,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ],
                                                ),
                                                if (saldoAFavor > 0)
                                                  CreditChip(
                                                    amount: saldoAFavor,
                                                    isCredit: true,
                                                    onTap: () {
                                                      final pendingVentas = ventasDelCliente.where((v) => v.deudaUsd > 0).toList();
                                                      if (pendingVentas.isNotEmpty) {
                                                        final targetVenta = pendingVentas.first;
                                                        final applyCubit = ApplyCreditCubit(
                                                          repository: ServiceLocator().creditRepository,
                                                          dataService: cubit.dataService,
                                                        );
                                                        ApplyCreditSheet.show(
                                                          context,
                                                          cubit: applyCubit,
                                                          clienteId: cliente.id,
                                                          clienteNombre: cliente.nombre,
                                                          ventaId: targetVenta.id,
                                                          deudaVenta: targetVenta.deudaUsd,
                                                          totalCreditoDisponible: saldoAFavor,
                                                          origenVentaId: clientCredits.firstOrNull?.origenVentaId,
                                                          userEmail: cubit.dataService.currentUsuarioEmail ?? 'Antigravity Senior Agent',
                                                        );
                                                      }
                                                    },
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // Botones de acción con Wrap para evitar overflow en pantallas estrechas
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.blue700,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.cart, size: 16),
                                                  label: const Text('Ver compras'),
                                                  onPressed: () => context.go(
                                                    '${RoutePaths.ventas}?cliente=${cliente.id}',
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.blue700,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.pencil, size: 16),
                                                  label: const Text('Editar'),
                                                  onPressed: () => _showClienteDialog(
                                                    context,
                                                    cliente: cliente,
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    foregroundColor: AppPalette.error,
                                                    side: const BorderSide(color: AppPalette.border),
                                                  ),
                                                  icon: const Icon(CupertinoIcons.trash, size: 16),
                                                  label: const Text('Eliminar'),
                                                  onPressed: () => _confirmDelete(
                                                    context,
                                                    cliente,
                                                  ),
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
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClienteDialog(BuildContext context, {Cliente? cliente}) {
    final cubit = context.read<ClientesCubit>();
    final isEditing = cliente != null;
    final id = isEditing ? cliente.id : cubit.dataService.nextClienteId;

    Logger.info(
      'ClientesPage: Abriendo diálogo para ${isEditing ? "editar cliente ${cliente.id}" : "crear nuevo cliente ($id)"}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ClienteModalSheet(
        cliente: cliente,
        nextId: id,
        cubit: cubit,
      ),
    );
  }

  void _confirmDelete(BuildContext context, Cliente cliente) {
    final cubit = context.read<ClientesCubit>();
    Logger.info(
      'ClientesPage: Diálogo de confirmación para eliminar cliente: ${cliente.id} (${cliente.nombre})',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar cliente?'),
        content: Text(
          'Se desincorporará a ${cliente.nombre} (${cliente.id}) de la base de datos.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              Logger.warning(
                'ClientesPage: Ejecutando eliminación de cliente: ${cliente.id}',
              );
              cubit.deleteCliente(cliente.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

class _ClienteModalSheet extends StatefulWidget {
  final Cliente? cliente;
  final String nextId;
  final ClientesCubit cubit;

  const _ClienteModalSheet({
    this.cliente,
    required this.nextId,
    required this.cubit,
  });

  @override
  State<_ClienteModalSheet> createState() => _ClienteModalSheetState();
}

class _ClienteModalSheetState extends State<_ClienteModalSheet> {
  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _emailController;
  late final TextEditingController _deudaController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cliente?.nombre ?? '');
    _telefonoController =
        TextEditingController(text: widget.cliente?.telefono ?? '');
    _emailController = TextEditingController(text: widget.cliente?.email ?? '');
    _deudaController = TextEditingController(
      text: widget.cliente?.saldoDeudaUsd.toStringAsFixed(2) ?? '0.00',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _deudaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.cliente != null;
    final id = isEditing ? widget.cliente!.id : widget.nextId;

    return PopScope(
      canPop: !_isProcessing,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing
                      ? 'Editar Cliente ($id)'
                      : 'Registrar Nuevo Cliente',
                  style: AppTypography.titleLarge.copyWith(fontSize: 17),
                ),
                IconButton(
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: AppPalette.textSecondary,
                  ),
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nombre Completo',
              controller: _nombreController,
              hint: 'Ej: Juan Pérez',
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Teléfono (E.164)',
              controller: _telefonoController,
              hint: '+584120000001',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Correo Electrónico',
              controller: _emailController,
              hint: 'cliente@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Saldo Deuda Inicial (USD)',
              controller: _deudaController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    label: 'Cancelar',
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: _isProcessing
                        ? 'Guardando...'
                        : (isEditing ? 'Guardar Cambios' : 'Registrar'),
                    icon: _isProcessing
                        ? null
                        : (isEditing
                            ? CupertinoIcons.check_mark
                            : CupertinoIcons.add),
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final nombre = _nombreController.text.trim();
                            if (nombre.isEmpty) {
                              Logger.warning(
                                'ClientesPage: Intento de guardar cliente con nombre vacío',
                              );
                              return;
                            }

                            final nuevoCliente = Cliente(
                              id: id,
                              nombre: nombre,
                              telefono: _telefonoController.text.trim(),
                              email: _emailController.text.trim(),
                              saldoDeudaUsd: double.tryParse(
                                    _deudaController.text.replaceAll(',', '.'),
                                  ) ??
                                  0.0,
                              fechaRegistro:
                                  widget.cliente?.fechaRegistro ?? DateTime.now(),
                            );

                            Logger.info(
                              'ClientesPage: Guardando cliente: ${nuevoCliente.id} (${nuevoCliente.nombre})',
                            );
                            Logger.object('Cliente Datos', nuevoCliente.toMap());

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);

                            setState(() => _isProcessing = true);
                            try {
                              if (isEditing) {
                                widget.cubit.updateCliente(nuevoCliente);
                              } else {
                                await widget.cubit.addCliente(nuevoCliente);
                              }
                              if (!mounted) return;
                              navigator.pop();
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isProcessing = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error al guardar cliente: $e'),
                                  backgroundColor: AppPalette.error,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
