# Cliente HTTP (dio)

Toda la app habla con Google (GViz para leer, Apps Script para escribir/subir fotos) a través de **`dio`** — migrado desde `package:http` a pedido explícito para que `dio` sea el cliente HTTP real de toda la app, no solo una dependencia declarada sin uso. Esta página documenta cómo quedó armado y, sobre todo, los problemas puntuales que aparecieron en el camino — para no repetirlos.

## Dónde vive

- **`lib/core/network/dio_client.dart`** — `DioClient`: wrapper fino sobre `Dio` con un interceptor de logging (pega con `Logger.api`/`Logger.object`) y defaults sensatos (`connectTimeout: 15s`, `sendTimeout: 15s`, `receiveTimeout: 20s`, headers `Content-Type`/`Accept: application/json`).
- **`lib/shared/google_sheets/sheets_data_service.dart`** — el único consumidor real. Expone un `Dio? dio` opcional en el constructor (para inyectar un doble de prueba, ver [Testing](#testing-con-dio)) y arma su `DioClient` así:
  ```dart
  _dioClient = DioClient(customDio: dio) {
    // Ajustar acá y no pasando `baseOptions` al constructor de DioClient:
    // pasarle baseOptions reemplaza TODOS sus defaults (timeouts, headers),
    // no se combina con ellos.
    _dioClient.dio.options.validateStatus = (status) => status != null && status < 500;
  }
  ```
  `validateStatus < 500` es clave: así un 400/404/403 de Apps Script llega como una `Response` normal (para leerla e inspeccionarla), no como una `DioException` que hay que atrapar.
- **`lib/presentation/pages/inventario_page.dart`** (`_FotoPickerState`) — un `Dio` propio (`DioClient().dio`), para las descargas simples (verificar que una URL ya está disponible, bajar la foto a la galería del teléfono).

## El patrón central: `_postAppsScriptJson`

Todas las escrituras (`_postToAppsScript`, `subirFotoGaleria`, `refrescarTasaHoy`) pasan por un solo helper privado en `SheetsDataService`: `_postAppsScriptJson(payload, {sendTimeout, receiveTimeout, reintentosEco})`.

**Por qué existe:** Apps Script, al recibir un POST, responde con un `302` que redirige a una URL de eco (`script.googleusercontent.com/macros/echo?...`) — y **dio no sigue automáticamente el redirect de un POST** (se comprobó en vivo: mismo comportamiento que tenía `package:http`, no es una regresión de la migración). Hay que pedir esa URL de eco a mano con un GET aparte.

```dart
Future<({bool huboRedirect, Map<String, dynamic>? data})> _postAppsScriptJson(
  Map<String, dynamic> payload, {
  Duration sendTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 15),
  List<Duration> reintentosEco = const [Duration(milliseconds: 500), Duration(milliseconds: 1000), Duration(milliseconds: 2000)],
}) async {
  // 1. POST al Web App.
  // 2. Si el status es 302/303/307 y hay header `location`, sigue esa URL
  //    con un GET — reintentando con backoff si el eco responde con un
  //    código distinto de 200 (es transitorio, no un fallo real).
  // 3. Devuelve `huboRedirect` (Apps Script aceptó el POST, aunque el eco
  //    haya fallado) + `data` (el body ya parseado, si se pudo leer).
}
```

`response.data` de dio **ya viene decodificado** (un `Map<String, dynamic>` si el content-type es JSON) — no hace falta `jsonDecode` manual como con `http`.

- **`_postToAppsScript`** (CRUD genérico) trata como éxito `data != null` **o** `huboRedirect` — si Apps Script aceptó el POST pero no se pudo confirmar el eco, se asume que la acción ya quedó procesada (no hace falta leer el body para un create/update/delete).
- **`subirFotoGaleria`** y **`refrescarTasaHoy`** exigen `data != null` — sí necesitan el contenido real de la respuesta (`fileId`/`fileUrl`, o el resultado de `obtenerTasaBCV()`).

## Timeouts largos para la subida de fotos

`subirFotoGaleria` pasa `sendTimeout`/`receiveTimeout` de **90 segundos** (no los 15s por defecto) — una imagen en base64 puede tardar bastante en subir por una red móvil real, y con 15-30s se cortaba a mitad de camino en pruebas de campo (ver [Galería de fotos § 3.2](galeria-fotos.md#32-la-causa-real-de-fondo-el-post-inicial-se-agota-en-redes-moviles-reales)).

## "Servidor ocupado": reintentar el POST completo

`doPost` en `google_apps_script.js` usa `LockService.getScriptLock()` — si otra ejecución todavía está corriendo del lado del servidor, devuelve de inmediato `{"status":"error","message":"Servidor ocupado..."}`, **sin haber llegado a hacer nada**. `subirFotoGaleria` detecta ese mensaje puntual y reintenta el POST completo desde cero (hasta 3 veces, con 2s de espera) — es seguro porque no se creó ningún archivo en el intento fallido.

## Logging: cuidado con volcar payloads grandes

El interceptor de `DioClient` loguea el body de cada request/response — para `upload_image` eso significaba, al principio, volcar la imagen entera en base64 a la consola. Se resolvió en dos lugares:

1. **`Logger.object`** (usado por el interceptor) trunca cualquier string mayor a 300 caracteres, recursivamente dentro de Maps/Lists.
2. **`Logger.truncate(String)`** — versión pública para cuando el mensaje se arma a mano con `Logger.api` en vez de pasarle un objeto a `Logger.object` (caso de `_postAppsScriptJson`, que arma el mensaje `'${response.statusCode} - Respuesta Apps Script: ...'` incluyendo el body crudo).

Si agregás un log nuevo que pueda incluir una respuesta HTTP cruda (páginas de error HTML de Google llegan a pesar 15-20 KB), usá `Logger.object` o `Logger.truncate` — nunca interpoles el body directo en un string.

## Testing con dio

### El gotcha: dio + `testWidgets()` sin `runAsync`

Esto costó bastante tiempo diagnosticar, así que queda documentado explícitamente: **una llamada real de dio (incluso contra un adapter 100% falso, sin red real) no se resuelve nunca dentro del zone "fake async" de `testWidgets()`**, a menos que corra dentro de `tester.runAsync()`. Es una limitación de cómo Flutter Test maneja async real dentro de ese zone — no es específico de este proyecto, y **tampoco es exclusivo de dio**: cualquier código que dispare una operación async real (dio, sockets, timers reales) sin pasar por `runAsync` puede colgar `pumpAndSettle()` indefinidamente hasta el timeout del test (por default, 10 minutos).

`package:http` parecía "funcionar bien" en los mismos tests antes de la migración — no es que fuera inmune al problema, es que el `HttpClient` de `dart:io` que usa por debajo sí tiene tratamiento especial dentro de Flutter Test, cosa que un `HttpClientAdapter` de dio (o uno hecho a mano) no tiene.

**Regla práctica:** cualquier `testWidgets()` que dispare, directa o indirectamente (`ServiceLocator().init()`, `addCliente()`, `addVenta()`, etc.), una llamada a través de `SheetsDataService` tiene que envolver ese disparo en `tester.runAsync()`:

```dart
await tester.runAsync(() async {
  await service.addCliente(cliente);
});
```

Ver `test/core/router/app_router_test.dart` y `test/presentation/clientes_page_test.dart` para los dos casos reales que se arreglaron así.

### `FakeHttpClientAdapter` — no tocar la red real en tests de widgets

`test/test_fake_dio.dart` define `FakeHttpClientAdapter implements HttpClientAdapter` + `buildFakeDio()`: responde de inmediato (sin red) con el status/body que se le pida (por default, 400 vacío — fuerza a `SheetsDataService` a quedarse con los datos semilla locales, que es lo que la mayoría de los tests de widgets necesita).

```dart
ServiceLocator().init(dio: buildFakeDio());
```

`ServiceLocator.init({Dio? dio})` acepta ese punto de inyección — pensado solo para tests, en producción se llama sin argumentos y arma su propio `Dio` real.

### `takeException()`, no reemplaces `FlutterError.onError` a mano

Si un test necesita comprobar que el árbol de widgets no tiró un error (ej. un `RenderFlex` overflow) sin que el `expect` de eso frene el resto del test, usá la API que ya trae Flutter para esto:

```dart
final exception = tester.takeException();
expect(exception, isNull);
```

Reemplazar `FlutterError.onError` a mano **sin encadenar el handler original** rompe el tracking interno de `TestWidgetsFlutterBinding` y tira un error de aserción (`_pendingExceptionDetails != null`) ajeno a lo que el test realmente quería probar — es justo lo que pasaba en `clientes_page_test.dart` antes de este fix.

## Qué NO cambió

- `googleapis`/`google_sign_in` siguen dependiendo de `package:http` — no se puede sacar `http` del todo del proyecto (queda como dependencia *transitiva*, ya no directa; confirmalo con `flutter pub deps` si alguna vez extrañás verlo en `pubspec.yaml`).
- El endpoint de lectura (GViz CSV) sigue siendo el mismo — solo cambió el cliente que hace el `GET`.
