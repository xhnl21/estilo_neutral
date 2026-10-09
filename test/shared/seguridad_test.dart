import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_config.dart';
import '../test_servidor.dart';

const _org = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';

/// Lo que devolvería el Apps Script: las hojas de acceso y un cliente.
final _hojas = <String, List<List<String>>>{
  'usuarios': [
    ['id', 'email', 'nombre', 'tipo_documento', 'cedula', 'status'],
    ['u00000001', 'xhnl21@gmail.com', 'Xavier', 'V', '1', 'activo'],
  ],
  'organizaciones': [
    ['id', 'nombre', 'email'],
    [_org, 'Estilo Neutral', ''],
  ],
  'usuario_organizacion': [
    ['id', 'usuario_email', 'organizacion_id'],
    ['uo00000001', 'xhnl21@gmail.com', _org],
  ],
  'clientes': [
    ['id', 'nombre', 'telefono', 'email', 'saldo_deuda_usd', 'fecha_registro', 'organizacion_id', 'tipo_documento', 'cedula', 'status'],
    ['c00000077', 'Cliente del servidor', '', '', '0', '2026-10-09', _org, 'V', '123', 'activo'],
  ],
};

void main() {
  test('el login de Google pide solo el email (no Sheets ni Drive del usuario)', () {
    expect(SheetsConfig.scopes, ['email']);
  });

  test('cada pedido al Apps Script lleva el token de la sesión; sin sesión, no', () async {
    final (ds, servidor) = await servicioConServidor();
    String? token = 'ya29.token-de-prueba';
    ds.proveedorToken = () async => token;
    await ds.addOrganizacion('Con token');
    expect(servidor.enviados.last['access_token'], 'ya29.token-de-prueba');
    token = null;
    await ds.addOrganizacion('Sin token');
    expect(servidor.enviados.last.containsKey('access_token'), isFalse);
  });

  test('con sesión, la carga lee todas las hojas en UN pedido al Apps Script (sin gviz)', () async {
    final (ds, servidor) = await servicioConServidor(inicializar: false);
    servidor.hojasServidor = _hojas;
    ds.proveedorToken = () async => 'tok';
    await ds.initialize();
    final lecturas = servidor.enviados.where((e) => e['action'] == 'leer_hojas').toList();
    expect(lecturas, hasLength(1));
    expect((lecturas.single['hojas'] as List), containsAll(['clientes', 'usuarios', 'organizaciones']));
    expect(servidor.lecturas, isEmpty, reason: 'nada por gviz');
    ds.setCurrentOrganizacion(_org);
    expect(ds.clientes.map((c) => c.id), contains('c00000077'));
    expect(ds.lastSync, isNotNull);
  });

  test('si el Apps Script no puede (script viejo), vuelve a gviz', () async {
    final (ds, servidor) = await servicioConServidor(inicializar: false);
    ds.proveedorToken = () async => 'tok';
    await ds.initialize();
    expect(servidor.enviados.where((e) => e['action'] == 'leer_hojas'), hasLength(1));
    expect(servidor.lecturas['clientes'], 1, reason: 'cayó a gviz');
  });

  test('sin sesión de Google no se pide leer_hojas', () async {
    final (ds, servidor) = await servicioConServidor(inicializar: false);
    ds.proveedorToken = () async => null;
    await ds.initialize();
    expect(servidor.enviados.where((e) => e['action'] == 'leer_hojas'), isEmpty);
  });

  test('si el servidor responde acceso_revocado al leer, se marca para cerrar la sesión', () async {
    final (ds, servidor) = await servicioConServidor();
    ds.proveedorToken = () async => 'tok';
    servidor.respuesta = '{"status":"error","code":"acceso_revocado","message":"La cuenta xhnl21@gmail.com está inactiva."}';
    await ds.releerAcceso();
    expect(ds.accesoRevocadoEnServidor, contains('inactiva'));
  });

  test('releer el acceso con sesión usa el Apps Script (funciona con la hoja privada)', () async {
    final (ds, servidor) = await servicioConServidor();
    servidor.hojasServidor = _hojas;
    ds.proveedorToken = () async => 'tok';
    servidor.lecturas.clear();
    await ds.releerAcceso();
    final pedido = servidor.enviados.lastWhere((e) => e['action'] == 'leer_hojas');
    expect(pedido['hojas'], unorderedEquals(['usuarios', 'organizaciones', 'usuario_organizacion']));
    expect(servidor.lecturas, isEmpty);
    expect(ds.resolverAcceso('xhnl21@gmail.com').organizacionId, _org);
  });

  test('la app no usa datos de ejemplo: si no puede leer, queda vacía (y lo dice)', () async {
    final (ds, servidor) = await servicioConServidor(datosDeRespaldo: false);
    expect(ds.clientes, isEmpty);
    expect(ds.usuarios, isEmpty);
    expect(ds.accesoCargado, isFalse);
    expect(ds.errorMessage, isNotNull);
    expect(servidor.lecturas, isNotEmpty);
  });

  test('sin sesión de Google, la app no lee nada al iniciar (la hoja es privada)', () async {
    final (ds, servidor) = await servicioConServidor(inicializar: false, datosDeRespaldo: false);
    ds.proveedorToken = () async => null;
    await ds.initialize(cargarSinSesion: false);
    expect(servidor.lecturas, isEmpty);
    expect(servidor.enviados, isEmpty);
    // Con la sesión, la carga la dispara el login.
    servidor.hojasServidor = _hojas;
    ds.proveedorToken = () async => 'tok';
    await ds.esperarCargaInicial();
    expect(servidor.enviados.where((e) => e['action'] == 'leer_hojas'), hasLength(1));
    expect(ds.accesoCargado, isTrue);
  });

  test('si el servidor rechaza la lectura, el error dice por qué (no "hacé pública la hoja")', () async {
    final (ds, servidor) = await servicioConServidor(inicializar: false, datosDeRespaldo: false);
    ds.proveedorToken = () async => 'tok';
    servidor.respuesta = '{"status":"error","code":"no_autenticado","message":"Sesión de Google emitida para otra aplicación (cliente X)."}';
    await ds.initialize();
    expect(ds.ultimoErrorLectura, contains('otra aplicación'));
    expect(ds.errorMessage, 'No se pudieron cargar los datos: Sesión de Google emitida para otra aplicación (cliente X).');
    expect(ds.errorMessage, isNot(contains('Compartir')));
  });
}
