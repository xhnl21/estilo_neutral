# Cumplimiento Normativo

El código de este proyecto referencia constantemente normas internacionales en comentarios (`ISO/IEC 25010`, `ISO 8000`, `ISO 8601`, `ISO/IEC 27001`, `GDPR Art. 5`, `COBIT 2019`, `OWASP MASVS`, `WCAG 2.2 AA`, `RFC 4180`, `NIST SP 800-53`, etc.). Esta página separa, con evidencia concreta, **qué se cumple de verdad** de **qué es solo texto descriptivo** en un comentario o en una fila semilla de auditoría — y deja explícita la lista de brechas conocidas.

!!! warning "Por qué existe esta página"
    Muchas de las referencias normativas en el código (sobre todo en `_seedFallbackData()` de `sheets_data_service.dart` y en las hojas `audit_log` / `reporte_migracion`) describen una auditoría **simulada/histórica** de una migración de datos, no un control que se siga ejecutando hoy. Es fácil leer esos comentarios y asumir un nivel de cumplimiento que no existe en el comportamiento real de la app.

## Resumen

| Norma | Estado | Nota corta |
|---|---|---|
| ISO/IEC 25010 (Calidad de software) | 🟡 Parcial | Cero Polling real; mantenibilidad afectada por un archivo "god object" |
| ISO 8000 (Calidad de datos) | 🟡 Parcial | PKs duplicadas e integridad referencial corregidas (2026-09-25); teléfono/email **sin validación real** |
| ISO 8601 (Fechas) | 🟢 Cumple | Formato consistente en todos los modelos |
| ISO/IEC 27001 (Seguridad de la información) | 🔴 No cumple | Lectura y escritura del backend son **públicas y sin autenticación** |
| GDPR Art. 5 / Art. 17 | 🔴 No cumple | Sin política de retención, sin derecho al olvido real |
| COBIT 2019 (DSS05) | 🔴 No cumple | Solo texto descriptivo, sin proceso de gobierno |
| OWASP MASVS | 🟡 Parcial | Storage, logging y biometría de login OK; Network y Resilience con brechas |
| WCAG 2.2 AA | 🟡 Parcial | Trabajo real y testeado, pero no auditado formalmente al 100% |
| RFC 4180 / 3986 / 5322 | 🟡 Parcial | CSV propio razonable; RFC 5322 (email) no se aplica en el modelo real |

## ISO/IEC 25010 — Calidad del producto de software

**Cumple:**

- **Eficiencia energética real**: la [Política de Cero Polling](no_polling_policy.md) está efectivamente implementada — ninguna pantalla usa `Timer.periodic` ni refresca sola.
- **Usabilidad**: sistema de diseño consistente (`lib/core/design_system/`) con tokens y widgets reutilizables.

**No cumple / parcial:**

- **Mantenibilidad**: `lib/shared/google_sheets/sheets_data_service.dart` concentra la lectura, el parseo y el CRUD completo de las **14 hojas** en un solo archivo de más de 1700 líneas — un "god object" que dificulta el mantenimiento y las pruebas aisladas.
- **Gobierno de deuda técnica débil**: durante esta misma sesión se encontró y eliminó código duplicado y desincronizado (`apps_script_source.dart`, un modelo `ChecklistISO` paralelo sin uso en `lib/features/audit/domain/`) — indicio de que el código muerto se acumula sin revisión periódica.

## ISO 8000 — Calidad de datos

**Cumple:**

- IDs con prefijo y secuencia consistentes (`c00000001`, `p00000001`, ...) — **generados en el servidor**, no en el cliente (ver corrección abajo).
- Fechas en formato ISO 8601 en todos los modelos.
- **Integridad referencial validada en el servidor**: `google_apps_script.js` rechaza la creación de `ventas` con `cliente_id` inexistente, de `venta_items` con `venta_id`/`item_id` inexistentes, y de `abonos` con `venta_id` inexistente (`_validarForeignKeys`).

**Corrección de integridad aplicada (2026-09-25):**

Una auditoría externa (ver hallazgos de DeepSeek sobre `Estilo Neutral.xlsx`) encontró **claves primarias duplicadas reales y en vivo**: dos filas con `id=c00000002` en `clientes` y dos pares de filas duplicadas en `galeria` (`g00000002`, `g00000003`). Se verificó cada hallazgo contra el Google Sheet real (no contra una copia local desactualizada) antes de actuar.

- **Causa raíz identificada**: el "siguiente ID" (`nextClienteId`, `nextGaleriaId`, etc.) se calculaba en `sheets_data_service.dart` a partir de una caché en memoria del cliente Flutter — si dos sesiones/dispositivos calculaban el mismo "siguiente ID" antes de que el otro sincronizara, ambas creaban filas con el mismo `id`.
- **Fix estructural**: la generación de ID se movió al servidor (`_siguienteIdServidor` en `google_apps_script.js`), ejecutándose **dentro del `LockService.getScriptLock()` global** que ya envolvía todo `doPost` — esto la hace atómica entre escrituras concurrentes. Se extendió a las 10 hojas con ID con prefijo (`clientes`, `inventario`, `galeria`, `ventas`, `venta_items`, `abonos`, `compras_divisas`, `usuarios`, `tasas`, `moneda_organizacion`). Del lado de Flutter, cada método de creación (`addCliente`, `addProducto`, `subirFotoGaleria`, `addVenta`, `addUsuario`, `addCompraDivisa`, `setTasaManualOrganizacion`, `setMonedaOrganizacion`) ahora espera el ID real devuelto por el servidor y reconcilia la fila local insertada de forma optimista si el servidor asignó un ID distinto al calculado localmente (`_crearEnServidor`).
- **Riesgo detectado y corregido durante la implementación**: `addVenta` sincronizaba `venta` + `venta_items` + `abono` en paralelo (`Future.wait`), los tres referenciando el ID de venta calculado localmente. Combinado con la validación de FK ya activa, una colisión de ID en la venta habría hecho que el servidor rechazara sus ítems/abono (por apuntar a un `venta_id` que ya no existe bajo ese ID). Se reestructuró para crear la venta primero, esperar su ID confirmado, y solo entonces sincronizar ítems y abono con ese ID.
- **Limpieza de los datos ya rotos en producción** (vía Sheets API, verificado con lectura antes/después):
    - `clientes`: se fusionó el duplicado de `c00000002` en una sola fila, con `saldo_deuda_usd` recalculado desde la venta real pendiente (`v00000002`, sin abonos) → 180 USD.
    - `galeria`: las dos filas huérfanas duplicadas (mismo `id` que `g00000002`/`g00000003`, subidas más tarde y no referenciadas por ningún `inventario.foto_id`) se renumeraron a `g00000007`/`g00000008` — ninguna foto se eliminó.
    - `ventas`: se limpió un valor fantasma en la columna P de `v00000001` (sin encabezado, resto de una columna eliminada en algún momento).
    - `ventas`: se corrigió una tasa cambiaria cruzada — `v00000002`/`v00000003` (fecha 2026-09-22) usaban `tasa_bcv=474` (la tasa manual de otra fecha) en vez de `852.4168` (la tasa BCV real de ese día, `t00000003`); `v00000004` (fecha 2026-09-23) usaba `976.5483`, que es la tasa **EUR** de ese día (`t00000002`), en vez de `853.4993`, la tasa USD correcta (`t00000001`). Se recalculó `monto_bs` para las tres filas.
    - `inventario`: se eliminaron 4 filas duplicadas de "Gorra Deportiva" (`p00000005`-`p00000008`, sin ninguna venta asociada en `venta_items`) y se completó el `organizacion_id` faltante en `p00000004` (la fila real, con una venta asociada).
- **Fuera de este alcance, explícitamente**: no se implementó RBAC, Row-Level Security, bitácora con hash-chaining, tokenización de PII ni comité de gobierno de datos — un plan de 12 fases propuesto en paralelo para "cumplir normas internacionales" fue evaluado y descartado por desproporcionado para el tamaño del negocio; además, ninguna cantidad de código puede por sí sola producir una certificación real ISO 27001/GDPR/COBIT, que requiere procesos organizacionales, acuerdos legales (ej. un DPA con Google) y auditorías externas.

**No cumple:**

- **Teléfono sin validación E.164 real**: el modelo de producción [`lib/models/cliente.dart`](../lib/models/cliente.dart) guarda `telefono` como `String` libre, sin ninguna regla de formato. (La única validación E.164 que existió en el proyecto vivía en un módulo de demo Clean Architecture — `lib/features/sales/` — que nunca estuvo conectado a los datos reales y se eliminó por completo al implementar el esquema de factura con múltiples ítems, ver [Casos de Uso — UC-30](casos-de-uso.md#uc-30-registrar-una-venta-factura-con-uno-o-mas-productos); su eliminación no cambia este hallazgo, esa validación nunca protegió datos reales.) Consecuencia real: en la planilla en producción, los teléfonos quedaron guardados como número plano sin el prefijo `+` (ej. `4120374325` en vez de `+584120374325`).
- **Email sin validación (RFC 5322)**: tampoco hay ninguna regex de email en el modelo de producción, pese a que una entrada semilla de `audit_log` afirma "email regex compliant" — es texto descriptivo de una auditoría pasada, no una regla que se ejecute hoy.
- **Defecto de parseo en `reporte_migracion`**: el parser (`ReporteMigracion.fromRow`) solo excluye filas que empiezan con "REPORTE" o "Estándares"; la fila de encabezados reales (fila 4 de la hoja) no queda excluida y se interpreta como si fuera un registro de datos válido.

## ISO 8601 — Fechas

**Cumple bien.** Formato `YYYY-MM-DD` y timestamps con zona horaria explícita (`-04:00`) de forma consistente en todos los modelos y en la hoja `audit_log`.

## ISO/IEC 27001 — Seguridad de la información

**Cumple:**

- Tokens de sesión cifrados con `flutter_secure_storage` (Keychain en iOS, EncryptedSharedPreferences en Android).
- Credenciales de las herramientas de automatización (`client_secret.json`, `token.json`, `~/.clasprc.json`) excluidas de control de versiones. **Corrección:** una auditoría posterior encontró 3 archivos `client_secret_312343708119-*.json` (credenciales OAuth tipo "Desktop app", sin campo `client_secret` real) commiteados en la raíz del repo — no cubiertos por esta regla. Se sacaron del control de versiones y se agregó el patrón `client_secret*.json` al `.gitignore` para que no vuelva a pasar. Pendiente de decisión: `upload-keystore.jks.md` (el keystore real de firma, con extensión disfrazada) sigue en el historial de git — no se tocó, requiere decidir si ya se usó para firmar algo publicado antes de rotar la clave o reescribir historia.
- Bitácora de auditoría (`audit_log`) que registra las mutaciones del sistema.
- Sanitización de PII antes de loguear (`Logger.sanitize` ofusca emails, JWTs y claves sensibles — ver [`lib/core/utils/logger.dart`](../lib/core/utils/logger.dart)).
- **Sanitización contra inyección de fórmulas (CWE-1236 / CSV-Formula Injection):** `google_apps_script.js` (`_sanitizarContraFormulas`) antepone una comilla simple a cualquier valor de texto que empiece con `=`, `+`, `-`, `@` o tab, antes de escribirlo en cualquier hoja — un nombre de cliente como `=IMPORTXML(...)` ya no se ejecuta como fórmula al abrir la planilla en un navegador. De paso, preserva el `+` de teléfonos en formato E.164 (antes se perdía, porque Sheets interpretaba `+584121234567` como una expresión numérica).

**No cumple (brechas reales de arquitectura, no de configuración):**

- **Lectura sin autenticación**: la app lee las 14 hojas vía el endpoint público de exportación CSV de Google Sheets (`gviz/tq?tqx=out:csv`). Cualquiera con el enlace de la planilla puede leer **todos los datos del negocio** sin pasar por el login de la app.
- **Escritura sin autenticación**: `google_apps_script.js` está desplegado con `"access": "ANYONE_ANONYMOUS"` (ver [`appsscript.json`](../appsscript.json)). Cualquiera con la URL `/exec` puede ejecutar `create` / `update` / `delete` / `set_metodo_seguridad` sin que el servidor verifique identidad alguna. El control de acceso real (`AccessControlConfig`, la lista `ALLOWED_EMAILS`) existe **solo del lado del cliente** — es una pantalla de login para la UI de la app, no una barrera de seguridad del backend. Ver [Multi-organización — limitación conocida](google/multi-organizacion.md#contexto-y-limitacion-conocida).
- **Sin cifrado adicional en tránsito ni certificate pinning**: las peticiones HTTP (`http`/`dio`) no verifican el certificado del servidor más allá de la validación TLS por defecto del sistema.
- **Sin control de acceso basado en roles**: cualquier cuenta autorizada puede operar cualquier vista; no existe el concepto de rol o permiso diferenciado en `lib/features/auth/`.

## GDPR — Art. 5 (Principios) y Art. 17 (Derecho al olvido)

**Cumple:**

- Referencias explícitas a los principios de minimización y exactitud en comentarios de modelo.

**No cumple:**

- **Sin derecho al olvido real**: borrar un cliente es un `deleteRow` manual sobre la hoja — no hay un proceso formal de solicitud/registro de eliminación, ni verificación de que los datos no persistan en copias/backups.
- **Sin política de retención**: no hay ninguna regla de cuánto tiempo se conservan los datos de clientes ni un mecanismo de anonimización.
- **Sin base legal de tratamiento documentada** más allá de un comentario en el modelo — no hay un aviso de privacidad ni registro de consentimiento para los datos personales que se cargan (teléfono, email).
- Los datos personales viven en la infraestructura de Google (Sheets/Drive) sin un Acuerdo de Tratamiento de Datos (DPA) específico documentado para este uso.

## COBIT 2019 (DSS05 — Gestionar Servicios de Seguridad)

**No cumple.** Aparece únicamente como texto descriptivo en comentarios de auditoría semilla. No existe ningún proceso real de gobierno: no hay revisión periódica de accesos, no hay gestión formal de incidentes, no hay reporting de cumplimiento más allá de esta página.

## OWASP MASVS (Mobile Application Security Verification Standard)

**Cumple:**

- **MASVS-STORAGE**: tokens en almacenamiento cifrado nativo.
- **MASVS-PRIVACY** (parcial): sanitización de PII en logs.
- **MASVS-PLATFORM** (CWE-1236, Formula/CSV Injection): sanitizado del lado del backend (`_sanitizarContraFormulas` en `google_apps_script.js`) — ver arriba, sección ISO/IEC 27001.

**No cumple:**

- **MASVS-NETWORK**: sin certificate pinning.
- **MASVS-RESILIENCE**: sin detección de root/jailbreak, sin ofuscación de código; y como ya se documentó, el backend es completamente público, así que no hay "resiliencia" que proteger del lado del cliente — el atacante ni necesita comprometer la app.
- **MASVS-AUTH** (parcial): el toggle **Biométrico** ya gatea el login de verdad (ver más abajo); **Desbloqueo facial** y **2FA** siguen siendo cosméticos.

## WCAG 2.2 AA (Accesibilidad)

**Cumple parcialmente, con evidencia real:** hay uso genuino de `Semantics`, `ExcludeSemantics`, roles de encabezado y regiones en vivo en al menos 23 archivos de `lib/`, respaldado por un test suite dedicado (`test/presentation/accessibility_semantics_test.dart`, 367 líneas).

**No verificado / no cumple:**

- No hay una auditoría formal completa (contraste de color medido, navegación end-to-end con lector de pantalla real, verificación de zoom de texto dinámico al 200%). Lo implementado es real, pero es una cobertura parcial, no una certificación.

## RFC 4180 / RFC 3986 / RFC 5322

- **RFC 4180 (CSV)**: el parser propio (`parseCsv` en `sheets_data_service.dart`) maneja comillas, comas y saltos de línea — razonablemente compliant, sin una batería de tests exhaustiva contra los casos borde del estándar.
- **RFC 3986 (URI)**: las URLs de Google Drive generadas están bien formadas; sin hallazgos.
- **RFC 5322 (email)**: mencionado en comentarios, **no se aplica** como validación real en el modelo de producción (ver ISO 8000 arriba).

## Caso especial: la pantalla "Seguridad" — actualizado

La vista **Seguridad** (Biométrico / Desbloqueo facial / 2FA, ver [Casos de Uso — UC-64](casos-de-uso.md#uc-64-elegir-el-metodo-de-autenticacion-adicional-seguridad)) ahora presenta los tres métodos como **mutuamente excluyentes** (selección única, modelado en [`Seguridad.metodoActivo`](../lib/models/seguridad.dart)) y tiene un estado mixto de implementación:

- **Biométrico y Desbloqueo facial → ambos son reales.** `pubspec.yaml` incluye `local_auth`, y [`login_page.dart`](../lib/features/auth/presentation/pages/login_page.dart) llama a [`BiometricAuthService`](../lib/shared/auth/biometric_auth_service.dart) inmediatamente después de resolver la organización del usuario: si cualquiera de los dos es el método activo, exige una verificación biométrica del sistema operativo antes de completar el login (o de restaurar la sesión en aperturas siguientes, ver UC-01b). Si el usuario cancela o falla la verificación, no se otorga acceso. Si el dispositivo no tiene hardware biométrico o no tiene nada enrolado, el chequeo se omite (falla abierta a nivel de hardware, pero falla cerrada si el intento de verificación en sí falla).

  **Limitación de Android descubierta en dispositivo real (Redmi Note 8) y ya resuelta:** `local_auth_android` llama a `BiometricPrompt` con `setAllowedAuthenticators(BIOMETRIC_STRONG or BIOMETRIC_WEAK)` — esta API **no permite pedirle al sistema "solo rostro" o "solo huella"**, siempre presenta lo que el equipo tenga enrolado. En un primer intento, seleccionar "Desbloqueo facial" en un equipo sin reconocimiento facial de clase fuerte terminaba mostrando el diálogo de huella igual, con el botón todavía rotulado "Face ID" — engañoso. Se corrigió agregando [`BiometricAuthService.hasFaceId()`](../lib/shared/auth/biometric_auth_service.dart), que consulta `getAvailableBiometrics()` **antes** de mostrar el botón: si el dispositivo no reporta `BiometricType.face` de verdad, el botón se muestra como "Verificar con Biométrico" (genérico) en vez de "Face ID", para no prometer algo que el equipo no puede cumplir. En iOS, donde Face ID y Touch ID sí son distinguibles por hardware, el botón sí muestra "Face ID" cuando corresponde.

  **Extensión a la pantalla de configuración:** la misma inconsistencia podía darse al revés — un usuario podía *elegir* "Desbloqueo facial" en la vista Seguridad desde un equipo que nunca podría cumplirlo, generando confusión antes de llegar siquiera al login. [`SeguridadPage`](../lib/presentation/pages/seguridad_page.dart) ahora consulta `isAvailable()`/`hasFaceId()` al entrar a la vista y solo lista **Biométrico** y **Desbloqueo facial** como opciones si el dispositivo actual realmente las soporta (si no soporta ninguna, solo se listan "Ninguno" y "2FA", con un texto aclaratorio).

  **Auto-corrección al detectar incompatibilidad:** si el método activo del usuario no es compatible con el dispositivo que abre esta vista, `SeguridadPage` lo restablece automáticamente a "Ninguno" (`setMetodoSeguridad(null)`) y persiste el cambio en la hoja `seguridad`, en vez de dejarlo seleccionado sin poder cumplirse.

  **Corrección de diseño (fila por usuario, no por organización):** en una primera versión, `seguridad` era una sola fila **por organización**, compartida por todos sus usuarios — el auto-reset de arriba terminaba siendo global: un solo usuario abriendo la vista desde un equipo incompatible desactivaba el método también para compañeros con hardware compatible. Se corrigió rediseñando el esquema: se agregaron las hojas `organizaciones` (maestro de organizaciones) y `usuario_organizacion` (relación explícita 1:N organización→usuarios, ver [Multi-organización](google/multi-organizacion.md)), y `seguridad` pasó a tener **una fila por usuario** (columna D: `usuario_email`, ya no `organizacion_id`). Con esto, el auto-reset por incompatibilidad de hardware solo afecta al usuario dueño de esa fila.
- **2FA → sigue siendo cosmético.** Se puede seleccionar (mutuamente excluyente con los otros dos a nivel de datos), pero no hay un segundo factor real implementado (necesitaría un flujo propio, tipo TOTP, no cubierto por `local_auth`). Por ahora, si un usuario tiene 2FA como método activo, el login se completa sin pedir nada adicional, dejando una advertencia en el log (`login_page.dart`) para que quede constancia de que no se aplicó el segundo factor.

## Recomendaciones priorizadas (si se decide cerrar brechas)

1. **Autenticar el backend real** (ISO 27001 / OWASP MASVS): mover de GViz público + Apps Script anónimo a la API oficial de Google Sheets con OAuth por usuario, o a un backend propio con autorización real por request. Es el cambio de mayor impacto y el de mayor esfuerzo.
2. **Validar teléfono y email en el modelo de producción** (ISO 8000): portar la regex E.164 de `customer.dart` a `Cliente.fromRow`/formulario real, y agregar validación de email.
3. **Definir qué hace "Desbloqueo facial" frente a "Biométrico"** (¿son el mismo control o dos gates independientes?) e implementar 2FA real si se necesita, o aclarar en la UI que esos dos siguen siendo preferencias sin efecto todavía.
4. **Definir una política de retención/eliminación de datos personales** (GDPR Art. 17) antes de operar con clientes reales a escala.
