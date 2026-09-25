import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/organizaciones/organizaciones_cubit.dart';
import '../cubits/organizaciones/organizaciones_state.dart';

/// Vista de Organizaciones (hoja: organizaciones)
/// BLoC/Cubit: OrganizacionesCubit / OrganizacionesState
class OrganizacionesPage extends StatelessWidget {
  final SheetsDataService dataService;

  const OrganizacionesPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrganizacionesCubit(dataService: dataService),
      child: const _OrganizacionesView(),
    );
  }
}

class _OrganizacionesView extends StatelessWidget {
  const _OrganizacionesView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrganizacionesCubit, OrganizacionesState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppPalette.error,
            ),
          );
        } else if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: AppPalette.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<OrganizacionesCubit>();
        final organizaciones = state.organizaciones;
        final esquemaListo = state.schemaMultiOrgListo;

        return AppScaffold(
          title: 'Organizaciones',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'organizaciones',
            userFriendlyText: '${organizaciones.length} organizaciones',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.isRefreshing,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_organizaciones',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.building_2_fill, size: 20),
            label: const Text('Nueva Organización', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => esquemaListo
                ? _showOrganizacionDialog(context)
                : _showEsquemaPendienteDialog(context),
          ),
          body: Column(
            children: [
              if (!esquemaListo)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: AppCard(
                    padding: AppSpacing.pSm,
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: AppPalette.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'El Google Sheet todavía no tiene la hoja "organizaciones" con su esquema nuevo. '
                            'Crear/editar organizaciones está deshabilitado hasta migrarlo.',
                            style: AppTypography.labelSmall.copyWith(color: AppPalette.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: organizaciones.isEmpty
                    ? const AppEmptyState(
                        title: 'No hay organizaciones registradas',
                        description: 'Usa el botón "Nueva Organización" para crear la primera.',
                        icon: CupertinoIcons.building_2_fill,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                        itemCount: organizaciones.length,
                        itemBuilder: (context, index) {
                          final organizacion = organizaciones[index];
                          final cantidadUsuarios = cubit.usuariosEnOrganizacion(organizacion.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ExcludeSemantics(
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppPalette.blue100,
                                      child: Icon(CupertinoIcons.building_2_fill, color: AppPalette.blue700, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: MergeSemantics(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            organizacion.nombre,
                                            style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            organizacion.id,
                                            style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          AppChip(
                                            label: '$cantidadUsuarios usuario${cantidadUsuarios == 1 ? '' : 's'}',
                                            variant: AppChipVariant.info,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                                        button: true,
                                        label: 'Ver y asignar usuarios de ${organizacion.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(CupertinoIcons.person_2, size: 18, color: AppPalette.blue700),
                                          tooltip: 'Ver / Asignar Usuarios',
                                          onPressed: () => esquemaListo
                                              ? _showMiembrosDialog(context, organizacion)
                                              : _showEsquemaPendienteDialog(context),
                                        ),
                                      ),
                                      Semantics(
                                        button: true,
                                        label: 'Editar organización ${organizacion.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                          tooltip: 'Editar Organización',
                                          onPressed: () => esquemaListo
                                              ? _showOrganizacionDialog(context, organizacion: organizacion)
                                              : _showEsquemaPendienteDialog(context),
                                        ),
                                      ),
                                      Semantics(
                                        button: true,
                                        label: 'Eliminar organización ${organizacion.nombre}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                          tooltip: 'Eliminar Organización',
                                          onPressed: () => esquemaListo
                                              ? _confirmDelete(context, organizacion, cantidadUsuarios)
                                              : _showEsquemaPendienteDialog(context),
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
            ],
          ),
        );
      },
    );
  }

  void _showMiembrosDialog(BuildContext context, Organizacion organizacion) {
    final cubit = context.read<OrganizacionesCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final miembros = cubit.state.usuarios
              .where((u) => cubit.organizacionIdForUsuario(u.email) == organizacion.id)
              .toList();
          final disponibles = cubit.state.usuarios
              .where((u) => cubit.organizacionIdForUsuario(u.email) != organizacion.id)
              .toList();
          Usuario? seleccionado = disponibles.isNotEmpty ? disponibles.first : null;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
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
                            'Usuarios de ${organizacion.nombre}',
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
                    if (miembros.isEmpty)
                      Text(
                        'Todavía no tiene usuarios asignados.',
                        style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
                      )
                    else
                      ...miembros.map((usuario) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: AppCard(
                              padding: AppSpacing.pSm,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      usuario.nombre.isNotEmpty ? '${usuario.nombre} (${usuario.email})' : usuario.email,
                                      style: AppTypography.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(CupertinoIcons.arrow_right_arrow_left, size: 18, color: AppPalette.blue700),
                                    tooltip: 'Mover a otra organización',
                                    onPressed: () => _showMoverUsuarioDialog(context, cubit, usuario, organizacion, () {
                                      Navigator.pop(ctx);
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1, color: AppPalette.divider),
                    const SizedBox(height: AppSpacing.md),
                    Text('Agregar usuario existente', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    if (disponibles.isEmpty)
                      Text(
                        'No hay otros usuarios para agregar (todos ya pertenecen a esta organización).',
                        style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Usuario>(
                              initialValue: seleccionado,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: AppPalette.surface,
                                border: OutlineInputBorder(borderRadius: AppSpacing.roundedSm),
                                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                              ),
                              items: disponibles
                                  .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(
                                          u.nombre.isNotEmpty ? '${u.nombre} (${u.email})' : u.email,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (val) => setModalState(() => seleccionado = val),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton(
                            onPressed: () async {
                              final usuario = seleccionado;
                              if (usuario == null) return;
                              await cubit.updateUsuario(usuario, organizacionId: organizacion.id);
                              setModalState(() {});
                            },
                            child: const Text('Agregar'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMoverUsuarioDialog(
    BuildContext context,
    OrganizacionesCubit cubit,
    Usuario usuario,
    Organizacion organizacionActual,
    VoidCallback onMoved,
  ) {
    final otras = cubit.state.organizaciones.where((o) => o.id != organizacionActual.id).toList();
    if (otras.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No hay otra organización'),
          content: const Text('Creá otra organización primero para poder mover usuarios entre ellas.'),
          actions: [TextButton(child: const Text('Entendido'), onPressed: () => Navigator.pop(ctx))],
        ),
      );
      return;
    }

    Organizacion destino = otras.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Mover a ${usuario.nombre.isNotEmpty ? usuario.nombre : usuario.email}'),
          content: DropdownButtonFormField<Organizacion>(
            initialValue: destino,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nueva organización'),
            items: otras.map((o) => DropdownMenuItem(value: o, child: Text(o.nombre))).toList(),
            onChanged: (val) => setDialogState(() => destino = val ?? destino),
          ),
          actions: [
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await cubit.updateUsuario(usuario, organizacionId: destino.id);
                onMoved();
              },
              child: const Text('Mover'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrganizacionDialog(BuildContext context, {Organizacion? organizacion}) {
    final cubit = context.read<OrganizacionesCubit>();
    final isEditing = organizacion != null;
    final nombreController = TextEditingController(text: organizacion?.nombre ?? '');
    final tasaManualExistente = organizacion != null ? cubit.tasaManualOrganizacion(organizacion.id) : null;
    final tasaManualController = TextEditingController(
      text: tasaManualExistente != null ? tasaManualExistente.valor.toStringAsFixed(2) : '',
    );
    var monedaBase = organizacion != null ? cubit.monedaOrganizacion(organizacion.id) : 'USD';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                      isEditing ? 'Editar Organización' : 'Nueva Organización',
                      style: AppTypography.titleLarge.copyWith(fontSize: 17),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Nombre',
                  controller: nombreController,
                  hint: 'Ej: Estilo Neutral',
                ),
                if (isEditing) ...[
                  const SizedBox(height: AppSpacing.lg),
                  MonedaSelector(
                    label: 'MONEDA BASE DEL SISTEMA',
                    value: monedaBase,
                    onChanged: (val) => setModalState(() => monedaBase = val),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Tasa manual (opcional)',
                    controller: tasaManualController,
                    hint: 'Ej: 533.00 — vacío para no ofrecer tasa manual',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Si la completás, al registrar ventas y abonos vas a poder elegir '
                      'usar esta tasa fija en vez de la BCV automática del día.',
                      style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: AppOutlinedButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: isEditing ? 'Guardar Cambios' : 'Crear',
                        icon: isEditing ? CupertinoIcons.check_mark : CupertinoIcons.add,
                        onPressed: () async {
                          final nombre = nombreController.text.trim();
                          if (nombre.isEmpty) return;

                          Navigator.pop(ctx);

                          if (isEditing) {
                            await cubit.updateOrganizacion(
                              Organizacion(id: organizacion.id, nombre: nombre),
                            );
                            await cubit.setMonedaOrganizacion(organizacion.id, monedaBase);

                            final tasaManual = double.tryParse(tasaManualController.text.trim().replaceAll(',', '.'));
                            if (tasaManual != null && tasaManual > 0) {
                              await cubit.setTasaManualOrganizacion(organizacion.id, monedaBase, tasaManual);
                            } else if (tasaManualExistente != null) {
                              await cubit.quitarTasaManualOrganizacion(organizacion.id);
                            }
                          } else {
                            await cubit.addOrganizacion(nombre);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Organizacion organizacion, int cantidadUsuarios) {
    final cubit = context.read<OrganizacionesCubit>();
    if (cantidadUsuarios > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            '${organizacion.nombre} todavía tiene $cantidadUsuarios usuario${cantidadUsuarios == 1 ? '' : 's'} asignado${cantidadUsuarios == 1 ? '' : 's'}. '
            'Reasigná o eliminá esos usuarios primero desde el módulo Usuarios.',
          ),
          actions: [
            TextButton(child: const Text('Entendido'), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar organización?'),
        content: Text('Se eliminará "${organizacion.nombre}" (${organizacion.id}).'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () async {
              Navigator.pop(ctx);
              await cubit.deleteOrganizacion(organizacion.id);
            },
          ),
        ],
      ),
    );
  }

  void _showEsquemaPendienteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Falta migrar el Google Sheet'),
        content: const Text(
          'Este módulo necesita que la hoja "organizaciones" ya tenga su encabezado nuevo '
          '(columnas "id"/"nombre"). Hasta que se haga esa migración manual (ver '
          'docs/google/multi-organizacion.md), crear/editar/eliminar organizaciones queda '
          'deshabilitado para no escribir datos mal alineados.',
        ),
        actions: [
          TextButton(child: const Text('Entendido'), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }
}
