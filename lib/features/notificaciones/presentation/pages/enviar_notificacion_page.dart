import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../models/config_notificaciones.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../domain/destino_notificacion.dart';
import '../cubit/enviar_notificacion_cubit.dart';
import '../cubit/enviar_notificacion_state.dart';

/// Vista "Ver" de una notificación guardada: su tipo, título y mensaje y,
/// debajo, los destinatarios (todos, una o varias organizaciones, o usuarios
/// puntuales de cualquier organización) y el botón para enviarla.
class EnviarNotificacionPage extends StatelessWidget {
  final SheetsDataService dataService;
  final String plantillaId;

  const EnviarNotificacionPage({super.key, required this.dataService, required this.plantillaId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EnviarNotificacionCubit(dataService: dataService, plantillaId: plantillaId),
      child: const _EnviarNotificacionView(),
    );
  }
}

class _EnviarNotificacionView extends StatelessWidget {
  const _EnviarNotificacionView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnviarNotificacionCubit, EnviarNotificacionState>(
      listenWhen: (prev, curr) => curr.avisoCupo != null && prev.avisoCupo != curr.avisoCupo,
      listener: (context, state) => _mostrarCupoAgotado(context, state.avisoCupo!),
      child: BlocConsumer<EnviarNotificacionCubit, EnviarNotificacionState>(
        listenWhen: (prev, curr) => curr.mensaje != null && prev.mensaje != curr.mensaje,
        listener: (context, state) {
          final ok = state.status == EnviarNotificacionStatus.enviada;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.mensaje!),
            backgroundColor: ok ? AppPalette.success : AppPalette.error,
            duration: const Duration(seconds: 4),
          ));
        },
        builder: (context, state) => _build(context, state),
      ),
    );
  }

  void _mostrarCupoAgotado(BuildContext context, String motivo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(CupertinoIcons.bell_slash_fill, color: AppPalette.error),
        title: const Text('Se acabaron las notificaciones'),
        content: Text(motivo),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  void _volver(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.notificaciones);
    }
  }

  Widget _build(BuildContext context, EnviarNotificacionState state) {
    final cubit = context.read<EnviarNotificacionCubit>();
    final ocupado = state.enviando;
    final plantilla = state.plantilla;

    if (plantilla == null) {
      return AppScaffold(
        title: 'Notificación',
        showBackButton: true,
        onBack: () => _volver(context),
        body: AppEmptyState(
          title: 'Esta notificación ya no existe',
          subtitle: 'Puede que la hayan eliminado desde otro teléfono.',
          icon: CupertinoIcons.bell_slash,
          actionLabel: 'Volver al listado',
          onAction: () => _volver(context),
        ),
      );
    }

    return AppScaffold(
      title: 'Ver notificación',
      subtitle: 'Elegí los destinatarios y enviala',
      showBackButton: true,
      onBack: () => _volver(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
        children: [
          AppCard(
            semanticLabel: 'Notificación ${state.nombreTipo}: ${plantilla.titulo}. ${plantilla.cuerpo}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppChip(label: state.nombreTipo, icon: CupertinoIcons.tag),
                const SizedBox(height: AppSpacing.sm),
                Text(plantilla.titulo, style: AppTypography.titleLarge.copyWith(fontSize: 17)),
                const SizedBox(height: AppSpacing.xs),
                Text(plantilla.cuerpo, style: AppTypography.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Destinatarios', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<AlcanceNotificacion>(
            segments: const [
              ButtonSegment(
                value: AlcanceNotificacion.global,
                label: Text('Todos'),
                icon: Icon(CupertinoIcons.globe),
              ),
              ButtonSegment(
                value: AlcanceNotificacion.organizaciones,
                label: Text('Organizaciones'),
                icon: Icon(CupertinoIcons.building_2_fill),
              ),
              ButtonSegment(
                value: AlcanceNotificacion.usuarios,
                label: Text('Usuarios'),
                icon: Icon(CupertinoIcons.person_2),
              ),
            ],
            selected: {state.alcance},
            onSelectionChanged: ocupado ? null : (s) => cubit.cambiarAlcance(s.first),
          ),
          if (state.errores[CampoNotificacion.destino] case final error?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Semantics(
                liveRegion: true,
                child: Text(error, style: AppTypography.bodyMedium.copyWith(color: AppPalette.error)),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          ..._destinatarios(cubit, state, ocupado),
          const SizedBox(height: AppSpacing.lg),
          if (_textoCupo(state.uso) case final texto?) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                texto,
                style: AppTypography.bodyMedium.copyWith(
                  color: state.sinCupo ? AppPalette.error : AppPalette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Enviar notificación',
            icon: CupertinoIcons.paperplane_fill,
            isLoading: ocupado,
            isFullWidth: true,
            onPressed: ocupado || state.sinCupo ? null : cubit.enviarPlantilla,
          ),
        ],
      ),
    );
  }

  /// "Te quedan 5 notificaciones hoy." / "No te quedan… Se renueva el …".
  /// `null` si no hay límite o no se pudo consultar.
  String? _textoCupo(UsoNotificaciones? uso) {
    final restantes = uso?.restantes;
    if (uso == null || restantes == null) return null;
    final periodo = uso.periodo.enElPeriodo;
    if (restantes > 0) {
      return 'Te ${restantes == 1 ? 'queda 1 notificación' : 'quedan $restantes notificaciones'} $periodo.';
    }
    return 'No te quedan notificaciones $periodo.${uso.textoRenueva()}';
  }

  List<Widget> _destinatarios(EnviarNotificacionCubit cubit, EnviarNotificacionState state, bool ocupado) {
    switch (state.alcance) {
      case AlcanceNotificacion.global:
        return [
          Text(
            'Llega a todos los usuarios con acceso, de todas las organizaciones.',
            style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
          ),
        ];
      case AlcanceNotificacion.organizaciones:
        return [
          for (final o in state.organizaciones)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: state.organizacionesSeleccionadas.contains(o.id),
              title: Text(o.nombre, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${state.usuariosPorOrganizacion[o.id]?.length ?? 0} usuarios',
                style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
              ),
              onChanged: ocupado ? null : (_) => cubit.alternarOrganizacion(o.id),
            ),
        ];
      case AlcanceNotificacion.usuarios:
        return [
          for (final o in state.organizaciones)
            if ((state.usuariosPorOrganizacion[o.id] ?? const []).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(o.nombre, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${state.usuariosPorOrganizacion[o.id]!.where((u) => state.usuariosSeleccionados.contains(u.email.toLowerCase())).length}'
                  ' de ${state.usuariosPorOrganizacion[o.id]!.length} elegidos',
                  style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                ),
                trailing: TextButton(
                  onPressed: ocupado ? null : () => cubit.alternarUsuariosDeOrganizacion(o.id),
                  child: const Text('Todos'),
                ),
                children: [
                  for (final u in state.usuariosPorOrganizacion[o.id]!)
                    CheckboxListTile(
                      value: state.usuariosSeleccionados.contains(u.email.toLowerCase()),
                      title: Text(u.nombre.isNotEmpty ? u.nombre : u.email, overflow: TextOverflow.ellipsis),
                      subtitle: u.nombre.isNotEmpty ? Text(u.email, overflow: TextOverflow.ellipsis) : null,
                      onChanged: ocupado ? null : (_) => cubit.alternarUsuario(u.email),
                    ),
                ],
              ),
        ];
    }
  }
}
