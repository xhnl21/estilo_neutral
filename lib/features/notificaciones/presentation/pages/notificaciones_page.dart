import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../models/plantilla_notificacion.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../cubit/plantilla_form_cubit.dart';
import '../cubit/plantillas_notificacion_cubit.dart';
import '../cubit/plantillas_notificacion_state.dart';

/// Vista "Notificaciones": las notificaciones guardadas de la organización
/// (hoja plantillas_notificacion) para reutilizarlas, filtradas por tipo.
/// "Ver" abre la notificación con sus destinatarios y el envío.
class NotificacionesPage extends StatelessWidget {
  final SheetsDataService dataService;

  const NotificacionesPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlantillasNotificacionCubit(dataService: dataService),
      child: const _NotificacionesView(),
    );
  }
}

class _NotificacionesView extends StatelessWidget {
  const _NotificacionesView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlantillasNotificacionCubit, PlantillasNotificacionState>(
      listenWhen: (prev, curr) =>
          (curr.actionSuccessMessage != null && prev.actionSuccessMessage != curr.actionSuccessMessage) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        final ok = state.actionSuccessMessage != null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.actionSuccessMessage ?? state.errorMessage!),
          backgroundColor: ok ? AppPalette.success : AppPalette.error,
          duration: Duration(seconds: ok ? 2 : 4),
        ));
      },
      builder: (context, state) {
        final cubit = context.read<PlantillasNotificacionCubit>();
        final cargando = state.status == PlantillasNotificacionStatus.loading;
        return AppScaffold(
          title: 'Notificaciones',
          subtitle: 'Notificaciones guardadas para reutilizar',
          actions: [AppRefreshButton(onRefresh: cubit.refresh, isRefreshing: cargando)],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'nueva_notificacion',
            onPressed: () => abrirFormularioPlantilla(context),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Nueva notificación'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.plantillas.isNotEmpty) _FiltrosPorTipo(state: state),
              Expanded(child: _lista(context, state, cargando)),
            ],
          ),
        );
      },
    );
  }

  Widget _lista(BuildContext context, PlantillasNotificacionState state, bool cargando) {
    if (state.plantillas.isEmpty && cargando) return const AppLoadingState();
    if (state.plantillas.isEmpty) {
      return AppEmptyState(
        title: 'Todavía no hay notificaciones',
        subtitle: 'Creá una (por ejemplo "Día de pago") para enviarla cuando la necesites.',
        icon: CupertinoIcons.bell,
        actionLabel: 'Nueva notificación',
        onAction: () => abrirFormularioPlantilla(context),
      );
    }
    final filtradas = state.filtradas;
    if (filtradas.isEmpty) {
      return AppEmptyState(
        title: 'No hay notificaciones de este tipo',
        icon: CupertinoIcons.line_horizontal_3_decrease,
        actionLabel: 'Ver todas',
        onAction: () => context.read<PlantillasNotificacionCubit>().filtrarPorTipo(null),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
      itemCount: filtradas.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _TarjetaPlantilla(plantilla: filtradas[i], nombreTipo: state.nombreTipo(filtradas[i].tipoId)),
    );
  }
}

/// Chips "Todas" + un chip por tipo con notificaciones guardadas.
class _FiltrosPorTipo extends StatelessWidget {
  final PlantillasNotificacionState state;

  const _FiltrosPorTipo({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlantillasNotificacionCubit>();
    final conteo = state.cantidadPorTipo;
    final tipos = state.tipos.where((t) => conteo.containsKey(t.id)).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('Todas (${state.plantillas.length})'),
            selected: state.filtroTipoId == null,
            onSelected: (_) => cubit.filtrarPorTipo(null),
          ),
          for (final t in tipos) ...[
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              label: Text('${t.nombre} (${conteo[t.id]})'),
              selected: state.filtroTipoId == t.id,
              onSelected: (_) => cubit.filtrarPorTipo(state.filtroTipoId == t.id ? null : t.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaPlantilla extends StatelessWidget {
  final PlantillaNotificacion plantilla;
  final String nombreTipo;

  const _TarjetaPlantilla({required this.plantilla, required this.nombreTipo});

  @override
  Widget build(BuildContext context) {
    final estiloBoton = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppPalette.border),
    );
    return AppCard(
      semanticLabel: '$nombreTipo: ${plantilla.titulo}. ${plantilla.cuerpo}',
      mergeSemantics: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppChip(label: nombreTipo, icon: CupertinoIcons.tag),
          const SizedBox(height: AppSpacing.sm),
          Text(plantilla.titulo, style: AppTypography.titleLarge.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(
            plantilla.cuerpo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: estiloBoton.copyWith(foregroundColor: const WidgetStatePropertyAll(AppPalette.blue700)),
                icon: const Icon(CupertinoIcons.eye, size: 16),
                label: const Text('Ver'),
                onPressed: () => context.push(RoutePaths.buildPlantillaNotificacionPath(plantilla.id)),
              ),
              OutlinedButton.icon(
                style: estiloBoton.copyWith(foregroundColor: const WidgetStatePropertyAll(AppPalette.blue700)),
                icon: const Icon(CupertinoIcons.pencil, size: 16),
                label: const Text('Editar'),
                onPressed: () => abrirFormularioPlantilla(context, plantilla: plantilla),
              ),
              OutlinedButton.icon(
                style: estiloBoton.copyWith(foregroundColor: const WidgetStatePropertyAll(AppPalette.error)),
                icon: const Icon(CupertinoIcons.trash, size: 16),
                label: const Text('Eliminar'),
                onPressed: () => _confirmarEliminar(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    final cubit = context.read<PlantillasNotificacionCubit>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar notificación?'),
        content: Text('Se elimina "${plantilla.titulo}" del listado. Las que ya se enviaron siguen registradas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            onPressed: () {
              Navigator.pop(ctx);
              cubit.eliminar(plantilla);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Abre el formulario para crear (sin [plantilla]) o editar una notificación.
void abrirFormularioPlantilla(BuildContext context, {PlantillaNotificacion? plantilla}) {
  final dataService = context.read<PlantillasNotificacionCubit>().dataService;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => BlocProvider(
      create: (_) => PlantillaFormCubit(dataService: dataService, plantilla: plantilla),
      child: const _FormularioPlantilla(),
    ),
  );
}

/// Formulario: tipo, título y mensaje. Solo los `TextEditingController`
/// viven en el widget; tipo, validación y guardado, en [PlantillaFormCubit].
class _FormularioPlantilla extends StatefulWidget {
  const _FormularioPlantilla();

  @override
  State<_FormularioPlantilla> createState() => _FormularioPlantillaState();
}

class _FormularioPlantillaState extends State<_FormularioPlantilla> {
  late final TextEditingController _titulo;
  late final TextEditingController _cuerpo;

  @override
  void initState() {
    super.initState();
    final p = context.read<PlantillaFormCubit>().plantilla;
    _titulo = TextEditingController(text: p?.titulo ?? '');
    _cuerpo = TextEditingController(text: p?.cuerpo ?? '');
  }

  @override
  void dispose() {
    _titulo.dispose();
    _cuerpo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlantillaFormCubit>();
    return BlocConsumer<PlantillaFormCubit, PlantillaFormState>(
      listenWhen: (prev, curr) =>
          (curr.guardada && !prev.guardada) || (curr.errorMessage != null && curr.errorMessage != prev.errorMessage),
      listener: (context, state) {
        if (state.guardada) {
          final mensajero = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          mensajero.showSnackBar(SnackBar(
            content: Text(cubit.esEdicion ? 'Notificación actualizada.' : 'Notificación guardada.'),
            backgroundColor: AppPalette.success,
            duration: const Duration(seconds: 2),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppPalette.error,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        final ocupado = state.guardando;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(cubit.esEdicion ? 'Editar notificación' : 'Nueva notificación',
                    style: AppTypography.titleLarge.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // La clave lo reconstruye cuando cambia el tipo elegido
                        // (p. ej. al crear uno nuevo desde el botón +).
                        key: ValueKey('tipo-${state.tipoId}-${state.tipos.length}'),
                        initialValue: state.tipos.any((t) => t.id == state.tipoId) ? state.tipoId : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Tipo',
                          errorText: state.errores[CampoPlantilla.tipo],
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final t in state.tipos)
                            DropdownMenuItem(value: t.id, child: Text(t.nombre, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: ocupado ? null : (id) => id == null ? null : cubit.elegirTipo(id),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton.outlined(
                        tooltip: 'Nuevo tipo',
                        onPressed: ocupado || state.creandoTipo ? null : () => _nuevoTipo(context),
                        icon: state.creandoTipo
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(CupertinoIcons.add),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Título',
                  controller: _titulo,
                  hint: 'Ej: Día de pago',
                  readOnly: ocupado,
                  errorText: state.errores[CampoPlantilla.titulo],
                  onChanged: (_) => cubit.campoEditado(CampoPlantilla.titulo),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Mensaje',
                  controller: _cuerpo,
                  hint: 'Ej: Hoy se realizó el pago de su quincena.',
                  maxLines: 4,
                  readOnly: ocupado,
                  errorText: state.errores[CampoPlantilla.cuerpo],
                  onChanged: (_) => cubit.campoEditado(CampoPlantilla.cuerpo),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Guardar',
                  icon: CupertinoIcons.checkmark_alt,
                  isLoading: ocupado,
                  isFullWidth: true,
                  onPressed: ocupado ? null : () => cubit.guardar(titulo: _titulo.text, cuerpo: _cuerpo.text),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _nuevoTipo(BuildContext context) async {
    final cubit = context.read<PlantillaFormCubit>();
    final nombre = await showDialog<String>(context: context, builder: (_) => const _DialogoNuevoTipo());
    if (nombre != null && nombre.trim().isNotEmpty) await cubit.crearTipo(nombre);
  }
}

/// Pide el nombre de un tipo nuevo. El controlador vive en el diálogo
/// (estado visual); el alta la hace [PlantillaFormCubit.crearTipo].
class _DialogoNuevoTipo extends StatefulWidget {
  const _DialogoNuevoTipo();

  @override
  State<_DialogoNuevoTipo> createState() => _DialogoNuevoTipoState();
}

class _DialogoNuevoTipoState extends State<_DialogoNuevoTipo> {
  final _nombre = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo tipo de notificación'),
      content: TextField(
        controller: _nombre,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Aniversario'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _nombre.text), child: const Text('Agregar')),
      ],
    );
  }
}
