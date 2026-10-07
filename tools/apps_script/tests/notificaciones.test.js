// Tests del Apps Script con Node (sin Google): `node tools/apps_script/tests/notificaciones.test.js`
const fs = require('fs');
const vm = require('vm');
const src = fs.readFileSync(process.argv[2] || require("path").join(__dirname, "../../../google_apps_script.js"), 'utf8');

function hoja(nombre, filas) {
  const sh = {
    filas, nombre,
    getName: () => nombre,
    getLastRow: () => sh.filas.length,
    getLastColumn: () => Math.max(...sh.filas.map(f => f.length), 1),
    appendRow: (v) => sh.filas.push(v.slice()),
    deleteRow: (r) => sh.filas.splice(r - 1, 1),
    setFrozenRows: () => {},
    getDataRange: () => ({ getValues: () => sh.filas.map(f => f.slice()) }),
    getRange: (r, c, nr = 1, nc = 1) => {
      if (typeof r === 'string') return { setNumberFormat() {}, setDataValidation() {}, setNote() {} };
      return {
        getValues: () => Array.from({ length: nr }, (_, i) => Array.from({ length: nc }, (_, j) => ((sh.filas[r - 1 + i] || [])[c - 1 + j]) ?? '')),
        getValue: () => ((sh.filas[r - 1] || [])[c - 1]) ?? '',
        setValues: (vals) => vals.forEach((fila, i) => { const f = sh.filas[r - 1 + i] || (sh.filas[r - 1 + i] = []); fila.forEach((v, j) => f[c - 1 + j] = v); }),
        setValue: (v) => { (sh.filas[r - 1] || (sh.filas[r - 1] = []))[c - 1] = v; },
        setNumberFormat() {}, setDataValidation() {},
      };
    },
  };
  return sh;
}

function crearContexto(props, embebida) {
  const hojas = {
    usuarios: hoja('usuarios', [['id','email','nombre'],['u1','ana@x.com','Ana'],['u2','bea@x.com','Bea'],['u3','cami@x.com','Cami'],['u4','dani@x.com','Dani']]),
    usuario_organizacion: hoja('usuario_organizacion', [['id','usuario_email','organizacion_id'],['uo1','ana@x.com','org1'],['uo2','bea@x.com','org2'],['uo3','cami@x.com','org2'],['uo4','dani@x.com','org-borrada']]),
    organizaciones: hoja('organizaciones', [['id','nombre'],['org1','Centro'],['org2','Sucursal Este']]),
    dispositivos: hoja('dispositivos', [['id','usuario_email','organizacion_id','token','plataforma','actualizado'],
      ['dv00000001','ana@x.com','org1','tok-ana','android',''],
      ['dv00000002','bea@x.com','org1','tok-bea','ios',''],          // org guardada vieja: hoy es org2
      ['dv00000003','cami@x.com','org2','tok-cami-vencido','android',''],
      ['dv00000004','dani@x.com','org-borrada','tok-dani','android',''], // sin acceso: no recibe
      ['dv00000005','intruso@x.com','org1','tok-intruso','android','']]),
  };
  const enviados = [];
  const cache = {};
  const ss = {
    getSheetByName: (n) => hojas[n] || null,
    insertSheet: (n) => (hojas[n] = hoja(n, [])),
  };
  const ctx = {
    console,
    SpreadsheetApp: { getActiveSpreadsheet: () => ss, openById: () => ss, newDataValidation: () => ({ requireValueInList() { return this; }, build() { return {}; } }) },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] || null }) },
    CacheService: { getScriptCache: () => ({ get: (k) => (cache[k] ?? null), put: (k, v) => { cache[k] = v; } }) },
    Utilities: { base64EncodeWebSafe: (x) => Buffer.from(x).toString('base64'), computeRsaSha256Signature: () => [1, 2, 3] },
    UrlFetchApp: {
      fetch: () => ({ getResponseCode: () => 200, getContentText: () => '{"access_token":"at"}' }),
      fetchAll: (pedidos) => pedidos.map((p) => {
        const token = JSON.parse(p.payload).message.token;
        enviados.push(JSON.parse(p.payload).message);
        if (token === 'tok-cami-vencido') return { getResponseCode: () => 404, getContentText: () => '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}' };
        return { getResponseCode: () => 200, getContentText: () => '{}' };
      }),
    },
    ContentService: { createTextOutput: (t) => ({ setMimeType: () => t }), MimeType: { JSON: 'json' } },
    ScriptApp: { getProjectTriggers: () => [], newTrigger: () => ({ forSpreadsheet() { return this; }, onEdit() { return this; }, create() {} }) },
    DriveApp: {}, Logger: { log() {} },
  };
  if (embebida) ctx.FCM_SERVICE_ACCOUNT_EMBEBIDA = embebida;
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  return { ctx, hojas, enviados, ss };
}

let fallas = 0;
const check = (cond, msg) => { console.log((cond ? 'OK   ' : 'FAIL ') + msg); if (!cond) fallas++; };
const cred = { FCM_SERVICE_ACCOUNT: JSON.stringify({ client_email: 'sa@p.iam', private_key: 'k', project_id: 'proyecto' }) };
const tokensDe = (e) => e.map((m) => m.token).sort().join(',');

{ // global: todos con acceso, organización de hoy, sin intrusos ni revocados
  const { ctx, enviados, hojas } = crearContexto(cred);
  const r = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"global", titulo:"=Hola", cuerpo:"Mensaje", datos:{ruta:"/ventas"}})`, ctx);
  check(r.status === 'success' && r.enviados === 2 && r.fallidos === 1, 'global: 2 enviados, 1 fallido (token vencido) -> ' + JSON.stringify(r));
  check(tokensDe(enviados) === 'tok-ana,tok-bea,tok-cami-vencido', 'global: no envía a usuarios sin acceso ni a emails fuera de usuarios');
  check(enviados[0].notification.title === '=Hola', 'el título viaja sin sanitizar');
  check(enviados[0].data.ruta === '/ventas' && enviados[0].data.notificacion_id === r.id, 'datos: ruta y notificacion_id');
  check(enviados[0].android.notification.channel_id === 'estilo_neutral_general', 'canal Android');
  check(enviados[0].android.notification.color === '#BC976F' && /^https:\/\/lh3\.googleusercontent\.com\//.test(enviados[0].android.notification.image), 'marca: color dorado y logo');
  check(!hojas.dispositivos.filas.some((f) => f[3] === 'tok-cami-vencido'), 'el token vencido se da de baja');
  const fila = hojas.notificaciones.filas[1];
  check(fila[0] === 'nt00000001' && fila[9] === 'ENVIADA' && fila[6] === "'=Hola", 'queda registrada en la hoja (título sanitizado) -> ' + fila.slice(0, 10).join('|'));
}
{ // una organización (por nombre) usa la membresía de hoy
  const { ctx, enviados } = crearContexto(cred);
  const r = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"organizaciones", organizacion_ids:["Sucursal Este"], titulo:"T", cuerpo:"C"})`, ctx);
  check(r.status === 'success' && tokensDe(enviados) === 'tok-bea,tok-cami-vencido', 'organización por nombre: usa la organización actual de cada usuario');
}
{ // varias organizaciones
  const { ctx, enviados } = crearContexto(cred);
  vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "bea@x.com", {alcance:"organizaciones", organizacion_ids:["org1","org2"], titulo:"T", cuerpo:"C"})`, ctx);
  check(tokensDe(enviados) === 'tok-ana,tok-bea,tok-cami-vencido', 'varias organizaciones');
}
{ // varios usuarios de distintas organizaciones
  const { ctx, enviados } = crearContexto(cred);
  vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"usuarios", usuarios:["ANA@x.com","bea@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(tokensDe(enviados) === 'tok-ana,tok-bea', 'varios usuarios de distintas organizaciones');
}
{ // validaciones
  const { ctx, enviados } = crearContexto(cred);
  const e1 = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "dani@x.com", {alcance:"global", titulo:"T", cuerpo:"C"})`, ctx);
  check(e1.status === 'error' && /no tiene acceso/.test(e1.message), 'remitente sin organización válida no puede enviar');
  const e2 = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"usuarios", usuarios:["dani@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(e2.status === 'error' && /sin acceso/.test(e2.message), 'no se puede enviar a un usuario sin acceso');
  const e3 = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"organizaciones", organizacion_ids:["Inexistente"], titulo:"T", cuerpo:"C"})`, ctx);
  check(e3.status === 'error' && /inexistentes/.test(e3.message), 'organización inexistente');
  const e4 = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"global", titulo:"", cuerpo:"C"})`, ctx);
  check(e4.status === 'error', 'título vacío');
  check(enviados.length === 0, 'nada enviado en los casos inválidos');
}
{ // sin credencial
  const { ctx, hojas } = crearContexto({});
  const r = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"global", titulo:"T", cuerpo:"C"})`, ctx);
  check(r.status === 'error' && /FCM_SERVICE_ACCOUNT/.test(r.message), 'sin credencial: error claro');
  check(hojas.notificaciones.filas[1][9] === 'ERROR', 'sin credencial: queda registrada como ERROR');
}
{ // registrar / eliminar dispositivo
  const { ctx, hojas } = crearContexto(cred);
  const r = vm.runInContext(`_registrarDispositivo(getSpreadsheet(), "cami@x.com", {token:"tok-nuevo", plataforma:"android"})`, ctx);
  const fila = hojas.dispositivos.filas.find((f) => f[3] === 'tok-nuevo');
  check(r.id === 'dv00000006' && fila[1] === 'cami@x.com' && fila[2] === 'org2', 'registrar: ID del servidor y organización de la membresía');
  vm.runInContext(`_registrarDispositivo(getSpreadsheet(), "ana@x.com", {token:"tok-nuevo", plataforma:"android"})`, ctx);
  check(hojas.dispositivos.filas.filter((f) => f[3] === 'tok-nuevo').length === 1 && hojas.dispositivos.filas.find((f) => f[3] === 'tok-nuevo')[1] === 'ana@x.com', 'mismo token con otra cuenta: se reasigna, no se duplica');
  const otro = vm.runInContext(`_eliminarDispositivo(getSpreadsheet(), "bea@x.com", {token:"tok-ana"})`, ctx);
  check(otro.status === 'error', 'no se puede borrar el dispositivo de otro usuario');
  vm.runInContext(`_eliminarDispositivo(getSpreadsheet(), "ana@x.com", {token:"tok-ana"})`, ctx);
  check(!hojas.dispositivos.filas.some((f) => f[3] === 'tok-ana'), 'el dueño borra su dispositivo');
}
{ // envío desde la hoja
  const { ctx, hojas, enviados } = crearContexto(cred);
  vm.runInContext(`prepararHojasNotificaciones()`, ctx);
  hojas.notificaciones.filas.push(['', '', 'bea@x.com', 'organizaciones', 'Centro, org2', '', 'Desde la hoja', 'Hola', '', 'PENDIENTE', '', '', '']);
  hojas.notificaciones.filas.push(['', '', 'intruso@x.com', 'global', '', '', 'X', 'Y', '', 'PENDIENTE', '', '', '']);
  const r = vm.runInContext(`enviarNotificacionesPendientes()`, ctx);
  const [f1, f2] = [hojas.notificaciones.filas[1], hojas.notificaciones.filas[2]];
  check(r.procesadas === 2 && f1[9] === 'ENVIADA' && f1[0] === 'nt00000001' && f1[4] === 'org1, org2', 'hoja: fila válida enviada (organizaciones por nombre o ID) -> ' + f1.slice(0, 12).join('|'));
  check(f2[9] === 'ERROR' && /no tiene acceso/.test(f2[12]), 'hoja: remitente que no está en usuarios -> ERROR');
  check(enviados.length === 3, 'hoja: solo se envió la fila válida');
  const r2 = vm.runInContext(`enviarNotificacionesPendientes()`, ctx);
  check(r2.procesadas === 0, 'hoja: una fila ya procesada no se reenvía');
}
{ // doPost exige usuario_sesion para las acciones de notificaciones
  const { ctx } = crearContexto(cred);
  const sin = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"enviar_notificacion", data:{alcance:"global",titulo:"T",cuerpo:"C"}})}})`, ctx));
  check(sin.status === 'error' && /usuario de la sesión/.test(sin.message), 'doPost: sin usuario_sesion se rechaza');
  const ok = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"enviar_notificacion", usuario_sesion:"ana@x.com", data:{alcance:"usuarios",usuarios:["bea@x.com"],titulo:"T",cuerpo:"C"}})}})`, ctx));
  check(ok.status === 'success' && ok.enviados === 1, 'doPost: envío desde la app');
}
{ // límite de envíos por remitente
  const { ctx } = crearContexto(cred);
  let ultimo;
  for (let i = 0; i < 31; i++) {
    ultimo = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"usuarios", usuarios:["bea@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  }
  check(ultimo.status === 'error' && /Límite/.test(ultimo.message), 'límite: el envío 31 de la hora se rechaza');
  const otro = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "bea@x.com", {alcance:"usuarios", usuarios:["ana@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(otro.status === 'success', 'límite: es por remitente');
}
{ // credencial embebida por deploy.sh (sin propiedad del script)
  const { ctx } = crearContexto({}, { client_email: 'sa@p.iam', private_key: 'k', project_id: 'proyecto' });
  const r = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"usuarios", usuarios:["bea@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(r.status === 'success' && r.enviados === 1, 'credencial embebida: se usa si no hay propiedad');
}
{ // acción preparar_notificaciones
  const { ctx, hojas } = crearContexto(cred);
  delete hojas.notificaciones;
  const r = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"preparar_notificaciones", usuario_sesion:"ana@x.com"})}})`, ctx));
  check(r.status === 'success' && hojas.notificaciones && hojas.notificaciones.filas[0][0] === 'id', 'preparar_notificaciones: crea la hoja y el disparador');
  const sin = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"preparar_notificaciones"})}})`, ctx));
  check(sin.status === 'error', 'preparar_notificaciones: exige usuario de la sesión');
}
process.exit(fallas ? 1 : 0);
