import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/models/cuenta_bancaria.dart';
import 'package:estilo_neutral/presentation/cubits/datos_bancarios/cuenta_bancaria_form_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/datos_bancarios/datos_bancarios_cubit.dart';
import 'package:estilo_neutral/presentation/pages/datos_bancarios_page.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../../test_servidor.dart';

const _bancosCsv = 'id,codigo,nombre,status\n'
    'bn00000001,0102,Banco de Venezuela,activo\n'
    'bn00000008,0134,Banesco,activo\n'
    'bn00000003,105,Mercantil,activo\n'
    'bn00000009,0999,Banco Cerrado,inactivo\n';

/// Servicio con el catálogo de bancos leído de la "hoja".
Future<(SheetsDataService, ServidorSimulado)> _servicio({bool inicializar = true}) async {
  final (ds, servidor) = await servicioConServidor(inicializar: inicializar);
  servidor.csvPorHoja['bancos'] = _bancosCsv;
  await ds.releerDatosBancarios();
  return (ds, servidor);
}

CuentaBancaria _transferencia({String cuenta = '01340001234567890123', String titular = 'Estilo Neutral C.A.'}) =>
    CuentaBancaria(
      id: '',
      organizacionId: '',
      tipo: TipoCuentaBancaria.transferencia,
      bancoId: 'bn00000008',
      titular: titular,
      tipoDocumento: 'J',
      documento: '070133805',
      numeroCuenta: cuenta,
      modalidad: ModalidadCuenta.corriente,
    );

CuentaBancaria _pagoMovil({String telefono = '04121234567'}) => CuentaBancaria(
      id: '',
      organizacionId: '',
      tipo: TipoCuentaBancaria.pagoMovil,
      bancoId: 'bn00000001',
      titular: 'Ana Pérez',
      tipoDocumento: 'V',
      documento: '12345678',
      telefono: telefono,
    );

void main() {
  group('modelos', () {
    test('Banco repone los ceros del código que Sheets convirtió en número', () {
      expect(Banco.fromRow(const ['bn00000003', '105', 'Mercantil', 'activo']).codigo, '0105');
      expect(Banco.fromRow(const ['bn00000009', "'0999", 'X', 'inactivo']).activo, isFalse);
    });

    test('CuentaBancaria: lee la fila, formatos legibles y texto para compartir', () {
      final c = CuentaBancaria.fromRow(const [
        'cb00000001', 'org1', 'pago_movil', 'bn00000001', 'Ana Pérez', 'V', "'12345678", '', '', '4121234567', 'activo', ''
      ])!;
      expect(c.telefono, '04121234567');
      expect(c.telefonoLegible, '0412-1234567');
      final texto = c.textoParaCompartir(
          banco: const Banco(id: 'bn00000001', codigo: '0102', nombre: 'Banco de Venezuela'),
          documentoLegible: 'V-12345678');
      expect(texto, 'Pago móvil\nBanco: Banco de Venezuela (0102)\nTeléfono: 0412-1234567\nCédula: V-12345678\nTitular: Ana Pérez');
      expect(_transferencia().numeroCuentaLegible, '0134-0001-23-4567890123');
      expect(CuentaBancaria.fromRow(const ['cb00000002', 'org1', 'zelle']), isNull);
    });
  });

  group('SheetsDataService', () {
    test('alta con ID del servidor en la organización actual; editar y eliminar por ID', () async {
      final (ds, servidor) = await _servicio();
      final t = await ds.addCuentaBancaria(_transferencia());
      final alta = servidor.enviados.last;
      expect(alta['sheet'], 'cuentas_bancarias');
      expect((alta['data'] as Map).containsKey('id'), isFalse);
      expect(alta['data'], containsPair('organizacion_id', organizacionDePrueba));
      expect(alta['data'], containsPair('telefono', ''));
      expect(t.id, startsWith('cb9'));

      await ds.updateCuentaBancaria(CuentaBancaria(
        id: t.id, organizacionId: 'otra', tipo: t.tipo, bancoId: t.bancoId, titular: 'Nuevo', tipoDocumento: 'J',
        documento: t.documento, numeroCuenta: t.numeroCuenta, modalidad: ModalidadCuenta.ahorro,
      ));
      final edicion = servidor.enviados.last;
      expect(edicion['action'], 'update');
      expect((edicion['data'] as Map).containsKey('organizacion_id'), isFalse);
      expect(ds.cuentasBancarias.single.organizacionId, organizacionDePrueba);
      expect(ds.cuentasBancarias.single.modalidad, ModalidadCuenta.ahorro);

      await ds.deleteCuentaBancaria(t.id);
      expect(servidor.enviados.last['action'], 'delete');
      expect(ds.cuentasBancarias, isEmpty);
    });

    test('valida banco, cuenta, código del banco, teléfono, documento y duplicados', () async {
      final (ds, servidor) = await _servicio();
      await ds.addCuentaBancaria(_transferencia());
      await ds.addCuentaBancaria(_pagoMovil());
      final antes = servidor.enviados.length;
      Future<void> rechaza(CuentaBancaria c, String motivo) =>
          expectLater(ds.addCuentaBancaria(c), throwsA(isA<ArgumentError>().having((e) => '${e.message}', 'msg', contains(motivo))));
      await rechaza(_transferencia(cuenta: '0134123'), '20 dígitos');
      await rechaza(_transferencia(cuenta: '01020001234567890123'), 'código de Banesco es 0134');
      await rechaza(_transferencia(), 'ya está registrada');
      await rechaza(_pagoMovil(telefono: '02121234567'), 'celular');
      await rechaza(_pagoMovil(), 'ya está registrado');
      await rechaza(_transferencia(cuenta: '01340001234567890999', titular: ' '), 'titular');
      expect(servidor.enviados.length, antes);
    });

    test('si Sheets no confirma: alta, edición y baja se revierten', () async {
      final (ds, servidor) = await _servicio();
      final t = await ds.addCuentaBancaria(_transferencia());
      servidor.rechazar('sin red');
      await expectLater(ds.addCuentaBancaria(_pagoMovil()), throwsA(isA<StateError>()));
      await expectLater(ds.updateCuentaBancaria(t.copyWith(activa: false)), throwsA(isA<StateError>()));
      await expectLater(ds.deleteCuentaBancaria(t.id), throwsA(isA<StateError>()));
      expect(ds.cuentasBancarias, [t]);
    });
  });

  group('DatosBancariosCubit', () {
    test('filtra por tipo, inactiva y elimina', () async {
      final (ds, _) = await _servicio();
      await ds.addCuentaBancaria(_transferencia());
      await ds.addCuentaBancaria(_pagoMovil());
      final cubit = DatosBancariosCubit(dataService: ds);
      expect(cubit.state.cantidad(TipoCuentaBancaria.pagoMovil), 1);
      cubit.filtrarPorTipo(TipoCuentaBancaria.pagoMovil);
      expect(cubit.state.filtradas.single.telefono, '04121234567');
      final pm = cubit.state.filtradas.single;
      await cubit.cambiarEstado(pm, activa: false);
      expect(ds.cuentasBancarias.firstWhere((c) => c.id == pm.id).activa, isFalse);
      expect(cubit.state.cuentas.last.id, pm.id, reason: 'las inactivas van al final');
      await cubit.eliminar(pm);
      expect(cubit.state.cuentas, hasLength(1));
      await cubit.close();
    });
  });

  group('CuentaBancariaFormCubit', () {
    test('transferencia: valida y guarda normalizada', () async {
      final (ds, _) = await _servicio();
      final cubit = CuentaBancariaFormCubit(dataService: ds);
      expect(cubit.state.bancos.map((b) => b.nombre), isNot(contains('Banco Cerrado')), reason: 'sin bancos inactivos');
      await cubit.guardar(titular: '', documento: '1', numeroCuenta: '123');
      expect(cubit.state.errores.keys,
          containsAll([CampoCuenta.banco, CampoCuenta.titular, CampoCuenta.documento, CampoCuenta.numeroCuenta, CampoCuenta.modalidad]));
      cubit.elegirBanco('bn00000008');
      cubit.elegirModalidad(ModalidadCuenta.corriente);
      await cubit.guardar(titular: 'Banesco', documento: 'J-07013380-5', numeroCuenta: '0102 0001 23 4567890123');
      expect(cubit.state.errores[CampoCuenta.numeroCuenta], contains('empiezan con 0134'));
      await cubit.guardar(titular: 'Estilo Neutral C.A.', documento: 'J-07013380-5', numeroCuenta: '0134-0001-23-4567890123');
      expect(cubit.state.guardada, isTrue);
      final c = ds.cuentasBancarias.single;
      expect((c.documento, c.numeroCuenta), ('070133805', '01340001234567890123'));
      await cubit.close();
    });

    test('pago móvil: código + 7 dígitos; editar conserva el ID', () async {
      final (ds, servidor) = await _servicio();
      final cubit = CuentaBancariaFormCubit(dataService: ds)
        ..elegirTipo(TipoCuentaBancaria.pagoMovil)
        ..elegirBanco('bn00000001')
        ..elegirTipoDocumento('V')
        ..elegirCodigoTelefono('0412');
      await cubit.guardar(titular: 'Ana', documento: '12.345.678', numeroTelefono: '12345');
      expect(cubit.state.errores.keys, [CampoCuenta.telefono]);
      await cubit.guardar(titular: 'Ana', documento: '12.345.678', numeroTelefono: '1234567');
      final pm = ds.cuentasBancarias.single;
      expect(pm.telefono, '04121234567');
      await cubit.close();

      final edicion = CuentaBancariaFormCubit(dataService: ds, cuenta: pm);
      expect(edicion.state.codigoTelefono, '0412');
      await edicion.guardar(titular: 'Ana María', documento: '12345678', numeroTelefono: '1234567');
      expect(servidor.enviados.last['id'], pm.id);
      expect(ds.cuentasBancarias.single.titular, 'Ana María');
      await edicion.close();
    });
  });

  testWidgets('la pantalla y el formulario se ven en pantalla chica', (tester) async {
    tester.view.physicalSize = const Size(392 * 2.8, 800 * 2.8);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    late SheetsDataService ds;
    await tester.runAsync(() async {
      (ds, _) = await _servicio(inicializar: false);
      ds.setCurrentOrganizacion(organizacionDePrueba);
      await ds.addCuentaBancaria(_transferencia(titular: 'Un titular con un nombre bastante largo para la tarjeta C.A.'));
      await ds.addCuentaBancaria(_pagoMovil());
    });
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: DatosBancariosPage(dataService: ds)));
    await tester.pump();
    expect(find.text('Todos (2)'), findsOneWidget);
    expect(find.text('0134-0001-23-4567890123'), findsOneWidget);
    expect(find.text('0412-1234567'), findsOneWidget);
    await tester.tap(find.text('Editar').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar dato bancario'), findsOneWidget);
    await tester.tap(find.text('Pago móvil').last);
    await tester.pumpAndSettle();
    expect(find.text('Teléfono'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
