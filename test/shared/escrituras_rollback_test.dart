// Etapa 3 del estándar (docs/estandar-hojas.md, R4): toda escritura espera la
// confirmación de Sheets y, si falla, deja los datos del teléfono como estaban.
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/models.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

void main() {
  late SheetsDataService ds;
  late ServidorSimulado servidor;

  setUp(() async => (ds, servidor) = await servicioConServidor());

  Map<String, dynamic> ultimo(String hoja) => servidor.enviados.lastWhere((e) => e['sheet'] == hoja);

  group('clientes', () {
    test('alta: ID del servidor; rechazada: no queda nada', () async {
      final antes = ds.clientes.length;
      servidor.rechazar();
      await expectLater(
        ds.addCliente(Cliente(id: 'c-local', nombre: 'X', telefono: '', email: '', saldoDeudaUsd: 0, fechaRegistro: DateTime(2026))),
        throwsA(isA<StateError>()),
      );
      expect(ds.clientes.length, antes);
    });

    test('edición rechazada vuelve al valor anterior', () async {
      final c = ds.clientes.first;
      servidor.rechazar();
      await expectLater(ds.updateCliente(c.copyWith(nombre: 'Otro')), throwsA(isA<StateError>()));
      expect(ds.clientes.firstWhere((x) => x.id == c.id).nombre, c.nombre);
    });

    test('baja rechazada: el cliente vuelve a la lista', () async {
      await ds.addCliente(Cliente(id: '', nombre: 'Borrable', telefono: '', email: '', saldoDeudaUsd: 0, fechaRegistro: DateTime(2026)));
      final id = ds.clientes.firstWhere((c) => c.nombre == 'Borrable').id;
      servidor.rechazar();
      await expectLater(ds.deleteCliente(id), throwsA(isA<StateError>()));
      expect(ds.clientes.any((c) => c.id == id), isTrue);
    });
  });

  group('inventario', () {
    test('editar conserva la organización (no cae en la por defecto)', () async {
      ds.setCurrentOrganizacion('org-b');
      await ds.addProducto(const Producto(id: '', cantidad: 3, nombre: 'Camisa', marca: 'm', modelo: '0501', talla: '06', precioUsd: 10));
      final p = ds.productos.firstWhere((x) => x.nombre == 'Camisa');
      await ds.updateProducto(Producto(id: p.id, cantidad: 3, nombre: 'Camisa 2', marca: 'm', modelo: '0501', talla: '06', precioUsd: 12));
      expect(ds.productos.firstWhere((x) => x.id == p.id).organizacionId, 'org-b');
    });

    test('cambiar la foto envía solo foto_id (no pisa el stock)', () async {
      final p = ds.productos.first;
      await ds.actualizarFotoProducto(p.id, 'g00000001');
      expect(ultimo('inventario')['data'], {'foto_id': 'g00000001'});
    });

    test('ajuste de stock rechazado vuelve al stock anterior', () async {
      final p = ds.productos.first;
      servidor.rechazar();
      await expectLater(ds.adjustStock(p.id, 1), throwsA(isA<StateError>()));
      expect(ds.productos.firstWhere((x) => x.id == p.id).cantidad, p.cantidad);
    });

    test('no se elimina un producto que ya se vendió', () async {
      final vendido = ds.ventaItems.first.itemId;
      await expectLater(ds.deleteProducto(vendido), throwsA(isA<ArgumentError>()));
      expect(ds.productos.any((p) => p.id == vendido), isTrue);
    });
  });

  group('ventas', () {
    test('anular: un solo lote atómico con venta, ítems, abonos y reposición de stock', () async {
      final venta = ds.ventas.first;
      await ds.deleteVenta(venta.id);
      final lote = servidor.enviados.last;
      expect(lote['action'], 'batch');
      final ops = (lote['operations'] as List).cast<Map>();
      expect(ops.any((o) => o['sheet'] == 'ventas' && o['action'] == 'delete'), isTrue);
      expect(ops.any((o) => o['sheet'] == 'inventario' && o['action'] == 'increment' && (o['delta'] as num) > 0), isTrue);
      expect(ds.ventas.any((v) => v.id == venta.id), isFalse);
    });

    test('anulación rechazada: la venta sigue', () async {
      final venta = ds.ventas.first;
      servidor.rechazar();
      await expectLater(ds.deleteVenta(venta.id), throwsA(isA<StateError>()));
      expect(ds.ventas.any((v) => v.id == venta.id), isTrue);
    });
  });

  group('compras de divisas', () {
    test('editar conserva organización y validación; rechazo revierte', () async {
      final c = ds.comprasDivisas.first;
      servidor.rechazar();
      await expectLater(ds.updateCompraDivisa(c.copyWith(capitalUsd: 999, validacion: 'X')), throwsA(isA<StateError>()));
      expect(ds.comprasDivisas.firstWhere((x) => x.id == c.id).capitalUsd, c.capitalUsd);
      servidor.confirmar();
      await ds.updateCompraDivisa(c.copyWith(capitalUsd: 999, validacion: 'X', organizacionId: 'otra'));
      final editada = ds.comprasDivisas.firstWhere((x) => x.id == c.id);
      expect(editada.capitalUsd, 999);
      expect(editada.validacion, c.validacion);
      expect(editada.organizacionId, c.organizacionId);
    });
  });

  group('organizaciones', () {
    test('no se elimina la organización en uso ni una con usuarios', () async {
      await expectLater(ds.deleteOrganizacion(organizacionDePrueba), throwsA(isA<ArgumentError>()));
    });

    test('nombre vacío o repetido se rechaza sin enviar nada', () async {
      final antes = servidor.enviados.length;
      await expectLater(ds.addOrganizacion('  '), throwsA(isA<ArgumentError>()));
      await expectLater(ds.addOrganizacion('Estilo Neutral'), throwsA(isA<ArgumentError>()));
      expect(servidor.enviados.length, antes);
    });
  });

  group('métodos de pago', () {
    test('el ID lo genera el servidor', () async {
      await ds.addMetodoPago(nombre: 'Cripto');
      expect((ultimo('metodo pago')['data'] as Map).containsKey('id'), isFalse);
      expect(ds.metodosPago.firstWhere((m) => m.nombre == 'Cripto').id, startsWith('mp'));
    });
  });

  group('tasa manual y moneda', () {
    test('tasa manual rechazada no queda; valor no positivo ni se envía', () async {
      await expectLater(ds.setTasaManualOrganizacion(organizacionDePrueba, 'USD', 0), throwsA(isA<ArgumentError>()));
      servidor.rechazar();
      await expectLater(ds.setTasaManualOrganizacion(organizacionDePrueba, 'USD', 500), throwsA(isA<StateError>()));
      expect(ds.tasaManualOrganizacion(organizacionDePrueba)?.valor, isNot(500));
    });

    test('cambio de moneda rechazado vuelve a la anterior', () async {
      final antes = ds.monedaOrganizacion(organizacionDePrueba);
      servidor.rechazar();
      await expectLater(
        ds.setMonedaOrganizacion(organizacionDePrueba, antes == 'USD' ? 'EUR' : 'USD'),
        throwsA(isA<StateError>()),
      );
      expect(ds.monedaOrganizacion(organizacionDePrueba), antes);
    });
  });
}
