import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/design_system/design_system.dart';
import '../cubit/apply_credit_cubit.dart';
import '../cubit/apply_credit_state.dart';
import '../widgets/credit_summary_row.dart';

/// Bottom sheet modal para confirmar la compensación de créditos (narrativa de negocio).
class ApplyCreditSheet extends StatelessWidget {
  final String clienteId;
  final String clienteNombre;
  final String ventaId;
  final double deudaVenta;
  final double totalCreditoDisponible;
  final String? origenVentaId;
  final String userEmail;

  const ApplyCreditSheet({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
    required this.ventaId,
    required this.deudaVenta,
    required this.totalCreditoDisponible,
    this.origenVentaId,
    required this.userEmail,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ApplyCreditCubit cubit,
    required String clienteId,
    required String clienteNombre,
    required String ventaId,
    required double deudaVenta,
    required double totalCreditoDisponible,
    String? origenVentaId,
    required String userEmail,
  }) {
    cubit.loadPreview(
      clienteId: clienteId,
      ventaDestinoId: ventaId,
      deudaVenta: deudaVenta,
    );

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ApplyCreditSheet(
          clienteId: clienteId,
          clienteNombre: clienteNombre,
          ventaId: ventaId,
          deudaVenta: deudaVenta,
          totalCreditoDisponible: totalCreditoDisponible,
          origenVentaId: origenVentaId,
          userEmail: userEmail,
        ),
      ),
    ).whenComplete(() => cubit.close());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ApplyCreditCubit, ApplyCreditState>(
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.successMessage ?? 'Saldo aplicado. Factura #$ventaId marcada como Pagada.',
              ),
              backgroundColor: AppPalette.success,
            ),
          );
        } else if (state.isFailure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppPalette.error,
              action: SnackBarAction(
                label: 'Reintentar',
                textColor: Colors.white,
                onPressed: () => context.read<ApplyCreditCubit>().applyCredit(
                      clienteId: clienteId,
                      ventaDestinoId: ventaId,
                      deudaVenta: deudaVenta,
                      userEmail: userEmail,
                    ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final preview = state.preview;
        final montoAplicar = preview?.montoAplicable ??
            (totalCreditoDisponible < deudaVenta ? totalCreditoDisponible : deudaVenta);
        final saldoRestante = preview?.saldoRestante ?? (totalCreditoDisponible - montoAplicar);
        final deudaRestante = preview?.deudaRestante ?? (deudaVenta - montoAplicar);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera con botón de cierre
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aplicar saldo a favor',
                      style: AppTypography.titleLarge.copyWith(color: AppPalette.blue700),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Frase 2: Cliente
                Row(
                  children: [
                    const Icon(CupertinoIcons.pin_fill, size: 16, color: AppPalette.blue700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cliente: $clienteNombre',
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Frase 3: Montos de compensación
                CreditSummaryRow(
                  label: 'Saldo a favor disponible',
                  amount: totalCreditoDisponible,
                  color: AppPalette.success,
                ),
                CreditSummaryRow(
                  label: 'Deuda de la factura #$ventaId',
                  amount: deudaVenta,
                  color: AppPalette.error,
                ),
                const Divider(height: 18),
                CreditSummaryRow(
                  label: 'Se aplicará',
                  amount: montoAplicar,
                  color: AppPalette.blue700,
                  isBold: true,
                ),
                CreditSummaryRow(
                  label: 'Saldo restante después',
                  amount: saldoRestante,
                ),
                CreditSummaryRow(
                  label: 'Deuda restante después',
                  amount: deudaRestante,
                ),
                const SizedBox(height: 14),

                // Cuadro informativo de compensación
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.blue100.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppPalette.blue100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(CupertinoIcons.info_circle_fill, size: 18, color: AppPalette.blue700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          origenVentaId != null && origenVentaId!.isNotEmpty
                              ? 'No entra dinero nuevo. Se reutiliza el pago que ya hiciste en la factura #$origenVentaId.'
                              : 'No entra dinero nuevo. Se reutiliza un pago excedente previo del cliente.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppPalette.blue700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (preview?.advertencias.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview!.advertencias.first,
                    style: AppTypography.labelSmall.copyWith(color: AppPalette.blue700),
                  ),
                ],
                const SizedBox(height: 20),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppPalette.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: state.isLoading || montoAplicar <= 0
                              ? null
                              : () => context.read<ApplyCreditCubit>().applyCredit(
                                    clienteId: clienteId,
                                    ventaDestinoId: ventaId,
                                    deudaVenta: deudaVenta,
                                    userEmail: userEmail,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.blue700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: state.isLoading
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : const Text('Confirmar aplicación', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
