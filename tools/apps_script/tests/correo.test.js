// Tests del Apps Script con Node (sin Google): `node tools/apps_script/tests/correo.test.js`
const fs = require('fs');
const vm = require('vm');
const src = fs.readFileSync(process.argv[2] || require('path').join(__dirname, '../../../google_apps_script.js'), 'utf8');

function hoja(nombre, filas) {
  const sh = {
    filas,
    getName: () => nombre,
    getLastRow: () => sh.filas.length,
    getLastColumn: () => Math.max(...sh.filas.map((f) => f.length), 1),
    appendRow: (v) => sh.filas.push(v.slice()),
    deleteRow: (r) => sh.filas.splice(r - 1, 1),
    setFrozenRows: () => {},
    getDataRange: () => ({ getValues: () => sh.filas.map((f) => f.slice()) }),
    getRange: (r, c, nr = 1, nc = 1) => {
      if (typeof r === 'string') return { setNumberFormat() {}, setDataValidation() {}, setNote() {} };
      return {
        getValues: () => Array.from({ length: nr }, (_, i) => Array.from({ length: nc }, (_, j) => ((sh.filas[r - 1 + i] || [])[c - 1 + j]) ?? '')),
        getValue: () => ((sh.filas[r - 1] || [])[c - 1]) ?? '',
        setValues: (vals) => vals.forEach((fila, i) => { const f = sh.filas[r - 1 + i] || (sh.filas[r - 1 + i] = []); fila.forEach((v, j) => (f[c - 1 + j] = v)); }),
        setValue: (v) => { (sh.filas[r - 1] || (sh.filas[r - 1] = []))[c - 1] = v; },
        setNumberFormat() {}, setDataValidation() {},
      };
    },
  };
  return sh;
}

function contexto({ cupo = 100, fallaCon = null } = {}) {
  const enc = ['id', 'nombre', 'telefono', 'email', 'saldo_deuda_usd', 'fecha_registro', 'organizacion_id', 'tipo_documento', 'cedula', 'status'];
  const hojas = {
    usuarios: hoja('usuarios', [['id', 'email', 'nombre'], ['u1', 'ana@x.com', 'Ana'], ['u2', 'bea@x.com', 'Bea']]),
    usuario_organizacion: hoja('usuario_organizacion', [['id', 'usuario_email', 'organizacion_id'], ['uo1', 'ana@x.com', 'org1'], ['uo2', 'bea@x.com', 'org2']]),
    organizaciones: hoja('organizaciones', [['id', 'nombre', 'email'], ['org1', 'Centro', 'centro@tienda.com'], ['org2', 'Este', '']]),
    clientes: hoja('clientes', [enc,
      ['c1', 'Cami', '', 'cami@x.com', 0, '', 'org1', 'V', '1', 'activo'],
      ['c2', 'Dani', '', 'DANI@x.com', 0, '', 'org1', 'V', '2', ''],
      ['c3', 'Sin correo', '', '', 0, '', 'org1', 'V', '3', 'activo'],
      ['c4', 'Inactivo', '', 'ina@x.com', 0, '', 'org1', 'V', '4', 'inactivo'],
      ['c5', 'Otra org', '', 'otra@x.com', 0, '', 'org2', 'V', '5', 'activo'],
      ['c6', 'Mal correo', '', 'no-es-correo', 0, '', 'org1', 'V', '6', 'activo']]),
    audit_log: hoja('audit_log', [['id']]),
  };
  const enviados = [];
  let restantes = cupo;
  const ss = { getSheetByName: (n) => hojas[n] || null, insertSheet: (n) => (hojas[n] = hoja(n, [])) };
  const ctx = {
    console,
    SpreadsheetApp: { flush() {}, getActiveSpreadsheet: () => ss, openById: () => ss, newDataValidation: () => ({ requireValueInList() { return this; }, build() { return {}; } }) },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    // Estos tests simulan pedidos sin token: vuelta atrás AUTENTICACION_OBLIGATORIA = no.
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => (k === 'AUTENTICACION_OBLIGATORIA' ? 'no' : null) }) },
    CacheService: { getScriptCache: () => ({ get: () => null, put() {} }) },
    Utilities: { formatDate: (d) => d.toISOString().slice(0, 10), base64EncodeWebSafe: (x) => Buffer.from(x).toString('base64') },
    ContentService: { createTextOutput: (t) => ({ setMimeType: () => t }), MimeType: { JSON: 'json' } },
    MailApp: {
      getRemainingDailyQuota: () => restantes,
      sendEmail: (o) => { if (o.to === fallaCon) throw new Error('Servicio no disponible'); restantes--; enviados.push(o); },
    },
    UrlFetchApp: {}, ScriptApp: {}, DriveApp: {}, Logger: { log() {} },
  };
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  const post = (o) => JSON.parse(vm.runInContext(`doPost({postData:{contents: ${JSON.stringify(JSON.stringify(Object.assign({ usuario_sesion: 'ana@x.com' }, o)))}}})`, ctx));
  return { hojas, post, enviados };
}

let fallas = 0;
const check = (cond, msg) => { console.log((cond ? 'OK   ' : 'FAIL ') + msg); if (!cond) fallas++; };
const correo = (extra) => ({ action: 'enviar_correo', data: Object.assign({ asunto: 'Día de pago', cuerpo: 'Hoy se realizó el pago.\nGracias.', todos: true }, extra) });

{ // email de la organización
  const { hojas, post } = contexto();
  check(post({ action: 'update', sheet: 'organizaciones', id: 'org1', data: { email: ' Este@Tienda.com ' } }).status === 'success' && hojas.organizaciones.filas[1][2] === 'este@tienda.com', 'organización: guarda el email normalizado');
  check(post({ action: 'update', sheet: 'organizaciones', id: 'org2', data: { email: 'x@t.com' } }).code === 'no_autorizado', 'separación: no se edita una organización ajena');
  check(post({ action: 'update', sheet: 'organizaciones', id: 'org1', data: { email: 'mal' } }).status === 'error', 'organización: email inválido se rechaza');
  const nueva = post({ action: 'create', sheet: 'organizaciones', data: { id: 'org3', nombre: 'Norte', email: 'norte@tienda.com' } });
  check(nueva.status === 'success' && hojas.organizaciones.filas[3][2] === 'norte@tienda.com', 'organización: alta con email');
  const hojaVieja = contexto();
  hojaVieja.hojas.organizaciones.filas[0] = ['id', 'nombre'];
  hojaVieja.post({ action: 'update', sheet: 'organizaciones', id: 'org1', data: { email: 'c@t.com' } });
  check(hojaVieja.hojas.organizaciones.filas[0][2] === 'email', 'organización: agrega el encabezado "email" si la hoja no lo tenía');
}
{ // envío a todos los clientes de la organización
  const { hojas, post, enviados } = contexto();
  const r = post(correo());
  check(r.status === 'success' && r.enviados === 2 && r.restantes === 98, 'todos: envía solo a activos de la organización con email válido -> ' + JSON.stringify(r));
  check(enviados.map((e) => e.to).sort().join(',') === 'cami@x.com,dani@x.com', 'todos: destinatarios correctos (uno por correo)');
  const e = enviados[0];
  check(e.name === 'Centro' && e.replyTo === 'centro@tienda.com' && e.subject === 'Día de pago', 'remitente: nombre de la organización y Responder-a su correo');
  check(/Para responder, escribí a centro@tienda\.com/.test(e.body) && /Hoy se realizó el pago\.<br>Gracias\./.test(e.htmlBody), 'cuerpo: texto + pie, y HTML con saltos de línea');
  const fila = hojas.correos.filas[1];
  check(fila[0] === 'co00000001' && fila[3] === 'org1' && fila[6] === 'c1, c2' && fila[7] === 2 && fila[9] === 'ENVIADO', 'registro en la hoja "correos" -> ' + fila.join('|'));
}
{ // elegidos, validaciones, cupo y fallas
  const a = contexto();
  check(a.post(correo({ todos: false, cliente_ids: ['c2', 'c5', 'c3'] })).enviados === 1 && a.enviados[0].to === 'dani@x.com', 'elegidos: ignora clientes de otra organización o sin correo');
  check(/al menos un cliente/.test(a.post(correo({ todos: false, cliente_ids: [] })).message), 'elegidos: lista vacía se rechaza');
  check(/correo válido/.test(a.post(correo({ todos: false, cliente_ids: ['c3'] })).message), 'elegidos: sin correo válido se rechaza');
  check(/asunto/.test(a.post(correo({ asunto: '' })).message), 'asunto obligatorio');
  check(/mensaje/.test(a.post(correo({ cuerpo: 'x'.repeat(501) })).message), 'mensaje hasta 500');
  const sinCorreo = a.post(Object.assign(correo(), { usuario_sesion: 'bea@x.com' }));
  check(sinCorreo.code === 'organizacion_sin_correo' && /Organizaciones/.test(sinCorreo.message), 'organización sin correo: error claro');
  const b = contexto({ cupo: 1 });
  const c = b.post(correo());
  check(c.code === 'cupo_correo' && b.enviados.length === 0 && /1 correo más hoy/.test(c.message), 'cupo de Google insuficiente: no envía nada');
  const d = contexto({ fallaCon: 'cami@x.com' });
  const r = d.post(correo());
  check(r.status === 'success' && r.enviados === 1 && r.fallidos === 1 && /c1: /.test(d.hojas.correos.filas[1][10]), 'una falla no frena al resto y queda en el detalle');
  check(contexto().post({ action: 'enviar_correo', usuario_sesion: '', data: {} }).status === 'error', 'exige usuario de la sesión');
  const u = contexto({ cupo: 42 }).post({ action: 'uso_correo' });
  check(u.status === 'success' && u.restantes === 42, 'uso_correo: cupo restante de Google');
}
process.exit(fallas ? 1 : 0);
