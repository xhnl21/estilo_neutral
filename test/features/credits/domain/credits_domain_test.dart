import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/features/credits/credits.dart';

void main() {
  group('Credits Domain Tests (T01 - T08)', () {
    // T01. CreditAmount rechaza 0 y negativos
    test('T01: CreditAmount rechaza 0 y valores negativos', () {
      expect(() => CreditAmount(0.0), throwsArgumentError);
      expect(() => CreditAmount(-5.50), throwsArgumentError);
      expect(() => CreditAmount(-0.01), throwsArgumentError);

      final valid = CreditAmount(10.55);
      expect(valid.value, 10.55);
    });

    // T02. CreditId valida regex y es inmutable
    test('T02: CreditId valida regex ^cr\\d{8}\$ y verifica inmutabilidad', () {
      expect(() => CreditId('invalid'), throwsArgumentError);
      expect(() => CreditId('cr123'), throwsArgumentError);
      expect(() => CreditId('CR00000001'), throwsArgumentError);

      final id1 = CreditId('cr00000001');
      final id2 = CreditId('cr00000001');
      expect(id1, equals(id2));
      expect(id1.value, 'cr00000001');
    });

    // T03. ClientCredit no puede estar APLICADO sin aplicadoAVentaId o fechaAplicacion
    test('T03: ClientCredit no puede estar APLICADO sin metadata de aplicación', () {
      expect(
        () => ClientCredit(
          id: CreditId('cr00000001'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 3),
          montoUsd: CreditAmount(100.0),
          origenVentaId: 'v00000002',
          estado: CreditStatus.aplicado,
          organizacionId: 'org1',
          aplicadoAVentaId: null,
          fechaAplicacion: null,
        ),
        throwsStateError,
      );

      final validApplied = ClientCredit(
        id: CreditId('cr00000001'),
        clienteId: 'c00000001',
        fecha: DateTime(2026, 4, 3),
        montoUsd: CreditAmount(100.0),
        origenVentaId: 'v00000002',
        estado: CreditStatus.aplicado,
        organizacionId: 'org1',
        aplicadoAVentaId: 'v00000005',
        fechaAplicacion: DateTime(2026, 4, 4),
      );
      expect(validApplied.estado, CreditStatus.aplicado);
      expect(validApplied.isAvailable, isFalse);
    });

    // T04. CreditApplier: saldo > deuda -> aplica deuda completa
    test('T04: CreditApplier con saldo > deuda aplica exactamente la deuda', () {
      final applier = CreditApplier();
      final credits = [
        ClientCredit(
          id: CreditId('cr00000001'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 1),
          montoUsd: CreditAmount(150.0),
          origenVentaId: 'v00000001',
          organizacionId: 'org1',
          saldoUsd: 150.0,
        ),
      ];

      final plan = applier.compute(
        availableCredits: credits,
        deudaUsd: 100.0,
        targetVentaId: 'v00000005',
        applicationDate: DateTime(2026, 4, 4),
        nextCreditIdForSplit: 'cr00000002',
      );

      expect(plan.totalApplied, 100.0);
      expect(plan.remainingDebt, 0.0);
      expect(plan.consumedCredits.length, 1);
      expect(plan.partialSplitCredit, isNotNull);
      expect(plan.partialSplitCredit!.saldoUsd, 50.0);
      expect(plan.partialSplitCredit!.id.value, 'cr00000002');
      expect(plan.partialSplitCredit!.estado, CreditStatus.disponible);
    });

    // T05. CreditApplier: saldo < deuda -> aplica saldo completo
    test('T05: CreditApplier con saldo < deuda aplica saldo completo y deja remanente de deuda', () {
      final applier = CreditApplier();
      final credits = [
        ClientCredit(
          id: CreditId('cr00000001'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 1),
          montoUsd: CreditAmount(60.0),
          origenVentaId: 'v00000001',
          organizacionId: 'org1',
          saldoUsd: 60.0,
        ),
      ];

      final plan = applier.compute(
        availableCredits: credits,
        deudaUsd: 100.0,
        targetVentaId: 'v00000005',
        applicationDate: DateTime(2026, 4, 4),
        nextCreditIdForSplit: 'cr00000002',
      );

      expect(plan.totalApplied, 60.0);
      expect(plan.remainingDebt, 40.0);
      expect(plan.consumedCredits.length, 1);
      expect(plan.partialSplitCredit, isNull);
    });

    // T06. CreditApplier: saldo == deuda -> ambos a cero
    test('T06: CreditApplier con saldo == deuda lleva ambos a cero sin remanentes', () {
      final applier = CreditApplier();
      final credits = [
        ClientCredit(
          id: CreditId('cr00000001'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 1),
          montoUsd: CreditAmount(100.0),
          origenVentaId: 'v00000001',
          organizacionId: 'org1',
          saldoUsd: 100.0,
        ),
      ];

      final plan = applier.compute(
        availableCredits: credits,
        deudaUsd: 100.0,
        targetVentaId: 'v00000005',
        applicationDate: DateTime(2026, 4, 4),
        nextCreditIdForSplit: 'cr00000002',
      );

      expect(plan.totalApplied, 100.0);
      expect(plan.remainingDebt, 0.0);
      expect(plan.partialSplitCredit, isNull);
      expect(plan.consumedCredits.first.saldoUsd, 0.0);
    });

    // T07. CreditApplier: múltiples créditos -> FIFO por fecha
    test('T07: CreditApplier consume múltiples créditos en orden FIFO por fecha más antigua', () {
      final applier = CreditApplier();
      final credits = [
        ClientCredit(
          id: CreditId('cr00000002'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 2),
          montoUsd: CreditAmount(40.0),
          origenVentaId: 'v00000002',
          organizacionId: 'org1',
          saldoUsd: 40.0,
        ),
        ClientCredit(
          id: CreditId('cr00000001'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 1),
          montoUsd: CreditAmount(50.0),
          origenVentaId: 'v00000001',
          organizacionId: 'org1',
          saldoUsd: 50.0,
        ),
      ];

      final plan = applier.compute(
        availableCredits: credits,
        deudaUsd: 70.0,
        targetVentaId: 'v00000005',
        applicationDate: DateTime(2026, 4, 4),
        nextCreditIdForSplit: 'cr00000003',
      );

      expect(plan.totalApplied, 70.0);
      expect(plan.remainingDebt, 0.0);
      expect(plan.consumedCredits.length, 2);
      expect(plan.consumedCredits[0].id.value, 'cr00000001'); // 50 consumidos
      expect(plan.consumedCredits[1].id.value, 'cr00000002'); // 20 consumidos
      expect(plan.partialSplitCredit, isNotNull);
      expect(plan.partialSplitCredit!.saldoUsd, 20.0); // 40 - 20
    });

    // T08. CreditApplier: remanente genera crédito DISPONIBLE nuevo
    test('T08: Remanente de crédito dividido genera crédito DISPONIBLE con nuevo ID', () {
      final applier = CreditApplier();
      final credits = [
        ClientCredit(
          id: CreditId('cr00000001'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 1),
          montoUsd: CreditAmount(200.0),
          origenVentaId: 'v00000001',
          organizacionId: 'org1',
          saldoUsd: 200.0,
        ),
      ];

      final plan = applier.compute(
        availableCredits: credits,
        deudaUsd: 75.0,
        targetVentaId: 'v00000005',
        applicationDate: DateTime(2026, 4, 4),
        nextCreditIdForSplit: 'cr00000009',
      );

      expect(plan.partialSplitCredit, isNotNull);
      final split = plan.partialSplitCredit!;
      expect(split.id.value, 'cr00000009');
      expect(split.montoUsd.value, 125.0);
      expect(split.saldoUsd, 125.0);
      expect(split.estado, CreditStatus.disponible);
      expect(split.isAvailable, isTrue);
    });
  });
}
