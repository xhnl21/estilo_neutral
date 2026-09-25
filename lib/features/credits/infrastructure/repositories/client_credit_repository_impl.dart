import '../../../../models/models.dart';
import '../../domain/entities/client_credit.dart';
import '../../domain/entities/credit_status.dart';
import '../../domain/repositories/client_credit_repository.dart';
import '../../domain/services/credit_applier.dart';
import '../datasources/sheets_credits_datasource.dart';
import '../models/client_credit_model.dart';

/// Implementación del repositorio de créditos utilizando Google Sheets y transacciones atómicas.
class ClientCreditRepositoryImpl implements ClientCreditRepository {
  final SheetsCreditsDataSource dataSource;
  final CreditApplier creditApplier;

  ClientCreditRepositoryImpl({
    required this.dataSource,
    CreditApplier? creditApplier,
  }) : creditApplier = creditApplier ?? CreditApplier();

  @override
  Future<List<ClientCredit>> getAllCredits() async {
    return dataSource.credits;
  }

  @override
  Future<List<ClientCredit>> getCreditsByCliente(String clienteId) async {
    return dataSource.credits.where((c) => c.clienteId == clienteId).toList();
  }

  @override
  Future<List<ClientCredit>> getAvailableCredits(String clienteId) async {
    return dataSource.credits
        .where((c) => c.clienteId == clienteId && c.isAvailable)
        .toList();
  }

  @override
  Future<ClientCredit?> findById(String id) async {
    final matches = dataSource.credits.where((c) => c.id.value == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<bool> registerCredit(ClientCredit credit) async {
    final op = BatchOperation.create(
      sheet: 'creditos_clientes',
      data: ClientCreditModel.toMap(credit),
    );

    final auditData = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'usuario': credit.usuarioEmail ?? 'Antigravity Senior Agent',
      'hoja': 'creditos_clientes',
      'celda': credit.id.value,
      'valor_anterior': 'null',
      'valor_nuevo': 'DISPONIBLE (\$${credit.montoUsd.value})',
      'accion': 'creacion_credito_cliente',
      'norma': 'ISO 8000 §5.3 / COBIT 2019 DSS05',
      'observaciones': 'Crédito registrado por sobrepago en venta ${credit.origenVentaId}',
      'organizacion_id': credit.organizacionId,
    };
    auditData['hash_evidencia'] = ClientCreditModel.generateEvidenceHash(auditData);

    final audit = BatchOperation.create(
      sheet: 'audit_log',
      data: auditData,
    );

    final tx = BatchTransaction(
      operations: [op, audit],
    );

    final res = await dataSource.executeBatch(tx);
    if (res.isSuccess) {
      dataSource.addCreditLocal(credit);
      return true;
    }
    return false;
  }

  @override
  Future<bool> annulCredit(String creditId, String motivo) async {
    final credit = await findById(creditId);
    if (credit == null || credit.estado != CreditStatus.disponible) return false;

    final now = DateTime.now();
    final op = BatchOperation.update(
      sheet: 'creditos_clientes',
      id: creditId,
      data: const {
        'estado': 'ANULADO',
        'saldo_usd': 0.0,
      },
    );

    final auditData = <String, dynamic>{
      'timestamp': now.toIso8601String(),
      'usuario': 'Antigravity Senior Agent',
      'hoja': 'creditos_clientes',
      'celda': creditId,
      'valor_anterior': 'DISPONIBLE',
      'valor_nuevo': 'ANULADO',
      'accion': 'anulacion_credito_cliente',
      'norma': 'ISO 8000 §5.3 / COBIT 2019 DSS05',
      'observaciones': 'Crédito $creditId anulado. Motivo: $motivo',
      'organizacion_id': credit.organizacionId,
    };
    auditData['hash_evidencia'] = ClientCreditModel.generateEvidenceHash(auditData);

    final audit = BatchOperation.create(
      sheet: 'audit_log',
      data: auditData,
    );

    final tx = BatchTransaction(operations: [op, audit]);
    final res = await dataSource.executeBatch(tx);
    if (res.isSuccess) {
      dataSource.updateCreditLocal(credit.copyWith(
        estado: CreditStatus.anulado,
        saldoUsd: 0.0,
      ));
      return true;
    }
    return false;
  }

  @override
  Future<bool> applyCreditTransaction({
    required String clienteId,
    required String targetVentaId,
    required double amountToApply,
    required String userEmail,
  }) async {
    final available = await getAvailableCredits(clienteId);
    if (available.isEmpty || amountToApply <= 0.0) return false;

    final now = DateTime.now();
    final nextId = dataSource.nextCreditId;

    final plan = creditApplier.planFifoApplication(
      availableCredits: available,
      debtToCover: amountToApply,
      targetVentaId: targetVentaId,
      applicationDate: now,
      nextCreditIdForSplit: nextId,
    );

    if (plan.consumedCredits.isEmpty || plan.totalApplied <= 0.0) return false;

    final operations = <BatchOperation>[];

    // Paso 1: Crear Abono con método "Saldo a Favor" (mp00000009)
    final abonoId = dataSource.dataService.nextAbonoId;
    operations.add(BatchOperation.create(
      sheet: 'abonos',
      data: {
        'id': abonoId,
        'venta_id': targetVentaId,
        'fecha': now.toIso8601String().split('T').first,
        'monto': plan.totalApplied,
        'metodo_pago': 'mp00000009',
        'tasa_id': dataSource.dataService.tasaBcvVigente('USD')?.id ?? '',
      },
    ));

    // Paso 2: Actualizar la cabecera de la factura en 'ventas'
    final targetVenta = dataSource.dataService.ventas.where((v) => v.id == targetVentaId).firstOrNull;
    if (targetVenta != null) {
      final nuevoAbono = targetVenta.abonoUsd + plan.totalApplied;
      final nuevaDeuda = (targetVenta.totalPagarUsd - nuevoAbono).clamp(0.0, double.infinity);
      final nuevoEstado = nuevaDeuda <= 0 ? 'Pagada' : 'Pendiente';
      operations.add(BatchOperation.update(
        sheet: 'ventas',
        id: targetVentaId,
        data: {
          'abono_usd': nuevoAbono,
          'estado': nuevoEstado,
        },
      ));
    }

    // Paso 3: Consumir créditos (marcar como APLICADO) y registrar remanente si hubo corte
    for (final credit in plan.consumedCredits) {
      operations.add(BatchOperation.update(
        sheet: 'creditos_clientes',
        id: credit.id.value,
        data: {
          'id': credit.id.value,
          'cliente_id': credit.clienteId,
          'fecha': credit.fecha.toIso8601String(),
          'monto_usd': credit.montoUsd.value,
          'origen_venta_id': credit.origenVentaId,
          'estado': 'APLICADO',
          'organizacion_id': credit.organizacionId,
          'aplicado_a_venta_id': targetVentaId,
          'fecha_aplicacion': now.toIso8601String(),
          'saldo_usd': 0.0,
          'usuario_email': userEmail,
          'hash_evidencia': credit.hashEvidencia,
        },
      ));
    }

    if (plan.partialSplitCredit != null) {
      operations.add(BatchOperation.create(
        sheet: 'creditos_clientes',
        data: ClientCreditModel.toMap(plan.partialSplitCredit!),
      ));
    }

    // Paso 3: Auditoría forense ISO 8000 / COBIT (con hash SHA-256)
    final auditData = <String, dynamic>{
      'timestamp': now.toIso8601String(),
      'usuario': userEmail,
      'hoja': 'creditos_clientes',
      'celda': targetVentaId,
      'valor_anterior': 'DISPONIBLE',
      'valor_nuevo': 'APLICADO',
      'accion': 'aplicacion_credito_cliente',
      'norma': 'ISO 8000 §5.3 / COBIT 2019 DSS05',
      'observaciones':
          'Saldo a favor aplicado a $targetVentaId por \$${plan.totalApplied.toStringAsFixed(2)}. Antigravity Senior Agent.',
      'organizacion_id': dataSource.dataService.currentOrganizacionId ??
          '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    };
    auditData['hash_evidencia'] = ClientCreditModel.generateEvidenceHash(auditData);

    operations.add(BatchOperation.create(
      sheet: 'audit_log',
      data: auditData,
    ));

    // Ejecutar lote atómico All-or-Nothing
    final tx = BatchTransaction(
      transactionId: 'tx_credit_${now.millisecondsSinceEpoch}',
      operations: operations,
    );

    final res = await dataSource.executeBatch(tx);
    if (!res.isSuccess) return false;

    // Éxito: sincronizar estado en memoria local
    for (final c in plan.consumedCredits) {
      dataSource.updateCreditLocal(c);
    }
    if (plan.partialSplitCredit != null) {
      dataSource.addCreditLocal(plan.partialSplitCredit!);
    }

    // Paso 4: Refrescar la venta y abonos localmente
    await dataSource.dataService.fetchAllSheets();
    return true;
  }
}
