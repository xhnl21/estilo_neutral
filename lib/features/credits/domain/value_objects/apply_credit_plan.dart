import 'package:equatable/equatable.dart';
import '../entities/client_credit.dart';

/// Plan de aplicación FIFO de créditos sobre una factura pendiente.
class ApplyCreditPlan extends Equatable {
  final double totalApplied;
  final double remainingDebt;
  final List<ClientCredit> consumedCredits;
  final ClientCredit? partialSplitCredit;

  const ApplyCreditPlan({
    required this.totalApplied,
    required this.remainingDebt,
    required this.consumedCredits,
    this.partialSplitCredit,
  });

  @override
  List<Object?> get props => [
        totalApplied,
        remainingDebt,
        consumedCredits,
        partialSplitCredit,
      ];
}

/// Previsualización inmutable del impacto de aplicar un saldo a favor (Frase 3 de la narrativa).
class ApplyCreditPreview extends Equatable {
  final double montoAplicable;
  final double saldoRestante;
  final double deudaRestante;
  final List<ClientCredit> creditosConsumidos;
  final List<String> advertencias;

  const ApplyCreditPreview({
    required this.montoAplicable,
    required this.saldoRestante,
    required this.deudaRestante,
    required this.creditosConsumidos,
    this.advertencias = const [],
  });

  @override
  List<Object?> get props => [
        montoAplicable,
        saldoRestante,
        deudaRestante,
        creditosConsumidos,
        advertencias,
      ];
}

/// Resultado de la ejecución de una aplicación de crédito.
class ApplyCreditResult extends Equatable {
  final bool isSuccess;
  final double montoAplicado;
  final double saldoRestante;
  final double deudaRestante;
  final String? errorMessage;

  const ApplyCreditResult({
    required this.isSuccess,
    required this.montoAplicado,
    required this.saldoRestante,
    required this.deudaRestante,
    this.errorMessage,
  });

  factory ApplyCreditResult.success({
    required double montoAplicado,
    required double saldoRestante,
    required double deudaRestante,
  }) {
    return ApplyCreditResult(
      isSuccess: true,
      montoAplicado: montoAplicado,
      saldoRestante: saldoRestante,
      deudaRestante: deudaRestante,
    );
  }

  factory ApplyCreditResult.failure(String message) {
    return ApplyCreditResult(
      isSuccess: false,
      montoAplicado: 0.0,
      saldoRestante: 0.0,
      deudaRestante: 0.0,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [
        isSuccess,
        montoAplicado,
        saldoRestante,
        deudaRestante,
        errorMessage,
      ];
}
