import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import 'package:estilo_neutral/models/models.dart';

void main() {
  group('SheetsDataService Unit & CRUD Tests', () {
    late SheetsDataService service;

    setUp(() async {
      service = SheetsDataService();
      // Inicializar con datos de respaldo. Se espera a que termine (incluye
      // un fetch real de red) para que no siga corriendo en paralelo con el
      // cuerpo del test — si no, puede pisar cambios locales del test a
      // mitad de camino (ej. el stock ajustado por una venta) con lo que
      // haya en el Sheet real en ese momento, dando falsos negativos.
      await service.initialize();
      // Activar la organización de respaldo para que los getters filtrados por
      // organización expongan los datos sembrados en las pruebas.
      service.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');
    });

    test('Inicializa con las 9 hojas cargadas en memoria', () {
      expect(service.clientes.isNotEmpty, isTrue);
      expect(service.productos.isNotEmpty, isTrue);
      expect(service.ventas.isNotEmpty, isTrue);
      expect(service.comprasDivisas.isNotEmpty, isTrue);
      expect(service.resumenesDiarios.isNotEmpty, isTrue);
      expect(service.cuarentenas.isNotEmpty, isTrue);
      expect(service.auditLogs.isNotEmpty, isTrue);
      expect(service.reportesMigracion.isNotEmpty, isTrue);
      expect(service.checklistIsos.isNotEmpty, isTrue);
    });

    test('CRUD Clientes: crear, actualizar y eliminar', () {
      final initialCount = service.clientes.length;
      final newCliente = Cliente(
        id: service.nextClienteId,
        nombre: 'Carlos Test',
        telefono: '+584140000002',
        email: 'carlos@test.com',
        saldoDeudaUsd: 15.0,
        fechaRegistro: DateTime.now(),
      );

      // Create
      service.addCliente(newCliente);
      expect(service.clientes.length, equals(initialCount + 1));
      expect(service.clientes.any((c) => c.id == newCliente.id), isTrue);

      // Update
      final updated = Cliente(
        id: newCliente.id,
        nombre: 'Carlos Actualizado',
        telefono: '+584140000002',
        email: 'carlos.act@test.com',
        saldoDeudaUsd: 20.0,
        fechaRegistro: newCliente.fechaRegistro,
      );
      service.updateCliente(updated);
      expect(service.clientes.firstWhere((c) => c.id == newCliente.id).nombre,
          equals('Carlos Actualizado'));

      // Delete
      service.deleteCliente(newCliente.id);
      expect(service.clientes.length, equals(initialCount));
    });

    test('CRUD Inventario: crear, ajustar stock y eliminar', () {
      final initialCount = service.productos.length;
      final newProd = Producto(
        id: service.nextProductoId,
        cantidad: 5,
        nombre: 'Gorra Deportiva',
        marca: 'MarcaX',
        modelo: 'Pro',
        talla: 'U',
        precioUsd: 12.0,
      );

      // Create
      service.addProducto(newProd);
      expect(service.productos.length, equals(initialCount + 1));

      // Adjust stock
      service.adjustStock(newProd.id, 3);
      expect(service.productos.firstWhere((p) => p.id == newProd.id).cantidad,
          equals(8));

      // Delete
      service.deleteProducto(newProd.id);
      expect(service.productos.length, equals(initialCount));
    });

    test(
      'CRUD Ventas y Abonos: registrar factura multi-ítem, amortizar y anular',
      () async {
        final initialCount = service.ventas.length;
        final initialItemsCount = service.ventaItems.length;
        final initialStock =
            service.productos.firstWhere((p) => p.id == 'p00000001').cantidad;
        final ventaId = service
            .nextVentaId; // id que addVenta debería asignarle (nadie más crea ventas en el medio)

        // Create (factura con 1 ítem, con deuda pendiente)
        await service.addVenta(
          clienteId: 'c00000001',
          items: const [
            (productoId: 'p00000001', cantidad: 1, precioUsd: 20.0)
          ],
          tasaBcv: 474.0,
          tasaUsd: 30.0,
          tipoPago: TipoPago.efectivo,
          abonoUsd: 5.0,
        );
        expect(service.ventas.length, equals(initialCount + 1));
        expect(service.ventaItems.length, equals(initialItemsCount + 1));
        expect(
          service.productos.firstWhere((p) => p.id == 'p00000001').cantidad,
          equals(initialStock - 1),
        );

        final creada = service.ventas.firstWhere((v) => v.id == ventaId);

        // Abono
        service.registrarAbono(creada.id, 15.0);
        final ventaActualizada =
            service.ventas.firstWhere((v) => v.id == creada.id);
        expect(ventaActualizada.deudaUsd, equals(0.0));
        expect(ventaActualizada.estado, equals(EstadoVenta.pagada));

        // Delete (repone stock)
        await service.deleteVenta(creada.id);
        expect(service.ventas.length, equals(initialCount));
        expect(service.ventaItems.length, equals(initialItemsCount));
        expect(
          service.productos.firstWhere((p) => p.id == 'p00000001').cantidad,
          equals(initialStock),
        );
      },
      // Esta prueba hace varias llamadas de red reales (create/update/delete
      // sobre "ventas" y "venta_items" contra el Apps Script real) — el
      // timeout por defecto de 30s puede no alcanzar si hay contención del
      // LockService del script con otras pruebas concurrentes.
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test('CRUD Checklist ISO: alternar conformidad y persistir auditoría', () {
      expect(service.checklistIsos.isNotEmpty, isTrue);
      final primerItem = service.checklistIsos.first;
      final estadoInicial = primerItem.estado;

      // Toggle
      service.toggleChecklistEstado(primerItem.nro);
      final alternado =
          service.checklistIsos.firstWhere((c) => c.nro == primerItem.nro);
      expect(alternado.estado, isNot(equals(estadoInicial)));

      // Re-toggle para restaurar
      service.toggleChecklistEstado(primerItem.nro);
      final restaurado =
          service.checklistIsos.firstWhere((c) => c.nro == primerItem.nro);
      expect(restaurado.estado, equals(estadoInicial));
    });

    test('Parser CSV RFC 4180 procesa comillas y campos anidados', () {
      const csvData = '''id,nombre,valor
"1","Item, con coma","100.00"
"2","Item ""entrecomillado""","200.00"''';

      final parsed = parseCsv(csvData);
      expect(parsed.length, equals(3));
      expect(parsed[1][1], equals('Item, con coma'));
      expect(parsed[2][1], equals('Item "entrecomillado"'));
    });

    test(
        'Apps Script dispatch envía acciones remotas cuando appsScriptUrl está configurada',
        () async {
      final dispatched = <Map<String, dynamic>>[];
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('script.google.com')) {
          dispatched.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"status":"success"}', 200);
        }
        return http.Response('', 200);
      });

      final testService = SheetsDataService(
        appsScriptUrl: 'https://script.google.com/macros/s/TEST/exec',
        httpClient: mockClient,
      );

      final cliente = Cliente(
        id: 'c00000099',
        nombre: 'Cliente Remoto',
        telefono: '+584120000099',
        email: 'remoto@test.com',
        saldoDeudaUsd: 0.0,
        fechaRegistro: DateTime.now(),
      );

      testService.addCliente(cliente);
      await pumpEventQueue();
      expect(dispatched.length, equals(1));
      expect(dispatched.first['action'], equals('create'));
      expect(dispatched.first['sheet'], equals('clientes'));
      expect(dispatched.first['data']['nombre'], equals('Cliente Remoto'));
    });
  });
}
