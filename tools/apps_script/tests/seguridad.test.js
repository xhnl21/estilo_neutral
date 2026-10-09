// Tests del Apps Script con Node (sin Google): `node tools/apps_script/tests/seguridad.test.js`
const fs = require('fs');
const vm = require('vm');
const crypto = require('crypto');
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
    getDataRange: () => ({ getValues: () => sh.filas.map((f) => f.slice()), getDisplayValues: () => sh.filas.map((f) => f.map(String)) }),
    getRange: (r, c, nr = 1, nc = 1) => {
      if (typeof r === 'string') return { setNumberFormat() {}, setDataValidation() {}, setNote() {} };
      return {
        getValues: () => Array.from({ length: nr }, (_, i) => Array.from({ length: nc }, (_, j) => ((sh.filas[r - 1 + i] || [])[c - 1 + j]) ?? '')),
        getValue: () => ((sh.filas[r - 1] || [])[c - 1]) ?? '',
        getDisplayValues: () => Array.from({ length: nr }, (_, i) => Array.from({ length: nc }, (_, j) => String(((sh.filas[r - 1 + i] || [])[c - 1 + j]) ?? ''))),
        setValues: (vals) => vals.forEach((fila, i) => { const f = sh.filas[r - 1 + i] || (sh.filas[r - 1 + i] = []); fila.forEach((v, j) => (f[c - 1 + j] = v)); }),
        setValue: (v) => { (sh.filas[r - 1] || (sh.filas[r - 1] = []))[c - 1] = v; },
        setNumberFormat() {}, setDataValidation() {},
      };
    },
  };
  return sh;
}

/** tokens: token → respuesta de tokeninfo (o null = inválido). */
function contexto({ props = {}, tokens = {} } = {}) {
  const hojas = {
    usuarios: hoja('usuarios', [['id', 'email', 'nombre', 'tipo_documento', 'cedula', 'status'], ['u1', 'ana@x.com', 'Ana', 'V', '1', ''], ['u2', 'eli@x.com', 'Eli', 'V', '2', 'inactivo']]),
    usuario_organizacion: hoja('usuario_organizacion', [['id', 'usuario_email', 'organizacion_id'], ['uo1', 'ana@x.com', 'org1'], ['uo2', 'eli@x.com', 'org1']]),
    organizaciones: hoja('organizaciones', [['id', 'nombre'], ['org1', 'Centro']]),
    clientes: hoja('clientes', [['id', 'nombre'], ['c1', 'Cami']]),
    secreta: hoja('secreta', [['id'], ['x']]),
    audit_log: hoja('audit_log', [['id']]),
  };
  const cache = {};
  const consultas = [];
  const ss = { getSheetByName: (n) => hojas[n] || null, insertSheet: (n) => (hojas[n] = hoja(n, [])), getId: () => 'ID-SECRETO', getName: () => 'X', getSheets: () => Object.values(hojas) };
  const ctx = {
    console,
    SpreadsheetApp: { flush() {}, getActiveSpreadsheet: () => ss, openById: () => ss, newDataValidation: () => ({ requireValueInList() { return this; }, build() { return {}; } }) },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; } }) },
    CacheService: { getScriptCache: () => ({ get: (k) => cache[k] ?? null, put: (k, v) => { cache[k] = v; } }) },
    Utilities: {
      formatDate: (d) => d.toISOString().slice(0, 10),
      base64EncodeWebSafe: (x) => Buffer.from(x).toString('base64url'),
      computeDigest: (_, t) => [...crypto.createHash('sha256').update(t).digest()],
      DigestAlgorithm: { SHA_256: 'sha256' },
    },
    ContentService: { createTextOutput: (t) => ({ setMimeType: () => t }), MimeType: { JSON: 'json' } },
    UrlFetchApp: {
      fetch: (url) => {
        consultas.push(url);
        const token = decodeURIComponent(url.split('access_token=')[1] || '');
        const info = tokens[token];
        return info ? { getResponseCode: () => 200, getContentText: () => JSON.stringify(info) } : { getResponseCode: () => 400, getContentText: () => '{"error":"invalid_token"}' };
      },
    },
    MailApp: {}, ScriptApp: {}, DriveApp: {}, Logger: { log() {} },
  };
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  const post = (o) => JSON.parse(vm.runInContext(`doPost({postData:{contents: ${JSON.stringify(JSON.stringify(o))}}})`, ctx));
  return { ctx, hojas, post, props, consultas };
}

let fallas = 0;
const check = (cond, msg) => { console.log((cond ? 'OK   ' : 'FAIL ') + msg); if (!cond) fallas++; };
const ana = { email: 'ana@x.com', email_verified: 'true', expires_in: '3500', azp: 'cliente-app.apps.googleusercontent.com' };
const crear = (extra) => Object.assign({ action: 'create', sheet: 'organizaciones', data: { id: 'org9', nombre: 'Nueva' } }, extra);

{ // doGet no expone la hoja
  const { ctx } = contexto();
  const r = JSON.parse(vm.runInContext('doGet({})', ctx));
  check(r.status === 'ok' && !('spreadsheetId' in r) && !('sheets' in r), 'doGet: sin ID de la hoja ni nombres de hojas -> ' + JSON.stringify(r));
}
{ // identidad verificada: manda el email del token, no el declarado
  const { post, hojas, consultas } = contexto({ tokens: { 'tok-ana': ana } });
  const r = post(crear({ access_token: 'tok-ana', usuario_sesion: 'eli@x.com' }));
  check(r.status === 'success', 'token válido: la escritura pasa aunque el email declarado sea de un inactivo (se usa el del token) -> ' + JSON.stringify(r));
  post(crear({ access_token: 'tok-ana', data: { id: 'org10', nombre: 'Otra' } }));
  check(consultas.length === 1, 'token: se verifica con Google una vez y después se usa la caché');
  const malo = post(crear({ access_token: 'tok-falso' }));
  check(malo.status === 'error' && malo.code === 'no_autenticado', 'token inválido o vencido: se rechaza');
  check(hojas.organizaciones.filas.length === 4, 'el rechazo no escribe nada');
  const sinEmail = contexto({ tokens: { 't': { email_verified: 'false', email: 'ana@x.com', expires_in: '100' } } });
  check(sinEmail.post(crear({ access_token: 't' })).code === 'no_autenticado', 'token sin email verificado: se rechaza');
}
{ // token obligatorio por defecto; vuelta atrás con AUTENTICACION_OBLIGATORIA = no
  const estricto = contexto({ tokens: { 'tok-ana': ana } });
  const r = estricto.post(crear({ usuario_sesion: 'ana@x.com' }));
  check(r.code === 'no_autenticado' && /Actualizá la app/.test(r.message), 'por defecto: sin token se rechaza aunque declare un usuario válido');
  check(estricto.hojas.organizaciones.filas.length === 2, 'por defecto: el rechazo no escribe nada');
  check(estricto.post(crear({ access_token: 'tok-ana' })).status === 'success', 'por defecto: con token pasa');
  check(estricto.post({ action: 'enviar_notificacion', usuario_sesion: 'ana@x.com', data: {} }).code === 'no_autenticado', 'por defecto: también las acciones de notificaciones exigen token');
  const atras = contexto({ props: { AUTENTICACION_OBLIGATORIA: 'no' } });
  check(atras.post(crear({ usuario_sesion: 'ana@x.com' })).status === 'success', 'vuelta atrás (= no): sin token se acepta el declarado');
  check(atras.post(crear({ usuario_sesion: 'eli@x.com', data: { id: 'o2', nombre: 'Y' } })).code === 'acceso_revocado', 'vuelta atrás: el declarado inactivo sigue rechazado');
}
{ // clientes OAuth permitidos
  const a = contexto({ tokens: { 'tok-ana': ana } });
  a.post(crear({ access_token: 'tok-ana' }));
  check(a.props.OAUTH_CLIENTES_VISTOS === 'cliente-app.apps.googleusercontent.com', 'sin lista: anota el cliente OAuth visto');
  const b = contexto({ props: { OAUTH_CLIENTES_PERMITIDOS: 'otro-cliente' }, tokens: { 'tok-ana': ana } });
  const rb = b.post(crear({ access_token: 'tok-ana' }));
  check(rb.code === 'no_autenticado' && /cliente-app\.apps\.googleusercontent\.com/.test(rb.message), 'con lista: un token de otra app se rechaza y el mensaje dice qué cliente es');
  check(b.props.OAUTH_CLIENTES_VISTOS === 'cliente-app.apps.googleusercontent.com', 'con lista: el cliente rechazado también queda anotado');
  const c = contexto({ props: { OAUTH_CLIENTES_PERMITIDOS: 'x, cliente-app.apps.googleusercontent.com' }, tokens: { 'tok-ana': ana } });
  check(c.post(crear({ access_token: 'tok-ana' })).status === 'success', 'con lista: el cliente de la app pasa');
}
{ // límite de escrituras por minuto
  const { post } = contexto({ tokens: { 'tok-ana': ana } });
  let ultimo;
  for (let i = 0; i < 91; i++) ultimo = post({ action: 'update', sheet: 'organizaciones', id: 'org1', access_token: 'tok-ana', data: { nombre: 'Centro ' + i } });
  check(ultimo.code === 'demasiadas_escrituras', 'límite: la escritura 91 del minuto se rechaza');
}
{ // leer_hojas
  const { post } = contexto({ tokens: { 'tok-ana': ana, 'tok-eli': Object.assign({}, ana, { email: 'eli@x.com' }) } });
  const r = post({ action: 'leer_hojas', access_token: 'tok-ana', hojas: ['clientes', 'usuarios', 'secreta'] });
  check(r.status === 'success' && r.hojas.clientes[1][1] === 'Cami' && r.hojas.usuarios && !r.hojas.secreta, 'leer_hojas: devuelve las hojas permitidas (no otras) -> ' + Object.keys(r.hojas || {}));
  check(post({ action: 'leer_hojas', usuario_sesion: 'ana@x.com', hojas: ['clientes'] }).code === 'no_autenticado', 'leer_hojas: sin token se rechaza (aunque declare un email)');
  check(post({ action: 'leer_hojas', access_token: 'tok-eli', hojas: ['clientes'] }).code === 'acceso_revocado', 'leer_hojas: un usuario inactivo no lee');
  check(post({ action: 'leer_hojas', access_token: 'tok-ana', hojas: [] }).status === 'error', 'leer_hojas: hay que pedir al menos una hoja');
}
{ // válvula: leer por gviz
  const { post } = contexto({ props: { LECTURA_POR_SERVIDOR: 'no' }, tokens: { 'tok-ana': ana } });
  check(post({ action: 'leer_hojas', access_token: 'tok-ana', hojas: ['clientes'] }).code === 'lectura_desactivada', 'LECTURA_POR_SERVIDOR = no: la app vuelve a gviz');
}
{ // audit_log: solo las últimas filas
  const { post, hojas } = contexto({ tokens: { 'tok-ana': ana } });
  hojas.audit_log.filas = [['id', 'fecha']].concat(Array.from({ length: 620 }, (_, i) => ['al' + String(i + 1).padStart(8, '0'), 'f']));
  const r = post({ action: 'leer_hojas', access_token: 'tok-ana', hojas: ['audit_log'] });
  const filas = r.hojas.audit_log;
  check(filas.length === 501 && filas[0][0] === 'id' && filas[1][0] === 'al00000121' && filas[500][0] === 'al00000620', 'audit_log: encabezado + las últimas 500 filas');
}
{ // lectura en lote con la API de Sheets (servicio avanzado)
  const c = contexto({ tokens: { 'tok-ana': ana } });
  c.hojas['metodo pago'] = hoja('metodo pago', [['id', 'nombre', 'status'], ['mp1', 'Zelle', 'activo']]);
  c.hojas.audit_log.filas = [['id', 'fecha']].concat(Array.from({ length: 600 }, (_, i) => ['al' + (i + 1), 'f']));
  const pedidos = [];
  c.ctx.Sheets = { Spreadsheets: { Values: { batchGet: (id, o) => {
    pedidos.push(o.ranges);
    return { valueRanges: o.ranges.map((r) => {
      if (r === "'clientes'!A:ZZ") return { values: [['id', 'nombre', 'extra'], ['c1', 'Cami']] }; // la API omite celdas vacías finales
      if (r === "'metodo pago'!A:ZZ") return { values: [['id', 'nombre', 'status'], ['mp1', 'Zelle', 'activo']] };
      if (r === "'audit_log'!1:1") return { values: [['id', 'fecha']] };
      if (r === "'audit_log'!102:601") return { values: Array.from({ length: 500 }, (_, i) => ['al' + (i + 101), 'f']) };
      return {};
    }) };
  } } } };
  const r = c.post({ action: 'leer_hojas', access_token: 'tok-ana', hojas: ['clientes', 'metodo pago', 'audit_log'] });
  check(r.via === 'batchGet' && pedidos.length === 1, 'lote: una sola llamada a la API -> ' + r.via + ' ' + JSON.stringify(pedidos[0]));
  check(JSON.stringify(r.hojas.clientes[1]) === JSON.stringify(['c1', 'Cami', '']), 'lote: completa las filas al ancho del encabezado');
  check(r.hojas['metodo pago'][1][1] === 'Zelle', 'lote: nombres de hoja con espacios');
  check(r.hojas.audit_log.length === 501 && r.hojas.audit_log[500][0] === 'al600', 'lote: audit_log con encabezado + últimas 500');
  check(typeof r.ms === 'number', 'lote: informa cuánto tardó');
}
process.exit(fallas ? 1 : 0);
