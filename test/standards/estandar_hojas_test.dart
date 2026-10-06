// Guardas del estándar de hojas y escrituras (docs/estandar-hojas.md).
//
// Cada test compara lo que hay en el código contra una lista de excepciones.
// - Si aparece un incumplimiento NUEVO, el test falla: hay que corregirlo,
//   no agregarlo a la lista.
// - Si se corrige uno PENDIENTE, el test también falla hasta quitarlo de la
//   lista: así la lista solo puede achicarse.
import 'package:flutter_test/flutter_test.dart';
import 'estandar_analisis.dart';

/// Escrituras que no pasan por los helpers con rollback: ninguna desde la
/// etapa 3. No agregues: usá `_crearConRollback` / `_sincronizarConRollback`.
const _escriturasDirectasPendientes = <String>{};

/// Permanente: `organizaciones` usa un UUID v4 generado en el cliente, que no
/// colisiona entre dispositivos.
const _hojasConIdDelClientePermitidas = {'organizaciones'};

/// Hojas que la app crea sin ID generado por el servidor: ninguna. No agregues.
const _hojasSinIdDelServidorPendientes = <String>{};

/// Modelos de hojas sin columna `id`: ninguno desde la etapa 2. No agregues.
const _modelosSinIdPendientes = <String>{};

/// Usuarios de auditoría inventados: ninguno. No agregues.
const _usuariosInventadosPendientes = 0;

void _sinNuevosNiResueltos<T>(String regla, Set<T> actual, Set<T> pendientes) {
  final nuevos = actual.difference(pendientes);
  final resueltos = pendientes.difference(actual);
  expect(nuevos, isEmpty,
      reason: '$regla — incumplimientos nuevos: corregilos siguiendo docs/estandar-hojas.md.');
  expect(resueltos, isEmpty,
      reason: '$regla — ya están resueltos: quitalos de la lista de pendientes de este test.');
}

void main() {
  test('R4 · solo los helpers con rollback escriben en Sheets', () {
    _sinNuevosNiResueltos('R4', escriturasDirectas(), _escriturasDirectasPendientes);
  });

  test('R2 · toda hoja que la app crea o edita tiene rama explícita en el script', () {
    expect(operacionesSinRamaEnScript(), isEmpty,
        reason: 'Agregá la rama `sheetName === "<hoja>"` en _handleCreate/_handleUpdate de '
            'google_apps_script.js (el genérico Object.values() escribe columnas en cualquier orden '
            'y convierte textos en números).');
  });

  test('R1 · los IDs de las hojas que crea la app los genera el servidor', () {
    final actual = hojasSinIdDelServidor().difference(_hojasConIdDelClientePermitidas);
    _sinNuevosNiResueltos('R1', actual, _hojasSinIdDelServidorPendientes);
  });

  test('R1 · toda hoja tiene columna id', () {
    _sinNuevosNiResueltos('R1', modelosSinId(), _modelosSinIdPendientes);
  });

  test('R1 · toda lectura valida que el encabezado empiece con id', () {
    expect(lecturasSinEncabezadoId(), isEmpty,
        reason: 'Agregá expectedHeaders (empezando por \'id\') al safeFetch de la hoja: sin eso, '
            'una hoja con columnas corridas se lee en silencio con datos mezclados.');
  });

  test('R7 · no hay usuarios de auditoría inventados', () {
    final actual = usuariosDeAuditoriaInventados();
    expect(actual, lessThanOrEqualTo(_usuariosInventadosPendientes),
        reason: 'R7 — no inventes un autor: usá currentUsuarioEmail.');
    expect(actual, _usuariosInventadosPendientes,
        reason: 'R7 — bajaron a $actual: actualizá _usuariosInventadosPendientes.');
  });
}
