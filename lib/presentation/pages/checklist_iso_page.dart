import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/tokens/typography.dart';
import '../../core/design_system/widgets/app_button.dart';
import '../../core/design_system/widgets/app_card.dart';
import '../../core/design_system/widgets/app_chip.dart';
import '../../core/design_system/widgets/app_empty_state.dart';
import '../../core/design_system/widgets/app_outlined_button.dart';
import '../../core/design_system/widgets/app_refresh_button.dart';
import '../../core/design_system/widgets/app_scaffold.dart';
import '../../core/design_system/widgets/app_text_field.dart';
import '../../models/checklist_iso.dart';
import '../../shared/google_sheets/sheets_data_service.dart';

/// Vista de Matriz de Cumplimiento Normativo (hoja: checklist_iso)
/// Controles ISO 27001, ISO 8000, ISO 25010, WCAG 2.2 AA y CRUD interactivo.
class ChecklistIsoPage extends StatefulWidget {
  final SheetsDataService dataService;

  const ChecklistIsoPage({super.key, required this.dataService});

  @override
  State<ChecklistIsoPage> createState() => _ChecklistIsoPageState();
}

class _ChecklistIsoPageState extends State<ChecklistIsoPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final items = widget.dataService.checklistIsos;
        final totalConformes = items.where((i) => i.estado == '☑').length;
        final porcentaje = items.isNotEmpty ? (totalConformes / items.length * 100).round() : 0;

        return AppScaffold(
          title: 'Checklist Normativo ISO',
          subtitle: 'Hoja checklist_iso • $porcentaje% de conformidad auditada',
          actions: [
            AppRefreshButton(
              onRefresh: () => widget.dataService.fetchAllSheets(),
              isLoading: widget.dataService.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.checkmark_shield_fill, size: 20),
            label: const Text('Nuevo Requisito', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showChecklistDialog(context),
          ),
          body: ListView(
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
                      child: LinearProgressIndicator(
                        value: items.isNotEmpty ? totalConformes / items.length : 0.0,
                        backgroundColor: AppPalette.divider,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.success),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text('Requisitos y Evidencias de Cumplimiento', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
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
                          IconButton(
                            icon: Icon(
                              isConforme ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                              color: isConforme ? AppPalette.success : AppPalette.textSecondary,
                              size: 26,
                            ),
                            tooltip: 'Alternar conformidad',
                            onPressed: () => widget.dataService.toggleChecklistEstado(item.nro),
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
