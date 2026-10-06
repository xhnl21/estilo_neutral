import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/codigos_telefono/codigos_telefono_cubit.dart';
import '../cubits/codigos_telefono/codigos_telefono_state.dart';

/// Vista de Códigos de Teléfono (hoja: "codigo de telefonos")
/// Administra los prefijos telefónicos disponibles en clientes y usuarios (CRUD completo).
class CodigosTelefonoPage extends StatelessWidget {
  final SheetsDataService dataService;

  const CodigosTelefonoPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CodigosTelefonoCubit(dataService: dataService),
      child: _CodigosTelefonoView(dataService: dataService),
    );
  }
}

class _CodigosTelefonoView extends StatefulWidget {
  final SheetsDataService dataService;

  const _CodigosTelefonoView({required this.dataService});

  @override
  State<_CodigosTelefonoView> createState() => _CodigosTelefonoViewState();
}

class _CodigosTelefonoViewState extends State<_CodigosTelefonoView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CodigosTelefonoCubit, CodigosTelefonoState>(
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
        final cubit = context.read<CodigosTelefonoCubit>();
        final codigos = state.filteredCodigos;
        final totalActivos = state.totalActivos;

        return AppScaffold(
          title: 'Códigos de Teléfonos',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'codigo de telefonos',
            userFriendlyText: '$totalActivos activos de ${state.codigos.length}',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == CodigosTelefonoStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_codigos_telefono',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.phone_badge_plus, size: 20),
            label: const Text('Nuevo Código', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  label: 'Buscar código telefónico',
                  hint: 'Ej: 0414, 0424, ct00000001...',
                  prefixIcon: CupertinoIcons.search,
                  onChanged: (val) => cubit.search(val),
                ),
              ),
              Expanded(
                child: codigos.isEmpty
                    ? const AppEmptyState(
                        title: 'No se encontraron códigos telefónicos',
                        description: 'Usa el botón "Nuevo Código" para registrar uno.',
                        icon: CupertinoIcons.phone,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 80),
                        itemCount: codigos.length,
                        itemBuilder: (context, index) {
                          final item = codigos[index];
                          final enUso = state.enUso.contains(item.codigo.trim());

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
                                      child: Icon(
                                        CupertinoIcons.phone_fill,
                                        color: item.status ? AppPalette.blue700 : AppPalette.textDisabled,
                                        size: 20,
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
                                                item.codigo,
                                                style: AppTypography.titleLarge.copyWith(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
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
                                    color: enUso ? AppPalette.textDisabled : AppPalette.primary,
                                    // Los teléfonos de clientes guardan el código:
                                    // en uso no se puede renombrar.
                                    tooltip: enUso ? 'En uso (no editable)' : 'Editar código',
                                    onPressed: enUso ? null : () => _showFormDialog(context, codigoToEdit: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.trash, size: 20),
                                    color: enUso ? AppPalette.textDisabled : AppPalette.error,
                                    tooltip: enUso ? 'En uso (no eliminable)' : 'Eliminar código',
                                    onPressed: () => _handleDelete(context, item, enUso),
                                  ),
                                  Semantics(
                                    label: 'Alternar estado de ${item.codigo}',
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

  Future<void> _handleToggleStatus(BuildContext context, CodigoTelefono item, bool enUso) async {
    final cubit = context.read<CodigosTelefonoCubit>();

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
            'El código "${item.codigo}" (ID: ${item.id}) está actualmente asignado a clientes o usuarios registrados en el sistema.\n\nPor integridad referencial y normativa ISO 8000, los códigos en uso no pueden desactivarse.',
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
      await cubit.toggleCodigoTelefonoStatus(item.id);
    } catch (_) {
      // El error ya es emitido en el estado del cubit
    }
  }

  Future<void> _handleDelete(BuildContext context, CodigoTelefono item, bool enUso) async {
    final cubit = context.read<CodigosTelefonoCubit>();

    if (enUso) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppPalette.warning,
            size: 36,
          ),
          title: const Text('Código en uso'),
          content: Text(
            'No es posible eliminar el código "${item.codigo}" porque existen clientes o usuarios que tienen este prefijo telefónico asignado.',
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
        title: const Text('¿Eliminar código telefónico?'),
        content: Text(
          'Se eliminará el código "${item.codigo}" (ID: ${item.id}) de la base de datos de Google Sheets.',
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
        await cubit.deleteCodigoTelefono(item.id);
      } catch (_) {}
    }
  }

  Future<void> _showFormDialog(BuildContext context, {CodigoTelefono? codigoToEdit}) async {
    final cubit = context.read<CodigosTelefonoCubit>();
    final isEditing = codigoToEdit != null;
    final controller = TextEditingController(text: codigoToEdit?.codigo ?? '');
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Código Telefónico' : 'Nuevo Código Telefónico'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing
                    ? 'Modifica el prefijo telefónico. Se actualizará en los selectores del sistema.'
                    : 'Ingresa el prefijo telefónico que estará disponible para clientes y usuarios.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: 'Prefijo telefónico',
                  hintText: 'Ej: 0414, 0424, 0212',
                  prefixIcon: const Icon(CupertinoIcons.phone),
                  border: const OutlineInputBorder(),
                  errorText: errorText,
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
                final input = controller.text.trim();
                if (input.isEmpty) {
                  setDialogState(() => errorText = 'El código no puede estar vacío');
                  return;
                }
                if (!SheetsDataService.formatoCodigoTelefono.hasMatch(input)) {
                  setDialogState(() => errorText = 'Debe tener 4 dígitos y empezar con 0 (ej: 0414)');
                  return;
                }

                final duplicado = widget.dataService.codigosTelefono.any(
                  (c) => c.codigo.trim() == input && (isEditing ? c.id != codigoToEdit.id : true),
                );
                if (duplicado) {
                  setDialogState(() => errorText = 'Ya existe el código "$input"');
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  if (isEditing) {
                    await cubit.updateCodigoTelefono(codigoToEdit.id, input);
                  } else {
                    await cubit.addCodigoTelefono(input);
                  }
                } catch (_) {}
              },
              child: Text(isEditing ? 'Guardar Cambios' : 'Registrar Código'),
            ),
          ],
        ),
      ),
    );
  }
}
