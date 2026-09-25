import 'package:equatable/equatable.dart';
import '../value_objects/credit_amount.dart';
import '../value_objects/credit_id.dart';
import 'credit_status.dart';

/// Entidad pura de Dominio para el crédito a favor de un cliente.
class ClientCredit extends Equatable {
  final CreditId id;
  final String clienteId;
  final DateTime fecha;
  final CreditAmount montoUsd;
  final String origenVentaId;
  final CreditStatus estado;
  final String organizacionId;
  final String? aplicadoAVentaId;
  final DateTime? fechaAplicacion;
  final double saldoUsd;
  final String? usuarioEmail;
  final String? hashEvidencia;

  ClientCredit({
    required this.id,
    required this.clienteId,
    required this.fecha,
    required this.montoUsd,
    required this.origenVentaId,
    this.estado = CreditStatus.disponible,
    required this.organizacionId,
    this.aplicadoAVentaId,
    this.fechaAplicacion,
    double? saldoUsd,
    this.usuarioEmail,
    this.hashEvidencia,
  }) : saldoUsd = saldoUsd ?? (estado == CreditStatus.disponible ? montoUsd.value : 0.0) {
    if (estado == CreditStatus.aplicado) {
      if (aplicadoAVentaId == null || aplicadoAVentaId!.trim().isEmpty) {
        throw StateError('Un crédito APLICADO requiere obligatoriamente aplicadoAVentaId.');
      }
      if (fechaAplicacion == null) {
        throw StateError('Un crédito APLICADO requiere obligatoriamente fechaAplicacion.');
      }
    }
  }

  bool get isAvailable => estado == CreditStatus.disponible && saldoUsd > 0.0;

  ClientCredit copyWith({
    CreditStatus? estado,
    String? aplicadoAVentaId,
    DateTime? fechaAplicacion,
    double? saldoUsd,
    String? usuarioEmail,
    String? hashEvidencia,
  }) {
    return ClientCredit(
      id: id,
      clienteId: clienteId,
      fecha: fecha,
      montoUsd: montoUsd,
      origenVentaId: origenVentaId,
      estado: estado ?? this.estado,
      organizacionId: organizacionId,
      aplicadoAVentaId: aplicadoAVentaId ?? this.aplicadoAVentaId,
      fechaAplicacion: fechaAplicacion ?? this.fechaAplicacion,
      saldoUsd: saldoUsd ?? this.saldoUsd,
      usuarioEmail: usuarioEmail ?? this.usuarioEmail,
      hashEvidencia: hashEvidencia ?? this.hashEvidencia,
    );
  }

  @override
  List<Object?> get props => [
        id,
        clienteId,
        fecha,
        montoUsd,
        origenVentaId,
        estado,
        organizacionId,
        aplicadoAVentaId,
        fechaAplicacion,
        saldoUsd,
        usuarioEmail,
        hashEvidencia,
      ];
}
