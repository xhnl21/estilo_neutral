// Análisis estático compartido por los tests de estándar (ver
// docs/estandar-hojas.md). Lee el código fuente; no ejecuta la app.
import 'dart:io';

const servicioPath = 'lib/shared/google_sheets/sheets_data_service.dart';
const scriptPath = 'google_apps_script.js';

/// Métodos autorizados a llamar directo a `_postToAppsScript` / `_crearEnServidor`.
const helpersDeEscritura = {
  '_postToAppsScript',
  '_crearEnServidor',
  '_sincronizarConRollback',
  '_crearConRollback',
};

final _cabeceraMetodo = RegExp(
  r'^  (?:static )?(?:Future<[^{]*?>|void|bool|int|double|String\??|[A-Z][\w<>?, ]*?) (\w+)\(',
);

/// Métodos del servicio que llaman directamente a `_postToAppsScript` o
/// `_crearEnServidor` (en vez de pasar por los helpers con rollback).
Set<String> escriturasDirectas() {
  final lineas = File(servicioPath).readAsLinesSync();
  final resultado = <String>{};
  String? metodo;
  for (final l in lineas) {
    final m = _cabeceraMetodo.firstMatch(l);
    if (m != null) metodo = m.group(1);
    final llama = RegExp(r'(?<![\w.])(_postToAppsScript|_crearEnServidor)\(').hasMatch(l);
    if (llama && metodo != null && !helpersDeEscritura.contains(metodo)) resultado.add(metodo);
  }
  return resultado;
}

/// (acción, hoja) de cada escritura que hace la app: llamadas al Apps Script
/// desde el servicio y operaciones de lotes atómicos en todo `lib/`.
Set<(String, String)> operacionesDeLaApp() {
  final ops = <(String, String)>{};
  final archivos = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final f in archivos) {
    final src = f.readAsStringSync();
    for (final m in RegExp(r"'action':\s*'(\w+)'[^}]{0,120}?'sheet':\s*'([^']+)'").allMatches(src)) {
      ops.add((m.group(1)!, m.group(2)!));
    }
    for (final m in RegExp(r"_crear(?:EnServidor|ConRollback)\(\s*'([^']+)'").allMatches(src)) {
      ops.add(('create', m.group(1)!));
    }
    for (final m in RegExp(r"BatchOperation\.(create|batchCreate|update)\(\s*sheet:\s*'([^']+)'").allMatches(src)) {
      ops.add((m.group(1) == 'update' ? 'update' : 'create', m.group(2)!));
    }
  }
  return ops;
}

String _cuerpoFuncionJs(String src, String nombre) {
  final i = src.indexOf('function $nombre(');
  if (i == -1) return '';
  final fin = src.indexOf('\nfunction ', i + 1);
  return src.substring(i, fin == -1 ? src.length : fin);
}

/// Hojas con manejador propio en doPost (atiende create/update/delete).
Set<String> hojasConManejadorPropio() {
  final src = File(scriptPath).readAsStringSync();
  return RegExp(r'if \(sheetName === "([^"]+)" && \[')
      .allMatches(src)
      .map((m) => m.group(1)!)
      .toSet();
}

/// (acción, hoja) que la app usa y el script no maneja con una rama explícita.
Set<(String, String)> operacionesSinRamaEnScript() {
  final src = File(scriptPath).readAsStringSync();
  final crear = _cuerpoFuncionJs(src, '_handleCreate');
  final actualizar = _cuerpoFuncionJs(src, '_handleUpdate');
  final propios = hojasConManejadorPropio();
  final faltan = <(String, String)>{};
  for (final (accion, hoja) in operacionesDeLaApp()) {
    if (propios.contains(hoja)) continue;
    final cuerpo = switch (accion) { 'create' => crear, 'update' => actualizar, _ => null };
    if (cuerpo != null && !cuerpo.contains('sheetName === "$hoja"')) faltan.add((accion, hoja));
  }
  return faltan;
}

/// Hojas que la app crea y cuyo ID no genera el servidor (sin ID_PREFIXES).
Set<String> hojasSinIdDelServidor() {
  final src = File(scriptPath).readAsStringSync();
  final bloque = RegExp(r'const ID_PREFIXES = \{([\s\S]*?)\};').firstMatch(src)!.group(1)!;
  final prefijos = RegExp(r'(?:"([^"]+)"|(\w+)):').allMatches(bloque).map((m) => m.group(1) ?? m.group(2)!).toSet();
  return operacionesDeLaApp()
      .where((op) => op.$1 == 'create')
      .map((op) => op.$2)
      .where((hoja) => !prefijos.contains(hoja))
      .toSet();
}

/// Modelos con `fromRow` (filas de una hoja) que no tienen campo `id`.
Set<String> modelosSinId() {
  final archivos = [
    ...Directory('lib/models').listSync(),
    ...Directory('lib/features').listSync(recursive: true),
  ].whereType<File>().where((f) => f.path.endsWith('.dart'));
  final sinId = <String>{};
  for (final f in archivos) {
    final src = f.readAsStringSync();
    for (final m in RegExp(r'factory (\w+)\.fromRow\(').allMatches(src)) {
      if (!src.contains(RegExp(r'final (?:String|CreditId) id;'))) sinId.add(m.group(1)!);
    }
  }
  return sinId;
}

/// Ocurrencias del usuario de auditoría inventado.
int usuariosDeAuditoriaInventados() {
  var total = 0;
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    total += RegExp(r"'(Antigravity Senior Agent|Operador App \(CRUD Móvil\)|Auditor Manual)'")
        .allMatches(f.readAsStringSync())
        .length;
  }
  return total;
}

/// Hojas que la app lee sin validar un encabezado que empiece con `id`.
Set<String> lecturasSinEncabezadoId() {
  final src = File(servicioPath).readAsStringSync();
  final sin = <String>{};
  for (final m in RegExp(r"safeFetch\(\s*'([^']+)',[^;]*?\)(?=,\s*\n|\s*\])", dotAll: true).allMatches(src)) {
    if (!RegExp(r"expectedHeaders:\s*const\s*\[\s*'id'").hasMatch(m.group(0)!)) sin.add(m.group(1)!);
  }
  return sin;
}
