# Galería de fotos (Inventario)

Caso completo del rediseño de "subir foto de producto": qué se pidió, cómo quedó diseñado, el bug que apareció al probarlo en producción, y el runbook para resolverlo si vuelve a pasar (por ejemplo, al cambiar los scopes de Apps Script).

## 1. Qué se pidió

El flujo anterior era 100% manual: el usuario tenía que subir la foto a Google Drive por su cuenta y pegar el enlace/ID en un campo de texto del formulario de producto. Se pidió rediseñarlo con estos requisitos:

1. El usuario **solo toma la foto** (o la elige de la galería) — no maneja rutas ni IDs.
2. Ninguna URL/ID vive hardcodeada en el código — todo sale de variables de entorno.
3. Tres acciones posibles: tomar foto, elegir de galería, descargar la foto a la galería del teléfono.
4. Subir una imagen tiene que ser trivial para el usuario.
5. **La foto de un producto que ya se usó en una venta no se puede perder ni pisar** — una factura vieja siempre tiene que poder resolver la foto correcta, aunque el producto haya cambiado de foto después.
6. Todo se relaciona **por ID, no por URL** — se agrega una hoja nueva, `galeria`, que es la única que guarda URLs reales.

## 2. Diseño final

### Hoja `galeria` (nueva)

| columna | contenido |
|---|---|
| `id` | `g00000001`, `g00000002`, ... |
| `url` | `https://lh3.googleusercontent.com/d/<fileId>` |
| `drive_file_id` | ID del archivo en Drive |
| `nombre_archivo` | nombre original del archivo |
| `fecha_subida` | timestamp ISO |

**Regla clave:** las filas de `galeria` **nunca se borran ni se pisan**. Cada subida crea una fila nueva; cambiar la foto de un producto solo actualiza a qué `id` de `galeria` apunta (`inventario.foto_id`), la fila vieja queda intacta. Esto es lo que satisface el requisito 5: una foto usada en una venta pasada sigue existiendo para siempre en `galeria`, aunque el producto tenga hoy una foto distinta.

### FK en `inventario`

La columna `foto_url` se reemplazó por `foto_id` (FK a `galeria.id`). La imagen visual en el Sheet se resuelve con `VLOOKUP`, no con una URL embebida:

```
=IFERROR(IMAGE(VLOOKUP(H{fila};galeria!A:B;2;FALSE));"")
```

(el separador de argumentos es `;`, no `,` — configuración regional de esta planilla, ver [Troubleshooting](troubleshooting.md)).

En Flutter, `SheetsDataService.fotoUrlPorId(fotoId)` hace ese mismo JOIN lógico contra `_galeria` en memoria.

### Flujo en la app (`_FotoPicker`, en `inventario_page.dart`)

Un único widget reutilizable (creación de producto y edición de foto existente) con 4 botones: **Tomar foto**, **Galería**, **Descargar**, **Quitar**. El usuario nunca ve un ID ni una URL.

- Tomar/Elegir → `image_picker` (`ImagePicker().pickImage(...)`) → bytes → `SheetsDataService.subirFotoGaleria(...)`.
- Descargar → `http.get` sobre la URL resuelta → `gal` (`Gal.putImageBytes(...)`) guarda en la galería del teléfono.

### Backend (Apps Script)

`upload_image` (acción ya existente, ver [Apps Script](apps-script.md)) sube el archivo a `DRIVE_FOLDER_ID` y devuelve `{fileId, fileUrl, downloadUrl}`. `subirFotoGaleria` en Flutter llama a esa acción y, si responde éxito, hace un segundo POST con `action: "create", sheet: "galeria"` para registrar la fila nueva.

### Variables de entorno

Nada de esto vive hardcodeado: `APPS_SCRIPT_URL` (Apps Script Web App) sale de `.env`/`.env.dev`/`.env.test`. El único ID que sigue "fijo" es `DRIVE_FOLDER_ID`, pero vive **del lado del servidor** (dentro de `google_apps_script.js`), nunca en el cliente Flutter — el usuario ni la app lo ven.

## 3. El bug: `"Exception: Access denied: DriveApp."`

Al probar la subida real por primera vez (la acción `upload_image` estaba escrita pero nunca se había ejercitado en producción), toda subida fallaba y la app mostraba "No se pudo subir la foto. Probá de nuevo."

### Primer hallazgo (no era el problema real): 404 transitorio del redirect

Apps Script responde a un POST con un `302` que redirige a una URL de eco (`script.googleusercontent.com/macros/echo?...`). Esa URL de eco a veces devuelve `404` de forma transitoria aunque la escritura ya se haya completado del lado del servidor. Se solucionó agregando reintentos con backoff en `SheetsDataService.subirFotoGaleria` (`sheets_data_service.dart`) antes de darse por vencido — pero esto **no era la causa del fallo real**, solo un ruido aparte que también valía la pena arreglar.

### Diagnóstico real

El mensaje de error que devolvía Apps Script era siempre el mismo: `Exception: Access denied: DriveApp.` — un error de autorización de scopes de Apps Script. Los "Registros de Cloud" del editor **no se pueblan para ejecuciones de tipo Aplicación web** en este proyecto (limitación real, no hace falta perder tiempo ahí), así que la forma efectiva de diagnosticar fue devolver el detalle directo en la respuesta JSON:

```javascript
} catch (err) {
  let debugInfo = {};
  try {
    debugInfo = {
      effectiveUser: Session.getEffectiveUser().getEmail(),
      stack: (err && err.stack ? err.stack : '(sin stack)')
    };
  } catch (debugErr) {
    debugInfo = { debugError: debugErr.toString() };
  }
  return respond({ status: "error", message: err.toString(), debug: debugInfo }, 500);
}
```

Eso reveló dos cosas:

1. `effectiveUser` era la cuenta correcta (`xhnl21@gmail.com`, dueña de la carpeta de Drive) — **no era un problema de autorización general**, ya tenía el scope de Drive concedido.
2. El `stack` apuntaba a una línea muy específica, **no** a `DriveApp.getFolderById(...)` ni a `folder.createFile(...)` (esas dos ya funcionaban):
   ```
   file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
   ```

### Causa raíz

`file.setSharing(ANYONE_WITH_LINK, VIEW)` — hacer un archivo "público, cualquiera con el enlace" mediante la API — es una operación que **Google bloquea para apps no verificadas**, como medida antiabuso/antimalware (evita que apps de terceros sin revisión de seguridad publiquen archivos públicos a voluntad). No es un bug de configuración de la cuenta ni de scopes: es una restricción de plataforma para esa acción puntual, independiente de que el resto del acceso a Drive funcione bien.

### Fix

Se sacó esa línea. Es innecesaria: `DRIVE_FOLDER_ID` ya tiene configurado el permiso "cualquiera con el enlace: escritor" **a nivel de carpeta** (confirmado con la API de Drive), y los archivos nuevos creados dentro heredan ese permiso automáticamente. Se verificó pidiendo la URL pública (`https://lh3.googleusercontent.com/d/<fileId>`) de un archivo recién creado **sin** el `setSharing` explícito — devolvió `200` sin necesidad de autenticación.

```javascript
const file = folder.createFile(blob);
// No se llama a file.setSharing(): Google bloquea a apps no verificadas
// hacer públicos archivos vía API (prevención de abuso/malware). No hace
// falta: el archivo hereda el permiso "cualquiera con el enlace" que ya
// tiene configurado DRIVE_FOLDER_ID a nivel de carpeta.
```

## 3.1 Efecto secundario: la foto recién subida no se ve en el momento

Una vez arreglado el bug anterior, apareció un síntoma distinto: la foto se sube bien (queda registrada en `galeria` con la URL correcta), pero el ícono de error aparece igual, un instante, apenas termina la subida.

**Causa 1 (real, pero secundaria):** el CDN público de Drive (`lh3.googleusercontent.com`) tarda unos segundos en empezar a servir un archivo recién creado — la URL es válida y va a funcionar, pero justo después de subir todavía no está propagada. Si la app intenta mostrarla de inmediato, `Image.network` la pide antes de que esté lista y cae en el error.

**Fix:** en `_tomarOElegir` (`inventario_page.dart`), después de una subida exitosa, se espera a que la URL responda `200` (hasta 5 intentos, 1 segundo entre cada uno) **antes** de llamar a `onChanged` y mostrar la foto nueva:

```dart
Future<void> _esperarUrlDisponible(String? url) async {
  if (url == null || url.isEmpty) return;
  for (var intento = 0; intento < 5; intento++) {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return;
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
  }
}
```

**Causa 2 (la real, de fondo):** en `_showFotoActionSheet` (el bottom sheet que se abre al tocar el ícono de cámara en la lista, sin pasar por "Editar Producto"), `_FotoPicker` recibía `fotoId: producto.fotoId` como un valor **fijo**, capturado una sola vez cuando se abría la hoja — el `Column` de ese bottom sheet no estaba envuelto en un `StatefulBuilder`. El upload y el `updateProducto()` sí guardaban bien el `foto_id` nuevo en el backend (se pudo confirmar leyendo la hoja directamente), pero la UI nunca se enteraba del cambio: seguía mostrando la foto (o el estado) que tenía el producto al momento de abrir la hoja, no la recién subida. Por eso el síntoma persistía incluso después de arreglar el retraso del CDN — no era un problema de timing, era que el widget nunca iba a actualizarse pasara lo que pasara.

`_showProductoDialog` (crear/editar producto completo) no tenía este problema porque ya usaba `StatefulBuilder` con una variable local `pendingFotoId`.

**Fix:** se envolvió el contenido de `_showFotoActionSheet` en un `StatefulBuilder`, con una variable local `fotoIdActual` que arranca en `producto.fotoId` y se actualiza con `setModalState` dentro del callback `onChanged` de `_FotoPicker`, antes de persistir el cambio con `updateProducto`.

## 3.2 La causa real de fondo: el POST inicial se agota en redes móviles reales

Después de los fixes anteriores, probando en un dispositivo físico (Redmi Note 8) sobre red móvil real, la subida seguía fallando con el mismo síntoma ("no se pudo subir la foto"), incluso con la ventana de reintentos del redirect de eco ampliada a ~15s. Se agregó logging detallado (`Logger.api`/`Logger.error`) en cada paso de `subirFotoGaleria` para ver exactamente dónde fallaba, y apareció esto:

```
Error uploading image to Google Drive: TimeoutException after 0:00:30.000000: Future not completed
```

Es decir: **ninguno de los reintentos del redirect llegó siquiera a ejecutarse** — el POST inicial (el que manda la imagen en base64) se agotaba a los 30 segundos, antes de que Apps Script pudiera responder. Confirmado con el archivo apareciendo igual en Drive minutos después: Apps Script sí termina de procesar el request y crea el archivo, pero la respuesta nunca llega al teléfono a tiempo — el cliente ya se había rendido.

**Causa:** una imagen de ~370 KB en bytes se vuelve ~500 KB en base64 (overhead ~33%), y sobre una red móvil real (no la red estable de una PC de desarrollo) ese POST + el tiempo de procesamiento de Apps Script (`LockService`, decodificar base64, crear el archivo en Drive) fácilmente supera los 30 segundos que tenía configurado el timeout del POST inicial. Todos los fixes anteriores (reintentos del redirect de eco) apuntaban al paso equivocado — ese código nunca se ejecutaba porque el timeout ocurría antes, en el primer POST.

**Fix:** se subió el timeout del POST inicial de `subirFotoGaleria` de 30 a **90 segundos** (es la única llamada que manda un payload grande; el resto de las acciones CRUD tienen payloads chicos y no lo necesitan).

Moraleja para el futuro: ante un timeout en un flujo de subida de archivos, revisar primero el **request que manda el payload pesado**, no solo el mecanismo de confirmación/redirect — son problemas de naturaleza distinta (tamaño de payload + velocidad de red vs. una particularidad de la infraestructura de Apps Script).

## 4. Runbook: reautorizar Apps Script cuando cambian los scopes

Mientras se investigaba lo anterior, hizo falta declarar explícitamente los scopes del script (`appsscript.json` → `oauthScopes`) para descartar que Apps Script estuviera auto-detectando un scope de Drive más angosto de lo necesario. Cambiar los scopes declarados de un proyecto ya desplegado **no siempre dispara un nuevo diálogo de consentimiento solo con "Nueva versión"** — quedó "pegado" con una autorización vieja varias veces seguidas. La forma que sí funcionó, de punta a punta:

1. Agregar una función descartable que ejercite el servicio en cuestión (en este caso, Drive):
   ```javascript
   function testDriveAuth() {
     DriveApp.getFolderById(DRIVE_FOLDER_ID);
   }
   ```
   (si usás `clasp push`, tiene que estar en el archivo local `google_apps_script.js`, no solo pegada a mano en el editor — un `push` posterior te la borra sin avisar).
2. **Revocar el acceso actual del proyecto** desde la cuenta de Google: [myaccount.google.com/permissions](https://myaccount.google.com/permissions) → buscar el nombre del proyecto (ojo con mayúsculas/minúsculas si hay más de una entrada parecida) → **Borrar todo**.
3. En el editor de Apps Script, recargar la página (F5) — el dropdown de funciones se cachea y a veces no ve una función recién subida por `clasp` sin recargar.
4. Seleccionar la función de prueba (`testDriveAuth`) → **Ejecutar**. Ahora sí debería aparecer el diálogo completo de autorización ("Se requiere autorización") pidiendo **todos** los scopes declarados de una — aceptar (Avanzado → Ir a "estilo neutral", no seguro → Permitir).
5. **Implementar → Administrar implementaciones → ✏️ editar la implementación Web App existente → Versión: Nueva versión → Implementar.** (edición de la implementación existente, no una nueva — así no cambia la URL `/exec` y no hace falta tocar `.env`).
6. Borrar la función de prueba del archivo (`testDriveAuth`) una vez confirmado que todo funciona, y volver a desplegar.

Este runbook es más general que este bug puntual: sirve para cualquier caso futuro en el que Apps Script devuelva `Access denied: <Servicio>` para un servicio que debería estar autorizado.

## 5. Scopes declarados (`appsscript.json`)

Se pasó de scopes auto-detectados a una lista explícita, para que quede documentado qué necesita realmente el script:

```json
"oauthScopes": [
  "https://www.googleapis.com/auth/spreadsheets",
  "https://www.googleapis.com/auth/drive",
  "https://www.googleapis.com/auth/script.external_request",
  "https://www.googleapis.com/auth/script.scriptapp",
  "https://www.googleapis.com/auth/userinfo.email"
]
```

- `spreadsheets` — `SpreadsheetApp` (CRUD de todas las hojas).
- `drive` — `DriveApp` (subida de fotos a `DRIVE_FOLDER_ID`).
- `script.external_request` — `UrlFetchApp` (usado por `obtenerTasaBCV`, ver [Automatización](automatizacion.md)).
- `script.scriptapp` — `ScriptApp` (triggers programados de `obtenerTasaBCV`).
- `userinfo.email` — `Session.getEffectiveUser()/getActiveUser()` (usado durante este diagnóstico; se puede sacar si no se vuelve a necesitar, pero no molesta dejarlo).

Nota: al declarar `oauthScopes` explícitamente, Apps Script **deja de auto-detectar scopes** — cualquier servicio nuevo que se agregue al script más adelante hay que sumarlo acá a mano, o va a fallar con el mismo `Access denied`.
