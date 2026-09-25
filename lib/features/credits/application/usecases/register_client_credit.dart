import '../../domain/entities/client_credit.dart';
import '../../domain/entities/credit_status.dart';
import '../../domain/repositories/client_credit_repository.dart';
import '../../domain/value_objects/credit_amount.dart';
import '../../domain/value_objects/credit_id.dart';
import '../../infrastructure/models/client_credit_model.dart';

/// Caso de Uso: Registrar un crédito a favor de un cliente por excedente de pago.
class RegisterClientCredit {
  final ClientCreditRepository repository;

  const RegisterClientCredit(this.repository);

  Future<bool> call({
    required String creditId,
    required String clienteId,
    required double excessAmountUsd,
    required String origenVentaId,
    required String organizacionId,
    String? usuarioEmail,
    DateTime? fecha,
  }) async {
    if (excessAmountUsd <= 0.009) return false;

    final creditDate = fecha ?? DateTime.now();
    final preliminaryMap = <String, dynamic>{
      'id': creditId,
      'cliente_id': clienteId,
      'fecha': creditDate.toIso8601String(),
      'monto_usd': double.parse(excessAmountUsd.toStringAsFixed(2)),
      'origen_venta_id': origenVentaId,
      'estado': 'DISPONIBLE',
      'organizacion_id': organizacionId,
      'usuario_email': usuarioEmail ?? 'sistema',
    };

    final evidenceHash = ClientCreditModel.generateEvidenceHash(preliminaryMap);

    final credit = ClientCredit(
      id: CreditId(creditId),
      clienteId: clienteId,
      fecha: creditDate,
      montoUsd: CreditAmount(excessAmountUsd),
      origenVentaId: origenVentaId,
      estado: CreditStatus.disponible,
      organizacionId: organizacionId,
      saldoUsd: double.parse(excessAmountUsd.toStringAsFixed(2)),
      usuarioEmail: usuarioEmail ?? 'sistema',
      hashEvidencia: evidenceHash,
    );

    return repository.registerCredit(credit);
  }
}
