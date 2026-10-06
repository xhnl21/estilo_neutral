// Correcciones de los pendientes de informe.md (2026-10-06): stock y deuda
// como diferencias, IDs del servidor en abonos y créditos, baja de
// organización en cascada, catálogos en uso, validaciones y fechas.
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/models.dart';
import 'package:estilo_neutral/presentation/cubits/abono/abono_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/codigos_telefono/codigos_telefono_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/tasas/tasas_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/usuario_form/usuario_form_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/usuario_form/usuario_form_state.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_servidor.dart';

void main() {
  late SheetsDataService ds;
  late ServidorSimulado servidor;

  setUp(() async => (ds, servidor) = await servicioConServidor());

  List<Map> operacionesDelUltimoLote() =>
      (servidor.enviados.lastWhere((e) => e['action'] == 'batch')['operations'] as List).cast<Map>();

  group('stock como diferencia (M3)', () {
    test('ajustar stock envía la diferencia, no el valor final', () async {
      final p = ds.productos.first;
      await ds.adjustStock(p.id, -2);
      final op = operacionesDelUltimoLote().single;
      expect(op['action'], 'increment');
      expect(op['sheet'], 'inventario');
      expect(op['delta'], -2);
      expect(op['min'], 0);
    });

    test('se adopta el stock que quedó en el servidor (otro dispositivo vendió)', () async {
      final p = ds.productos.first;
      servidor.valoresIncremento['inventario/${p.id}'] = 3;
      await ds.adjustStock(p.id, 1);
      expect(ds.productos.firstWhere((x) => x.id == p.id).cantidad, 3);
    });

    test('si Sheets rechaza, se deshace solo ese ajuste', () async {
      final p = ds.productos.first;
      servidor.rechazar();
      await expectLater(ds.adjustStock(p.id, 1), throwsA(isA<StateError>()));
      expect(ds.productos.firstWhere((x) => x.id == p.id).cantidad, p.cantidad);
    });
  });

  group('deuda del cliente en Sheets (B6)', () {
    test('una venta con saldo pendiente suma la deuda en el mismo lote', () async {
      final p = ds.productos.firstWhere((p) => p.cantidad > 0);
      await ds.addVenta(
        clienteId: 'c00000001',
        items: [(productoId: p.id, cantidad: 1, precioUsd: 40.0)],
        metodoPagoId: 'mp00000001',
        abonoUsd: 10,
      );
      final ops = operacionesDelUltimoLote();
      final deuda = ops.firstWhere((o) => o['sheet'] == 'clientes');
      expect(deuda['action'], 'increment');
      expect(deuda['delta'], 30.0);
      final stock = ops.firstWhere((o) => o['sheet'] == 'inventario');
      expect(stock['action'], 'increment');
      expect(stock['delta'], -1);
    });

    test('un abono baja la deuda solo en lo que cubre de la factura', () async {
      final venta = ds.ventas.firstWhere((v) => v.deudaUsd > 0);
      await ds.registrarAbono(venta.id, venta.deudaUsd + 15, metodoPagoId: 'mp00000001');
      final ops = operacionesDelUltimoLote();
      final deuda = ops.firstWhere((o) => o['sheet'] == 'clientes');
      expect(deuda['delta'], -venta.deudaUsd);
      expect(deuda['min'], 0);
    });

    test('anular una venta con deuda la descuenta del cliente', () async {
      final venta = ds.ventas.firstWhere((v) => v.deudaUsd > 0);
      await ds.deleteVenta(venta.id);
      final deuda = operacionesDelUltimoLote().firstWhere((o) => o['sheet'] == 'clientes');
      expect(deuda['delta'], -venta.deudaUsd);
    });
  });

  group('IDs del servidor en abonos y créditos (M2)', () {
    test('el abono y el crédito por sobrepago no llevan ID; se usan los del servidor', () async {
      servidor.generarIdsEnLotes = true;
      final venta = ds.ventas.firstWhere((v) => v.deudaUsd > 0);
      final creditosAntes = ds.creditosClientes.length;
      await ds.registrarAbono(venta.id, venta.deudaUsd + 15, metodoPagoId: 'mp00000001');

      final ops = operacionesDelUltimoLote();
      expect((ops.firstWhere((o) => o['sheet'] == 'abonos')['data'] as Map).containsKey('id'), isFalse);
      expect((ops.firstWhere((o) => o['sheet'] == 'creditos_clientes')['data'] as Map).containsKey('id'), isFalse);

      expect(ds.abonos.first.id, startsWith('ab9'));
      expect(ds.creditosClientes.length, creditosAntes + 1);
      expect(ds.creditosClientes.any((c) => c.id.value.startsWith('cr9')), isTrue);
    });

    test('si el lote falla, no queda crédito en el teléfono', () async {
      servidor.rechazar();
      final venta = ds.ventas.firstWhere((v) => v.deudaUsd > 0);
      final creditosAntes = ds.creditosClientes.length;
      expect(await ds.registrarAbono(venta.id, venta.deudaUsd + 15, metodoPagoId: 'mp00000001'),
          ResultadoAbono.rechazado);
      expect(ds.creditosClientes.length, creditosAntes);
    });
  });

  group('abono mayor que la deuda (M1)', () {
    test('pide confirmación antes de guardar el excedente', () async {
      final venta = ds.ventas.firstWhere((v) => v.deudaUsd > 0);
      final cubit = AbonoCubit(dataService: ds, ventaId: venta.id);
      final enviadosAntes = servidor.enviados.length;

      await cubit.registrar((venta.deudaUsd + 5).toStringAsFixed(2));
      expect(cubit.state.excedentePorConfirmar, closeTo(5, 0.001));
      expect(servidor.enviados.length, enviadosAntes);

      await cubit.registrar((venta.deudaUsd + 5).toStringAsFixed(2), excedenteConfirmado: true);
      expect(servidor.enviados.length, enviadosAntes + 1);
      await cubit.close();
    });
  });

  group('baja de organización (§2-M4)', () {
    test('borra en un lote la organización, su moneda y sus tasas manuales', () async {
      await ds.addOrganizacion('Sucursal');
      final org = ds.organizaciones.firstWhere((o) => o.nombre == 'Sucursal').id;
      await ds.setMonedaOrganizacion(org, 'EUR');
      await ds.setTasaManualOrganizacion(org, 'EUR', 500);

      await ds.deleteOrganizacion(org);

      final ops = operacionesDelUltimoLote();
      expect(ops.map((o) => o['sheet']), containsAll(['moneda_organizacion', 'tasas', 'organizaciones']));
      expect(ops.every((o) => o['action'] == 'delete'), isTrue);
      expect(ds.organizaciones.any((o) => o.id == org), isFalse);
      expect(ds.monedasOrganizacion.any((m) => m.organizacionId == org), isFalse);
      expect(ds.tasaManualOrganizacion(org), isNull);
    });

    test('no se elimina una organización con datos propios', () async {
      await ds.addOrganizacion('Con datos');
      final org = ds.organizaciones.firstWhere((o) => o.nombre == 'Con datos').id;
      ds.setCurrentOrganizacion(org);
      await ds.addCliente(Cliente(id: '', nombre: 'Cliente B', telefono: '', email: '', saldoDeudaUsd: 0, fechaRegistro: DateTime(2026)));
      ds.setCurrentOrganizacion(organizacionDePrueba);

      expect(ds.motivoNoEliminableOrganizacion(org), contains('1 cliente'));
      await expectLater(ds.deleteOrganizacion(org), throwsA(isA<ArgumentError>()));
    });

    test('si Sheets rechaza el lote, la organización sigue', () async {
      await ds.addOrganizacion('Rechazo');
      final org = ds.organizaciones.firstWhere((o) => o.nombre == 'Rechazo').id;
      servidor.rechazar();
      await expectLater(ds.deleteOrganizacion(org), throwsA(isA<StateError>()));
      expect(ds.organizaciones.any((o) => o.id == org), isTrue);
    });
  });

  group('catálogos en uso (§5-A3)', () {
    test('un código de teléfono en uso no se puede renombrar', () async {
      // Los clientes de respaldo tienen teléfonos 0412.
      final codigo = ds.codigosTelefono.firstWhere((c) => c.codigo == '0412');
      await expectLater(
        ds.updateCodigoTelefono(id: codigo.id, nuevoCodigo: '0413'),
        throwsA(isA<ArgumentError>()),
      );
      expect(ds.codigosTelefono.firstWhere((c) => c.id == codigo.id).codigo, '0412');
    });

    test('un tipo de documento en uso conserva la sigla pero cambia la descripción', () async {
      final tipo = ds.tiposDocumento.firstWhere((t) => t.tipo == 'V');
      await expectLater(
        ds.updateTipoDocumento(id: tipo.id, nuevoTipo: 'X', nuevaDescripcion: 'Otro'),
        throwsA(isA<ArgumentError>()),
      );
      await ds.updateTipoDocumento(id: tipo.id, nuevoTipo: 'V', nuevaDescripcion: 'Venezolana');
      expect(ds.tiposDocumento.firstWhere((t) => t.id == tipo.id).descripcion, 'Venezolana');
    });

    test('el Cubit calcula "en uso" una vez y no reemite el error de carga como error de acción', () async {
      final cubit = CodigosTelefonoCubit(dataService: ds);
      expect(cubit.state.enUso, contains('0412'));
      expect(cubit.state.enUso, isNot(contains('0414')));
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });
  });

  group('validaciones (§5-M2)', () {
    test('cuarentena con datos vacíos o JSON inválido se rechaza sin enviar nada', () async {
      final antes = servidor.enviados.length;
      await expectLater(
        ds.addCuarentena(RegistroCuarentena(
          idRegistroOriginal: 'v1', hojaOrigen: 'ventas', fechaDeteccion: DateTime(2026),
          motivoCuarentena: 'm', datosOriginalesJson: '{no es json', estado: 'PENDIENTE',
          resolucion: '', hashEvidencia: 'h')),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        ds.addCuarentena(RegistroCuarentena(
          idRegistroOriginal: '', hojaOrigen: 'ventas', fechaDeteccion: DateTime(2026),
          motivoCuarentena: 'm', datosOriginalesJson: '{}', estado: 'PENDIENTE',
          resolucion: '', hashEvidencia: 'h')),
        throwsA(isA<ArgumentError>()),
      );
      expect(servidor.enviados.length, antes);
    });

    test('reporte y checklist exigen su campo principal', () {
      expect(const ReporteMigracion(metrica: '', valorEstado: 'x', normaAplicada: '', observaciones: '').errores,
          contains('metrica'));
      expect(
          ChecklistISO(id: '', nro: 1, control: ' ', norma: 'ISO', estado: '☐', evidencia: '', timestamp: DateTime(2026))
              .errores,
          contains('control'));
    });
  });

  group('fechas de Sheets (§4-B4)', () {
    test('se leen los formatos que devuelve gviz', () {
      expect(parseFechaHoja('2026-10-06'), DateTime(2026, 10, 6));
      expect(parseFechaHoja("'2026-10-06"), DateTime(2026, 10, 6));
      expect(parseFechaHoja('6/10/2026'), DateTime(2026, 10, 6));
      expect(parseFechaHoja('Date(2026,9,6)'), DateTime(2026, 10, 6));
      expect(parseFechaHoja('31/02/2026'), isNull);
      expect(parseFechaHoja('hoy'), isNull);
    });

    test('una fecha ilegible no se convierte en "hoy": la fila se descarta', () {
      expect(() => ResumenDiario.fromRow(['rd00000001', 'ayer', '1']), throwsFormatException);
      expect(
        () => CompraDivisa.fromRow(['d00000001', '???', '2026-10-06', '10']),
        throwsFormatException,
      );
    });
  });

  group('tasas (§4-M4, M5)', () {
    test('el historial no muestra tasas manuales de otras organizaciones', () async {
      await ds.addOrganizacion('Otra');
      final otra = ds.organizaciones.firstWhere((o) => o.nombre == 'Otra').id;
      await ds.setTasaManualOrganizacion(otra, 'USD', 999);
      final cubit = TasasCubit(dataService: ds);
      expect(cubit.state.tasas.any((t) => t.fuente == 'manual' && t.organizacionId == otra), isFalse);
      await cubit.close();
    });

    test('salir durante "Actualizar tasa" no emite después de cerrado', () async {
      final cubit = TasasCubit(dataService: ds);
      final pedido = cubit.obtenerTasaDeHoy();
      await cubit.close();
      await expectLater(pedido, completes);
    });
  });

  group('UsuarioFormCubit (§1, §2-M5, M6)', () {
    test('valida correo, duplicados y organización sin enviar nada', () async {
      final cubit = UsuarioFormCubit(dataService: ds);
      final antes = servidor.enviados.length;
      await cubit.submit(email: 'no-es-correo', nombre: '', cedula: '');
      expect(cubit.state.errors, contains(UsuarioFormField.email));
      await cubit.submit(email: 'XHNL21@gmail.com', nombre: '', cedula: '');
      expect(cubit.state.errors[UsuarioFormField.email], contains('ya tiene acceso'));
      expect(servidor.enviados.length, antes);
      await cubit.close();
    });

    test('valida la cédula según el tipo', () async {
      final cubit = UsuarioFormCubit(dataService: ds);
      cubit.tipoDocumentoChanged('J');
      await cubit.submit(email: 'nuevo@x.com', nombre: '', cedula: '123');
      expect(cubit.state.errors, contains(UsuarioFormField.cedula));
      await cubit.close();
    });

    test('un tipo de documento inactivo se muestra y se guarda tal cual', () async {
      final usuario = ds.usuarios.first.copyWith(tipoDocumento: 'P');
      final cubit = UsuarioFormCubit(dataService: ds, usuario: usuario);
      expect(cubit.state.tipoDocumento, 'P');
      expect(cubit.state.tiposDocumento, contains('P'));
      await cubit.close();
    });

    test('alta correcta: se guarda y el estado queda en "guardado"', () async {
      final cubit = UsuarioFormCubit(dataService: ds);
      await cubit.submit(email: 'Nuevo@X.com', nombre: 'Nuevo', cedula: '');
      expect(cubit.state.status, UsuarioFormStatus.guardado);
      expect(ds.usuarios.any((u) => u.email == 'nuevo@x.com'), isTrue);
      await cubit.close();
    });

    test('si Sheets rechaza, el formulario queda abierto con el error', () async {
      servidor.rechazar();
      final cubit = UsuarioFormCubit(dataService: ds);
      await cubit.submit(email: 'otro@x.com', nombre: '', cedula: '');
      expect(cubit.state.status, UsuarioFormStatus.error);
      expect(cubit.state.resultMessage, isNotNull);
      expect(ds.usuarios.any((u) => u.email == 'otro@x.com'), isFalse);
      await cubit.close();
    });
  });
}
