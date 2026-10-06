import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/tipos_documento/tipos_documento_cubit.dart';
import '../cubits/tipos_documento/tipos_documento_state.dart';

/// Vista de Tipos de Documento (hoja: "tipo de documento")
/// Administra los tipos de identificación (V, E, J, G, etc.) disponibles en el sistema (CRUD completo).
class TiposDocumentoPage extends StatelessWidget {
  final SheetsDataService dataService;

  const TiposDocumentoPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TiposDocumentoCubit(dataService: dataService),
      child: _TiposDocumentoView(dataService: dataService),
    );
  }
}

class _TiposDocumentoView extends StatefulWidget {
  final SheetsDataService dataService;

  const _TiposDocumentoView({required this.dataService});

  @override
  State<_TiposDocumentoView> createState() => _TiposDocumentoViewState();
}

class _TiposDocumentoViewState extends State<_TiposDocumentoView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TiposDocumentoCubit, TiposDocumentoState>(
      listenWhen: (prev, curr) =>
          (curr.actionSuccessMessage != null && prev.actionSuccessMessage != curr.actionSuccessMessage) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppPalette.success,
              content: Text(state.actionSuccessMessage!),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppPalette.error,
              content: Text(state.errorMessage!),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TiposDocumentoCubit>();
        final tipos = state.filteredTipos;
        final totalActivos = state.totalActivos;

        return AppScaffold(
          title: 'Tipos de Documento',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'tipo de documento',
            userFriendlyText: '$totalActivos activos de ${state.tipos.length}',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == TiposDocumentoStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_tipos_documento',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.add, size: 20),
            label: const Text('Nuevo Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showFormDialog(context),
          ),
          body: Column(
            children: [
              if (state.errorCarga != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'No se pudieron cargar los datos: ${state.errorCarga}',
                      style: AppTypography.bodyMedium.copyWith(color: AppPalette.error),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: AppTextField(
                  label: 'Buscar tipo de documento',
                  hint: 'Letra o descripción (ej: V, Venezolano, Jurídico)...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => cubit.search(val),
                ),
              ),
              Expanded(
                child: tipos.isEmpty
                    ? const AppEmptyState(
                        title: 'No se encontraron tipos de documento',
                        description: 'Usa el botón "Nuevo Tipo" para registrar uno.',
                        icon: CupertinoIcons.doc_text,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 80),
                        itemCount: tipos.length,
                        itemBuilder: (context, index) {
                          final item = tipos[index];
                          final enUso = state.enUso.contains(item.tipo.trim().toUpperCase());

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ExcludeSemantics(
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: item.status ? AppPalette.blue100 : AppPalette.divider,
                                      child: Text(
                                        item.tipo,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: item.status ? AppPalette.blue900 : AppPalette.textDisabled,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item.tipo} - ${item.descripcion}',
                                                style: AppTypography.titleLarge.copyWith(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.status
                                                      ? AppPalette.textPrimary
                                                      : AppPalette.textDisabled,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: ${item.id}',
                                          style: AppTypography.labelSmall.copyWith(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: AppPalette.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            AppChip(
                                              label: item.status ? 'Activo' : 'Inactivo',
                                              variant: item.status ? AppChipVariant.success : AppChipVariant.info,
                                            ),
                                            if (enUso)
                                              const AppChip(
                                                label: 'En uso',
                                                variant: AppChipVariant.warning,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.pencil, size: 20),
                                    color: AppPalette.primary,
                                    tooltip: 'Editar tipo',
                                    onPressed: () => _showFormDialog(context, tipoToEdit: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.trash, size: 20),
                                    color: enUso ? AppPalette.textDisabled : AppPalette.error,
                                    tooltip: enUso ? 'En uso (no eliminable)' : 'Eliminar tipo',
                                    onPressed: () => _handleDelete(context, item, enUso),
                                  ),
                                  Semantics(
                                    label: 'Alternar estado de ${item.tipo}',
                                    child: Switch.adaptive(
                                      value: item.status,
                                      activeTrackColor: AppPalette.primary,
                                      onChanged: (val) => _handleToggleStatus(context, item, enUso),
                                    ),
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

  Future<void> _handleToggleStatus(BuildContext context, TipoDocumento item, bool enUso) async {
    final cubit = context.read<TiposDocumentoCubit>();

    if (item.status && enUso) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            CupertinoIcons.exclamationmark_shield_fill,
            color: AppPalette.warning,
            size: 36,
          ),
          title: const Text('No se puede deshabilitar'),
          content: Text(
            'El tipo de documento "${item.tipo}" (${item.descripcion}) está actualmente asignado a clientes o usuarios registrados en el sistema.\n\nPor integridad referencial y normativa ISO 8000, los tipos en uso no pueden desactivarse.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await cubit.toggleTipoDocumentoStatus(item.id);
    } catch (_) {}
  }

  Future<void> _handleDelete(BuildContext context, TipoDocumento item, bool enUso) async {
    final cubit = context.read<TiposDocumentoCubit>();

    if (enUso) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppPalette.warning,
            size: 36,
          ),
          title: const Text('Tipo en uso'),
          content: Text(
            'No es posible eliminar el tipo de documento "${item.tipo}" (${item.descripcion}) porque existen clientes o usuarios que tienen este tipo asignado.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          CupertinoIcons.trash,
          color: AppPalette.error,
          size: 36,
        ),
        title: const Text('¿Eliminar tipo de documento?'),
        content: Text(
          'Se eliminará el tipo "${item.tipo}" (${item.descripcion}) de la base de datos de Google Sheets.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await cubit.deleteTipoDocumento(item.id);
      } catch (_) {}
    }
  }

  Future<void> _showFormDialog(BuildContext context, {TipoDocumento? tipoToEdit}) async {
    final cubit = context.read<TiposDocumentoCubit>();
    final isEditing = tipoToEdit != null;
    // Clientes y usuarios guardan la sigla: en uso solo se edita la descripción.
    final siglaBloqueada = isEditing && cubit.state.enUso.contains(tipoToEdit.tipo.trim().toUpperCase());
    final tipoController = TextEditingController(text: tipoToEdit?.tipo ?? '');
    final descController = TextEditingController(text: tipoToEdit?.descripcion ?? '');
    String? errorTipo;
    String? errorDesc;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Tipo de Documento' : 'Nuevo Tipo de Documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing
                    ? (siglaBloqueada
                        ? 'La sigla está en uso por clientes o usuarios: solo se puede cambiar la descripción.'
                        : 'Modifica los datos del tipo de documento de identidad.')
                    : 'Ingresa el prefijo y descripción para el documento de identidad.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: tipoController,
                autofocus: !siglaBloqueada,
                readOnly: siglaBloqueada,
                onChanged: (_) {
                  if (errorTipo != null) setDialogState(() => errorTipo = null);
                },
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(2),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Tipo / Sigla (ej: V, E, J, G, P)',
                  hintText: 'V, E, J, G, P...',
                  prefixIcon: const Icon(CupertinoIcons.textformat),
                  border: const OutlineInputBorder(),
                  errorText: errorTipo,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descController,
                autofocus: siglaBloqueada,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (errorDesc != null) setDialogState(() => errorDesc = null);
                },
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: Venezolano, Pasaporte, Jurídico...',
                  prefixIcon: const Icon(CupertinoIcons.doc_plaintext),
                  border: const OutlineInputBorder(),
                  errorText: errorDesc,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final tipoInput = tipoController.text.trim().toUpperCase();
                final descInput = descController.text.trim();

                var hasError = false;
                setDialogState(() {
                  errorTipo = null;
                  errorDesc = null;
                });
                if (tipoInput.isEmpty) {
                  setDialogState(() => errorTipo = 'La sigla no puede estar vacía');
                  hasError = true;
                }
                if (descInput.isEmpty) {
                  setDialogState(() => errorDesc = 'La descripción no puede estar vacía');
                  hasError = true;
                }

                if (hasError) return;

                final duplicado = widget.dataService.tiposDocumento.any(
                  (t) => t.tipo.trim().toUpperCase() == tipoInput && (isEditing ? t.id != tipoToEdit.id : true),
                );
                if (duplicado) {
                  setDialogState(() => errorTipo = 'Ya existe el tipo "$tipoInput"');
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  if (isEditing) {
                    await cubit.updateTipoDocumento(
                      id: tipoToEdit.id,
                      nuevoTipo: tipoInput,
                      nuevaDescripcion: descInput,
                    );
                  } else {
                    await cubit.addTipoDocumento(
                      tipo: tipoInput,
                      descripcion: descInput,
                    );
                  }
                } catch (_) {}
              },
              child: Text(isEditing ? 'Guardar Cambios' : 'Registrar Tipo'),
            ),
          ],
        ),
      ),
    );
  }
}
