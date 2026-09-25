import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/usuarios/usuarios_cubit.dart';
import '../cubits/usuarios/usuarios_state.dart';

/// Vista de Usuarios autorizados (hoja: usuarios + relación usuario_organizacion)
/// Administra quién puede iniciar sesión y a qué organización pertenece.
class UsuariosPage extends StatelessWidget {
  final SheetsDataService dataService;

  const UsuariosPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UsuariosCubit(dataService: dataService),
      child: _UsuariosView(dataService: dataService),
    );
  }
}

class _UsuariosView extends StatefulWidget {
  final SheetsDataService dataService;

  const _UsuariosView({required this.dataService});

  @override
  State<_UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<_UsuariosView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UsuariosCubit, UsuariosState>(
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
        final cubit = context.read<UsuariosCubit>();
        final usuarios = state.filteredUsuarios;
        final esquemaListo = state.schemaMultiOrgListo;

        return AppScaffold(
          title: 'Usuarios',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'usuarios',
            userFriendlyText: '${state.usuarios.length} usuarios autorizados',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == UsuariosStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_usuarios',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.person_add_solid, size: 20),
            label: const Text('Nuevo Usuario', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => esquemaListo ? _showUsuarioDialog(context) : _showEsquemaPendienteDialog(context),
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
                            'El Google Sheet todavía no tiene las hojas "organizaciones"/"usuario_organizacion" (ver Cumplimiento Normativo). '
                            'Crear/editar usuarios está deshabilitado hasta migrarlo.',
                            style: AppTypography.labelSmall.copyWith(color: AppPalette.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: AppTextField(
                  label: 'Buscar usuario',
                  hint: 'Email o nombre...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => cubit.search(val),
                ),
              ),
              Expanded(
                child: usuarios.isEmpty
                    ? const AppEmptyState(
                        title: 'No hay usuarios autorizados',
                        description: 'Usa el botón "Nuevo Usuario" para dar acceso a alguien.',
                        icon: CupertinoIcons.person_2,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 80),
                        itemCount: usuarios.length,
                        itemBuilder: (context, index) {
                          final usuario = usuarios[index];
                          final organizacionId = widget.dataService.organizacionIdForUsuario(usuario.email);
                          final organizacion = organizacionId == null
                              ? null
                              : widget.dataService.organizaciones
                                  .where((o) => o.id == organizacionId)
                                  .firstOrNull;

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
                                      child: Icon(CupertinoIcons.person_fill, color: AppPalette.blue700, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: MergeSemantics(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            usuario.nombre.isNotEmpty ? usuario.nombre : usuario.email,
                                            style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '✉️ ${usuario.email} • ${usuario.id}',
                                            style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          AppChip(
                                            label: organizacion?.nombre ?? 'Sin organización asignada',
                                            variant: organizacion != null ? AppChipVariant.info : AppChipVariant.warning,
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
                                        label: 'Editar usuario ${usuario.email}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                          tooltip: 'Editar Usuario',
                                          onPressed: () => esquemaListo
                                              ? _showUsuarioDialog(context, usuario: usuario)
                                              : _showEsquemaPendienteDialog(context),
                                        ),
                                      ),
                                      Semantics(
                                        button: true,
                                        label: 'Eliminar usuario ${usuario.email}',
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                          tooltip: 'Eliminar Usuario',
                                          onPressed: () => esquemaListo
                                              ? _confirmDelete(context, usuario)
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

  void _showUsuarioDialog(BuildContext context, {Usuario? usuario}) {
    final isEditing = usuario != null;
    final id = isEditing ? usuario.id : widget.dataService.nextUsuarioId;
    final emailController = TextEditingController(text: usuario?.email ?? '');
    final nombreController = TextEditingController(text: usuario?.nombre ?? '');
    final organizaciones = widget.dataService.organizaciones;
    final organizacionActual =
        isEditing ? widget.dataService.organizacionIdForUsuario(usuario.email) : null;
    var organizacionSeleccionada = organizacionActual ?? (organizaciones.isNotEmpty ? organizaciones.first.id : null);

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
                    Expanded(
                      child: Text(
                        isEditing ? 'Editar Usuario' : 'Nuevo Usuario Autorizado',
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
                if (isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      id,
                      style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Correo electrónico (Google)',
                  controller: emailController,
                  hint: 'usuario@ejemplo.com',
                  keyboardType: TextInputType.emailAddress,
                  readOnly: isEditing,
                ),
                if (isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'El correo no se puede cambiar una vez creado: es la clave usada por Seguridad y el login.',
                      style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Nombre (opcional)',
                  controller: nombreController,
                  hint: 'Ej: Juan Pérez',
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: organizacionSeleccionada,
                  decoration: const InputDecoration(
                    labelText: 'Organización',
                    filled: true,
                    fillColor: AppPalette.surface,
                    border: OutlineInputBorder(borderRadius: AppSpacing.roundedSm),
                  ),
                  items: organizaciones
                      .map((o) => DropdownMenuItem(value: o.id, child: Text(o.nombre)))
                      .toList(),
                  onChanged: (val) => setModalState(() => organizacionSeleccionada = val),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: AppOutlinedButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: isEditing ? 'Guardar Cambios' : 'Autorizar Acceso',
                        icon: isEditing ? CupertinoIcons.check_mark : CupertinoIcons.add,
                        onPressed: () async {
                          final email = emailController.text.trim().toLowerCase();
                          if (email.isEmpty || organizacionSeleccionada == null) return;

                          final nuevoUsuario = Usuario(
                            id: id,
                            email: email,
                            nombre: nombreController.text.trim(),
                          );

                          Navigator.pop(ctx);

                          if (isEditing) {
                            await widget.dataService.updateUsuario(
                              nuevoUsuario,
                              organizacionId: organizacionSeleccionada!,
                            );
                          } else {
                            await widget.dataService.addUsuario(
                              nuevoUsuario,
                              organizacionId: organizacionSeleccionada!,
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
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Usuario usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar acceso a este usuario?'),
        content: Text('${usuario.email} ya no va a poder iniciar sesión en el sistema.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.dataService.deleteUsuario(usuario);
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
          'Este módulo necesita que el Sheet real ya tenga las hojas "organizaciones" y '
          '"usuario_organizacion", y que "usuarios" tenga su columna "id". Hasta que se haga esa '
          'migración manual (ver docs/google/multi-organizacion.md), crear/editar/eliminar usuarios '
          'queda deshabilitado para no escribir datos mal alineados.',
        ),
        actions: [
          TextButton(child: const Text('Entendido'), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }
}
