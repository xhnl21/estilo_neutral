import 'dart:math';
import '../../domain/repositories/client_credit_repository.dart';
import '../../domain/services/credit_applier.dart';
import '../../domain/value_objects/apply_credit_plan.dart';

/// Caso de Uso: Previsualizar la aplicación de créditos sin persistir cambios (Frase 3).
class PreviewApplyCredit {
  final ClientCreditRepository repository;
  final CreditApplier applier;

  PreviewApplyCredit({
    required this.repository,
    CreditApplier? applier,
  }) : applier = applier ?? CreditApplier();

  Future<ApplyCreditPreview> call({
    required String clienteId,
    required String ventaDestinoId,
    required double deudaVenta,
  }) async {
    final available = await repository.getAvailableCredits(clienteId);
    final totalAvailable = available.fold<double>(0.0, (acc, c) => acc + c.saldoUsd);

    final applicable = applier.calculateApplicableAmount(
      totalCreditoDisponible: totalAvailable,
      deudaVenta: deudaVenta,
    );

    final plan = applier.planFifoApplication(
      availableCredits: available,
      debtToCover: deudaVenta,
      targetVentaId: ventaDestinoId,
      applicationDate: DateTime.now(),
      nextCreditIdForSplit: 'cr99999999', // temporal para simulación
    );

    final remainingCredit = max(0.0, totalAvailable - applicable);
    final remainingDebt = max(0.0, deudaVenta - applicable);

    final warnings = <String>[];
    if (totalAvailable > deudaVenta) {
      warnings.add(
        'Quedarán \$${remainingCredit.toStringAsFixed(2)} disponibles para futuras facturas.',
      );
    }

    return ApplyCreditPreview(
      montoAplicable: applicable,
      saldoRestante: double.parse(remainingCredit.toStringAsFixed(2)),
      deudaRestante: double.parse(remainingDebt.toStringAsFixed(2)),
      creditosConsumidos: plan.consumedCredits,
      advertencias: warnings,
    );
  }
}
