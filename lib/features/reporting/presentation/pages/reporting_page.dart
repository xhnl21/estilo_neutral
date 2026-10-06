import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/environment_config.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../models/models.dart';
import '../../../../shared/shared.dart';
import '../cubit/reporting_cubit.dart';
import '../cubit/reporting_state.dart';

/// Vista de Reportes y Resumen Diario (hoja: resumen_diario)
/// Implementada con arquitectura BLoC/Cubit estricta (ReportingCubit / ReportingState).
class ReportingPage extends StatelessWidget {
  final SheetsDataService dataService;

  const ReportingPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportingCubit(dataService: dataService),
      child: const _ReportingView(),
    );
  }
}

class _ReportingView extends StatelessWidget {
  const _ReportingView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportingCubit, ReportingState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppPalette.error,
            ),
          );
        } else if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: AppPalette.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<ReportingCubit>();
        final resumenes = state.resumenesDiarios;
        final totalVentasUsd = state.totalVentasUsd;
        final totalBs = state.totalBs;

        return AppScaffold(
          title: 'Resumen Diario',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'resumen_diario',
            userFriendlyText: '${resumenes.length} cierres contables',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => cubit.refresh(),
              isLoading: state.isLoading,
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_resumen_diario',
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            icon: const Icon(CupertinoIcons.calendar_badge_plus, size: 20),
            label: const Text('Nuevo Cierre', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _showCierreDialog(context),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: state.isLoading && resumenes.isEmpty
                ? const ReportingSkeleton(key: ValueKey('reporting_skeleton'))
                : ListView(
                    key: const ValueKey('reporting_content'),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                    children: [
                      // Card Destacada: Resumen General Consolidado
                      AppCard(
                        padding: AppSpacing.pLg,
                        mergeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('CONSOLIDADO GENERAL DE CIERRES',
                                    style: AppTypography.labelSmall.copyWith(letterSpacing: 0.5)),
                                const ExcludeSemantics(
                                  child: Icon(AppIcons.summary, size: 18, color: AppPalette.blue700),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricCol('Ventas Acumuladas', totalVentasUsd, MoneyCurrency.usd),
                                _buildMetricCol('Monto en Bolívares', totalBs, MoneyCurrency.bs),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Semantics(
                        header: true,
                        headingLevel: 2,
                        child: Text('Histórico de Cierres Diarios',
                            style: AppTypography.titleLarge.copyWith(fontSize: 16)),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      if (resumenes.isEmpty)
                        const AppEmptyState(
                          title: 'No hay cierres diarios registrados',
                          description: 'Registra el primer cierre con "Nuevo Cierre".',
                          icon: CupertinoIcons.doc_chart,
                        )
                      else
                        ...resumenes.map((r) {
                          final fechaStr = r.fecha.toIso8601String().split('T').first;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: AppSpacing.pMd,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: AppSpacing.sm,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Fecha: $fechaStr',
                                        style: AppTypography.titleLarge.copyWith(fontSize: 15),
                                      ),
                                      AppMoneyText(
                                        amount: r.totalUsd,
                                        currency: MoneyCurrency.usd,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nro. Ventas: ${r.nroVentas} • Total Bs: ${r.totalBs.toStringAsFixed(2)} Bs.',
                                    style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                                  ),
                                  Text(
                                    'Tasa BCV: ${r.tasaBcv} • Paralelo: ${r.tasaUsd} • Comprados: USD ${r.usdComprados} • Vendidos: USD ${r.usdVendidos}',
                                    style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(CupertinoIcons.pencil, size: 18, color: AppPalette.blue700),
                                        tooltip: 'Editar Cierre',
                                        onPressed: () => _showCierreDialog(context, resumen: r),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(CupertinoIcons.trash, size: 18, color: AppPalette.error),
                                        tooltip: 'Eliminar Cierre',
                                        onPressed: () => _confirmDelete(context, r),
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

  Widget _buildMetricCol(String label, double amount, MoneyCurrency currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall),
        const SizedBox(height: 2),
        AppMoneyText(
          amount: amount,
          currency: currency,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }

  void _showCierreDialog(BuildContext context, {ResumenDiario? resumen}) {
    final cubit = context.read<ReportingCubit>();
    final isEditing = resumen != null;
    final fechaStr = resumen != null
        ? resumen.fecha.toIso8601String().split('T').first
        : DateTime.now().toIso8601String().split('T').first;
    final fechaController = TextEditingController(text: fechaStr);
    // Un cierre nuevo no trae montos de ejemplo: se podrían guardar por error.
    final nroVentasController = TextEditingController(text: resumen?.nroVentas.toString() ?? '');
    final totalUsdController = TextEditingController(text: resumen?.totalUsd.toStringAsFixed(2) ?? '');
    final totalBsController = TextEditingController(text: resumen?.totalBs.toStringAsFixed(2) ?? '');
    final tasaBcvController = TextEditingController(
        text: resumen?.tasaBcv.toStringAsFixed(2) ?? cubit.tasaBcvVigente?.toStringAsFixed(2) ?? '');
    final tasaUsdController = TextEditingController(text: resumen?.tasaUsd.toStringAsFixed(2) ?? '');
    final compradosController = TextEditingController(text: resumen?.usdComprados.toStringAsFixed(2) ?? '');
    final vendidosController = TextEditingController(text: resumen?.usdVendidos.toStringAsFixed(2) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => LiberarControladores(
        controladores: [
          fechaController,
          nroVentasController,
          totalUsdController,
          totalBsController,
          tasaBcvController,
          tasaUsdController,
          compradosController,
          vendidosController
        ],
        child: Padding(
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
                        isEditing ? 'Editar Cierre Diario ($fechaStr)' : 'Nuevo Cierre Diario',
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
                const SizedBox(height: AppSpacing.md),
                // La fecha (con la organización) identifica al cierre: al
                // editar no se puede cambiar, o se pisaría el cierre de otro día.
                AppTextField(
                  label: 'Fecha (AAAA-MM-DD)',
                  controller: fechaController,
                  readOnly: isEditing,
                  hint: '2026-10-06',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Nro. Ventas',
                        controller: nroVentasController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Total USD',
                        controller: totalUsdController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Total en Bolívares (Bs.)',
                  controller: totalBsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Tasa BCV',
                        controller: tasaBcvController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Tasa USD',
                        controller: tasaUsdController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'USD Comprados',
                        controller: compradosController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'USD Vendidos',
                        controller: vendidosController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
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
                        label: isEditing ? 'Guardar Cambios' : 'Registrar Cierre',
                        icon: CupertinoIcons.check_mark,
                        onPressed: () {
                          final cierre = ReportingCubit.construirCierre(
                            fecha: fechaController.text,
                            nroVentas: nroVentasController.text,
                            totalBs: totalBsController.text,
                            totalUsd: totalUsdController.text,
                            tasaBcv: tasaBcvController.text,
                            tasaUsd: tasaUsdController.text,
                            usdComprados: compradosController.text,
                            usdVendidos: vendidosController.text,
                          );
                          // Al editar se conserva el ID del cierre original.
                          final r = isEditing ? cierre.resumen?.copyWith(id: resumen.id) : cierre.resumen;
                          if (r == null) {
                            showDialog(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Revisá los datos'),
                                content: Text(cierre.error!),
                                actions: [
                                  TextButton(
                                    child: const Text('Entendido'),
                                    onPressed: () => Navigator.pop(dCtx),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          if (isEditing) {
                            cubit.updateResumen(r);
                          } else {
                            cubit.addResumen(r);
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

  void _confirmDelete(BuildContext context, ResumenDiario r) {
    final cubit = context.read<ReportingCubit>();
    final fechaStr = r.fecha.toIso8601String().split('T').first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar cierre diario?'),
        content: Text('Se eliminará el balance del día $fechaStr por USD ${r.totalUsd}.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            child: const Text('Eliminar'),
            onPressed: () {
              cubit.deleteResumen(r.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
