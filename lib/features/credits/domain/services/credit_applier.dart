import 'dart:math';
import '../entities/client_credit.dart';
import '../entities/credit_status.dart';
import '../value_objects/apply_credit_plan.dart';
import '../value_objects/credit_amount.dart';
import '../value_objects/credit_id.dart';

/// Servicio puro de dominio para cálculo de aplicación de créditos a facturas pendientes.
class CreditApplier {
  /// Calcula el monto máximo aplicable entre el saldo a favor disponible y la deuda.
  double calculateApplicableAmount({
    required double totalCreditoDisponible,
    required double deudaVenta,
  }) {
    if (totalCreditoDisponible <= 0.0 || deudaVenta <= 0.0) return 0.0;
    return double.parse(min(totalCreditoDisponible, deudaVenta).toStringAsFixed(2));
  }

  /// Calcula el plan de aplicación FIFO según la especificación del dominio.
  ApplyCreditPlan compute({
    required List<ClientCredit> availableCredits,
    required double deudaUsd,
    required String targetVentaId,
    required DateTime applicationDate,
    required String nextCreditIdForSplit,
  }) {
    return planFifoApplication(
      availableCredits: availableCredits,
      debtToCover: deudaUsd,
      targetVentaId: targetVentaId,
      applicationDate: applicationDate,
      nextCreditIdForSplit: nextCreditIdForSplit,
    );
  }

  /// Aplica los créditos disponibles bajo estrategia FIFO (por fecha más antigua primero).
  ApplyCreditPlan planFifoApplication({
    required List<ClientCredit> availableCredits,
    required double debtToCover,
    required String targetVentaId,
    required DateTime applicationDate,
    required String nextCreditIdForSplit,
  }) {
    var pendingDebt = double.parse(max(0.0, debtToCover).toStringAsFixed(2));
    var totalApplied = 0.0;
    final consumed = <ClientCredit>[];
    ClientCredit? splitCredit;

    // Ordenar FIFO por fecha ascendente
    final sorted = List<ClientCredit>.from(availableCredits.where((c) => c.isAvailable))
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    for (final credit in sorted) {
      if (pendingDebt <= 0.009) break;

      final availableOnThisCredit = credit.saldoUsd;

      if (availableOnThisCredit <= pendingDebt) {
        // Se consume por completo este crédito
        totalApplied += availableOnThisCredit;
        pendingDebt -= availableOnThisCredit;
        consumed.add(credit.copyWith(
          estado: CreditStatus.aplicado,
          aplicadoAVentaId: targetVentaId,
          fechaAplicacion: applicationDate,
          saldoUsd: 0.0,
        ));
      } else {
        // Cubre parcialmente el crédito: se aplica pendingDebt y queda un remanente
        final amountToApply = pendingDebt;
        final remainder = double.parse((availableOnThisCredit - amountToApply).toStringAsFixed(2));

        totalApplied += amountToApply;
        pendingDebt = 0.0;

        // El crédito consumido se marca como aplicado por la porción consumida
        consumed.add(credit.copyWith(
          estado: CreditStatus.aplicado,
          aplicadoAVentaId: targetVentaId,
          fechaAplicacion: applicationDate,
          saldoUsd: 0.0,
        ));

        // Se genera el crédito remanente DISPONIBLE con nuevo ID
        splitCredit = ClientCredit(
          id: CreditId(nextCreditIdForSplit),
          clienteId: credit.clienteId,
          fecha: applicationDate,
          montoUsd: CreditAmount(remainder),
          origenVentaId: credit.origenVentaId,
          estado: CreditStatus.disponible,
          organizacionId: credit.organizacionId,
          saldoUsd: remainder,
          usuarioEmail: credit.usuarioEmail,
        );
      }
    }

    return ApplyCreditPlan(
      totalApplied: double.parse(totalApplied.toStringAsFixed(2)),
      remainingDebt: double.parse(pendingDebt.toStringAsFixed(2)),
      consumedCredits: consumed,
      partialSplitCredit: splitCredit,
    );
  }
}
