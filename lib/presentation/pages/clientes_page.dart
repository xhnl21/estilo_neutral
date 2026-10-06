import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../cubits/cliente_form/cliente_form_cubit.dart';
import '../cubits/cliente_form/cliente_form_state.dart';

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
          (curr.actionSuccessMessage != null &&
              prev.actionSuccessMessage != curr.actionSuccessMessage) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        final error = state.errorMessage;
        if (error != null) {
          _showMessage(context, error, ClienteFormResultType.error);
        } else if (state.actionSuccessMessage != null) {
          _showMessage(context, state.actionSuccessMessage!, ClienteFormResultType.success);
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
                  hint: 'Nombre, cédula/RIF, teléfono o ID...',
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
                                  expandedHeaderPadding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  expansionCallback: (panelIndex, isExpanded) {
                                    final cliente = clientes[panelIndex];
                                    cubit.toggleExpanded(cliente.id);
                                  },
                                  children:
                                      clientes.map<ExpansionPanel>((cliente) {
                                    final resumen = state.resumenDe(cliente.id);
                                    final deudaReal = resumen.deudaUsd;
                                    final hasDebt = resumen.hasDebt;
                                    final saldoAFavor = resumen.saldoAFavorUsd;
                                    final isExpanded =
                                        state.expandedClienteId == cliente.id;

                                    return ExpansionPanel(
                                      isExpanded: isExpanded,
                                      canTapOnHeader: true,
                                      backgroundColor: AppPalette.surface,
                                      headerBuilder:
                                          (context, isHeaderExpanded) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                              vertical: AppSpacing.sm),
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
                                              const SizedBox(
                                                  width: AppSpacing.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      cliente.nombre,
                                                      style: AppTypography
                                                          .titleLarge
                                                          .copyWith(
                                                              fontSize: 15),
                                                      maxLines: isHeaderExpanded
                                                          ? null
                                                          : 1,
                                                      overflow: isHeaderExpanded
                                                          ? null
                                                          : TextOverflow
                                                              .ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 8,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          'ID: ${cliente.id}',
                                                          style: AppTypography
                                                              .labelSmall
                                                              .copyWith(
                                                            color: AppPalette
                                                                .textSecondary,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        if (cliente
                                                            .documentoCompleto
                                                            .isNotEmpty)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        1),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppPalette
                                                                  .surface,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              border: Border.all(
                                                                  color: AppPalette
                                                                      .divider),
                                                            ),
                                                            child: Text(
                                                              cliente
                                                                  .documentoCompleto,
                                                              style:
                                                                  AppTypography
                                                                      .labelSmall
                                                                      .copyWith(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppPalette
                                                                    .textPrimary,
                                                              ),
                                                            ),
                                                          ),
                                                        if (hasDebt)
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                'Deuda: ',
                                                                style: AppTypography
                                                                    .labelSmall
                                                                    .copyWith(
                                                                  color:
                                                                      AppPalette
                                                                          .error,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                              AppMoneyText(
                                                                amount:
                                                                    deudaReal,
                                                                currency:
                                                                    MoneyCurrency
                                                                        .usd,
                                                                nature:
                                                                    MoneyNature
                                                                        .debt,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
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
                                        padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.md,
                                            0,
                                            AppSpacing.md,
                                            AppSpacing.md),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Divider(
                                                color: AppPalette.divider),
                                            const SizedBox(height: 4),
                                            // Detalle completo sin recortar textos
                                            SelectableText.rich(
                                              TextSpan(
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                        fontSize: 13,
                                                        height: 1.5),
                                                children: [
                                                  const TextSpan(
                                                      text: '🆔 Cédula / Doc: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: cliente
                                                              .documentoCompleto
                                                              .isNotEmpty
                                                          ? cliente
                                                              .documentoCompleto
                                                          : 'No registrada'),
                                                  const TextSpan(
                                                      text: '\n📞 Teléfono: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: cliente.telefono
                                                              .isNotEmpty
                                                          ? (TelefonoVe.parse(
                                                                      cliente
                                                                          .telefono)
                                                                  ?.legible ??
                                                              cliente.telefono)
                                                          : 'No registrado'),
                                                  const TextSpan(
                                                      text: '\n✉️ Email: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: cliente
                                                              .email.isNotEmpty
                                                          ? cliente.email
                                                          : 'No registrado'),
                                                  const TextSpan(
                                                      text:
                                                          '\n📅 Fecha Registro: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: cliente
                                                          .fechaRegistro
                                                          .toIso8601String()
                                                          .split('T')
                                                          .first),
                                                  const TextSpan(
                                                      text:
                                                          '\n🏢 Organización: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  TextSpan(
                                                      text: cliente
                                                          .organizacionId),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Deuda Total: ',
                                                      style: AppTypography
                                                          .labelSmall
                                                          .copyWith(
                                                        color: hasDebt
                                                            ? AppPalette.error
                                                            : AppPalette
                                                                .textSecondary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    AppMoneyText(
                                                      amount: deudaReal,
                                                      currency:
                                                          MoneyCurrency.usd,
                                                      nature: hasDebt
                                                          ? MoneyNature.debt
                                                          : MoneyNature.neutral,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ],
                                                ),
                                                if (saldoAFavor > 0)
                                                  CreditChip(
                                                    amount: saldoAFavor,
                                                    isCredit: true,
                                                    onTap: () {
                                                      final usuarioEmail =
                                                          state.usuarioEmail;
                                                      if (usuarioEmail ==
                                                          null) {
                                                        _showMessage(
                                                          context,
                                                          'No hay un usuario identificado: no se puede aplicar el crédito.',
                                                          ClienteFormResultType
                                                              .error,
                                                        );
                                                        return;
                                                      }
                                                      final pendingVentas =
                                                          resumen
                                                              .ventasPendientes;
                                                      if (pendingVentas
                                                          .isNotEmpty) {
                                                        final targetVenta =
                                                            pendingVentas.first;
                                                        final applyCubit =
                                                            ApplyCreditCubit(
                                                          repository:
                                                              ServiceLocator()
                                                                  .creditRepository,
                                                          dataService:
                                                              cubit.dataService,
                                                        );
                                                        ApplyCreditSheet.show(
                                                          context,
                                                          cubit: applyCubit,
                                                          clienteId: cliente.id,
                                                          clienteNombre:
                                                              cliente.nombre,
                                                          ventaId:
                                                              targetVenta.id,
                                                          deudaVenta:
                                                              targetVenta
                                                                  .deudaUsd,
                                                          totalCreditoDisponible:
                                                              saldoAFavor,
                                                          origenVentaId: resumen
                                                              .origenVentaIdCredito,
                                                          userEmail:
                                                              usuarioEmail,
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
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    foregroundColor:
                                                        AppPalette.blue700,
                                                    side: const BorderSide(
                                                        color:
                                                            AppPalette.border),
                                                  ),
                                                  icon: const Icon(
                                                      CupertinoIcons.cart,
                                                      size: 16),
                                                  label: const Text('Ver'),
                                                  onPressed: () => context.go(
                                                    '${RoutePaths.ventas}?cliente=${cliente.id}',
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    foregroundColor:
                                                        AppPalette.blue700,
                                                    side: const BorderSide(
                                                        color:
                                                            AppPalette.border),
                                                  ),
                                                  icon: const Icon(
                                                      CupertinoIcons.pencil,
                                                      size: 16),
                                                  label: const Text('Editar'),
                                                  onPressed: () =>
                                                      _showClienteDialog(
                                                    context,
                                                    cliente: cliente,
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    foregroundColor:
                                                        AppPalette.error,
                                                    side: const BorderSide(
                                                        color:
                                                            AppPalette.border),
                                                  ),
                                                  icon: const Icon(
                                                      CupertinoIcons.trash,
                                                      size: 16),
                                                  label: const Text('Eliminar'),
                                                  onPressed: () =>
                                                      _confirmDelete(
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
    final dataService = context.read<ClientesCubit>().dataService;

    Logger.info(
      'ClientesPage: Abriendo diálogo para ${cliente != null ? "editar cliente ${cliente.id}" : "crear nuevo cliente"}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BlocProvider(
        create: (_) =>
            ClienteFormCubit(dataService: dataService, cliente: cliente),
        child: const _ClienteModalSheet(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Cliente cliente) {
    final cubit = context.read<ClientesCubit>();
    final motivo = cubit.motivoNoEliminable(cliente.id);
    if (motivo != null) {
      Logger.info(
        'ClientesPage: Eliminación de ${cliente.id} bloqueada: $motivo',
      );
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            '${cliente.nombre} (${cliente.id}) no se puede desincorporar. $motivo',
          ),
          actions: [
            FilledButton(
              child: const Text('Entendido'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      return;
    }
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

void _showMessage(
  BuildContext context,
  String message,
  ClienteFormResultType type,
) {
  final color = switch (type) {
    ClienteFormResultType.success => AppPalette.success,
    ClienteFormResultType.warning => AppPalette.warning,
    ClienteFormResultType.error => AppPalette.error,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: color,
      content: Text(message),
      duration: Duration(
        seconds: type == ClienteFormResultType.success ? 2 : 4,
      ),
    ),
  );
}

/// Formulario de alta/edición. Solo los `TextEditingController` viven en el
/// widget (estado visual efímero); catálogos, dropdowns, validación y estado
/// de guardado viven en [ClienteFormCubit].
class _ClienteModalSheet extends StatefulWidget {
  const _ClienteModalSheet();

  @override
  State<_ClienteModalSheet> createState() => _ClienteModalSheetState();
}

class _ClienteModalSheetState extends State<_ClienteModalSheet> {
  late final TextEditingController _nombreController;
  late final TextEditingController _cedulaController;
  late final TextEditingController _telefonoNumeroController;
  late final TextEditingController _emailController;
  late final TextEditingController _deudaController;

  @override
  void initState() {
    super.initState();
    final initial = context.read<ClienteFormCubit>().state;
    _nombreController = TextEditingController(text: initial.nombreInicial);
    _cedulaController = TextEditingController(text: initial.cedulaInicial);
    _telefonoNumeroController =
        TextEditingController(text: initial.telefonoNumeroInicial);
    _emailController = TextEditingController(text: initial.emailInicial);
    _deudaController = TextEditingController(text: '0.00');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _telefonoNumeroController.dispose();
    _emailController.dispose();
    _deudaController.dispose();
    super.dispose();
  }

  void _submit(ClienteFormCubit cubit) {
    cubit.submit(
      nombre: _nombreController.text,
      cedula: _cedulaController.text,
      telefonoNumero: _telefonoNumeroController.text,
      email: _emailController.text,
      deuda: _deudaController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClienteFormCubit, ClienteFormState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          (curr.status == ClienteFormStatus.success ||
              curr.status == ClienteFormStatus.failure),
      listener: (context, state) {
        final message = state.resultMessage;
        if (message != null) {
          _showMessage(context, message, state.resultType);
        }
        if (state.status == ClienteFormStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ClienteFormCubit>();
        final isProcessing = state.isSubmitting;
        final tiposDoc = state.tiposDocumento;
        final codigos = state.codigosTelefono;

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
                          state.isEditing
                              ? 'Editar Cliente (${state.id})'
                              : 'Registrar Nuevo Cliente',
                          style:
                              AppTypography.titleLarge.copyWith(fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: AppPalette.textSecondary,
                        ),
                        onPressed:
                            isProcessing ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Nombre Completo',
                    controller: _nombreController,
                    hint: 'Ej: Juan Pérez',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    errorText: state.errors[ClienteFormField.nombre],
                    onChanged: (_) =>
                        cubit.fieldChanged(ClienteFormField.nombre),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text('Tipo Doc.', style: AppTypography.labelSmall),
                            // const SizedBox(height: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppPalette.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppPalette.divider),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: tiposDoc.contains(state.tipoDocumento)
                                      ? state.tipoDocumento
                                      : tiposDoc.first,
                                  isExpanded: true,
                                  items: tiposDoc
                                      .map((t) => DropdownMenuItem(
                                          value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: isProcessing
                                      ? null
                                      : (v) {
                                          if (v != null) {
                                            cubit.tipoDocumentoChanged(v);
                                          }
                                        },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          label: 'Cédula / Documento',
                          controller: _cedulaController,
                          hint: DocumentoIdentidad.esRif(state.tipoDocumento)
                              ? '123456789'
                              : '12345678',
                          keyboardType:
                              DocumentoIdentidad.esNumerico(state.tipoDocumento)
                                  ? TextInputType.number
                                  : TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            if (DocumentoIdentidad.esNumerico(
                                state.tipoDocumento))
                              FilteringTextInputFormatter.digitsOnly
                            else
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]')),
                            LengthLimitingTextInputFormatter(15),
                          ],
                          errorText: state.errors[ClienteFormField.cedula],
                          onChanged: (_) =>
                              cubit.fieldChanged(ClienteFormField.cedula),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 105,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text('Código', style: AppTypography.labelSmall),
                            // const SizedBox(height: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppPalette.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppPalette.divider),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: codigos.contains(state.codigoTelefono)
                                      ? state.codigoTelefono
                                      : codigos.first,
                                  isExpanded: true,
                                  items: codigos
                                      .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: isProcessing
                                      ? null
                                      : (v) {
                                          if (v != null) {
                                            cubit.codigoTelefonoChanged(v);
                                          }
                                        },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          label: 'Número de Teléfono',
                          controller: _telefonoNumeroController,
                          hint: '1234567',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          errorText: state.errors[ClienteFormField.telefono],
                          onChanged: (_) =>
                              cubit.fieldChanged(ClienteFormField.telefono),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Correo Electrónico',
                    controller: _emailController,
                    hint: 'cliente@ejemplo.com',
                    keyboardType: TextInputType.emailAddress,
                    // En una edición es el último campo: "Listo" guarda.
                    textInputAction: state.isEditing
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onFieldSubmitted: state.isEditing && !isProcessing
                        ? (_) => _submit(cubit)
                        : null,
                    errorText: state.errors[ClienteFormField.email],
                    onChanged: (_) =>
                        cubit.fieldChanged(ClienteFormField.email),
                  ),
                  // El saldo inicial solo se captura en el alta: en una edición
                  // la deuda real se deriva de las ventas del cliente.
                  if (!state.isEditing) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Saldo Deuda Inicial (USD)',
                      controller: _deudaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onFieldSubmitted:
                          isProcessing ? null : (_) => _submit(cubit),
                      errorText: state.errors[ClienteFormField.deuda],
                      onChanged: (_) =>
                          cubit.fieldChanged(ClienteFormField.deuda),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppOutlinedButton(
                          label: 'Cancelar',
                          onPressed: isProcessing
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: isProcessing
                              ? 'Guardando...'
                              : (state.isEditing
                                  ? 'Guardar Cambios'
                                  : 'Registrar'),
                          icon: isProcessing
                              ? null
                              : (state.isEditing
                                  ? CupertinoIcons.check_mark
                                  : CupertinoIcons.add),
                          onPressed: isProcessing ? null : () => _submit(cubit),
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
