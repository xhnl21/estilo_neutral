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
    SpreadsheetApp: { flush() {}, getActiveSpreadsheet: () => ss, openById: () => ss, newDataValidation: () => ({ requireValueInList() { return this; }, build() { return {}; } }) },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    // Estos tests simulan pedidos sin token: vuelta atrás AUTENTICACION_OBLIGATORIA = no.
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => (k === 'AUTENTICACION_OBLIGATORIA' ? 'no' : props[k] || null) }) },
    CacheService: { getScriptCache: () => ({ get: (k) => (cache[k] ?? null), put: (k, v) => { cache[k] = v; } }) },
    Utilities: { base64EncodeWebSafe: (x) => Buffer.from(x).toString('base64'), computeRsaSha256Signature: () => [1, 2, 3], formatDate: (d) => d.toISOString().slice(0, 10) },
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
  check(enviados[0].data.titulo === '=Hola' && enviados[0].data.cuerpo === 'Mensaje', 'el título viaja sin sanitizar, en los datos');
  check(enviados[0].notification === undefined && enviados[0].android.priority === 'HIGH', 'Android: solo datos y prioridad alta (la app arma la notificación)');
  check(enviados[0].apns.payload.aps.alert.title === '=Hola', 'iOS: alerta en apns');
  check(enviados[0].data.ruta === '/ventas' && enviados[0].data.notificacion_id === r.id, 'datos: ruta y notificacion_id');
  check(enviados[0].data.canal === 'estilo_neutral_general', 'canal Android en los datos');
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
  check(ultimo.status === 'error' && /límite de 30 notificaciones esta hora/.test(ultimo.message) && ultimo.code === 'limite_notificaciones', 'límite por defecto: el envío 31 de la hora se rechaza -> ' + ultimo.message);
  const otro = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "bea@x.com", {alcance:"usuarios", usuarios:["ana@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(otro.status === 'success', 'límite: es por remitente');
}
{ // la credencial del deploy tiene prioridad sobre la propiedad (rotar = reemplazar el archivo y desplegar)
  const { ctx } = crearContexto({ FCM_SERVICE_ACCOUNT: '{"clave":"vieja-rota' }, { client_email: 'sa@p.iam', private_key: 'k', project_id: 'proyecto', private_key_id: 'nueva' });
  const r = vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"usuarios", usuarios:["bea@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(r.status === 'success' && r.enviados === 1, 'credencial: la embebida gana sobre una propiedad vieja');
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
{ // inactivar usuario: push silencioso, borra sus dispositivos y deja de recibir
  const { ctx, hojas, enviados } = crearContexto(cred);
  const r = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"update", sheet:"usuarios", id:"u1", usuario_sesion:"bea@x.com", data:{status:false}})}})`, ctx));
  check(r.status === 'success', 'inactivar: update aceptado -> ' + JSON.stringify(r).slice(0, 120));
  check(hojas.usuarios.filas[0][5] === 'status' && hojas.usuarios.filas[1][5] === 'inactivo', 'inactivar: escribe la columna F "status"');
  const silencioso = enviados.filter((m) => m.data && m.data.tipo === 'sesion_revocada');
  check(silencioso.length === 1 && silencioso[0].token === 'tok-ana' && !silencioso[0].data.titulo && !silencioso[0].notification, 'inactivar: push silencioso solo a sus tokens');
  check(!hojas.dispositivos.filas.some((f) => f[1] === 'ana@x.com'), 'inactivar: borra sus dispositivos');
  check(/inactiva/.test(vm.runInContext(`_motivoSinAcceso(getSpreadsheet(), "ana@x.com")`, ctx) || ''), 'inactivar: ya no tiene acceso');
  const rechazo = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"enviar_notificacion", usuario_sesion:"ana@x.com", data:{alcance:"global",titulo:"T",cuerpo:"C"}})}})`, ctx));
  check(rechazo.status === 'error', 'inactivar: el inactivo no puede usar el servidor');
  hojas.dispositivos.filas.push(['dv9', 'ana@x.com', 'org1', 'tok-ana-2', 'android', '']);
  enviados.length = 0;
  vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "bea@x.com", {alcance:"global", titulo:"T", cuerpo:"C"})`, ctx);
  check(!enviados.some((m) => m.token === 'tok-ana-2'), 'inactivar: el inactivo no recibe notificaciones');
  vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"update", sheet:"usuarios", id:"u1", usuario_sesion:"bea@x.com", data:{status:true}})}})`, ctx);
  check(hojas.usuarios.filas[1][5] === 'activo' && vm.runInContext(`_motivoSinAcceso(getSpreadsheet(), "ana@x.com")`, ctx) === null, 'activar: recupera el acceso');
}
{ // inactivar escribiendo en la hoja: el disparador de edición lo expulsa
  const { ctx, hojas, enviados } = crearContexto(cred);
  hojas.usuarios.filas[2][5] = 'inactivo';
  const rango = { getSheet: () => hojas.usuarios, getColumn: () => 6, getLastColumn: () => 6, getRow: () => 3, getNumRows: () => 1 };
  ctx.__e = { range: rango };
  vm.runInContext(`alEditarNotificaciones(__e)`, ctx);
  check(enviados.length === 1 && enviados[0].token === 'tok-bea' && enviados[0].data.tipo === 'sesion_revocada', 'hoja: inactivar a mano envía el push silencioso');
  rango.getColumn = () => 3; rango.getLastColumn = () => 3;
  vm.runInContext(`alEditarNotificaciones(__e)`, ctx);
  check(enviados.length === 1, 'hoja: editar otra columna no expulsa');
}
{ // eliminar usuario también lo expulsa; sin dispositivos no falla
  const { ctx, hojas, enviados } = crearContexto(cred);
  vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"delete", sheet:"usuarios", id:"u2", usuario_sesion:"ana@x.com"})}})`, ctx);
  check(enviados.some((m) => m.token === 'tok-bea' && m.data.tipo === 'sesion_revocada'), 'eliminar usuario: push silencioso');
  const r = vm.runInContext(`_expulsarUsuario(getSpreadsheet(), "nadie@x.com", "x")`, ctx);
  check(r.enviados === 0, 'expulsar sin dispositivos: no hace nada');
}
{ // clientes: crear con status y cambiarlo
  const { ctx, hojas } = crearContexto(cred);
  hojas.clientes = hoja('clientes', [['id','nombre','telefono','email','saldo_deuda_usd','fecha_registro','organizacion_id','tipo_documento','cedula']]);
  vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"create", sheet:"clientes", usuario_sesion:"ana@x.com", data:{nombre:"Zoe", organizacion_id:"org1", cedula:"123"}})}})`, ctx);
  const fila = hojas.clientes.filas[1];
  check(hojas.clientes.filas[0][9] === 'status' && fila && fila[9] === 'activo', 'cliente nuevo: status "activo" en J -> ' + JSON.stringify(fila));
  const id = fila ? fila[0] : '';
  vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"update", sheet:"clientes", id:"${id}", usuario_sesion:"ana@x.com", data:{status:false}})}})`, ctx);
  check(hojas.clientes.filas[1] && hojas.clientes.filas[1][9] === 'inactivo' && hojas.clientes.filas[1][1] === 'Zoe', 'cliente: inactivar sin tocar el resto');
}
{ // configuración por organización: períodos de calendario (hora de Venezuela)
  const { ctx } = crearContexto(cred);
  const iso = (d) => vm.runInContext(`(function(){ const p = _limitesPeriodo(${JSON.stringify(d.p)}, new Date(${JSON.stringify(d.ahora)})); return [p.inicio.toISOString(), p.fin.toISOString()]; })()`, ctx);
  // miércoles 2026-10-07 23:30 en Venezuela = 2026-10-08T03:30Z
  check(JSON.stringify(iso({ p: 'dia', ahora: '2026-10-08T03:30:00Z' })) === JSON.stringify(['2026-10-07T04:00:00.000Z', '2026-10-08T04:00:00.000Z']), 'período día: de 00:00 a 00:00 de Venezuela');
  check(JSON.stringify(iso({ p: 'semana', ahora: '2026-10-08T03:30:00Z' })) === JSON.stringify(['2026-10-05T04:00:00.000Z', '2026-10-12T04:00:00.000Z']), 'período semana: de lunes a lunes');
  check(JSON.stringify(iso({ p: 'mes', ahora: '2026-10-08T03:30:00Z' })) === JSON.stringify(['2026-10-01T04:00:00.000Z', '2026-11-01T04:00:00.000Z']), 'período mes: del día 1 al 1');
  check(JSON.stringify(iso({ p: 'hora', ahora: '2026-10-08T03:30:00Z' })) === JSON.stringify(['2026-10-08T03:00:00.000Z', '2026-10-08T04:00:00.000Z']), 'período hora: hora en punto');
}
{ // límite por usuario y de la organización (org2: bea y cami)
  const { ctx, hojas } = crearContexto(cred);
  const crear = (data) => JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify(${JSON.stringify({ action: 'create', sheet: 'config_notificaciones', usuario_sesion: 'ana@x.com', data })})}})`, ctx));
  const r = crear({ organizacion_id: 'org2', periodo: 'dia', limite_por_usuario: 2, limite_organizacion: 3, actualizado_por: 'ana@x.com' });
  check(r.status === 'success' && hojas.config_notificaciones && hojas.config_notificaciones.filas[1][0] === 'cn00000001', 'config: se crea la hoja y la fila con ID del servidor -> ' + JSON.stringify(r));
  check(crear({ organizacion_id: 'org2', periodo: 'dia', limite_por_usuario: 1, limite_organizacion: 0 }).status === 'error', 'config: una sola fila por organización');
  check(crear({ organizacion_id: 'org-x', periodo: 'dia', limite_por_usuario: 1, limite_organizacion: 0 }).status === 'error', 'config: la organización tiene que existir');
  check(crear({ organizacion_id: 'org1', periodo: 'anio', limite_por_usuario: 1, limite_organizacion: 0 }).status === 'error', 'config: período inválido se rechaza');
  check(crear({ organizacion_id: 'org1', periodo: 'dia', limite_por_usuario: -1, limite_organizacion: 0 }).status === 'error', 'config: límite negativo se rechaza');
  const enviar = (de) => vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "${de}", {alcance:"usuarios", usuarios:["ana@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(enviar('bea@x.com').status === 'success' && enviar('bea@x.com').status === 'success', 'por usuario: bea envía 2');
  const b3 = enviar('bea@x.com');
  check(b3.status === 'error' && /2 notificaciones hoy por usuario/.test(b3.message), 'por usuario: la 3ra de bea se rechaza -> ' + b3.message);
  check(enviar('cami@x.com').status === 'success', 'organización: cami usa el 3er envío de org2');
  const c2 = enviar('cami@x.com');
  check(c2.status === 'error' && /organización llegó a su límite de 3/.test(c2.message), 'organización: el 4to de org2 se rechaza -> ' + c2.message);
  check(enviar('ana@x.com').status === 'success', 'otra organización (org1, sin fila) no se ve afectada');
  const filasError = hojas.notificaciones.filas.filter((f) => f[9] === 'ERROR').length;
  check(filasError === 0, 'desde la app, el rechazo por límite no agrega filas');
  const uso = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"uso_notificaciones", usuario_sesion:"bea@x.com"})}})`, ctx));
  check(uso.status === 'success' && uso.periodo === 'dia' && uso.limite_por_usuario === 2 && uso.usados_usuario === 2 && uso.usados_organizacion === 3, 'uso_notificaciones -> ' + JSON.stringify(uso));
  // editar: sube el límite de la organización
  const id = hojas.config_notificaciones.filas[1][0];
  const u = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"update", sheet:"config_notificaciones", id:"${id}", usuario_sesion:"bea@x.com", data:{limite_por_usuario:0, limite_organizacion:0}})}})`, ctx));
  check(u.status === 'success' && enviar('bea@x.com').status === 'success', 'editar: con 0 (sin límite) vuelve a enviar');
  const mal = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"update", sheet:"config_notificaciones", id:"${id}", usuario_sesion:"bea@x.com", data:{periodo:"anio"}})}})`, ctx));
  check(mal.status === 'error' && hojas.config_notificaciones.filas[1][2] === 'dia', 'editar: período inválido no se guarda');
}
{ // desde la hoja: la fila que supera el límite queda en ERROR (no PENDIENTE)
  const { ctx, hojas } = crearContexto(cred);
  hojas.config_notificaciones = hoja('config_notificaciones', [
    ['id','organizacion_id','periodo','limite_por_usuario','limite_organizacion','actualizado_en','actualizado_por'],
    ['cn00000001','org1','mes',1,0,'','']]);
  vm.runInContext(`prepararHojasNotificaciones()`, ctx);
  hojas.notificaciones.filas.push(['', '', 'ana@x.com', 'global', '', '', 'Uno', 'x', '', 'PENDIENTE', '', '', '']);
  hojas.notificaciones.filas.push(['', '', 'ana@x.com', 'global', '', '', 'Dos', 'x', '', 'PENDIENTE', '', '', '']);
  vm.runInContext(`enviarNotificacionesPendientes()`, ctx);
  const [f1, f2] = [hojas.notificaciones.filas[1], hojas.notificaciones.filas[2]];
  check(f1[9] === 'ENVIADA' && f2[9] === 'ERROR' && /límite de 1 notificaciones este mes/.test(f2[12]), 'hoja: la segunda del mes queda en ERROR con el motivo -> ' + f2[12]);
}
{ // pushes silenciosos: cambio de límites y uso del cupo de la organización
  const { ctx, hojas, enviados } = crearContexto(cred);
  const silenciosos = (tipo) => enviados.filter((m) => m.data && m.data.tipo === tipo);
  const r = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"create", sheet:"config_notificaciones", usuario_sesion:"ana@x.com", data:{organizacion_id:"org2", periodo:"dia", limite_por_usuario:0, limite_organizacion:5}})}})`, ctx));
  const conf = silenciosos('config_notificaciones');
  check(r.status === 'success' && tokensDe(conf) === 'tok-ana,tok-bea,tok-cami-vencido', 'config: push silencioso a todos los usuarios con acceso -> ' + tokensDe(conf));
  check(conf.every((m) => !m.data.titulo && !m.data.cuerpo && !m.notification), 'config: el push no tiene título ni cuerpo');
  check(!hojas.dispositivos.filas.some((f) => f[3] === 'tok-cami-vencido'), 'config: los tokens vencidos se borran');
  enviados.length = 0;
  vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "bea@x.com", {alcance:"usuarios", usuarios:["ana@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(tokensDe(silenciosos('uso_notificaciones')) === 'tok-bea', 'uso: con límite de organización, push silencioso a sus usuarios (org2)');
  enviados.length = 0;
  vm.runInContext(`_enviarNotificacion(getSpreadsheet(), "ana@x.com", {alcance:"usuarios", usuarios:["bea@x.com"], titulo:"T", cuerpo:"C"})`, ctx);
  check(silenciosos('uso_notificaciones').length === 0, 'uso: sin límite de organización (org1) no hay push de uso');
  enviados.length = 0;
  const mal = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"update", sheet:"config_notificaciones", id:"cn00000001", usuario_sesion:"ana@x.com", data:{periodo:"anio"}})}})`, ctx));
  check(mal.status === 'error' && silenciosos('config_notificaciones').length === 0, 'config: un cambio rechazado no avisa');
}
{ // plantillas y tipos de notificación
  const { ctx, hojas, enviados } = crearContexto(cred);
  const post = (o) => JSON.parse(vm.runInContext(`doPost({postData:{contents: ${JSON.stringify(JSON.stringify(Object.assign({ usuario_sesion: 'ana@x.com' }, o)))}}})`, ctx));
  vm.runInContext(`prepararHojasNotificaciones()`, ctx);
  const tipos = hojas.tipos_notificacion.filas;
  check(tipos.length === 8 && tipos[1][0] === 'tn00000001' && tipos[1][1] === 'Pago quincenal' && tipos[7][1] === 'Otro', 'tipos: la hoja nace con los 7 tipos iniciales');
  vm.runInContext(`prepararHojasNotificaciones()`, ctx);
  check(hojas.tipos_notificacion.filas.length === 8, 'tipos: preparar dos veces no duplica');
  const nt = post({ action: 'create', sheet: 'tipos_notificacion', data: { nombre: 'Aniversario' } });
  check(nt.status === 'success' && nt.id === 'tn00000008' && hojas.tipos_notificacion.filas[8][2] === 'activo', 'tipos: alta con ID del servidor -> ' + JSON.stringify(nt));
  check(post({ action: 'create', sheet: 'tipos_notificacion', data: { nombre: 'cumpleaños' } }).status === 'error', 'tipos: nombre repetido (sin importar mayúsculas) se rechaza');

  enviados.length = 0;
  const p1 = post({ action: 'create', sheet: 'plantillas_notificacion', data: { organizacion_id: 'org1', tipo_id: 'tn00000001', titulo: 'Día de pago', cuerpo: 'Hoy se realizó el pago de su quincena.', creado_por: 'ana@x.com' } });
  const fila = hojas.plantillas_notificacion.filas[1];
  check(p1.status === 'success' && fila[0] === 'pn00000001' && fila[2] === 'tn00000001' && fila[3] === 'Día de pago', 'plantilla: alta con ID del servidor -> ' + JSON.stringify(fila));
  check(enviados.some((m) => m.data && m.data.tipo === 'config_notificaciones'), 'plantilla: avisa con push silencioso');
  check(post({ action: 'create', sheet: 'plantillas_notificacion', data: { organizacion_id: 'org1', tipo_id: 'tn99', titulo: 'T', cuerpo: 'C' } }).status === 'error', 'plantilla: el tipo tiene que existir');
  check(post({ action: 'create', sheet: 'plantillas_notificacion', data: { organizacion_id: 'org1', tipo_id: 'tn00000001', titulo: '', cuerpo: 'C' } }).status === 'error', 'plantilla: título obligatorio');
  check(post({ action: 'create', sheet: 'plantillas_notificacion', data: { organizacion_id: 'org-x', tipo_id: 'tn00000001', titulo: 'T', cuerpo: 'C' } }).status === 'error', 'plantilla: la organización tiene que existir');
  const u = post({ action: 'update', sheet: 'plantillas_notificacion', id: 'pn00000001', data: { titulo: 'Pago de quincena', tipo_id: 'tn00000002' } });
  check(u.status === 'success' && hojas.plantillas_notificacion.filas[1][3] === 'Pago de quincena' && hojas.plantillas_notificacion.filas[1][2] === 'tn00000002' && hojas.plantillas_notificacion.filas[1][1] === 'org1', 'plantilla: editar conserva la organización');
  check(post({ action: 'update', sheet: 'plantillas_notificacion', id: 'pn00000001', data: { cuerpo: 'x'.repeat(501) } }).status === 'error', 'plantilla: mensaje de más de 500 se rechaza');
  const d = post({ action: 'delete', sheet: 'plantillas_notificacion', id: 'pn00000001' });
  check(d.status === 'success' && hojas.plantillas_notificacion.filas.length === 1, 'plantilla: eliminar por ID');
}
process.exit(fallas ? 1 : 0);
