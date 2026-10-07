import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../domain/destino_notificacion.dart';
import '../cubit/enviar_notificacion_cubit.dart';
import '../cubit/enviar_notificacion_state.dart';

/// Vista "Enviar notificación" (hojas: notificaciones + dispositivos).
/// Cualquier usuario con acceso puede enviar a todos, a una o varias
/// organizaciones, o a usuarios puntuales de cualquier organización.
class EnviarNotificacionPage extends StatelessWidget {
  final SheetsDataService dataService;

  const EnviarNotificacionPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EnviarNotificacionCubit(dataService: dataService),
      child: const _EnviarNotificacionView(),
    );
  }
}

class _EnviarNotificacionView extends StatefulWidget {
  const _EnviarNotificacionView();

  @override
  State<_EnviarNotificacionView> createState() => _EnviarNotificacionViewState();
}

class _EnviarNotificacionViewState extends State<_EnviarNotificacionView> {
  final _titulo = TextEditingController();
  final _cuerpo = TextEditingController();

  @override
  void dispose() {
    _titulo.dispose();
    _cuerpo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EnviarNotificacionCubit, EnviarNotificacionState>(
      listenWhen: (prev, curr) => curr.mensaje != null && prev.mensaje != curr.mensaje,
      listener: (context, state) {
        final ok = state.status == EnviarNotificacionStatus.enviada;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.mensaje!),
          backgroundColor: ok ? AppPalette.success : AppPalette.error,
          duration: const Duration(seconds: 4),
        ));
        if (ok) {
          _titulo.clear();
          _cuerpo.clear();
        }
      },
      builder: (context, state) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, EnviarNotificacionState state) {
    final cubit = context.read<EnviarNotificacionCubit>();
    final ocupado = state.enviando;

    return AppScaffold(
      title: 'Notificaciones',
      subtitle: 'Enviar un aviso a los teléfonos de los usuarios',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
        children: [
          AppTextField(
            label: 'Título',
            controller: _titulo,
            hint: 'Ej: Llegó mercancía nueva',
            readOnly: ocupado,
            errorText: state.errores[CampoNotificacion.titulo],
            onChanged: (_) => cubit.campoEditado(CampoNotificacion.titulo),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Mensaje',
            controller: _cuerpo,
            hint: 'Ej: Ya están disponibles las tallas nuevas.',
            maxLines: 4,
            readOnly: ocupado,
            errorText: state.errores[CampoNotificacion.cuerpo],
            onChanged: (_) => cubit.campoEditado(CampoNotificacion.cuerpo),
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
          AppButton(
            label: 'Enviar notificación',
            icon: CupertinoIcons.paperplane_fill,
            isLoading: ocupado,
            isFullWidth: true,
            onPressed: ocupado ? null : () => cubit.enviar(titulo: _titulo.text, cuerpo: _cuerpo.text),
          ),
        ],
      ),
    );
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
