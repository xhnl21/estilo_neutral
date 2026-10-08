// Tests del Apps Script con Node (sin Google): `node tools/apps_script/tests/datos_bancarios.test.js`
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

function contexto() {
  const hojas = {
    usuarios: hoja('usuarios', [['id', 'email', 'nombre'], ['u1', 'ana@x.com', 'Ana']]),
    usuario_organizacion: hoja('usuario_organizacion', [['id', 'usuario_email', 'organizacion_id'], ['uo1', 'ana@x.com', 'org1']]),
    organizaciones: hoja('organizaciones', [['id', 'nombre'], ['org1', 'Centro'], ['org2', 'Este']]),
    audit_log: hoja('audit_log', [['id']]),
  };
  const ss = { getSheetByName: (n) => hojas[n] || null, insertSheet: (n) => (hojas[n] = hoja(n, [])) };
  const ctx = {
    console,
    SpreadsheetApp: { flush() {}, getActiveSpreadsheet: () => ss, openById: () => ss, newDataValidation: () => ({ requireValueInList() { return this; }, build() { return {}; } }) },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    PropertiesService: { getScriptProperties: () => ({ getProperty: () => null }) },
    CacheService: { getScriptCache: () => ({ get: () => null, put() {} }) },
    Utilities: { formatDate: (d) => d.toISOString().slice(0, 10) },
    ContentService: { createTextOutput: (t) => ({ setMimeType: () => t }), MimeType: { JSON: 'json' } },
    UrlFetchApp: {}, ScriptApp: {}, DriveApp: {}, Logger: { log() {} },
  };
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  const post = (o) => JSON.parse(vm.runInContext(`doPost({postData:{contents: ${JSON.stringify(JSON.stringify(Object.assign({ usuario_sesion: 'ana@x.com' }, o)))}}})`, ctx));
  return { ctx, hojas, post };
}

let fallas = 0;
const check = (cond, msg) => { console.log((cond ? 'OK   ' : 'FAIL ') + msg); if (!cond) fallas++; };
const transferencia = (extra) => Object.assign({
  organizacion_id: 'org1', tipo: 'transferencia', banco_id: 'bn00000008', titular: 'Estilo Neutral C.A.',
  tipo_documento: 'J', documento: 'J-12345678-9', numero_cuenta: '0134-0001-23-4567890123', tipo_cuenta: 'corriente',
}, extra);
const pagoMovil = (extra) => Object.assign({
  organizacion_id: 'org1', tipo: 'pago_movil', banco_id: 'bn00000001', titular: 'Ana Pérez',
  tipo_documento: 'V', documento: '12.345.678', telefono: '+584121234567',
}, extra);

{ // catálogo de bancos
  const { ctx, hojas, post } = contexto();
  const r = post({ action: 'preparar_datos_bancarios' });
  const b = hojas.bancos.filas;
  check(r.status === 'success' && b.length === 27 && b[1][0] === 'bn00000001' && b[1][1] === "'0102" && b[8][2] === 'Banesco', 'bancos: la hoja nace con los bancos venezolanos -> ' + b[8].join('|'));
  vm.runInContext('prepararHojasDatosBancarios()', ctx);
  check(hojas.bancos.filas.length === 27, 'bancos: preparar dos veces no duplica');
  check(post({ action: 'create', sheet: 'bancos', data: { codigo: '0134', nombre: 'Otro' } }).status === 'error', 'bancos: código repetido se rechaza');
  check(post({ action: 'create', sheet: 'bancos', data: { codigo: '999', nombre: 'Corto' } }).status === 'error', 'bancos: el código tiene 4 dígitos');
  const nb = post({ action: 'create', sheet: 'bancos', data: { codigo: '0199', nombre: 'Banco Nuevo' } });
  check(nb.status === 'success' && hojas.bancos.filas[27][1] === "'0199", 'bancos: alta con el código como texto');
  check(post({ action: 'preparar_datos_bancarios', usuario_sesion: '' }).status === 'error', 'preparar_datos_bancarios exige usuario de la sesión');
}
{ // cuentas: alta, validaciones y duplicados
  const { hojas, post } = contexto();
  post({ action: 'preparar_datos_bancarios' });
  const t = post({ action: 'create', sheet: 'cuentas_bancarias', data: transferencia() });
  const f = hojas.cuentas_bancarias.filas[1];
  check(t.status === 'success' && f[0] === 'cb00000001' && f[7] === "'01340001234567890123" && f[6] === "'J123456789" && f[9] === '' && f[10] === 'activo', 'transferencia: alta normalizada (cuenta y RIF como texto, sin teléfono) -> ' + JSON.stringify(f));
  const pm = post({ action: 'create', sheet: 'cuentas_bancarias', data: pagoMovil() });
  const g = hojas.cuentas_bancarias.filas[2];
  check(pm.status === 'success' && g[9] === "'04121234567" && g[7] === '' && g[8] === '', 'pago móvil: teléfono local como texto, sin cuenta -> ' + JSON.stringify(g));
  const mal = (data, motivo) => { const r = post({ action: 'create', sheet: 'cuentas_bancarias', data }); check(r.status === 'error' && motivo.test(r.message), 'rechaza: ' + r.message); };
  mal(transferencia({ numero_cuenta: '0105000123456789012' }), /20 dígitos/);
  mal(transferencia({ numero_cuenta: '01050001234567890123' }), /código del banco es 0134/);
  mal(transferencia({ tipo_cuenta: '' }), /tipo de cuenta/);
  mal(transferencia({ numero_cuenta: '01340001234567890123' }), /ya está registrada/);
  mal(pagoMovil({ telefono: '02121234567' }), /celular venezolano/);
  mal(pagoMovil({ telefono: '0412-123.45.67' }), /ya está registrado/);
  mal(pagoMovil({ titular: '' }), /titular/);
  mal(pagoMovil({ banco_id: 'bn99' }), /banco bn99 no existe/);
  mal(pagoMovil({ organizacion_id: 'org-x' }), /organización/);
  mal(pagoMovil({ tipo: 'zelle' }), /Tipo inválido/);
  check(post({ action: 'create', sheet: 'cuentas_bancarias', data: transferencia({ organizacion_id: 'org2' }) }).status === 'success', 'la misma cuenta en otra organización se acepta');
}
{ // cuentas: editar y eliminar
  const { hojas, post } = contexto();
  post({ action: 'preparar_datos_bancarios' });
  post({ action: 'create', sheet: 'cuentas_bancarias', data: transferencia() });
  const u = post({ action: 'update', sheet: 'cuentas_bancarias', id: 'cb00000001', data: { titular: 'Nuevo Titular', tipo_cuenta: 'ahorro', organizacion_id: 'org2' } });
  const f = hojas.cuentas_bancarias.filas[1];
  check(u.status === 'success' && f[4] === 'Nuevo Titular' && f[8] === 'ahorro' && f[1] === 'org1' && f[7] === "'01340001234567890123", 'editar: cambia lo enviado, conserva cuenta y organización');
  const cambio = post({ action: 'update', sheet: 'cuentas_bancarias', id: 'cb00000001', data: { tipo: 'pago_movil', telefono: '04141234567' } });
  check(cambio.status === 'success' && hojas.cuentas_bancarias.filas[1][7] === '' && hojas.cuentas_bancarias.filas[1][9] === "'04141234567", 'editar: pasar a pago móvil limpia la cuenta');
  const malo = post({ action: 'update', sheet: 'cuentas_bancarias', id: 'cb00000001', data: { telefono: '123' } });
  check(malo.status === 'error' && hojas.cuentas_bancarias.filas[1][9] === "'04141234567", 'editar: un dato inválido no se guarda');
  const st = post({ action: 'update', sheet: 'cuentas_bancarias', id: 'cb00000001', data: { status: false } });
  check(st.status === 'success' && hojas.cuentas_bancarias.filas[1][10] === 'inactivo', 'editar: inactivar');
  const d = post({ action: 'delete', sheet: 'cuentas_bancarias', id: 'cb00000001' });
  check(d.status === 'success' && hojas.cuentas_bancarias.filas.length === 1, 'eliminar por ID');
}
{ // códigos que Sheets convirtió en número: se reparan y la validación los entiende
  const { hojas, post } = contexto();
  post({ action: 'preparar_datos_bancarios' });
  hojas.bancos.filas.forEach((f, i) => { if (i > 0) f[1] = Number(String(f[1]).replace(/^'/, '')); });
  check(hojas.bancos.filas[8][1] === 134, 'simula la hoja de producción (134 como número)');
  const t = post({ action: 'create', sheet: 'cuentas_bancarias', data: transferencia() });
  check(t.status === 'success', 'con el código como número, la cuenta 0134… igual se acepta -> ' + JSON.stringify(t));
  check(post({ action: 'create', sheet: 'bancos', data: { codigo: '0134', nombre: 'Otro' } }).status === 'error', 'el código 134 (número) cuenta como 0134 repetido');
  post({ action: 'preparar_datos_bancarios' });
  check(hojas.bancos.filas[8][1] === "'0134" && hojas.bancos.filas[1][1] === "'0102", 'preparar repara los códigos como texto');
}
process.exit(fallas ? 1 : 0);
