import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/environment_config.dart';
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
import '../../models/reporte_migracion.dart';
import '../../shared/google_sheets/sheets_data_service.dart';

/// Vista de Reporte de Migración y Calidad de Datos (hoja: reporte_migracion)
/// Cumplimiento ISO 25010, ISO 8000 y CRUD de controles.
class ReporteMigracionPage extends StatefulWidget {
  final SheetsDataService dataService;

  const ReporteMigracionPage({super.key, required this.dataService});

  @override
  State<ReporteMigracionPage> createState() => _ReporteMigracionPageState();
}

class _ReporteMigracionPageState extends State<ReporteMigracionPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final reportes = widget.dataService.reportesMigracion;

        return AppScaffold(
          title: 'Reporte de Migración',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'reporte_migracion',
            userFriendlyText: '${reportes.length} controles estructurales',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => widget.dataService.fetchAllSheets(),
              isLoading: widget.dataService.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.doc_append, size: 20),
            label: const Text('Nuevo Control', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showReporteDialog(context),
          ),
          body: reportes.isEmpty
              ? const AppEmptyState(
                  title: 'No hay controles de migración registrados',
                  description: 'Añade el primer control con "Nuevo Control".',
                  icon: CupertinoIcons.doc_text,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                  itemCount: reportes.length,
                  itemBuilder: (context, index) {
                    final rep = reportes[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: AppSpacing.pMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    rep.metrica,
                                    style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                AppChip(
                                  label: rep.normaAplicada,
                                  variant: AppChipVariant.info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Estado: ${rep.valorEstado}',
                              style: AppTypography.titleLarge.copyWith(fontSize: 13, color: AppPalette.success),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Obs: ${rep.observaciones}',
                              style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                  tooltip: 'Editar Control',
                                  onPressed: () => _showReporteDialog(context, index: index, reporte: rep),
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                  tooltip: 'Eliminar Control',
                                  onPressed: () => _confirmDelete(context, index, rep),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showReporteDialog(BuildContext context, {int? index, ReporteMigracion? reporte}) {
    final isEditing = reporte != null && index != null;
    final metricaController = TextEditingController(text: reporte?.metrica ?? '');
    final valorController = TextEditingController(text: reporte?.valorEstado ?? '100% Conforme');
    final normaController = TextEditingController(text: reporte?.normaAplicada ?? 'ISO 8000 §4.2');
    final obsController = TextEditingController(text: reporte?.observaciones ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
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
                    isEditing ? 'Editar Control de Migración' : 'Nuevo Control de Migración',
                    style: AppTypography.titleLarge.copyWith(fontSize: 17),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Métrica / Control', controller: metricaController, hint: 'Ej: Integridad Referencial'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Valor / Estado', controller: valorController, hint: 'Ej: 100% Conforme'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Norma Aplicada', controller: normaController, hint: 'Ej: ISO 8000 / ISO 27001'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Observaciones', controller: obsController),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: AppOutlinedButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx))),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: isEditing ? 'Guardar Cambios' : 'Registrar',
                      icon: CupertinoIcons.check_mark,
                      onPressed: () {
                        final metrica = metricaController.text.trim();
                        if (metrica.isEmpty) return;

                        final nuevo = ReporteMigracion(
                          metrica: metrica,
                          valorEstado: valorController.text.trim(),
                          normaAplicada: normaController.text.trim(),
                          observaciones: obsController.text.trim(),
                        );

                        if (isEditing) {
                          widget.dataService.updateReporteMigracion(index, nuevo);
                        } else {
                          widget.dataService.addReporteMigracion(nuevo);
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
    );
  }

  void _confirmDelete(BuildContext context, int index, ReporteMigracion rep) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar control?'),
        content: Text('Se desincorporará el control "${rep.metrica}".'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              widget.dataService.deleteReporteMigracion(index);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
