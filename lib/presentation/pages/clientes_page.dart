import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../core/router/route_paths.dart';
import '../../core/utils/logger.dart';
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
                          : ListView.builder(
                              key: const ValueKey('clientes_list'),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                80,
                              ),
                        itemCount: clientes.length,
                        itemBuilder: (context, index) {
                          final cliente = clientes[index];
                          final ventasDelCliente = cubit.dataService.ventas
                              .where((v) => v.clienteId == cliente.id);
                          // Deuda real, calculada desde las facturas del
                          // cliente (fuente de verdad) en vez de
                          // cliente.saldoDeudaUsd — ese campo se mantiene
                          // aparte, incrementado/decrementado a mano en cada
                          // venta/abono, y puede desincronizarse (fue
                          // exactamente lo que pasó acá: quedó en $600
                          // aunque la factura correspondiente ya estaba
                          // pagada).
                          final deudaReal = ventasDelCliente.fold<double>(
                              0.0, (sum, v) => sum + (v.deudaUsd > 0 ? v.deudaUsd : 0.0));
                          final hasDebt = deudaReal > 0;
                          // Cuánto pagó de más este cliente en alguna de
                          // sus facturas (ver Venta.excedenteUsd) — solo se
                          // muestra si de verdad existe, no es un estado
                          // normal de un cliente.
                          final excedente = ventasDelCliente.fold<double>(0.0, (sum, v) => sum + v.excedenteUsd);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ExcludeSemantics(
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: hasDebt
                                          ? const Color(0xFFFFEBEE)
                                          : AppPalette.blue100,
                                      child: Icon(
                                        CupertinoIcons.person_fill,
                                        color: hasDebt
                                            ? AppPalette.error
                                            : AppPalette.blue700,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: MergeSemantics(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              text: cliente.nombre,
                                              style: AppTypography.titleLarge
                                                  .copyWith(fontSize: 15),
                                              children: [
                                                TextSpan(
                                                  text: ' (${cliente.id})',
                                                  style: AppTypography.labelSmall
                                                      .copyWith(
                                                    color:
                                                        AppPalette.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '📞 ${cliente.telefono} • ✉️ ${cliente.email}',
                                            style: AppTypography.bodyMedium
                                                .copyWith(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 4,
                                            runSpacing: 2,
                                            children: [
                                              Text(
                                                'Deuda: ',
                                                style: AppTypography.labelSmall
                                                    .copyWith(
                                                  color: hasDebt
                                                      ? AppPalette.error
                                                      : AppPalette.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              AppMoneyText(
                                                amount: deudaReal,
                                                currency: MoneyCurrency.usd,
                                                nature: hasDebt
                                                    ? MoneyNature.debt
                                                    : MoneyNature.neutral,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              Text(
                                                '• Reg: ${cliente.fechaRegistro.toIso8601String().split('T').first}',
                                                style: AppTypography.labelSmall
                                                    .copyWith(
                                                  fontSize: 11,
                                                  color: AppPalette.textSecondary,
                                                ),
                                              ),
                                              if (excedente > 0) ...[
                                                Text(
                                                  '• Excedente: ',
                                                  style: AppTypography.labelSmall.copyWith(
                                                    color: AppPalette.success,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                AppMoneyText(
                                                  amount: excedente,
                                                  currency: MoneyCurrency.usd,
                                                  nature: MoneyNature.credit,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Acciones CRUD
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                                        button: true,
                                        label: 'Ver compras de ${cliente.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          icon: const Icon(
                                            CupertinoIcons.cart,
                                            size: 18,
                                            color: AppPalette.blue700,
                                          ),
                                          tooltip: 'Ver Compras',
                                          onPressed: () => context.go(
                                            '${RoutePaths.ventas}?cliente=${cliente.id}',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Semantics(
                                        button: true,
                                        label: 'Editar cliente ${cliente.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          icon: const Icon(
                                            CupertinoIcons.pencil,
                                            size: 18,
                                            color: AppPalette.blue700,
                                          ),
                                          tooltip: 'Editar Cliente',
                                          onPressed: () => _showClienteDialog(
                                            context,
                                            cliente: cliente,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Semantics(
                                        button: true,
                                        label: 'Eliminar cliente ${cliente.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          icon: const Icon(
                                            CupertinoIcons.trash,
                                            size: 18,
                                            color: AppPalette.error,
                                          ),
                                          tooltip: 'Eliminar Cliente',
                                          onPressed: () => _confirmDelete(
                                            context,
                                            cliente,
                                          ),
                                        ),
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
    final nombreController = TextEditingController(text: cliente?.nombre ?? '');
    final telefonoController =
        TextEditingController(text: cliente?.telefono ?? '+58');
    final emailController = TextEditingController(text: cliente?.email ?? '');
    final deudaController = TextEditingController(
      text: cliente?.saldoDeudaUsd.toStringAsFixed(2) ?? '0.00',
    );

    Logger.info(
      'ClientesPage: Abriendo diálogo para ${isEditing ? "editar cliente ${cliente.id}" : "crear nuevo cliente ($id)"}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
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
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Nombre Completo',
                controller: nombreController,
                hint: 'Ej: Juan Pérez',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Teléfono (E.164)',
                controller: telefonoController,
                hint: '+584120000001',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Correo Electrónico',
                controller: emailController,
                hint: 'cliente@ejemplo.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Saldo Deuda Inicial (USD)',
                controller: deudaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(
                      label: 'Cancelar',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: isEditing ? 'Guardar Cambios' : 'Registrar',
                      icon: isEditing
                          ? CupertinoIcons.check_mark
                          : CupertinoIcons.add,
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        if (nombre.isEmpty) {
                          Logger.warning(
                            'ClientesPage: Intento de guardar cliente con nombre vacío',
                          );
                          return;
                        }

                        final nuevoCliente = Cliente(
                          id: id,
                          nombre: nombre,
                          telefono: telefonoController.text.trim(),
                          email: emailController.text.trim(),
                          saldoDeudaUsd: double.tryParse(
                                deudaController.text.replaceAll(',', '.'),
                              ) ??
                              0.0,
                          fechaRegistro:
                              cliente?.fechaRegistro ?? DateTime.now(),
                        );

                        Logger.info(
                          'ClientesPage: Guardando cliente: ${nuevoCliente.id} (${nuevoCliente.nombre})',
                        );
                        Logger.object('Cliente Datos', nuevoCliente.toMap());

                        Navigator.pop(ctx);

                        if (isEditing) {
                          cubit.updateCliente(nuevoCliente);
                        } else {
                          await cubit.addCliente(nuevoCliente);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
