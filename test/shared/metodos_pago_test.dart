import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/models.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';

void main() {
  group('MetodoPago Model Tests', () {
    test('Parsea correctamente desde una fila de Google Sheets', () {
      final row = ['mp00000001', 'Efectivo', 'TRUE'];
      final mp = MetodoPago.fromRow(row);

      expect(mp.id, 'mp00000001');
      expect(mp.nombre, 'Efectivo');
      expect(mp.status, isTrue);
    });

    test('Parsea status inactivo en minúsculas o texto false', () {
      final row = ['mp00000002', 'Pago Movil', 'false'];
      final mp = MetodoPago.fromRow(row);

      expect(mp.status, isFalse);
    });

    test('Serializa a Map correctamente', () {
      const mp = MetodoPago(id: 'mp00000003', nombre: 'Transferencia', status: true);
      final map = mp.toMap();

      expect(map['id'], 'mp00000003');
      expect(map['nombre'], 'Transferencia');
      expect(map['status'], isTrue);
    });
  });

  group('SheetsDataService - Métodos de Pago & Abonos', () {
    late SheetsDataService ds;

    setUp(() {
      ds = SheetsDataService();
      ds.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');
    });

    test('Inicializa con el catálogo de 6 métodos de pago por defecto activos', () {
      expect(ds.metodosPago.length, greaterThanOrEqualTo(6));
      expect(ds.metodosPagoActivos.length, ds.metodosPago.length);

      final nombres = ds.metodosPago.map((m) => m.nombre).toList();
      expect(nombres, containsAll([
        'Efectivo',
        'Pago Movil',
        'Transferencia',
        'Zelle',
        'Binance',
        'Otro',
      ]));
    });

    test('Agregar nuevo método genera ID único y lo activa', () async {
      final totalInicial = ds.metodosPago.length;
      await ds.addMetodoPago(nombre: 'Tarjeta Débito');

      expect(ds.metodosPago.length, totalInicial + 1);
      final nuevo = ds.metodosPago.firstWhere((m) => m.nombre == 'Tarjeta Débito');
      expect(nuevo.id, startsWith('mp'));
      expect(nuevo.status, isTrue);
      expect(ds.metodosPagoActivos.map((m) => m.nombre), contains('Tarjeta Débito'));
    });

    test('Rechaza agregar método de pago con nombre duplicado o vacío', () async {
      expect(
        () => ds.addMetodoPago(nombre: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ds.addMetodoPago(nombre: 'Efectivo'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('No permite deshabilitar un método de pago en uso', () async {
      // Registrar una venta usando 'Efectivo'
      await ds.addVenta(
        clienteId: 'c00000001',
        items: [(productoId: 'p00000001', cantidad: 1, precioUsd: 20.0)],
        tasaBcv: 474.0,
        tasaUsd: 30.0,
        metodoPago: 'Efectivo',
        abonoUsd: 10.0,
      );

      final metodoEfectivo = ds.metodosPago.firstWhere((m) => m.nombre == 'Efectivo');
      expect(ds.isMetodoPagoEnUso(metodoEfectivo.id), isTrue);

      // Intentar deshabilitar Efectivo debe lanzar StateError
      expect(
        () => ds.toggleMetodoPagoStatus(metodoEfectivo.id),
        throwsA(isA<StateError>()),
      );

      // El status debe continuar siendo true
      final reloaded = ds.metodosPago.firstWhere((m) => m.id == metodoEfectivo.id);
      expect(reloaded.status, isTrue);
    });

    test('Permite deshabilitar un método de pago no usado y lo oculta de activos', () async {
      // Crear un método nuevo no utilizado en ninguna venta
      await ds.addMetodoPago(nombre: 'Cheque');
      final metodoCheque = ds.metodosPago.firstWhere((m) => m.nombre == 'Cheque');
      expect(ds.isMetodoPagoEnUso(metodoCheque.id), isFalse);

      final toggled = await ds.toggleMetodoPagoStatus(metodoCheque.id);
      expect(toggled, isTrue);

      final reloaded = ds.metodosPago.firstWhere((m) => m.id == metodoCheque.id);
      expect(reloaded.status, isFalse);
      expect(ds.metodosPagoActivos.any((m) => m.nombre == 'Cheque'), isFalse);
    });

    test('Registrar abono permite especificar método de pago y lo registra en auditoría', () async {
      await ds.addVenta(
        clienteId: 'c00000001',
        items: [(productoId: 'p00000001', cantidad: 1, precioUsd: 50.0)],
        tasaBcv: 474.0,
        tasaUsd: 30.0,
        metodoPago: 'Transferencia',
        abonoUsd: 10.0,
      );

      final venta = ds.ventas.first;
      expect(venta.deudaUsd, 40.0);

      // Aplicar abono de 20 USD con Zelle
      ds.registrarAbono(venta.id, 20.0, metodoPago: 'Zelle');

      final ventaActualizada = ds.ventas.firstWhere((v) => v.id == venta.id);
      expect(ventaActualizada.abonoUsd, 30.0);
      expect(ventaActualizada.deudaUsd, 20.0);

      // Comprobar que Zelle ahora cuenta como en uso
      final metodoZelle = ds.metodosPago.firstWhere((m) => m.nombre == 'Zelle');
      expect(ds.isMetodoPagoEnUso(metodoZelle.id), isTrue);

      // Comprobar log de auditoría
      final ultimoAudit = ds.auditLogs.first;
      expect(ultimoAudit.accion, 'registro_abono');
      expect(ultimoAudit.valorNuevo, contains('Zelle'));
    });
  });
}
