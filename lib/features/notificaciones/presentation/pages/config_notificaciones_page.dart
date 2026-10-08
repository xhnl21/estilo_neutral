import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../models/config_notificaciones.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../cubit/config_notificaciones_cubit.dart';
import '../cubit/config_notificaciones_state.dart';

/// Vista "Configuración de notificaciones" (hoja config_notificaciones):
/// cuántas notificaciones puede enviar cada usuario y cada organización por
/// hora, día, semana o mes. Cada organización tiene su propia configuración.
class ConfigNotificacionesPage extends StatelessWidget {
  final SheetsDataService dataService;

  const ConfigNotificacionesPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConfigNotificacionesCubit(dataService: dataService),
      child: const _ConfigNotificacionesView(),
    );
  }
}

/// "30 por usuario" / "sin límite por usuario".
String _textoLimite(int limite, String quien) => limite == 0 ? 'sin límite $quien' : '$limite $quien';

class _ConfigNotificacionesView extends StatelessWidget {
  const _ConfigNotificacionesView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConfigNotificacionesCubit, ConfigNotificacionesState>(
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
        final cubit = context.read<ConfigNotificacionesCubit>();
        return AppScaffold(
          title: 'Configuración de notificaciones',
          subtitle: 'Límites de envío por organización',
          actions: [AppRefreshButton(onRefresh: cubit.refresh, isRefreshing: state.status == ConfigNotificacionesStatus.loading)],
          body: state.filas.isEmpty && state.status == ConfigNotificacionesStatus.loading
              ? const AppLoadingState()
              : state.filas.isEmpty
                  ? const AppEmptyState(
                      title: 'No hay organizaciones',
                      subtitle: 'Creá una organización para configurar sus notificaciones.',
                      icon: CupertinoIcons.building_2_fill,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
                      children: [
                        Text(
                          'Cuentan las notificaciones enviadas desde la app y desde la hoja. El período es de '
                          'calendario (hora de Venezuela): el día empieza a las 00:00, la semana el lunes y el mes '
                          'el día 1. El límite de la organización suma los envíos de todos sus usuarios.',
                          style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final fila in state.filas) ...[
                          _TarjetaOrganizacion(fila: fila),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
        );
      },
    );
  }
}

class _TarjetaOrganizacion extends StatelessWidget {
  final FilaConfigNotificaciones fila;

  const _TarjetaOrganizacion({required this.fila});

  @override
  Widget build(BuildContext context) {
    final c = fila.config;
    final resumen = '${c.periodo.etiqueta}: ${_textoLimite(c.limitePorUsuario, 'por usuario')} · '
        '${_textoLimite(c.limiteOrganizacion, 'para la organización')}';
    return AppCard(
      semanticLabel: '${fila.organizacion.nombre}. $resumen',
      semanticHint: 'Toca para editar los límites',
      onTap: () => _abrirFormulario(context, fila),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppPalette.blue100,
              child: Icon(CupertinoIcons.bell_fill, color: AppPalette.blue700, size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fila.organizacion.nombre,
                    style: AppTypography.titleLarge.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(resumen, style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppChip(label: '${fila.usuarios} ${fila.usuarios == 1 ? 'usuario' : 'usuarios'}'),
                    if (c.esPorDefecto)
                      const AppChip(label: 'Por defecto', variant: AppChipVariant.warning)
                    else if (c.actualizadoPor.isNotEmpty)
                      AppChip(label: 'Editado por ${c.actualizadoPor}', variant: AppChipVariant.success),
                  ],
                ),
              ],
            ),
          ),
          const ExcludeSemantics(child: Icon(CupertinoIcons.pencil, color: AppPalette.blue700, size: 18)),
        ],
      ),
    );
  }

  void _abrirFormulario(BuildContext context, FilaConfigNotificaciones fila) {
    final cubit = context.read<ConfigNotificacionesCubit>()..abrirFormulario();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BlocProvider.value(value: cubit, child: _FormularioLimites(fila: fila)),
    );
  }
}

/// Formulario de límites. Solo los `TextEditingController` y el período
/// elegido viven en el widget (estado visual del formulario abierto); la
/// validación y el guardado, en [ConfigNotificacionesCubit].
class _FormularioLimites extends StatefulWidget {
  final FilaConfigNotificaciones fila;

  const _FormularioLimites({required this.fila});

  @override
  State<_FormularioLimites> createState() => _FormularioLimitesState();
}

class _FormularioLimitesState extends State<_FormularioLimites> {
  late final TextEditingController _porUsuario;
  late final TextEditingController _organizacion;
  late PeriodoNotificaciones _periodo;

  @override
  void initState() {
    super.initState();
    final c = widget.fila.config;
    _porUsuario = TextEditingController(text: '${c.limitePorUsuario}');
    _organizacion = TextEditingController(text: '${c.limiteOrganizacion}');
    _periodo = c.periodo;
  }

  @override
  void dispose() {
    _porUsuario.dispose();
    _organizacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConfigNotificacionesCubit>();
    return BlocConsumer<ConfigNotificacionesCubit, ConfigNotificacionesState>(
      listenWhen: (prev, curr) => curr.guardadaOrganizacionId == widget.fila.organizacion.id,
      listener: (context, _) => Navigator.of(context).pop(),
      builder: (context, state) {
        final ocupado = state.guardando;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Límites de ${widget.fila.organizacion.nombre}',
                    style: AppTypography.titleLarge.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.md),
                Text('Período', style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<PeriodoNotificaciones>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in PeriodoNotificaciones.values)
                      ButtonSegment(value: p, label: Text(p.etiqueta.replaceFirst('Por ', ''))),
                  ],
                  selected: {_periodo},
                  onSelectionChanged: ocupado ? null : (s) => setState(() => _periodo = s.first),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Por usuario',
                  hint: '0 = sin límite',
                  controller: _porUsuario,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  readOnly: ocupado,
                  errorText: state.erroresFormulario[CampoConfigNotificaciones.limitePorUsuario],
                  onChanged: (_) => cubit.campoEditado(CampoConfigNotificaciones.limitePorUsuario),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Para toda la organización',
                  hint: '0 = sin límite',
                  controller: _organizacion,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  readOnly: ocupado,
                  errorText: state.erroresFormulario[CampoConfigNotificaciones.limiteOrganizacion],
                  onChanged: (_) => cubit.campoEditado(CampoConfigNotificaciones.limiteOrganizacion),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Cada usuario puede enviar hasta el límite "por usuario", y entre todos los usuarios de la '
                  'organización no pueden pasar el límite "para toda la organización".',
                  style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Guardar',
                  icon: CupertinoIcons.checkmark_alt,
                  isLoading: ocupado,
                  isFullWidth: true,
                  onPressed: ocupado
                      ? null
                      : () => cubit.guardar(
                            organizacionId: widget.fila.organizacion.id,
                            periodo: _periodo,
                            limitePorUsuario: _porUsuario.text,
                            limiteOrganizacion: _organizacion.text,
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
