import '../../domain/repositories/client_credit_repository.dart';
import '../../domain/services/credit_applier.dart';
import '../../domain/value_objects/apply_credit_plan.dart';

/// Caso de Uso: Aplicar saldo a favor de un cliente a una factura pendiente (Transacción Atómica All-or-Nothing).
class ApplyClientCredit {
  final ClientCreditRepository repository;
  final CreditApplier applier;

  ApplyClientCredit({
    required this.repository,
    CreditApplier? applier,
  }) : applier = applier ?? CreditApplier();

  Future<ApplyCreditResult> execute({
    required String clienteId,
    required String targetVentaId,
    required double deudaVenta,
    required String userEmail,
  }) async {
    final available = await repository.getAvailableCredits(clienteId);
    final totalAvailable = available.fold<double>(0.0, (acc, c) => acc + c.saldoUsd);

    final applicable = applier.calculateApplicableAmount(
      totalCreditoDisponible: totalAvailable,
      deudaVenta: deudaVenta,
    );

    if (applicable <= 0.0) {
      return ApplyCreditResult.failure('No hay saldo a favor aplicable o la venta no tiene deuda.');
    }

    final success = await repository.applyCreditTransaction(
      clienteId: clienteId,
      targetVentaId: targetVentaId,
      amountToApply: applicable,
      userEmail: userEmail,
    );

    if (!success) {
      return ApplyCreditResult.failure('Error en la transacción atómica al aplicar el saldo a favor.');
    }

    final remainingCredit = (totalAvailable - applicable).clamp(0.0, double.infinity);
    final remainingDebt = (deudaVenta - applicable).clamp(0.0, double.infinity);

    return ApplyCreditResult.success(
      montoAplicado: applicable,
      saldoRestante: double.parse(remainingCredit.toStringAsFixed(2)),
      deudaRestante: double.parse(remainingDebt.toStringAsFixed(2)),
    );
  }

  /// Método de compatibilidad booleano
  Future<bool> call({
    required String clienteId,
    required String targetVentaId,
    required double amountToApply,
    required String userEmail,
  }) async {
    if (amountToApply <= 0.0) return false;

    return repository.applyCreditTransaction(
      clienteId: clienteId,
      targetVentaId: targetVentaId,
      amountToApply: amountToApply,
      userEmail: userEmail,
    );
  }
}
