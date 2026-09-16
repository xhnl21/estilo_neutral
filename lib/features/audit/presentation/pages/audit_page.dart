import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';

/// Vista de Auditoría y Trazabilidad (Read-Only).
/// Visualización estricta sin mutación de registros ISO 8000 / 27001.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  void _refreshAudit() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Auditoría',
      actions: [
        AppRefreshButton(
          isRefreshing: _isLoading,
          onRefresh: _refreshAudit,
        ),
      ],
      body: Column(
        children: [
          // Selector Segmentado de Secciones (CupertinoSlidingSegmentedControl)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedTabIndex,
                backgroundColor: AppPalette.blue100.withValues(alpha: 0.5),
                thumbColor: AppPalette.surface,
                onValueChanged: (val) {
                  if (val != null) setState(() => _selectedTabIndex = val);
                },
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Audit Log', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Cuarentena', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Checklist ISO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                },
              ),
            ),
          ),
          const Divider(),

          // Contenido de la pestaña
          Expanded(
            child: RefreshIndicator(
              color: AppPalette.blue700,
              backgroundColor: AppPalette.surface,
              onRefresh: () async => _refreshAudit(),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? switch (_selectedTabIndex) {
              0 => const AuditLogSkeleton(key: ValueKey('audit_tab_skeleton')),
              1 => const CuarentenaSkeleton(key: ValueKey('cuarentena_tab_skeleton')),
              2 => const ChecklistIsoSkeleton(key: ValueKey('checklist_tab_skeleton')),
              _ => const SizedBox.shrink(),
            }
          : switch (_selectedTabIndex) {
              0 => KeyedSubtree(
                  key: const ValueKey('audit_tab_content'),
                  child: _buildAuditLogList(),
                ),
              1 => KeyedSubtree(
                  key: const ValueKey('cuarentena_tab_content'),
                  child: _buildQuarantineList(),
                ),
              2 => KeyedSubtree(
                  key: const ValueKey('checklist_tab_content'),
                  child: _buildChecklistIso(),
                ),
              _ => const SizedBox.shrink(),
            },
    );
  }

  Widget _buildAuditLogList() {
    final sampleLogs = [
      (
        id: 40,
        ts: '2026-09-14T10:15:45',
        tipo: 'FASE_12_DESIGN',
        usuario: 'SISTEMA',
        accion: 'inicio_sistema_diseno_visual',
        val: 'OK'
      ),
      (
        id: 39,
        ts: '2026-09-14T09:28:40',
        tipo: 'FASE_11_DDD',
        usuario: 'SISTEMA',
        accion: 'reporte_migracion_actualizado',
        val: 'OK'
      ),
      (
        id: 38,
        ts: '2026-09-14T09:28:30',
        tipo: 'FASE_11_DDD',
        usuario: 'SISTEMA',
        accion: 'hash_final_certificado',
        val: 'OK'
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: sampleLogs.length,
      itemBuilder: (context, index) {
        final log = sampleLogs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: AppSpacing.pMd,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(AppIcons.audit, size: 18, color: AppPalette.blue700),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${log.id} • ${log.accion}',
                              style: AppTypography.titleLarge.copyWith(
                                fontSize: 14,
                                color: AppPalette.blue900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const AppChip(
                            label: 'OK',
                            variant: AppChipVariant.success,
                            icon: AppIcons.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tipo: ${log.tipo} | Resp: ${log.usuario}',
                        style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                      ),
                      Text(
                        log.ts,
                        style: AppTypography.labelSmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuarantineList() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          padding: AppSpacing.pLg,
          child: Row(
            children: [
              const Icon(AppIcons.quarantine, size: 24, color: AppPalette.success),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bandeja de Cuarentena Limpia',
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 15,
                        color: AppPalette.blue900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '0 anomalías registradas en validaciones contables.',
                      style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistIso() {
    final standards = [
      ('ISO 8000', 'Calidad de Datos e Inmutabilidad', true),
      ('ISO/IEC 25010', 'Adecuación Funcional y Rendimiento', true),
      ('ISO/IEC 27001', 'Seguridad de Información y Tokens', true),
      ('WCAG 2.2 AA', 'Contraste, Tap Targets y Semántica', true),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: standards.length,
      itemBuilder: (context, index) {
        final (code, desc, compliant) = standards[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: AppSpacing.pMd,
            child: Row(
              children: [
                const Icon(AppIcons.checklist, size: 20, color: AppPalette.blue700),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 14,
                          color: AppPalette.blue900,
                        ),
                      ),
                      Text(desc, style: AppTypography.bodyMedium.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                AppChip(
                  label: compliant ? 'Conforme' : 'Pendiente',
                  variant: compliant ? AppChipVariant.success : AppChipVariant.warning,
                  icon: AppIcons.success,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
