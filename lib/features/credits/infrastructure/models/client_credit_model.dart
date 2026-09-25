import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../models/number_parser.dart';
import '../../domain/entities/client_credit.dart';
import '../../domain/entities/credit_status.dart';
import '../../domain/value_objects/credit_amount.dart';
import '../../domain/value_objects/credit_id.dart';

/// Modelo de infraestructura para serialización y hashing SHA-256 de créditos.
class ClientCreditModel {
  static String generateEvidenceHash(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data)..remove('hash_evidencia');
    final raw = jsonEncode(copy);
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static ClientCredit fromRow(List<dynamic> row) {
    final id = row.isNotEmpty ? row[0].toString().trim() : '';
    final clienteId = row.length > 1 ? row[1].toString().trim() : '';
    final fechaStr = row.length > 2 ? row[2].toString().trim() : '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
    final montoRaw = row.length > 3 ? parseSheetDouble(row[3]) : 0.0;
    final origenVentaId = row.length > 4 ? row[4].toString().trim() : '';
    final estado = CreditStatus.fromString(row.length > 5 ? row[5].toString().trim() : 'DISPONIBLE');
    final orgId = row.length > 6 && row[6].toString().trim().isNotEmpty
        ? row[6].toString().trim()
        : '67774411-6aa1-4aa3-a4b2-d3fc6913b768';
    final aplicadoAVentaId = row.length > 7 && row[7].toString().trim().isNotEmpty
        ? row[7].toString().trim()
        : null;
    final fechaAppStr = row.length > 8 ? row[8].toString().trim() : '';
    final fechaApp = fechaAppStr.isNotEmpty ? DateTime.tryParse(fechaAppStr) : null;
    final saldoRaw = row.length > 9
        ? parseSheetDouble(row[9])
        : (estado == CreditStatus.disponible ? montoRaw : 0.0);
    final usuarioEmail = row.length > 10 && row[10].toString().trim().isNotEmpty
        ? row[10].toString().trim()
        : null;
    final hashEvidencia = row.length > 11 && row[11].toString().trim().isNotEmpty
        ? row[11].toString().trim()
        : null;

    return ClientCredit(
      id: CreditId(id.isNotEmpty ? id : 'cr00000000'),
      clienteId: clienteId,
      fecha: fecha,
      montoUsd: CreditAmount(montoRaw > 0 ? montoRaw : 0.01),
      origenVentaId: origenVentaId,
      estado: estado,
      organizacionId: orgId,
      aplicadoAVentaId: aplicadoAVentaId,
      fechaAplicacion: fechaApp,
      saldoUsd: saldoRaw,
      usuarioEmail: usuarioEmail,
      hashEvidencia: hashEvidencia,
    );
  }

  static ClientCredit fromMap(Map<String, dynamic> map) {
    final montoRaw = map['monto_usd'] is num
        ? (map['monto_usd'] as num).toDouble()
        : double.tryParse(map['monto_usd']?.toString() ?? '0') ?? 0.0;

    final saldoRaw = map['saldo_usd'] != null
        ? (map['saldo_usd'] is num
            ? (map['saldo_usd'] as num).toDouble()
            : double.tryParse(map['saldo_usd'].toString()) ?? 0.0)
        : null;

    final fechaStr = map['fecha']?.toString();
    final fecha = fechaStr != null ? DateTime.tryParse(fechaStr) ?? DateTime.now() : DateTime.now();

    final fechaAppStr = map['fecha_aplicacion']?.toString();
    final fechaApp = fechaAppStr != null && fechaAppStr.isNotEmpty
        ? DateTime.tryParse(fechaAppStr)
        : null;

    final estado = CreditStatus.fromString(map['estado']?.toString());

    return ClientCredit(
      id: CreditId(map['id']?.toString() ?? 'cr00000000'),
      clienteId: map['cliente_id']?.toString() ?? '',
      fecha: fecha,
      montoUsd: CreditAmount(montoRaw > 0 ? montoRaw : 0.01),
      origenVentaId: map['origen_venta_id']?.toString() ?? '',
      estado: estado,
      organizacionId: map['organizacion_id']?.toString() ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      aplicadoAVentaId: map['aplicado_a_venta_id']?.toString(),
      fechaAplicacion: fechaApp,
      saldoUsd: saldoRaw,
      usuarioEmail: map['usuario_email']?.toString(),
      hashEvidencia: map['hash_evidencia']?.toString(),
    );
  }

  static Map<String, dynamic> toMap(ClientCredit credit) {
    final map = <String, dynamic>{
      'id': credit.id.value,
      'cliente_id': credit.clienteId,
      'fecha': credit.fecha.toIso8601String(),
      'monto_usd': credit.montoUsd.value,
      'origen_venta_id': credit.origenVentaId,
      'estado': credit.estado.toSheetValue,
      'organizacion_id': credit.organizacionId,
      'aplicado_a_venta_id': credit.aplicadoAVentaId ?? '',
      'fecha_aplicacion': credit.fechaAplicacion?.toIso8601String() ?? '',
      'saldo_usd': credit.saldoUsd,
      'usuario_email': credit.usuarioEmail ?? '',
    };
    map['hash_evidencia'] = credit.hashEvidencia ?? generateEvidenceHash(map);
    return map;
  }
}
