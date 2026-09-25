import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/checklist_iso/checklist_iso_cubit.dart';
import '../cubits/checklist_iso/checklist_iso_state.dart';

/// Vista de Matriz de Cumplimiento Normativo (hoja: checklist_iso)
/// Controles ISO 27001, ISO 8000, ISO 25010, WCAG 2.2 AA y CRUD interactivo.
class ChecklistIsoPage extends StatelessWidget {
  final SheetsDataService dataService;

  const ChecklistIsoPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChecklistIsoCubit(dataService: dataService),
      child: _ChecklistIsoView(dataService: dataService),
    );
  }
}

class _ChecklistIsoView extends StatefulWidget {
  final SheetsDataService dataService;

  const _ChecklistIsoView({required this.dataService});

  @override
  State<_ChecklistIsoView> createState() => _ChecklistIsoViewState();
}

class _ChecklistIsoViewState extends State<_ChecklistIsoView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChecklistIsoCubit, ChecklistIsoState>(
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
        final cubit = context.read<ChecklistIsoCubit>();
        final items = state.items;
        final totalConformes = state.totalConformes;
        final porcentaje = state.porcentaje;

        return AppScaffold(
          title: 'Checklist Normativo ISO',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'checklist_iso',
            userFriendlyText: '$porcentaje% de conformidad auditada',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == ChecklistIsoStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_checklist_iso',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.checkmark_shield_fill, size: 20),
            label: const Text('Nuevo Requisito', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showChecklistDialog(context),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: (state.status == ChecklistIsoStatus.loading && items.isEmpty)
                ? const ChecklistIsoSkeleton(key: ValueKey('checklist_iso_skeleton'))
                : ListView(
                    key: const ValueKey('checklist_iso_content'),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
            children: [
              // Card de avance de conformidad
              AppCard(
                padding: AppSpacing.pMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CUMPLIMIENTO NORMATIVO GLOBAL', style: AppTypography.labelSmall),
                        Text('$totalConformes de ${items.length} ($porcentaje%)', style: AppTypography.titleLarge.copyWith(fontSize: 14, color: AppPalette.success)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Semantics(
                        label: 'Cumplimiento normativo global',
                        value: '$porcentaje%',
                        child: LinearProgressIndicator(
                          value: items.isNotEmpty ? totalConformes / items.length : 0.0,
                          backgroundColor: AppPalette.divider,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.success),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Semantics(
                header: true,
                headingLevel: 2,
                child: Text('Requisitos y Evidencias de Cumplimiento', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
              ),
              const SizedBox(height: AppSpacing.sm),

              if (items.isEmpty)
                const AppEmptyState(
                  title: 'No hay requisitos en la lista',
                  description: 'Registra un requisito con "Nuevo Requisito".',
                  icon: CupertinoIcons.checkmark_seal,
                )
              else
                ...items.map((item) {
                  final isConforme = item.estado == '☑';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: AppSpacing.pMd,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Botón interactivo para alternar conformidad
                          Semantics(
                            button: true,
                            checked: isConforme,
                            label: 'Control #${item.nro} ${item.control}',
                            hint: 'Toca dos veces para marcar o desmarcar conformidad',
                            child: IconButton(
                              icon: Icon(
                                isConforme ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                                color: isConforme ? AppPalette.success : AppPalette.textSecondary,
                                size: 26,
                              ),
                              tooltip: 'Alternar conformidad',
                              onPressed: () => widget.dataService.toggleChecklistEstado(item.nro),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '#${item.nro} • ${item.control}',
                                        style: AppTypography.titleLarge.copyWith(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    AppChip(
                                      label: item.norma,
                                      variant: AppChipVariant.info,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Evidencia: ${item.evidencia}',
                                  style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                                ),
                                Text(
                                  'Verificado: ${item.timestamp.toIso8601String().split('T').first}',
                                  style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                tooltip: 'Editar Requisito',
                                onPressed: () => _showChecklistDialog(context, item: item),
                              ),
                              IconButton(
                                icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                tooltip: 'Eliminar Requisito',
                                onPressed: () => _confirmDelete(context, item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showChecklistDialog(BuildContext context, {ChecklistISO? item}) {
    final isEditing = item != null;
    final nextNro = isEditing ? item.nro : widget.dataService.checklistIsos.length + 1;
    final controlController = TextEditingController(text: item?.control ?? '');
    final normaController = TextEditingController(text: item?.norma ?? 'ISO/IEC 27001 §8.13');
    final evidenciaController = TextEditingController(text: item?.evidencia ?? '');
    var isConforme = item?.estado == '☑';

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
                      isEditing ? 'Editar Requisito #$nextNro' : 'Nuevo Requisito Normativo',
                      style: AppTypography.titleLarge.copyWith(fontSize: 17),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Descripción del Control', controller: controlController, hint: 'Ej: Backup verificado en 3 formatos'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Norma / Estándar', controller: normaController, hint: 'Ej: ISO 27001 / NIST / WCAG 2.2'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Evidencia Comprobable', controller: evidenciaController, hint: 'Ruta, hash o referencia'),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  title: const Text('Estado Conforme (☑)'),
                  value: isConforme,
                  activeThumbColor: AppPalette.success,
                  onChanged: (val) => setModalState(() => isConforme = val),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: AppOutlinedButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: isEditing ? 'Guardar Cambios' : 'Registrar Requisito',
                        icon: CupertinoIcons.check_mark,
                        onPressed: () {
                          final control = controlController.text.trim();
                          if (control.isEmpty) return;

                          final nuevo = ChecklistISO(
                            nro: nextNro,
                            control: control,
                            norma: normaController.text.trim(),
                            estado: isConforme ? '☑' : '☐',
                            evidencia: evidenciaController.text.trim(),
                            timestamp: DateTime.now(),
                          );

                          if (isEditing) {
                            widget.dataService.updateChecklistIso(nuevo);
                          } else {
                            widget.dataService.addChecklistIso(nuevo);
                          }
                          Navigator.pop(ctx);
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

  void _confirmDelete(BuildContext context, ChecklistISO item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar requisito normativo?'),
        content: Text('Se desincorporará el control #${item.nro} (${item.control}).'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              widget.dataService.deleteChecklistIso(item.nro);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
