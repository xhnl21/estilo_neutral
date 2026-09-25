import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';
import '../cubits/audit_log/audit_log_cubit.dart';
import '../cubits/audit_log/audit_log_state.dart';

/// Vista de Registro de Auditoría Forense (hoja: audit_log)
/// Cumplimiento estricto ISO/IEC 27001 §8.13, COBIT 2019 e inmutabilidad.
class AuditLogPage extends StatelessWidget {
  final SheetsDataService dataService;

  const AuditLogPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuditLogCubit(dataService: dataService),
      child: _AuditLogView(dataService: dataService),
    );
  }
}

class _AuditLogView extends StatefulWidget {
  final SheetsDataService dataService;

  const _AuditLogView({required this.dataService});

  @override
  State<_AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<_AuditLogView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuditLogCubit, AuditLogState>(
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
        final cubit = context.read<AuditLogCubit>();
        final logs = state.filteredLogs;
        final hojas = ['Todas', 'global', 'clientes', 'inventario', 'ventas', 'compras_divisas', 'resumen_diario', 'cuarentena'];

        return AppScaffold(
          title: 'Bitácora de Auditoría',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'audit_log',
            userFriendlyText: '${state.logs.length} eventos inmutables',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.status == AuditLogStatus.loading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_audit_log',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.shield_fill, size: 20),
            label: const Text('Nuevo Checkpoint', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showAuditDialog(context),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: (state.status == AuditLogStatus.loading && state.logs.isEmpty)
                ? const AuditLogSkeleton(key: ValueKey('audit_log_skeleton'))
                : Column(
                    key: const ValueKey('audit_log_content'),
                    children: [
                      // Selector de hoja
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  children: hojas.map((h) {
                    final isSel = state.selectedHoja == h;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(h),
                        selected: isSel,
                        selectedColor: AppPalette.blue100,
                        labelStyle: TextStyle(
                          color: isSel ? AppPalette.blue900 : AppPalette.textSecondary,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        ),
                        onSelected: (val) {
                          if (val) cubit.selectHoja(h);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Lista de eventos
              Expanded(
                child: logs.isEmpty
                    ? const AppEmptyState(
                        title: 'No hay eventos de auditoría para esta hoja',
                        description: 'Todos los cambios y mutaciones se registrarán automáticamente.',
                        icon: CupertinoIcons.shield,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];

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
                                          '${log.hoja}!${log.celda} • ${log.accion}',
                                          style: AppTypography.titleLarge.copyWith(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      AppChip(
                                        label: log.normaAplicada,
                                        variant: AppChipVariant.info,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Usuario: ${log.usuario} • ${log.timestampIso8601.toIso8601String().split('T').first}',
                                    style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppPalette.divider),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Antes: ${log.valorAnterior}',
                                          style: AppTypography.labelSmall.copyWith(color: AppPalette.error, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ahora: ${log.valorNuevo}',
                                          style: AppTypography.labelSmall.copyWith(color: AppPalette.success, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Obs: ${log.observaciones}',
                                    style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.pencil, size: 16, color: AppPalette.blue700),
                                        tooltip: 'Editar Observaciones',
                                        onPressed: () => _showEditObservacionesDialog(context, index, log),
                                      ),
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.trash, size: 16, color: AppPalette.error),
                                        tooltip: 'Revocar Entrada',
                                        onPressed: () => _confirmDelete(context, index),
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
        ),
      );
      },
    );
  }

  void _showAuditDialog(BuildContext context) {
    final hojaController = TextEditingController(text: 'global');
    final celdaController = TextEditingController(text: 'A1');
    final valorAnteriorController = TextEditingController(text: 'Manual');
    final valorNuevoController = TextEditingController(text: 'Verificado');
    final accionController = TextEditingController(text: 'checkpoint_manual');
    final normaController = TextEditingController(text: 'ISO/IEC 27001 §8.13');
    final observacionesController = TextEditingController(text: 'Inspección de integridad por auditor');

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
                  Text('Nuevo Checkpoint de Auditoría', style: AppTypography.titleLarge.copyWith(fontSize: 17)),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppPalette.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: AppTextField(label: 'Hoja', controller: hojaController)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: AppTextField(label: 'Celda / Rango', controller: celdaController)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Acción Ejecutada', controller: accionController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Valor Anterior', controller: valorAnteriorController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Valor Nuevo', controller: valorNuevoController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Norma Aplicada', controller: normaController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Observaciones Forenses', controller: observacionesController),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: AppOutlinedButton(label: 'Cancelar', onPressed: () => Navigator.pop(ctx))),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Registrar',
                      icon: CupertinoIcons.shield_fill,
                      onPressed: () {
                        final log = AuditLog(
                          timestampIso8601: DateTime.now(),
                          usuario: 'Auditor Manual',
                          hoja: hojaController.text.trim(),
                          celda: celdaController.text.trim(),
                          valorAnterior: valorAnteriorController.text.trim(),
                          valorNuevo: valorNuevoController.text.trim(),
                          accion: accionController.text.trim(),
                          normaAplicada: normaController.text.trim(),
                          observaciones: observacionesController.text.trim(),
                        );
                        widget.dataService.addAuditLogManual(log);
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

  void _showEditObservacionesDialog(BuildContext context, int index, AuditLog log) {
    final controller = TextEditingController(text: log.observaciones);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Observación Forense'),
        content: AppTextField(
          label: 'Observaciones',
          controller: controller,
        ),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            child: const Text('Guardar'),
            onPressed: () {
              widget.dataService.updateAuditLog(index, controller.text.trim());
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Revocar entrada de auditoría?'),
        content: const Text('Esta acción eliminará el registro de la bitácora activa.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Revocar'),
            onPressed: () {
              widget.dataService.deleteAuditLog(index);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
