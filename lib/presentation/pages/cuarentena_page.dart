import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/icons.dart';
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
import '../../models/registro_cuarentena.dart';
import '../../shared/google_sheets/sheets_data_service.dart';

/// Vista de Bandeja de Cuarentena (hoja: cuarentena)
/// Operaciones CRUD completas y análisis de anomalías forenses.
class CuarentenaPage extends StatefulWidget {
  final SheetsDataService dataService;

  const CuarentenaPage({super.key, required this.dataService});

  @override
  State<CuarentenaPage> createState() => _CuarentenaPageState();
}

class _CuarentenaPageState extends State<CuarentenaPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final items = widget.dataService.cuarentenas;

        return AppScaffold(
          title: 'Cuarentena',
          subtitle: 'Hoja cuarentena • ${items.length} anomalías forenses',
          actions: [
            AppRefreshButton(
              onRefresh: () => widget.dataService.fetchAllSheets(),
              isLoading: widget.dataService.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.shield_slash, size: 20),
            label: const Text('Reportar Anomalía', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showCuarentenaDialog(context),
          ),
          body: items.isEmpty
              ? const AppEmptyState(
                  title: 'Bandeja de Cuarentena Limpia',
                  description: 'No hay anomalías contables activas.',
                  icon: CupertinoIcons.shield_lefthalf_fill,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isResolved = item.estado == 'CONSOLIDADO' || item.estado == 'CORREGIDO';

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
                                    '#${item.idRegistroOriginal} • Origen: ${item.hojaOrigen}',
                                    style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                AppChip(
                                  label: item.estado,
                                  variant: isResolved ? AppChipVariant.success : AppChipVariant.warning,
                                  icon: isResolved ? AppIcons.success : AppIcons.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Motivo: ${item.motivoCuarentena}',
                              style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: AppPalette.error),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'JSON: ${item.datosOriginalesJson}',
                                style: AppTypography.labelSmall.copyWith(fontFamily: 'monospace', fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Resolución: ${item.resolucion}',
                              style: AppTypography.labelSmall.copyWith(color: AppPalette.blue900),
                            ),
                            Text(
                              'Hash: ${item.hashEvidencia.substring(0, 16)}...',
                              style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary, fontSize: 10),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                  tooltip: 'Editar / Resolver Anomalía',
                                  onPressed: () => _showCuarentenaDialog(context, item: item),
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                  tooltip: 'Purgar de Cuarentena',
                                  onPressed: () => _confirmDelete(context, item),
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

  void _showCuarentenaDialog(BuildContext context, {RegistroCuarentena? item}) {
    final isEditing = item != null;
    final idController = TextEditingController(text: item?.idRegistroOriginal ?? 'ANOM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final hojaController = TextEditingController(text: item?.hojaOrigen ?? 'ventas');
    final motivoController = TextEditingController(text: item?.motivoCuarentena ?? 'Inconsistencia en montos');
    final jsonController = TextEditingController(text: item?.datosOriginalesJson ?? '{"ERROR": "Datos faltantes"}');
    final estadoController = TextEditingController(text: item?.estado ?? 'PENDIENTE');
    final resolucionController = TextEditingController(text: item?.resolucion ?? 'En revisión por auditoría');

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
                    isEditing ? 'Resolver Anomalía (${item.idRegistroOriginal})' : 'Reportar a Cuarentena',
                    style: AppTypography.titleLarge.copyWith(fontSize: 17),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'ID Registro Original',
                      controller: idController,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Hoja de Origen',
                      controller: hojaController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Motivo de Cuarentena',
                controller: motivoController,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Datos Originales (JSON)',
                controller: jsonController,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Estado (PENDIENTE, CORREGIDO, CONSOLIDADO)',
                      controller: estadoController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Resolución Forense',
                controller: resolucionController,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: isEditing ? 'Guardar Resolución' : 'Aislar Registro',
                      icon: CupertinoIcons.check_mark,
                      onPressed: () {
                        final nuevo = RegistroCuarentena(
                          idRegistroOriginal: idController.text.trim(),
                          hojaOrigen: hojaController.text.trim(),
                          fechaDeteccion: item?.fechaDeteccion ?? DateTime.now(),
                          motivoCuarentena: motivoController.text.trim(),
                          datosOriginalesJson: jsonController.text.trim(),
                          estado: estadoController.text.trim(),
                          resolucion: resolucionController.text.trim(),
                          hashEvidencia: item?.hashEvidencia ?? 'sha256_${DateTime.now().millisecondsSinceEpoch}',
                        );

                        if (isEditing) {
                          widget.dataService.updateCuarentena(nuevo);
                        } else {
                          widget.dataService.addCuarentena(nuevo);
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

  void _confirmDelete(BuildContext context, RegistroCuarentena item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Purgar registro de cuarentena?'),
        content: Text('Se desincorporará la anomalía #${item.idRegistroOriginal}.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Purgar'),
            onPressed: () {
              widget.dataService.deleteCuarentena(item.idRegistroOriginal);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
