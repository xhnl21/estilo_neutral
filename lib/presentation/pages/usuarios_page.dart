import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/usuario_form/usuario_form_cubit.dart';
import '../cubits/usuario_form/usuario_form_state.dart';
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
          (curr.actionSuccessMessage != null && prev.actionSuccessMessage != curr.actionSuccessMessage) ||
          (curr.actionErrorMessage != null && prev.actionErrorMessage != curr.actionErrorMessage),
      listener: (context, state) {
        final error = state.actionErrorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: error != null ? AppPalette.error : AppPalette.success,
            content: Text(error ?? state.actionSuccessMessage!),
            duration: Duration(seconds: error != null ? 4 : 2),
          ),
        );
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
            label: const Text('Nuevo Usuario',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => esquemaListo
                ? _showUsuarioDialog(context)
                : _showEsquemaPendienteDialog(context),
          ),
          body: Column(
            children: [
              if (!esquemaListo)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: AppCard(
                    padding: AppSpacing.pSm,
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                            size: 16, color: AppPalette.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'El Google Sheet todavía no tiene las hojas "organizaciones"/"usuario_organizacion" (ver Cumplimiento Normativo). '
                            'Crear/editar usuarios está deshabilitado hasta migrarlo.',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppPalette.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
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
                        description:
                            'Usa el botón "Nuevo Usuario" para dar acceso a alguien.',
                        icon: CupertinoIcons.person_2,
                      )
                    : ListView(
                        key: const ValueKey('usuarios_list'),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, 80),
                        children: [
                          ExpansionPanelList(
                            elevation: 1,
                            expandedHeaderPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            expansionCallback: (panelIndex, isExpanded) {
                              final usuario = usuarios[panelIndex];
                              cubit.toggleExpanded(usuario.id);
                            },
                            children: usuarios.map<ExpansionPanel>((usuario) {
                              final organizacionId = widget.dataService
                                  .organizacionIdForUsuario(usuario.email);
                              final organizacion = organizacionId == null
                                  ? null
                                  : widget.dataService.organizaciones
                                      .where((o) => o.id == organizacionId)
                                      .firstOrNull;
                              final isExpanded =
                                  state.expandedUsuarioId == usuario.id;

                              return ExpansionPanel(
                                isExpanded: isExpanded,
                                canTapOnHeader: true,
                                backgroundColor: AppPalette.surface,
                                headerBuilder: (context, isHeaderExpanded) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm),
                                    child: Row(
                                      children: [
                                        const ExcludeSemantics(
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AppPalette.blue100,
                                            child: Icon(
                                                CupertinoIcons.person_fill,
                                                color: AppPalette.blue700,
                                                size: 18),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                usuario.nombre.isNotEmpty
                                                    ? usuario.nombre
                                                    : usuario.email,
                                                style: AppTypography.titleLarge
                                                    .copyWith(fontSize: 15),
                                                maxLines:
                                                    isHeaderExpanded ? null : 1,
                                                overflow: isHeaderExpanded
                                                    ? null
                                                    : TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Wrap(
                                                spacing: 6,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    'ID: ${usuario.id}',
                                                    style: AppTypography
                                                        .labelSmall
                                                        .copyWith(
                                                      color: AppPalette
                                                          .textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  if (usuario.documentoCompleto
                                                      .isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppPalette.surface,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                            color: AppPalette
                                                                .divider),
                                                      ),
                                                      child: Text(
                                                        usuario
                                                            .documentoCompleto,
                                                        style: AppTypography
                                                            .labelSmall
                                                            .copyWith(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppPalette
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                  AppChip(
                                                    label:
                                                        organizacion?.nombre ??
                                                            'Sin organización',
                                                    variant: organizacion !=
                                                            null
                                                        ? AppChipVariant.info
                                                        : AppChipVariant
                                                            .warning,
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
                                      const Divider(color: AppPalette.divider),
                                      const SizedBox(height: 4),
                                      SelectableText.rich(
                                        TextSpan(
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                  fontSize: 13, height: 1.5),
                                          children: [
                                            const TextSpan(
                                                text: '👤 Nombre: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            TextSpan(
                                                text: usuario.nombre.isNotEmpty
                                                    ? usuario.nombre
                                                    : 'No especificado'),
                                            const TextSpan(
                                                text: '\n🆔 Cédula: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            TextSpan(
                                                text: usuario.documentoCompleto
                                                        .isNotEmpty
                                                    ? usuario.documentoCompleto
                                                    : 'No registrada'),
                                            const TextSpan(
                                                text: '\n✉️ Email: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            TextSpan(text: usuario.email),
                                            const TextSpan(
                                                text: '\n🏢 Organización: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            TextSpan(
                                                text: organizacion != null
                                                    ? '${organizacion.nombre} (${organizacion.id})'
                                                    : 'Sin organización asignada'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        alignment: WrapAlignment.end,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              foregroundColor:
                                                  AppPalette.blue700,
                                              side: const BorderSide(
                                                  color: AppPalette.border),
                                            ),
                                            icon: const Icon(
                                                CupertinoIcons.pencil,
                                                size: 16),
                                            label: const Text('Editar'),
                                            onPressed: () => esquemaListo
                                                ? _showUsuarioDialog(context,
                                                    usuario: usuario)
                                                : _showEsquemaPendienteDialog(
                                                    context),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              foregroundColor: AppPalette.error,
                                              side: const BorderSide(
                                                  color: AppPalette.border),
                                            ),
                                            icon: const Icon(
                                                CupertinoIcons.trash,
                                                size: 16),
                                            label: const Text('Eliminar'),
                                            onPressed: () => esquemaListo
                                                ? _confirmDelete(
                                                    context, usuario)
                                                : _showEsquemaPendienteDialog(
                                                    context),
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
            ],
          ),
        );
      },
    );
  }

  void _showUsuarioDialog(BuildContext context, {Usuario? usuario}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BlocProvider(
        create: (_) => UsuarioFormCubit(dataService: widget.dataService, usuario: usuario),
        child: _UsuarioFormSheet(id: usuario?.id),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Usuario usuario) {
    // El diálogo no queda debajo del BlocProvider: se toma el Cubit acá.
    final cubit = context.read<UsuariosCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar acceso a este usuario?'),
        content: Text(
            '${usuario.email} ya no va a poder iniciar sesión en el sistema.'),
        actions: [
          TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              Navigator.pop(ctx);
              cubit.deleteUsuario(usuario);
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
          TextButton(
              child: const Text('Entendido'),
              onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }
}

/// Formulario de alta/edición de un usuario autorizado. El estado de negocio
/// (catálogos, validación, guardado) vive en [UsuarioFormCubit]; acá solo
/// quedan los `TextEditingController`.
class _UsuarioFormSheet extends StatefulWidget {
  final String? id;

  const _UsuarioFormSheet({this.id});

  @override
  State<_UsuarioFormSheet> createState() => _UsuarioFormSheetState();
}

class _UsuarioFormSheetState extends State<_UsuarioFormSheet> {
  late final TextEditingController _email;
  late final TextEditingController _nombre;
  late final TextEditingController _cedula;

  @override
  void initState() {
    super.initState();
    final s = context.read<UsuarioFormCubit>().state;
    _email = TextEditingController(text: s.emailInicial);
    _nombre = TextEditingController(text: s.nombreInicial);
    _cedula = TextEditingController(text: s.cedulaInicial);
  }

  @override
  void dispose() {
    _email.dispose();
    _nombre.dispose();
    _cedula.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UsuarioFormCubit, UsuarioFormState>(
      listenWhen: (prev, curr) => curr.resultMessage != null && prev.resultMessage != curr.resultMessage,
      listener: (context, state) {
        final guardado = state.status == UsuarioFormStatus.guardado;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: guardado ? AppPalette.success : AppPalette.error,
          content: Text(state.resultMessage!),
          duration: Duration(seconds: guardado ? 2 : 4),
        ));
        // Si falló, el formulario queda abierto para corregir o reintentar.
        if (guardado) Navigator.of(context).pop();
      },
      builder: (context, state) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, UsuarioFormState state) {
    final cubit = context.read<UsuarioFormCubit>();
    final isEditing = state.isEditing;
    final ocupado = state.isSubmitting;

    return PopScope(
      canPop: !ocupado,
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
                      isEditing ? 'Editar Usuario' : 'Nuevo Usuario Autorizado',
                      style: AppTypography.titleLarge.copyWith(fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                    onPressed: ocupado ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              if (isEditing && widget.id != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.id!,
                    style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Correo electrónico (Google)',
                controller: _email,
                hint: 'usuario@ejemplo.com',
                keyboardType: TextInputType.emailAddress,
                readOnly: isEditing || ocupado,
                errorText: state.errors[UsuarioFormField.email],
                onChanged: (_) => cubit.fieldChanged(UsuarioFormField.email),
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
                controller: _nombre,
                hint: 'Ej: Juan Pérez',
                readOnly: ocupado,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppPalette.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppPalette.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.tipoDocumento,
                          isExpanded: true,
                          items: state.tiposDocumento
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: ocupado
                              ? null
                              : (val) {
                                  if (val != null) cubit.tipoDocumentoChanged(val);
                                },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: 'Cédula / Documento',
                      controller: _cedula,
                      hint: '12345678',
                      keyboardType: TextInputType.number,
                      readOnly: ocupado,
                      errorText: state.errors[UsuarioFormField.cedula],
                      onChanged: (_) => cubit.fieldChanged(UsuarioFormField.cedula),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // La key recrea el campo si el Cubit cambia la selección
              // (p. ej. la organización elegida se borró).
              DropdownButtonFormField<String>(
                key: ValueKey('usuario_org_${state.organizacionId}'),
                initialValue: state.organizacionId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Organización',
                  filled: true,
                  fillColor: AppPalette.surface,
                  border: const OutlineInputBorder(borderRadius: AppSpacing.roundedSm),
                  errorText: state.errors[UsuarioFormField.organizacion],
                ),
                items: state.organizaciones
                    .map((o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(o.nombre, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: ocupado ? null : cubit.organizacionChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(
                      label: 'Cancelar',
                      onPressed: ocupado ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: isEditing ? 'Guardar Cambios' : 'Autorizar Acceso',
                      icon: isEditing ? CupertinoIcons.check_mark : CupertinoIcons.add,
                      isLoading: ocupado,
                      onPressed: ocupado
                          ? null
                          : () => cubit.submit(email: _email.text, nombre: _nombre.text, cedula: _cedula.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
