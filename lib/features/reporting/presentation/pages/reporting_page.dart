import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/design_system/tokens/icons.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_money_text.dart';
import '../../../../core/design_system/widgets/app_refresh_button.dart';
import '../../../../core/design_system/widgets/app_scaffold.dart';

/// Vista de Reportes y Resumen Diario (Read-Only).
/// Gráficos minimalistas construidos con CustomPaint nativo (cero dependencias pesadas).
class ReportingPage extends StatefulWidget {
  const ReportingPage({super.key});

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage> {
  bool _isLoading = false;

  void _refreshData() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reportes',
      actions: [
        AppRefreshButton(
          isRefreshing: _isLoading,
          onRefresh: _refreshData,
        ),
      ],
      body: RefreshIndicator(
        color: AppPalette.blue700,
        backgroundColor: AppPalette.surface,
        onRefresh: () async => _refreshData(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Card Destacada: Resumen del Día
            AppCard(
              padding: AppSpacing.pLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RESUMEN DIARIO CONSOLIDADO',
                        style: AppTypography.labelSmall.copyWith(letterSpacing: 0.5),
                      ),
                      const Icon(AppIcons.summary, size: 18, color: AppPalette.blue700),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricCol('Ventas Totales', 20.00, MoneyNature.neutral),
                      _buildMetricCol('Abonos Recibidos', 20.00, MoneyNature.credit),
                      _buildMetricCol('Deuda Vigente', 0.00, MoneyNature.neutral),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Gráfico Sintético de Rendimiento (CustomPaint minimalista)
            Text(
              'Tendencia Semanal de Facturación',
              style: AppTypography.titleLarge.copyWith(
                fontSize: 16,
                color: AppPalette.blue900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: AppSpacing.pLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribución de Ingresos (USD)',
                    style: AppTypography.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MinimalBarChartPainter(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                        .map(
                          (day) => Text(
                            day,
                            style: AppTypography.labelSmall.copyWith(fontSize: 11),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, double val, MoneyNature nature) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall),
        const SizedBox(height: 2),
        AppMoneyText(
          amount: val,
          currency: MoneyCurrency.usd,
          nature: nature,
          fontSize: 16,
        ),
      ],
    );
  }
}

/// Gráfico de barras minimalista con paleta oficial de Estilo Neutral
class _MinimalBarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = AppPalette.blue700
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = AppPalette.blue100
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppPalette.divider
      ..strokeWidth = 1;

    // Líneas guía base
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      linePaint,
    );

    const values = [0.4, 0.65, 0.3, 0.85, 0.5, 0.95, 0.2];
    final slotWidth = size.width / values.length;
    const barWidth = 16.0;

    for (int i = 0; i < values.length; i++) {
      final x = (i * slotWidth) + (slotWidth - barWidth) / 2;
      final barHeight = size.height * values[i];
      final y = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );

      // Resaltar barra de mayor rendimiento con blue700, resto con blue100
      canvas.drawRRect(rect, values[i] > 0.8 ? barPaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
