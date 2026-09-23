import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../models/models.dart';
import '../../shared/shared.dart';

/// Vista de Tasas (hoja: "tasas")
/// Historial de tasas — una fila por moneda/fecha/fuente (ver
/// [TasaRegistro]). Las filas fuente='bcv' las alimenta el módulo Tasas en
/// Apps Script (función obtenerTasaBCV, con trigger diario); las
/// fuente='manual' las fija cada organización desde Organizaciones. Esta
/// vista además puede pedirle al servidor que corra obtenerTasaBCV ahora
/// mismo (botón "Actualizar tasa").
class TasasPage extends StatefulWidget {
  final SheetsDataService dataService;

  const TasasPage({super.key, required this.dataService});

  @override
  State<TasasPage> createState() => _TasasPageState();
}

class _TasasPageState extends State<TasasPage> {
  bool _actualizando = false;

  Future<void> _obtenerTasaDeHoy() async {
    setState(() => _actualizando = true);
    final ok = await widget.dataService.refrescarTasaHoy();
    if (!mounted) return;
    setState(() => _actualizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Tasa de hoy obtenida correctamente.'
              : 'No se pudo obtener la tasa de hoy. Probá de nuevo en un momento.',
        ),
        backgroundColor: ok ? null : AppPalette.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final tasas = widget.dataService.tasas.toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
        final usdVigente = widget.dataService.tasaBcvVigente('USD');
        final eurVigente = widget.dataService.tasaBcvVigente('EUR');
        final orgId = widget.dataService.currentOrganizacionId ?? '';
        final monedaActual = widget.dataService.monedaOrganizacion(orgId);

        return AppScaffold(
          title: 'Tasas',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'tasas',
            userFriendlyText: '${tasas.length} registro${tasas.length == 1 ? '' : 's'}',
          ),
          actions: [
            AppRefreshButton(
              onRefresh: () => widget.dataService.fetchAllSheets(),
              isLoading: widget.dataService.isLoading,
            ),
          ],
          body: tasas.isEmpty
              ? AppEmptyState(
                  title: 'Todavía no hay tasas registradas',
                  description:
                      'Usá el botón "Actualizar tasa" para traer la '
                      'primera, o esperá al trigger diario del módulo Tasas '
                      'en Apps Script.',
                  icon: CupertinoIcons.money_dollar,
                  actionLabel: _actualizando ? 'Obteniendo...' : 'Obtener tasa',
                  onAction: _actualizando ? null : _obtenerTasaDeHoy,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
                  children: [
                    MonedaSelector(
                      label: 'MONEDA BASE DEL SISTEMA',
                      value: monedaActual,
                      onChanged: orgId.isEmpty
                          ? null
                          : (val) => widget.dataService.setMonedaOrganizacion(orgId, val),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (usdVigente != null)
                      _TasaVigenteCard(
                        tasa: usdVigente,
                        cambioPct: widget.dataService.cambioPctTasa(usdVigente),
                        eurVigente: eurVigente,
                        cambioPctEur: eurVigente != null ? widget.dataService.cambioPctTasa(eurVigente) : 0.0,
                        lastSync: widget.dataService.lastSync,
                        actualizando: _actualizando,
                        onActualizar: _obtenerTasaDeHoy,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Historial', style: AppTypography.titleLarge.copyWith(fontSize: 16)),
                    const SizedBox(height: AppSpacing.sm),
                    ...tasas.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            padding: AppSpacing.pMd,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${t.moneda} • ${t.fecha.toIso8601String().split('T').first}',
                                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                          if (t.fuente == 'manual') ...[
                                            const SizedBox(width: 6),
                                            AppChip(
                                              label: 'Manual · ${widget.dataService.organizaciones.where((o) => o.id == t.organizacionId).firstOrNull?.nombre ?? t.organizacionId}',
                                              variant: AppChipVariant.info,
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        'Valor: ${t.valor.toStringAsFixed(4)} Bs.',
                                        style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (t.fuente == 'bcv') _CambioPctChip(pct: widget.dataService.cambioPctTasa(t)),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
        );
      },
    );
  }
}

/// Tarjeta destacada con la tasa BCV vigente — fondo oscuro (paleta propia,
/// azul900) con el botón de refresco embebido, siguiendo el modelo de
/// tarjeta "fuente de tasa" que pidió el usuario.
class _TasaVigenteCard extends StatelessWidget {
  final TasaRegistro tasa;
  final double cambioPct;
  final TasaRegistro? eurVigente;
  final double cambioPctEur;
  final DateTime? lastSync;
  final bool actualizando;
  final VoidCallback onActualizar;

  const _TasaVigenteCard({
    required this.tasa,
    required this.cambioPct,
    required this.eurVigente,
    required this.cambioPctEur,
    required this.lastSync,
    required this.actualizando,
    required this.onActualizar,
  });

  String _haceCuanto(DateTime desde) {
    final diff = DateTime.now().difference(desde);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} minuto${diff.inMinutes == 1 ? '' : 's'}';
    if (diff.inHours < 24) return 'hace ${diff.inHours} hora${diff.inHours == 1 ? '' : 's'}';
    return 'hace ${diff.inDays} día${diff.inDays == 1 ? '' : 's'}';
  }

  String _horaFormateada(DateTime fecha) {
    final hora12 = fecha.hour % 12 == 0 ? 12 : fecha.hour % 12;
    final minuto = fecha.minute.toString().padLeft(2, '0');
    final ampm = fecha.hour < 12 ? 'AM' : 'PM';
    return '$hora12:$minuto $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.pMd,
      decoration: BoxDecoration(
        color: AppPalette.blue900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FUENTE DE TASA',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppPalette.blue100,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BCV (Oficial)',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.check_mark_circled_solid, color: AppPalette.success, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
              _ActualizarTasaButton(actualizando: actualizando, onPressed: onActualizar),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '1 USD = ', style: AppTypography.displayLarge.copyWith(color: Colors.white, fontSize: 24)),
                TextSpan(
                  text: '${tasa.valor.toStringAsFixed(2)} Bs.',
                  style: AppTypography.displayLarge.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          if (eurVigente != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '1 EUR = ${eurVigente!.valor.toStringAsFixed(2)} Bs.',
                style: AppTypography.bodyMedium.copyWith(color: AppPalette.blue100),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(CupertinoIcons.clock, color: AppPalette.blue100, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  lastSync != null
                      ? 'Actualizado ${_haceCuanto(lastSync!)} (${_horaFormateada(lastSync!)})'
                      : 'Fecha del dato: ${tasa.fecha.toIso8601String().split('T').first}',
                  style: AppTypography.labelSmall.copyWith(color: AppPalette.blue100),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _CambioPctChip(pct: cambioPct, label: 'USD'),
              if (eurVigente != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _CambioPctChip(pct: cambioPctEur, label: 'EUR'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActualizarTasaButton extends StatelessWidget {
  final bool actualizando;
  final VoidCallback onPressed;

  const _ActualizarTasaButton({required this.actualizando, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.blue100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: actualizando ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (actualizando)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppPalette.blue900),
                )
              else
                const Icon(CupertinoIcons.arrow_2_circlepath, size: 14, color: AppPalette.blue900),
              const SizedBox(width: 6),
              Text(
                actualizando ? 'Actualizando...' : 'Actualizar tasa',
                style: AppTypography.labelSmall.copyWith(
                  color: AppPalette.blue900,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CambioPctChip extends StatelessWidget {
  final double pct;
  final String? label;

  const _CambioPctChip({required this.pct, this.label});

  @override
  Widget build(BuildContext context) {
    final subiendo = pct > 0;
    final estable = pct == 0;
    return AppChip(
      label: '${label != null ? '$label ' : ''}${subiendo ? '+' : ''}${pct.toStringAsFixed(2)}%',
      variant: estable ? AppChipVariant.info : (subiendo ? AppChipVariant.warning : AppChipVariant.success),
      icon: estable ? null : (subiendo ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_right),
    );
  }
}
