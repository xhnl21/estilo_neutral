// Tests del Apps Script con Node (sin Google): `node tools/apps_script/tests/acceso.test.js`
const fs = require('fs');
const src = fs.readFileSync(process.argv[2] || require("path").join(__dirname, "../../../google_apps_script.js"), 'utf8');
const ini = src.indexOf('function _motivoSinAcceso');
const fin = src.indexOf('function _findRowByColumnValue');
eval(src.slice(ini, fin));
const hoja = (rows) => ({ getLastRow: () => rows.length, getDataRange: () => ({ getValues: () => rows }) });
const ss = (h) => ({ getSheetByName: (n) => h[n] ? hoja(h[n]) : null });
const base = {
  usuarios: [['id','email','nombre','tipo_documento','cedula','status'],['u1','ana@x.com','Ana','V','1',''],['u2','bea@x.com','Bea','V','2','activo'],['u3','cami@x.com','C','V','3','activo'],['u4','eli@x.com','Eli','V','4','inactivo']],
  usuario_organizacion: [['id','usuario_email','organizacion_id'],['uo1','ana@x.com','org1'],['uo3','eli@x.com','org1'],['uo2','cami@x.com','org-borrada']],
  organizaciones: [['id','nombre'],['org1','Org']],
};
const casos = [
  ['ana@x.com', null],
  ['intruso@x.com', 'ya no está autorizada'],
  ['bea@x.com', 'no pertenece'],
  ['cami@x.com', 'ya no existe'],
  ['eli@x.com', 'está inactiva'],
];
let ok = true;
for (const [email, esperado] of casos) {
  const r = _motivoSinAcceso(ss(base), email);
  const pasa = esperado === null ? r === null : (r || '').includes(esperado);
  ok = ok && pasa;
  console.log(pasa ? 'OK ' : 'FAIL', email, '->', r);
}
const sinHoja = _motivoSinAcceso(ss({ usuarios: base.usuarios }), 'intruso@x.com');
console.log(sinHoja === null ? 'OK ' : 'FAIL', 'sin hojas de membresía no bloquea');
process.exit(ok && sinHoja === null ? 0 : 1);
