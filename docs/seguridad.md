# Seguridad

**Última actualización:** 2026-10-09 · App `1.0.0+2026` · Apps Script producción `@72`

Estado de la seguridad del sistema (app + Apps Script + Google Sheets), qué se aplicó y qué queda por hacer.

## 1. Cómo se protegen hoy los datos

| Capa | Protección |
|---|---|
| **Login** | Google Sign-In. Pide **solo el email** (antes pedía acceso a todas las hojas y a leer todo el Drive del usuario, sin usarlo). |
| **Identidad en el servidor** | Cada pedido lleva el **token de acceso de Google** de la sesión (`access_token`). El Apps Script lo valida con Google (`tokeninfo`) y usa **ese** email, no el que declara la app. El resultado se guarda 5 minutos en caché. |
| **Acceso** | Solo cuentas de la hoja `usuarios`, **activas**, con membresía en una organización existente. Inactivar o quitar el acceso cierra la sesión al instante (push silencioso). |
| **Lecturas** | La app lee las hojas por el Apps Script (`leer_hojas`, en un solo pedido; el servidor usa el servicio avanzado de Sheets para leerlas todas en una llamada, y de `audit_log` manda las últimas 500 filas), verificado y solo para usuarios con acceso. Sin sesión de Google la app **no lee nada** (la hoja es privada): la primera carga la hace el login. |
| **Tiempo de carga** | Medido en un Redmi Note 8 (2026-10-09): el pedido de lectura completo (27 hojas) tarda ~2,7 s (la lectura en sí ~0,5 s con el script activo; ~3 s la primera vez tras un deploy). La app entra a los ~14 s desde que se abre, de los cuales ~7 s son el video de inicio. Antes de las mejoras: ~30 s. |
| **Sin datos de ejemplo** | La app ya no carga datos de ejemplo al iniciar (antes se mezclaban con los reales y permitían entrar sin verificar en el servidor). Si no puede leer, lo dice: "No se pudieron cargar los datos: <motivo>" o, en el login, "No se pudo verificar tu acceso con el servidor… Intentá de nuevo" (sin cerrar la sesión de Google). |
| **Escrituras** | Confirmadas por el servidor y revertidas si fallan. Límite de **90 cambios por minuto por usuario**. |
| **URL pública (`/exec`)** | El `doGet` solo dice "activo": ya no muestra el ID de la hoja ni sus nombres. |
| **Notificaciones y correo** | Cupos por organización y cupo diario de Google; clave de FCM rotada (2026-10-08) y fuera de git. |
| **Secretos** | `.env*`, firma (`key.properties`), `google-services.json`, `fcm-clave*.json` y `credencial_fcm.js` fuera de git. Los secretos del servidor nunca van en los `.env` (terminan en el APK). |
| **Registros** | Cada cambio queda en `audit_log`. El Logger oculta emails y tokens. |

### Token obligatorio (desde el 2026-10-09, `@68`)

El servidor **rechaza todo pedido sin token de Google válido** ("Actualizá la app y volvé a iniciar sesión"). Las apps anteriores a `1.0.0+2025` ya no pueden guardar ni enviar: hay que actualizarlas. Verificado en producción: un pedido sin token se rechaza y la app `1.0.0+2025` funciona.

Vuelta atrás de emergencia: propiedad del script `AUTENTICACION_OBLIGATORIA` = `no` (vuelve a aceptar el email declarado). Borrarla para volver a exigir el token.

## 2. Pasos para restringir (los hace el dueño)

Hacerlos **en este orden**: cada uno supone que el anterior funciona.

### Paso 1. Actualizar todos los teléfonos y comprobar

1. Instalar `1.0.0+2025` (o posterior) en **todos** los teléfonos que usan la app (incluido el de Neida).
2. Abrir la app e iniciar sesión en cada uno.
3. Revisar que los módulos muestren bien los datos: montos, fechas, clientes, inventario, ventas. Si algo se viera mal, en el editor de Apps Script → **⚙ Configuración del proyecto → Propiedades del script** agregar `LECTURA_POR_SERVIDOR` = `no` (la app vuelve a leer como antes) y avisar.

### Paso 2. Restringir la aplicación (cliente OAuth) (hecho el 2026-10-09)

1. En **Propiedades del script** aparece `OAUTH_CLIENTES_VISTOS`: el servidor anota ahí el cliente OAuth de cada app que le manda un token (también los que rechaza).
2. `OAUTH_CLIENTES_PERMITIDOS`: los clientes de **nuestras** apps, separados por coma. Cada variante (prod, QA, dev) es un cliente distinto:

| App | Cliente OAuth |
|---|---|
| Producción (`com.estiloneutral.es`) | `312343708119-itirtdireac6ka57268mg7elgr…` (ver la propiedad) |
| QA (`com.estiloneutral.es.qa`) | `312343708119-qd8qo1mm3u5g07osls9hl4sfov3qge3a.apps.googleusercontent.com` |
| Dev | Aparece en `OAUTH_CLIENTES_VISTOS` la primera vez que se use. |

Una app no listada recibe "Sesión de Google emitida para otra aplicación (cliente …)", con el ID para agregarlo.

### Paso 3. Modo estricto: ya aplicado

Desde `@68` el token es obligatorio sin necesidad de propiedades (ver §1). Solo hace falta actuar si algo falla: `AUTENTICACION_OBLIGATORIA` = `no`.

### Paso 4. Hacer privada la hoja (hecho el 2026-10-09)

Hojas de producción y de test en **Restringido**, solo el dueño con acceso. Verificado: gviz responde `401` desde afuera y las apps prod y QA inician sesión y cargan los datos por el Apps Script.


Recién con el paso 3 funcionando un día normal de trabajo:
1. Abrir la hoja "Estilo Neutral" → **Compartir** → **Acceso general**: cambiar de "Cualquier persona con el enlace" a **"Restringido"**.
2. Dejar con acceso solo a las personas que la editan a mano (dueño). Las apps no necesitan acceso: leen y escriben por el Apps Script, que corre como el dueño.
3. Abrir la app (cerrarla del todo y volver a entrar) y comprobar que carga los datos.

Si después de esto la app no muestra datos: volver a "Cualquier persona con el enlace" y avisar.

### Paso 5. Revisar quién tiene acceso

- **Hoja y carpeta de Drive de las fotos:** en **Compartir**, quitar a quien no corresponda. La carpeta de fotos puede seguir pública por enlace (son las fotos de los productos).
- **Proyecto de Apps Script:** en el editor → **Compartir**: solo el dueño.
- **Google Cloud / Firebase** (`estilo-neutral`): IAM → solo las cuentas necesarias.
- **Permisos viejos de la app en las cuentas de Google:** cada usuario puede quitar los permisos que la app pedía antes (Sheets/Drive) en <https://myaccount.google.com/permissions> → la app → **Quitar acceso**, y volver a iniciar sesión (ahora solo pide el email).

## 3. Lo que todavía falta (deuda técnica)

| Pendiente | Riesgo | Propuesta |
|---|---|---|
| **Roles** (DT-1) | Cualquier usuario con acceso administra usuarios, organizaciones, límites y datos bancarios. | Columna `rol` en `usuarios` (admin / vendedor) y validación en el servidor. |
| **Separación entre organizaciones en el servidor** | `leer_hojas` devuelve las hojas completas (todas las organizaciones) a cualquier usuario con acceso; el filtro por organización lo hace la app. | Filtrar en el servidor por la organización del usuario las hojas que tienen `organizacion_id`, e imponerla en las escrituras. |
| **Catálogo público** | — | Acción de solo lectura con datos públicos (sin tocar la hoja privada). |

## 4. Archivos

| Parte | Archivos |
|---|---|
| Servidor | `_identidadDelPedido`, `_verificarTokenGoogle`, `_limiteDeEscrituras`, `_leerHojas`, `doGet` en `google_apps_script.js` |
| App | `SheetsConfig.scopes`, `SheetsAuth.tokenDeAcceso`, `SheetsDataService.proveedorToken`, `_filasDelServidor` (lectura en lote), recarga tras el login en `LoginCubit` |
| Tests | `tools/apps_script/tests/seguridad.test.js`, `test/shared/seguridad_test.dart` |
