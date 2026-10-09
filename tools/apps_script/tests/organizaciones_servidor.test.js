// Tests del aislamiento de organizaciones en Apps Script:
// `node tools/apps_script/tests/organizaciones_servidor.test.js`
const fs = require('fs');
const vm = require('vm');
const crypto = require('crypto');
const path = require('path');

const srcPath = process.argv[2] || path.join(__dirname, '../../../google_apps_script.js');
const src = fs.readFileSync(srcPath, 'utf8');

function crearHoja(nombre, filasIniciales) {
  const filas = filasIniciales.map((f) => f.slice());
  const sh = {
    filas,
    getName: () => nombre,
    getLastRow: () => sh.filas.length,
    getLastColumn: () => Math.max(...sh.filas.map((f) => f.length), 1),
    appendRow: (v) => sh.filas.push(v.slice()),
    deleteRow: (r) => sh.filas.splice(r - 1, 1),
    setFrozenRows: () => {},
    getDataRange: () => ({
      getValues: () => sh.filas.map((f) => f.slice()),
      getDisplayValues: () => sh.filas.map((f) => f.map(String)),
    }),
    getRange: (r, c, nr = 1, nc = 1) => {
      if (typeof r === 'string') return { setNumberFormat() {}, setDataValidation() {}, setNote() {} };
      return {
        getValues: () =>
          Array.from({ length: nr }, (_, i) =>
            Array.from({ length: nc }, (_, j) => ((sh.filas[r - 1 + i] || [])[c - 1 + j]) ?? '')
          ),
        getValue: () => ((sh.filas[r - 1] || [])[c - 1]) ?? '',
        getDisplayValues: () =>
          Array.from({ length: nr }, (_, i) =>
            Array.from({ length: nc }, (_, j) => String(((sh.filas[r - 1 + i] || [])[c - 1 + j]) ?? ''))
          ),
        setValues: (vals) =>
          vals.forEach((fila, i) => {
            const f = sh.filas[r - 1 + i] || (sh.filas[r - 1 + i] = []);
            fila.forEach((v, j) => (f[c - 1 + j] = v));
          }),
        setValue: (v) => {
          (sh.filas[r - 1] || (sh.filas[r - 1] = []))[c - 1] = v;
        },
        setFormula: (f) => {},
        setNumberFormat() {},
        setDataValidation() {},
      };
    },
  };
  return sh;
}

function inicializarContexto({ props = {}, tokens = {} } = {}) {
  const tablasIniciales = {
    usuarios: [
      ['id', 'email', 'nombre', 'tipo_documento', 'cedula', 'status'],
      ['u1', 'ana@x.com', 'Ana', 'V', '1', 'activo'],
      ['u2', 'beto@x.com', 'Beto', 'V', '2', 'activo'],
      ['u3', 'multi@x.com', 'Multi', 'V', '3', 'activo'],
    ],
    organizaciones: [
      ['id', 'nombre', 'email'],
      ['org1', 'Centro', 'centro@x.com'],
      ['org2', 'Norte', 'norte@x.com'],
    ],
    usuario_organizacion: [
      ['id', 'usuario_email', 'organizacion_id'],
      ['uo1', 'ana@x.com', 'org1'],
      ['uo2', 'beto@x.com', 'org2'],
      ['uo3', 'multi@x.com', 'org1'],
      ['uo4', 'multi@x.com', 'org2'],
    ],
    clientes: [
      ['id', 'nombre', 'telefono', 'email', 'saldo_deuda_usd', 'fecha_registro', 'organizacion_id', 'tipo_documento', 'cedula', 'status'],
      ['c1', 'Cliente Ana', '04141111111', 'c1@x.com', 0, '2026-10-09', 'org1', 'V', '111', 'activo'],
      ['c2', 'Cliente Beto', '04142222222', 'c2@x.com', 0, '2026-10-09', 'org2', 'V', '222', 'activo'],
    ],
    inventario: [
      ['id', 'cantidad', 'nombre', 'marca', 'modelo', 'talla', 'precio_usd', 'foto_id', 'fotoFormula', 'organizacion_id'],
      ['inv1', 10, 'Camisa Org1', 'Marca1', 'M1', 'M', 20.0, 'f1', '', 'org1'],
      ['inv2', 5, 'Pantalon Org2', 'Marca2', 'M2', 'L', 30.0, 'f2', '', 'org2'],
    ],
    ventas: [
      ['id', 'fecha', 'cliente_id', 'tasa_bcv', 'tasa_usd', 'tipo_pago', 'comision_pago_movil_bs', 'monto_bs', 'monto_usd', 'abono_usd', 'deuda_usd', 'total_pagar_usd', 'validacion', 'estado', 'organizacion_id'],
      ['v1', '2026-10-09', 'c1', 1.0, 1.0, 'mp00000001', 0, 20, 20, 20, 0, 20, 'OK', 'Pagada', 'org1'],
      ['v2', '2026-10-09', 'c2', 1.0, 1.0, 'mp00000001', 0, 30, 30, 30, 0, 30, 'OK', 'Pagada', 'org2'],
    ],
    venta_items: [
      ['id', 'venta_id', 'item_id', 'cantidad', 'precio_usd', 'subtotal_usd'],
      ['vi1', 'v1', 'inv1', 1, 20.0, 20.0],
      ['vi2', 'v2', 'inv2', 1, 30.0, 30.0],
    ],
    abonos: [
      ['id', 'venta_id', 'fecha', 'monto', 'metodo_pago', 'tasa_id'],
      ['ab1', 'v1', '2026-10-09T10:00:00', 20.0, 'mp00000001', ''],
      ['ab2', 'v2', '2026-10-09T10:00:00', 30.0, 'mp00000001', ''],
    ],
    cuentas_bancarias: [
      ['id', 'organizacion_id', 'tipo', 'banco_id', 'titular', 'tipo_documento', 'documento', 'numero_cuenta', 'tipo_cuenta', 'telefono', 'status', 'fecha'],
      ['cb1', 'org1', 'pago_movil', 'bn00000001', 'Titular 1', 'V', '111', '01020000', 'corriente', '04141111111', 'activo', '2026-10-09'],
      ['cb2', 'org2', 'pago_movil', 'bn00000001', 'Titular 2', 'V', '222', '01020001', 'corriente', '04142222222', 'activo', '2026-10-09'],
    ],
    seguridad: [
      ['id', 'biometrico', 'desbloqueo_facial', 'dos_factores', 'usuario_email'],
      ['s1', true, false, false, 'ana@x.com'],
      ['s2', false, true, false, 'beto@x.com'],
    ],
    audit_log: [
      ['id', 'timestamp_iso8601', 'usuario', 'hoja', 'celda', 'valor_anterior', 'valor_nuevo', 'accion', 'norma_aplicada', 'observaciones', 'organizacion_id'],
      ['al1', '2026-10-09T10:00:00', 'ana@x.com', 'clientes', 'A2', 'null', 'c1', 'creacion_clientes', 'ISO 8000', '', 'org1'],
      ['al2', '2026-10-09T10:00:00', 'beto@x.com', 'clientes', 'A3', 'null', 'c2', 'creacion_clientes', 'ISO 8000', '', 'org2'],
    ],
    bancos: [
      ['id', 'codigo', 'nombre', 'status'],
      ['bn00000001', '0102', 'Banco de Venezuela', 'activo'],
    ],
    'metodo pago': [
      ['id', 'nombre', 'status'],
      ['mp00000001', 'Efectivo', true],
    ],
    'codigo de telefonos': [
      ['id', 'codigo', 'status'],
      ['tel1', '0414', true],
    ],
    'tipo de documento': [
      ['id', 'tipo', 'descripcion', 'status'],
      ['td1', 'V', 'Venezolano', true],
    ],
  };

  const hojas = {};
  for (const [nombre, filas] of Object.entries(tablasIniciales)) {
    hojas[nombre] = crearHoja(nombre, filas);
  }

  const cache = {};
  const ss = {
    getSheetByName: (n) => hojas[n] || null,
    insertSheet: (n) => (hojas[n] = crearHoja(n, [])),
    getId: () => 'SPREADSHEET_TEST_ID',
    getName: () => 'Estilo Neutral Test',
    getSheets: () => Object.values(hojas),
  };

  const ctx = {
    console,
    SpreadsheetApp: {
      flush() {},
      getActiveSpreadsheet: () => ss,
      openById: () => ss,
      newDataValidation: () => ({ requireValueInList() { return this; }, build() { return {}; } }),
    },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (k) => props[k] ?? null,
        setProperty: (k, v) => { props[k] = v; },
      }),
    },
    CacheService: {
      getScriptCache: () => ({
        get: (k) => cache[k] ?? null,
        put: (k, v) => { cache[k] = v; },
      }),
    },
    Utilities: {
      formatDate: (d, tz, f) => d.toISOString().slice(0, 10),
      base64EncodeWebSafe: (x) => Buffer.from(x).toString('base64url'),
      computeDigest: (_, t) => [...crypto.createHash('sha256').update(t).digest()],
      DigestAlgorithm: { SHA_256: 'sha256' },
    },
    ContentService: { createTextOutput: (t) => ({ setMimeType: () => t }), MimeType: { JSON: 'json' } },
    UrlFetchApp: {
      fetch: (url) => {
        const token = decodeURIComponent(url.split('access_token=')[1] || '');
        const info = tokens[token];
        return info
          ? { getResponseCode: () => 200, getContentText: () => JSON.stringify(info) }
          : { getResponseCode: () => 400, getContentText: () => '{"error":"invalid_token"}' };
      },
    },
    MailApp: { getRemainingDailyQuota: () => 100, sendEmail: () => {} },
    DriveApp: {},
    ScriptApp: { getProjectTriggers: () => [], deleteTrigger: () => {}, newTrigger: () => ({ timeBased: () => ({ everyWeeks: () => ({ onWeekDay: () => ({ atHour: () => ({ create: () => ({ getUniqueId: () => 'tr1', getHandlerFunction: () => 'h' }) }) }) }) }) }) },
    Logger: { log() {} },
  };

  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  const post = (o) => JSON.parse(vm.runInContext(`doPost({postData:{contents: ${JSON.stringify(JSON.stringify(o))}}})`, ctx));

  return { ctx, hojas, post, props };
}

let fallas = 0;
function check(cond, msg) {
  console.log((cond ? 'OK   ' : 'FAIL ') + msg);
  if (!cond) fallas++;
}

const tokens = {
  'tok-ana': { email: 'ana@x.com', email_verified: 'true', expires_in: '3600' },
  'tok-beto': { email: 'beto@x.com', email_verified: 'true', expires_in: '3600' },
  'tok-multi': { email: 'multi@x.com', email_verified: 'true', expires_in: '3600' },
};

console.log('--- TEST 1: Lectura filtrada por organización en el servidor ---');
{
  const { post } = inicializarContexto({ tokens });
  const resAna = post({
    action: 'leer_hojas',
    access_token: 'tok-ana',
    hojas: ['clientes', 'inventario', 'ventas', 'venta_items', 'abonos', 'cuentas_bancarias', 'organizaciones', 'bancos'],
  });

  check(resAna.status === 'success', 'Ana lee hojas con éxito');
  const hAna = resAna.hojas || {};

  // Clientes: solo c1 (de org1), nunca c2 (de org2)
  check(hAna.clientes && hAna.clientes.length === 2, 'Ana recibe encabezado + 1 fila de clientes (su organización)');
  check(hAna.clientes && hAna.clientes[1][0] === 'c1' && hAna.clientes[1][6] === 'org1', 'Ana recibe c1 de org1');
  const tieneC2 = (hAna.clientes || []).some((r) => r[0] === 'c2');
  check(!tieneC2, 'Ana NO recibe c2 de org2');

  // Inventario: solo inv1
  check(hAna.inventario && hAna.inventario.length === 2 && hAna.inventario[1][0] === 'inv1', 'Ana recibe únicamente inv1');

  // Ventas e items
  check(hAna.ventas && hAna.ventas.length === 2 && hAna.ventas[1][0] === 'v1', 'Ana recibe únicamente v1');
  check(hAna.venta_items && hAna.venta_items.length === 2 && hAna.venta_items[1][0] === 'vi1', 'Ana recibe únicamente vi1 vinculada a v1');
  check(hAna.abonos && hAna.abonos.length === 2 && hAna.abonos[1][0] === 'ab1', 'Ana recibe únicamente ab1 vinculada a v1');

  // Cuentas bancarias
  check(hAna.cuentas_bancarias && hAna.cuentas_bancarias.length === 2 && hAna.cuentas_bancarias[1][0] === 'cb1', 'Ana recibe únicamente cuentas bancarias de org1');

  // Organizaciones: Ana solo ve org1
  check(hAna.organizaciones && hAna.organizaciones.length === 2 && hAna.organizaciones[1][0] === 'org1', 'Ana recibe únicamente su organización org1');

  // Catálogos globales: bancos se devuelve completo
  check(hAna.bancos && hAna.bancos.length === 2, 'Catálogo global bancos se devuelve intacto');
}

{
  const { post } = inicializarContexto({ tokens });
  const resBeto = post({
    action: 'leer_hojas',
    access_token: 'tok-beto',
    hojas: ['clientes', 'ventas', 'organizaciones'],
  });
  check(resBeto.status === 'success', 'Beto lee hojas con éxito');
  const hBeto = resBeto.hojas || {};
  check(hBeto.clientes && hBeto.clientes.length === 2 && hBeto.clientes[1][0] === 'c2', 'Beto recibe únicamente c2 de org2');
  check(hBeto.ventas && hBeto.ventas.length === 2 && hBeto.ventas[1][0] === 'v2', 'Beto recibe únicamente v2 de org2');
  check(hBeto.organizaciones && hBeto.organizaciones.length === 2 && hBeto.organizaciones[1][0] === 'org2', 'Beto recibe únicamente org2');
}

{
  const { post } = inicializarContexto({ tokens });
  const resMulti = post({
    action: 'leer_hojas',
    access_token: 'tok-multi',
    hojas: ['clientes', 'organizaciones'],
  });
  check(resMulti.status === 'success', 'Usuario multi-org lee con éxito');
  const hMulti = resMulti.hojas || {};
  // Usuario en org1 y org2 recibe ambas
  check(hMulti.clientes && hMulti.clientes.length === 3, 'Usuario multi-org recibe clientes de ambas organizaciones (c1 y c2)');
  check(hMulti.organizaciones && hMulti.organizaciones.length === 3, 'Usuario multi-org recibe ambas organizaciones');
}

console.log('--- TEST 2: Ataque de actualización (update) cruzado entre organizaciones ---');
{
  const { post, hojas } = inicializarContexto({ tokens });
  // Beto intenta modificar c1 (cliente de org1)
  const intentoBeto = post({
    action: 'update',
    sheet: 'clientes',
    id: 'c1',
    access_token: 'tok-beto',
    data: { nombre: 'Nombre Hackeado por Beto' },
  });
  check(intentoBeto.status === 'error', 'Beto NO puede actualizar un cliente de org1');
  check(intentoBeto.code === 'no_autorizado' || (intentoBeto.message && intentoBeto.message.includes('organización')), 'Error de autorización claro -> ' + JSON.stringify(intentoBeto));
  const c1Nombre = hojas.clientes.filas[1][1];
  check(c1Nombre === 'Cliente Ana', 'El nombre de c1 no fue modificado en la hoja');

  // Beto actualiza c2 (su propio cliente en org2)
  const updatePropio = post({
    action: 'update',
    sheet: 'clientes',
    id: 'c2',
    access_token: 'tok-beto',
    data: { nombre: 'Cliente Beto Modificado' },
  });
  check(updatePropio.status === 'success', 'Beto actualiza exitosamente a su cliente c2');
  check(hojas.clientes.filas[2][1] === 'Cliente Beto Modificado', 'El nombre de c2 fue actualizado');
}

console.log('--- TEST 3: Ataque de eliminación (delete) cruzado entre organizaciones ---');
{
  const { post, hojas } = inicializarContexto({ tokens });
  // Beto intenta eliminar c1 (cliente de org1)
  const intentoDel = post({
    action: 'delete',
    sheet: 'clientes',
    id: 'c1',
    access_token: 'tok-beto',
  });
  check(intentoDel.status === 'error', 'Beto NO puede eliminar un cliente de org1');
  check(hojas.clientes.filas.length === 3, 'La hoja de clientes mantiene todas las filas (c1 no fue borrado)');

  // Beto elimina c2 (su propio cliente)
  const delPropio = post({
    action: 'delete',
    sheet: 'clientes',
    id: 'c2',
    access_token: 'tok-beto',
  });
  check(delPropio.status === 'success', 'Beto elimina exitosamente su cliente c2');
  check(hojas.clientes.filas.length === 2, 'c2 fue eliminado de la hoja');
}

console.log('--- TEST 4: Ataque de creación (create) con organización ajena ---');
{
  const { post, hojas } = inicializarContexto({ tokens });
  // Beto intenta crear cliente en org1
  const intentoCrearAjeno = post({
    action: 'create',
    sheet: 'clientes',
    access_token: 'tok-beto',
    data: {
      nombre: 'Infiltrado',
      organizacion_id: 'org1',
    },
  });
  check(intentoCrearAjeno.status === 'error', 'Beto NO puede crear registros en org1');
  const infiltradoExiste = hojas.clientes.filas.some((f) => f[1] === 'Infiltrado');
  check(!infiltradoExiste, 'El cliente infiltrado no fue insertado en clientes');

  // Beto crea cliente especificando org2 (su organización)
  const crearPropio = post({
    action: 'create',
    sheet: 'clientes',
    access_token: 'tok-beto',
    data: {
      nombre: 'Nuevo Beto',
      organizacion_id: 'org2',
    },
  });
  check(crearPropio.status === 'success', 'Beto crea cliente en su propia organización org2');
  const nuevoBeto = hojas.clientes.filas.find((f) => f[1] === 'Nuevo Beto');
  check(nuevoBeto && nuevoBeto[6] === 'org2', 'El nuevo cliente tiene organizacion_id = org2');

  // Beto crea cliente sin especificar organizacion_id (el servidor debe forzar su membresía única org2)
  const crearSinOrg = post({
    action: 'create',
    sheet: 'clientes',
    access_token: 'tok-beto',
    data: {
      nombre: 'Beto Sin Org Explícita',
    },
  });
  check(crearSinOrg.status === 'success', 'Beto crea cliente sin enviar organizacion_id');
  const clienteSinOrg = hojas.clientes.filas.find((f) => f[1] === 'Beto Sin Org Explícita');
  check(clienteSinOrg && clienteSinOrg[6] === 'org2', 'El servidor fija la organizacion_id del usuario automáticamente');
}

console.log('--- TEST 5: Transacciones atómicas por lote (batch) ---');
{
  const { post, hojas } = inicializarContexto({ tokens });
  // Beto intenta batch con una operación legítima y una ilegítima en org1
  const batchAtaque = post({
    action: 'batch',
    access_token: 'tok-beto',
    operations: [
      {
        action: 'create',
        sheet: 'clientes',
        data: { nombre: 'Beto Batch 1', organizacion_id: 'org2' },
      },
      {
        action: 'update',
        sheet: 'clientes',
        id: 'c1', // org1!
        data: { nombre: 'Hack Batch' },
      },
    ],
  });
  check(batchAtaque.status === 'error', 'El lote con ataque cruzado se rechaza');
  check(!hojas.clientes.filas.some((f) => f[1] === 'Beto Batch 1'), 'Rollback: Beto Batch 1 no fue guardado');
  check(hojas.clientes.filas[1][1] === 'Cliente Ana', 'c1 permanece intacto');
}

console.log('--- TEST 6: Interruptor de emergencia SEPARACION_ORGANIZACIONES = "no" ---');
{
  const { post } = inicializarContexto({
    props: { SEPARACION_ORGANIZACIONES: 'no' },
    tokens,
  });
  const resAna = post({
    action: 'leer_hojas',
    access_token: 'tok-ana',
    hojas: ['clientes'],
  });
  check(resAna.status === 'success', 'Con SEPARACION_ORGANIZACIONES=no la lectura funciona');
  check(resAna.hojas.clientes.length === 3, 'Con SEPARACION_ORGANIZACIONES=no se devuelven todos los clientes (c1 y c2) como antes');
}

console.log('----------------------------------------------------');
console.log(`Fallas totales: ${fallas}`);
process.exit(fallas > 0 ? 1 : 0);
