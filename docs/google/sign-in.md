# Google Sign-In

El login de la app (`lib/features/auth/presentation/pages/login_page.dart`) usa el paquete `google_sign_in` para autenticar contra una cuenta de Google real. Esto requiere configuración en **Google Cloud Console**, separada por completo del código de la app.

## Por qué falla si no configurás nada

En Android, `google_sign_in` **no necesita ningún client ID hardcodeado en la app**. En su lugar, Google Play Services valida la app comparando dos cosas contra lo que esté registrado en Cloud Console:

1. El **nombre del paquete** (`applicationId`) del APK instalado.
2. La **huella SHA-1** del certificado con el que se firmó ese APK.

Si esa combinación exacta no está registrada como una credencial **OAuth Client ID → Android**, el login falla con:

```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)
```

`ApiException: 10` = `DEVELOPER_ERROR`. Es, con diferencia, el error más común de este flujo — ver [Troubleshooting](troubleshooting.md#apiexception-10-developer_error-al-tocar-continuar-con-google).

## 1. Pantalla de consentimiento OAuth (una sola vez)

En [Google Auth Platform](https://console.cloud.google.com/auth/overview), configurar:

1. **Información de la app**: nombre (`Estilo Neutral`) y correo de asistencia.
2. **Público**: si la cuenta es Gmail normal (no Workspace), la única opción es **Externo**, en modo **Testing**.
3. **Scopes**: agregar
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/drive.readonly`
4. **Test users** (si quedó en modo Testing): agregar ahí cada cuenta de Google que vaya a loguearse. Sin esto, cualquier cuenta que no esté en la lista falla con `access_denied`, aunque el SHA-1 esté perfecto.

## 2. Credenciales Android (una por combinación package + certificado)

Cada **flavor** (`dev` / `qa` / `prod`) y cada **build type** (`debug` / `release`) firma el APK con un certificado distinto, y las flavors además cambian el `applicationId` (sufijo `.dev` / `.qa`). Cada combinación necesita su **propia** credencial en **Credentials → Create Credentials → OAuth Client ID → Android**.

### Sacar el SHA-1 de un keystore

```bash
# Debug (compartido por todas las flavors en modo debug)
keytool -keystore ~/.android/debug.keystore -list -v -storepass android -alias androiddebugkey

# Release (el keystore de producción del proyecto)
keytool -keystore android/app/upload-keystore.jks -list -v -storepass estiloneutral -alias upload
```

Buscar la línea `SHA1:` en la salida.

### Credenciales ya creadas en este proyecto

| Nombre | Package name | Build | SHA-1 |
|---|---|---|---|
| Estilo Neutral - QA Debug | `com.estiloneutral.es.qa` | debug | `D4:4A:33:1C:58:D2:30:3D:BD:07:71:0A:22:6D:40:AE:7B:5F:C0:9D` |
| Estilo Neutral - Dev Debug | `com.estiloneutral.es.dev` | debug | `D4:4A:33:1C:58:D2:30:3D:BD:07:71:0A:22:6D:40:AE:7B:5F:C0:9D` |
| Estilo Neutral - Prod Release | `com.estiloneutral.es` | release | `D8:87:5A:8D:2A:D8:31:60:6D:17:0B:A0:69:8B:D7:96:63:AD:71:2F` |

Falta (crear solo si hace falta probar `flutter run --flavor prod` sin `--release`):

| Nombre sugerido | Package name | Build | SHA-1 |
|---|---|---|---|
| Estilo Neutral - Prod Debug | `com.estiloneutral.es` | debug | `D4:4A:33:1C:58:D2:30:3D:BD:07:71:0A:22:6D:40:AE:7B:5F:C0:9D` |

!!! tip "Todas comparten la misma pantalla de consentimiento"
    La lista de "Test users" es **una sola para todo el proyecto de Cloud**, no por credencial. Agregarla una vez alcanza para las cuatro combinaciones de arriba.

## 3. Publicar a producción (opcional)

Si no querés mantener una lista de test users a mano, podés cambiar el estado de publicación de **Testing** a **In production** (botón "Publish app" en Audience). Con scopes "sensibles" (`spreadsheets`, `drive.readonly`), esto muestra una pantalla de advertencia **"Google no verificó esta app"** a cada usuario nuevo (sortear con Avanzado → Ir a Estilo Neutral, no seguro), pero cualquier cuenta de Google puede entrar sin estar en una lista.

⚠️ Esto **no reemplaza el control de acceso real** — ver la sección siguiente.

## 4. Control de acceso real: `AccessControlConfig`

El login de Google por sí solo solo prueba que la persona tiene *una* cuenta de Google válida — no que esté autorizada a operar los datos del negocio. La lista real de quién puede usar la app vive en código, en [`lib/core/config/access_control_config.dart`](../../lib/core/config/access_control_config.dart), configurable vía la variable de entorno `ALLOWED_EMAILS` (separada por comas) en `.env` / `.env.dev` / `.env.test`:

```env
ALLOWED_EMAILS=neidapulgar1989@gmail.com,xhnl21@gmail.com
```

Flujo en `login_page.dart`:

1. El usuario completa el login con Google (`sheetsAuth.signIn()`).
2. Si el email **no** está en `ALLOWED_EMAILS` → se cierra esa sesión de Google inmediatamente (`sheetsAuth.signOut()`) y se muestra un error. Nunca llega a entrar a la app.
3. Si está permitido, se resuelve a qué organización pertenece (ver [Multi-organización](multi-organizacion.md)) y recién ahí se llama `authNotifier.login(...)`.

Para agregar o sacar un usuario autorizado: solo hay que editar `ALLOWED_EMAILS` en el `.env` correspondiente — no requiere tocar código ni Cloud Console.
