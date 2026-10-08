import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/design_system.dart';
import '../cubit/enviar_correo_cubit.dart';

/// "Correo a clientes" en la vista Ver de una notificación guardada:
/// remitente (la organización), destinatarios (todos los clientes con correo
/// o algunos), cupo diario de Google y envío. Estado en [EnviarCorreoCubit];
/// acá solo vive el controlador del buscador.
class SeccionCorreoClientes extends StatefulWidget {
  const SeccionCorreoClientes({super.key});

  @override
  State<SeccionCorreoClientes> createState() => _SeccionCorreoClientesState();
}

class _SeccionCorreoClientesState extends State<SeccionCorreoClientes> {
  final _buscar = TextEditingController();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EnviarCorreoCubit>();
    return BlocConsumer<EnviarCorreoCubit, EnviarCorreoState>(
      listenWhen: (prev, curr) => curr.mensaje != null && prev.mensaje != curr.mensaje,
      listener: (context, state) {
        final ok = state.status == EnviarCorreoStatus.enviado;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.mensaje!),
          backgroundColor: ok ? AppPalette.success : AppPalette.error,
          duration: const Duration(seconds: 5),
        ));
      },
      builder: (context, state) {
        final org = state.organizacion;
        final ocupado = state.enviando;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              semanticLabel: state.organizacionSinCorreo
                  ? 'La organización no tiene correo'
                  : 'Remitente: ${org!.nombre}. Las respuestas llegan a ${org.email}',
              child: state.organizacionSinCorreo
                  ? Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: AppPalette.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${org?.nombre ?? 'La organización'} no tiene correo. Agregalo en '
                            'Administración → Organizaciones para poder enviar correos.',
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('De: ${org!.nombre}', style: AppTypography.titleLarge.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Responder a: ${org.email}',
                            style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary)),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Para', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text('Todos (${state.clientes.length})'),
                  icon: const Icon(CupertinoIcons.person_3_fill),
                ),
                const ButtonSegment(value: false, label: Text('Elegir'), icon: Icon(CupertinoIcons.checkmark_square)),
              ],
              selected: {state.todos},
              onSelectionChanged: ocupado ? null : (s) => cubit.elegirTodos(s.first),
            ),
            if (state.sinCorreo > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '${state.sinCorreo} ${state.sinCorreo == 1 ? 'cliente no tiene' : 'clientes no tienen'} '
                  'correo cargado y no lo${state.sinCorreo == 1 ? '' : 's'} va a recibir.',
                  style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                ),
              ),
            if (!state.todos) ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Buscar cliente',
                controller: _buscar,
                prefixIcon: CupertinoIcons.search,
                onChanged: cubit.buscar,
              ),
              for (final c in state.clientesFiltrados)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.seleccionados.contains(c.id),
                  title: Text(c.nombre, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c.email, overflow: TextOverflow.ellipsis),
                  onChanged: ocupado ? null : (_) => cubit.alternarCliente(c.id),
                ),
              if (state.clientesFiltrados.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    state.clientes.isEmpty ? 'Ningún cliente tiene correo cargado.' : 'Ningún cliente coincide.',
                    style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (state.cupoRestante case final cupo?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    cupo < state.cantidadDestinatarios
                        ? 'Google permite enviar $cupo correo${cupo == 1 ? '' : 's'} más hoy y elegiste '
                            '${state.cantidadDestinatarios}. Elegí menos clientes o probá mañana.'
                        : 'Google permite enviar $cupo correo${cupo == 1 ? '' : 's'} más hoy.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: cupo < state.cantidadDestinatarios ? AppPalette.error : AppPalette.textSecondary,
                    ),
                  ),
                ),
              ),
            AppButton(
              label: state.cantidadDestinatarios == 0
                  ? 'Enviar correo'
                  : 'Enviar correo a ${state.cantidadDestinatarios} '
                      '${state.cantidadDestinatarios == 1 ? 'cliente' : 'clientes'}',
              icon: CupertinoIcons.paperplane_fill,
              isLoading: ocupado,
              isFullWidth: true,
              onPressed: state.puedeEnviar ? cubit.enviar : null,
            ),
          ],
        );
      },
    );
  }
}
