# Cumplimiento Normativo

El código de este proyecto referencia constantemente normas internacionales en comentarios (`ISO/IEC 25010`, `ISO 8000`, `ISO 8601`, `ISO/IEC 27001`, `GDPR Art. 5`, `COBIT 2019`, `OWASP MASVS`, `WCAG 2.2 AA`, `RFC 4180`, `NIST SP 800-53`, etc.). Esta página separa, con evidencia concreta, **qué se cumple de verdad** de **qué es solo texto descriptivo** en un comentario o en una fila semilla de auditoría — y deja explícita la lista de brechas conocidas.

!!! warning "Por qué existe esta página"
    Muchas de las referencias normativas en el código (sobre todo en `_seedFallbackData()` de `sheets_data_service.dart` y en las hojas `audit_log` / `reporte_migracion`) describen una auditoría **simulada/histórica** de una migración de datos, no un control que se siga ejecutando hoy. Es fácil leer esos comentarios y asumir un nivel de cumplimiento que no existe en el comportamiento real de la app.

## Resumen

| Norma | Estado | Nota corta |
|---|---|---|
| ISO/IEC 25010 (Calidad de software) | 🟡 Parcial | Cero Polling real; mantenibilidad afectada por un archivo "god object" |
| ISO 8000 (Calidad de datos) | 🟡 Parcial | IDs y fechas consistentes; teléfono/email **sin validación real** |
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

- **Mantenibilidad**: `lib/shared/google_sheets/sheets_data_service.dart` concentra la lectura, el parseo y el CRUD completo de las **10 hojas** en un solo archivo de más de 1500 líneas — un "god object" que dificulta el mantenimiento y las pruebas aisladas.
- **Gobierno de deuda técnica débil**: durante esta misma sesión se encontró y eliminó código duplicado y desincronizado (`apps_script_source.dart`, un modelo `ChecklistISO` paralelo sin uso en `lib/features/audit/domain/`) — indicio de que el código muerto se acumula sin revisión periódica.

## ISO 8000 — Calidad de datos

**Cumple:**

- IDs con prefijo y secuencia consistentes (`c00000001`, `p00000001`, ...).
- Fechas en formato ISO 8601 en todos los modelos.

**No cumple:**

- **Teléfono sin validación E.164 real**: el modelo de producción [`lib/models/cliente.dart`](../lib/models/cliente.dart) guarda `telefono` como `String` libre, sin ninguna regla de formato. La única validación E.164 (`^\+58\d{10}$`) existe en [`lib/features/sales/domain/entities/customer.dart`](../lib/features/sales/domain/entities/customer.dart), que es un módulo de demo (Clean Architecture) **desconectado** de los datos reales de Google Sheets. Consecuencia real: en la planilla en producción, los teléfonos quedaron guardados como número plano sin el prefijo `+` (ej. `4120374325` en vez de `+584120374325`).
- **Email sin validación (RFC 5322)**: tampoco hay ninguna regex de email en el modelo de producción, pese a que una entrada semilla de `audit_log` afirma "email regex compliant" — es texto descriptivo de una auditoría pasada, no una regla que se ejecute hoy.
- **Defecto de parseo en `reporte_migracion`**: el parser (`ReporteMigracion.fromRow`) solo excluye filas que empiezan con "REPORTE" o "Estándares"; la fila de encabezados reales (fila 4 de la hoja) no queda excluida y se interpreta como si fuera un registro de datos válido.

## ISO 8601 — Fechas

**Cumple bien.** Formato `YYYY-MM-DD` y timestamps con zona horaria explícita (`-04:00`) de forma consistente en todos los modelos y en la hoja `audit_log`.

## ISO/IEC 27001 — Seguridad de la información

**Cumple:**

- Tokens de sesión cifrados con `flutter_secure_storage` (Keychain en iOS, EncryptedSharedPreferences en Android).
- Credenciales de las herramientas de automatización (`client_secret.json`, `token.json`, `~/.clasprc.json`) excluidas de control de versiones.
- Bitácora de auditoría (`audit_log`) que registra las mutaciones del sistema.
- Sanitización de PII antes de loguear (`Logger.sanitize` ofusca emails, JWTs y claves sensibles — ver [`lib/core/utils/logger.dart`](../lib/core/utils/logger.dart)).

**No cumple (brechas reales de arquitectura, no de configuración):**

- **Lectura sin autenticación**: la app lee las 10 hojas vía el endpoint público de exportación CSV de Google Sheets (`gviz/tq?tqx=out:csv`). Cualquiera con el enlace de la planilla puede leer **todos los datos del negocio** sin pasar por el login de la app.
- **Escritura sin autenticación**: `google_apps_script.js` está desplegado con `"access": "ANYONE_ANONYMOUS"` (ver [`appsscript.json`](../appsscript.json)). Cualquiera con la URL `/exec` puede ejecutar `create` / `update` / `delete` / `toggle_seguridad` sin que el servidor verifique identidad alguna. El control de acceso real (`AccessControlConfig`, la lista `ALLOWED_EMAILS`) existe **solo del lado del cliente** — es una pantalla de login para la UI de la app, no una barrera de seguridad del backend. Ver [Multi-organización — limitación conocida](google/multi-organizacion.md#contexto-y-limitacion-conocida).
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

La vista **Seguridad** (Biométrico / Desbloqueo facial / 2FA, ver [Casos de Uso — UC-64](casos-de-uso.md#uc-64-configurar-metodos-de-autenticacion-seguridad)) tiene ahora un estado mixto:

- **Biométrico → ya es real.** `pubspec.yaml` incluye `local_auth`, y [`login_page.dart`](../lib/features/auth/presentation/pages/login_page.dart) llama a [`BiometricAuthService`](../lib/shared/auth/biometric_auth_service.dart) inmediatamente después de resolver la organización del usuario: si `seguridad.biometrico` está activo para esa organización, exige una verificación biométrica del sistema operativo (huella o Face ID, según el hardware) antes de completar el login. Si el usuario cancela o falla la verificación, se cierra la sesión de Google y no se otorga acceso. Si el dispositivo no tiene hardware biométrico o no tiene nada enrolado, el chequeo se omite (falla abierta a nivel de hardware, pero falla cerrada si el intento de verificación en sí falla).
- **Desbloqueo facial y 2FA → siguen siendo cosméticos.** Guardan su valor en la hoja `seguridad`, pero ningún flujo de la app los consulta todavía. `local_auth` ya cubre Face ID como parte del mismo mecanismo biométrico (según el hardware del dispositivo), así que técnicamente el toggle "Biométrico" ya habilita reconocimiento facial en equipos compatibles con iOS/Face ID — falta decidir si "Desbloqueo facial" se fusiona con "Biométrico" o se mantiene como un control separado con su propia lógica.
- **2FA** seguiría necesitando un flujo propio (TOTP o similar) — no está cubierto por `local_auth`.

## Recomendaciones priorizadas (si se decide cerrar brechas)

1. **Autenticar el backend real** (ISO 27001 / OWASP MASVS): mover de GViz público + Apps Script anónimo a la API oficial de Google Sheets con OAuth por usuario, o a un backend propio con autorización real por request. Es el cambio de mayor impacto y el de mayor esfuerzo.
2. **Validar teléfono y email en el modelo de producción** (ISO 8000): portar la regex E.164 de `customer.dart` a `Cliente.fromRow`/formulario real, y agregar validación de email.
3. **Definir qué hace "Desbloqueo facial" frente a "Biométrico"** (¿son el mismo control o dos gates independientes?) e implementar 2FA real si se necesita, o aclarar en la UI que esos dos siguen siendo preferencias sin efecto todavía.
4. **Definir una política de retención/eliminación de datos personales** (GDPR Art. 17) antes de operar con clientes reales a escala.
