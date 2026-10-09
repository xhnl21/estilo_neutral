// Tests del Apps Script con Node (sin Google): `node tools/apps_script/tests/drive.test.js`
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
    getDataRange: () => ({ getValues: () => sh.filas.map((f) => f.slice()) }),
    getRange: (r, c, nr = 1, nc = 1) => ({
      getValues: () => Array.from({ length: nr }, (_, i) => Array.from({ length: nc }, (_, j) => ((sh.filas[r - 1 + i] || [])[c - 1 + j]) ?? '')),
      getValue: () => ((sh.filas[r - 1] || [])[c - 1]) ?? '',
      setValue: (v) => { (sh.filas[r - 1] || (sh.filas[r - 1] = []))[c - 1] = v; },
      setFormula: () => {},
    }),
  };
  return sh;
}

/** Drive en memoria: carpetas y archivos con un solo padre. */
function drive() {
  const items = {};
  let n = 0;
  const iter = (arr) => { let i = 0; return { hasNext: () => i < arr.length, next: () => arr[i++] }; };
  const carpeta = (nombre, padre) => {
    const c = {
      tipo: 'carpeta', id: 'F' + ++n, nombre, padre, descripcion: '',
      getId: () => c.id, getName: () => c.nombre, setName: (x) => { c.nombre = x; },
      getDescription: () => c.descripcion, setDescription: (x) => { c.descripcion = x; },
      getParents: () => iter(c.padre ? [items[c.padre]] : []),
      getFolders: () => iter(Object.values(items).filter((x) => x.tipo === 'carpeta' && x.padre === c.id)),
      getFoldersByName: (nm) => iter(Object.values(items).filter((x) => x.tipo === 'carpeta' && x.padre === c.id && x.nombre === nm)),
      getFiles: () => iter(Object.values(items).filter((x) => x.tipo === 'archivo' && x.padre === c.id)),
      createFolder: (nm) => carpeta(nm, c.id),
      createFile: (blob) => archivo(blob.nombre, c.id),
    };
    items[c.id] = c;
    return c;
  };
  const archivo = (nombre, padre, id) => {
    const a = {
      tipo: 'archivo', id: id || 'A' + ++n, nombre, padre,
      getId: () => a.id, getName: () => a.nombre, getDownloadUrl: () => 'https://drive/' + a.id,
      getParents: () => iter([items[a.padre]]),
      moveTo: (destino) => { a.padre = destino.id; },
    };
    items[a.id] = a;
    return a;
  };
  const raizDrive = carpeta('Mi unidad', null);
  return { items, carpeta, archivo, raizDrive };
}

function contexto() {
  const d = drive();
  const publica = d.carpeta('Estilo_neutral', d.raizDrive.id);
  const hojas = {
    usuarios: hoja('usuarios', [['id', 'email', 'nombre'], ['u1', 'ana@x.com', 'Ana']]),
    usuario_organizacion: hoja('usuario_organizacion', [['id', 'usuario_email', 'organizacion_id'], ['uo1', 'ana@x.com', 'org1']]),
    organizaciones: hoja('organizaciones', [['id', 'nombre'], ['org1', 'Centro'], ['org2', 'Este']]),
    inventario: hoja('inventario', [['id', 'cantidad', 'nombre', 'marca', 'modelo', 'talla', 'precio_usd', 'foto_id', 'foto', 'organizacion_id'],
      ['p1', 1, 'Pantalón', '', '', '', 10, 'g1', '', 'org1'],
      ['p2', 1, 'Gorra', '', '', '', 5, 'g2', '', 'org2']]),
    galeria: hoja('galeria', [['id', 'url', 'drive_file_id', 'nombre_archivo', 'fecha_subida'],
      ['g1', 'https://lh3.googleusercontent.com/d/ARCH1', 'ARCH1', 'pantalon.jpg', ''],
      ['g2', 'https://lh3.googleusercontent.com/d/ARCH2', '', 'gorra.jpg', ''],
      ['g3', 'https://lh3.googleusercontent.com/d/ARCH3', 'ARCH3', 'factura.jpg', '']]),
    audit_log: hoja('audit_log', [['id']]),
  };
  d.archivo('pantalon.jpg', publica.id, 'ARCH1');
  d.archivo('gorra.jpg', publica.id, 'ARCH2');
  d.archivo('factura.jpg', publica.id, 'ARCH3');
  const props = {};
  const ss = { getSheetByName: (n) => hojas[n] || null, getId: () => 'SS' };
  const ctx = {
    console: { log() {}, warn() {}, error: console.error },
    SpreadsheetApp: { getActiveSpreadsheet: () => ss, openById: () => ss },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; } }) },
    DriveApp: {
      getFolderById: (id) => { if (id === '1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD') return publica; const c = d.items[id]; if (!c) throw new Error('no existe'); return c; },
      getFileById: (id) => { const a = d.items[id]; if (!a) throw new Error('no existe'); return a; },
      createFolder: (nm) => d.carpeta(nm, d.raizDrive.id),
    },
    Utilities: { formatDate: (x) => x.toISOString().slice(0, 10), base64EncodeWebSafe: (x) => Buffer.from(x).toString('base64') },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    CacheService: { getScriptCache: () => ({ get: () => null, put() {} }) },
    ContentService: { createTextOutput: (t) => ({ setMimeType: () => t }), MimeType: { JSON: 'json' } },
    ScriptApp: {}, UrlFetchApp: {}, MailApp: {}, Logger: { log() {} },
  };
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  const ruta = (id) => { const p = []; let x = d.items[id]; while (x && x.padre) { x = d.items[x.padre]; p.unshift(x.nombre); } return p.slice(1).join('/'); };
  return { ctx, d, publica, props, ruta, hojas };
}

let fallas = 0;
const check = (cond, msg) => { console.log((cond ? 'OK   ' : 'FAIL ') + msg); if (!cond) fallas++; };

{ // organizarDrive: en uso a su organización, sin uso a la privada
  const { ctx, ruta, props, d } = contexto();
  const r = vm.runInContext('organizarDrive()', ctx);
  check(ruta('ARCH1') === 'Estilo_neutral/Centro (org1)/Productos', 'en uso (org1) -> ' + ruta('ARCH1'));
  check(ruta('ARCH2') === 'Estilo_neutral/Este (org2)/Productos', 'en uso, ID sacado de la URL (org2) -> ' + ruta('ARCH2'));
  check(ruta('ARCH3') === 'Estilo Neutral · Privado/Sin organización/Fotos sin usar', 'sin uso: a la carpeta privada -> ' + ruta('ARCH3'));
  check(r.publicas === 2 && r.privadas === 1 && r.errores.length === 0, 'resumen -> ' + JSON.stringify(r));
  check(!!props.DRIVE_CARPETA_PRIVADA_ID, 'la carpeta privada se crea y se recuerda su ID');
  check(d.items[props.DRIVE_CARPETA_PRIVADA_ID].padre === d.raizDrive.id, 'la carpeta privada está FUERA de la pública');
  const r2 = vm.runInContext('organizarDrive()', ctx);
  check(r2.publicas === 0 && r2.privadas === 0 && r2.sinCambios === 2, 'correrla de nuevo no mueve nada (la privada no se recorre)');
}
{ // la organización se renombra: misma carpeta, nombre nuevo
  const { ctx, ruta, hojas, d } = contexto();
  vm.runInContext('organizarDrive()', ctx);
  hojas.organizaciones.filas[1][1] = 'Centro Nuevo';
  vm.runInContext('organizarDrive()', ctx);
  const carpetasOrg1 = Object.values(d.items).filter((x) => x.tipo === 'carpeta' && x.descripcion === 'org1');
  check(carpetasOrg1.length === 1 && ruta('ARCH1') === 'Estilo_neutral/Centro Nuevo (org1)/Productos', 'renombrar la organización no duplica la carpeta -> ' + ruta('ARCH1'));
}
{ // foto que deja de usarse: a la privada de SU organización; si vuelve a usarse, a la pública
  const { ctx, ruta, hojas } = contexto();
  vm.runInContext('organizarDrive()', ctx);
  hojas.inventario.filas[1][7] = '';
  vm.runInContext('organizarDrive()', ctx);
  check(ruta('ARCH1') === 'Estilo Neutral · Privado/Centro (org1)/Fotos sin usar', 'deja de usarse: privada de su organización -> ' + ruta('ARCH1'));
  vm.runInContext('_publicarFotoDeProducto(getSpreadsheet(), "g1", "org1")', ctx);
  check(ruta('ARCH1') === 'Estilo_neutral/Centro (org1)/Productos', 'un producto la vuelve a usar: vuelve a la pública -> ' + ruta('ARCH1'));
  vm.runInContext('_publicarFotoDeProducto(getSpreadsheet(), "g-no-existe", "org1")', ctx);
  check(true, 'una foto inexistente no rompe nada');
}
{ // subida: a la carpeta de la organización del usuario
  const { ctx, ruta, d } = contexto();
  ctx.PropertiesService.getScriptProperties().setProperty('AUTENTICACION_OBLIGATORIA', 'no');
  ctx.Utilities.base64Decode = () => [1, 2];
  ctx.Utilities.newBlob = (bytes, tipo, nombre) => ({ nombre });
  const r = JSON.parse(vm.runInContext(`doPost({postData:{contents: JSON.stringify({action:"upload_image", usuario_sesion:"ana@x.com", fileName:"nueva.jpg", base64Data:"AQI="})}})`, ctx));
  check(r.status === 'success' && ruta(r.fileId) === 'Estilo_neutral/Centro (org1)/Productos', 'subida: va a <organización del usuario>/Productos -> ' + (r.fileId && ruta(r.fileId)));
}
process.exit(fallas ? 1 : 0);
