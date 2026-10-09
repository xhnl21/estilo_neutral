# Deuda técnica

Problemas conocidos que se decidió no resolver todavía. Cada entrada dice qué pasa, qué riesgo implica y qué haría falta para resolverla. Cuando una deuda se resuelva, hay que quitarla de acá y mencionarla en el commit que la cierra.

---

## DT-1. No hay roles: cualquier usuario con sesión administra usuarios y organizaciones

**Registrada:** 2026-10-06 · **Severidad:** Alta · **Origen:** hallazgo A1 de la revisión de formularios del 2026-10-06 (ver [informe.md](../informe.md))

> **Avance 2026-10-09:** el servidor ya **autentica** al usuario (token de Google verificado en cada pedido) y la hoja puede quedar privada. Siguen faltando los **roles**. Ver [seguridad.md](seguridad.md).

### Qué pasa

Desde el 2026-10-06, el acceso a la app lo decide la hoja `usuarios`. Una cuenta entra si está en `usuarios` y tiene membresía en `usuario_organizacion` apuntando a una organización existente (`SheetsDataService.resolverAcceso`). Antes de esa fecha lo decidía una lista blanca fija en compilación (`ALLOWED_EMAILS`), que se eliminó.

El problema es que **no existe ningún concepto de rol o administrador**. Cualquier usuario que pueda iniciar sesión puede, desde los módulos Usuarios y Organizaciones:

- dar de alta usuarios nuevos, es decir, **dar acceso a la app a cualquier cuenta de Google**;
- eliminar usuarios o quitarles la membresía, es decir, quitarles el acceso, incluido a los dueños;
- mover usuarios entre organizaciones;
- crear, editar y eliminar organizaciones.

Además, las listas de usuarios y organizaciones no se filtran por la organización actual (`SheetsDataService.usuarios` y `.organizaciones` devuelven todos los registros). Un usuario de una organización ve y administra a los de todas las demás.

### Riesgo

Cualquier persona a la que se le dé acceso, aunque sea solo para operar ventas o inventario, puede darle acceso a terceros o bloquear a los dueños. Mientras la app la usen solo los dueños, el riesgo es bajo. **Antes de dar acceso a empleados u otras personas hay que resolver esta deuda.**

### Qué haría falta

1. **Modelo de roles.** Por ejemplo, una columna `rol` en `usuario_organizacion` con los valores `administrador` y `operador`. Hay que agregarla en la hoja, en el modelo `UsuarioOrganizacion`, en `google_apps_script.js` (`_handleCreate` y `_handleUpdate`) y en la carga de datos.
2. **Autorización en la app.** Exponer el rol del usuario actual y ocultar o deshabilitar los módulos Usuarios y Organizaciones para quien no sea `administrador`. Esto tiene que hacerse en los Cubits; ocultar solo el menú no alcanza, porque se puede llegar a las rutas igual.
3. **Aislamiento entre organizaciones.** Que un administrador solo vea y administre usuarios de su propia organización.
4. **Protecciones mínimas.** Impedir que alguien se elimine a sí mismo o se quite su propio rol, y que una organización se quede sin ningún administrador.
5. **Autorización en el servidor.** Hoy Apps Script no verifica quién envía cada POST a la URL `/exec` (ver [cumplimiento-normativo.md](cumplimiento-normativo.md)). Desde el 2026-10-07 rechaza las escrituras cuyo `usuario_sesion` ya no tiene acceso (así una sesión revocada no puede seguir guardando), pero ese email lo manda el cliente: alguien que llame al script directamente puede omitirlo o falsificarlo. Mientras eso no cambie, los controles de la app se pueden saltear llamando al script directamente. La solución completa requiere que el script valide la identidad del usuario, por ejemplo con un ID token de Google, y su rol.

---

## DT-3. La opción "2FA" de Seguridad no pide un segundo factor

**Registrada:** 2026-10-06 · **Severidad:** Media · **Origen:** hallazgo M9 de la revisión de formularios del 2026-10-06 (ver [informe.md](../informe.md))

### Qué pasa

En Seguridad se puede elegir "2FA" (`dos_factores`) como método adicional de inicio de sesión. Pero no hay ningún segundo factor implementado: al iniciar sesión, `LoginCubit` registra una advertencia en el log y da la verificación por hecha (`lib/features/auth/presentation/cubit/login_cubit.dart`, rama `dos_factores`).

### Riesgo

Quien elige "2FA" cree que su cuenta tiene una protección que no existe. Entrar sigue requiriendo la cuenta de Google y estar autorizado en la hoja `usuarios`, así que no se abre un acceso nuevo, pero la opción es engañosa.

### Qué haría falta

Una de dos:

1. **Implementarlo**, por ejemplo con TOTP (código de 6 dígitos de una app autenticadora): generar y guardar un secreto por usuario (en `seguridad`, protegido), una pantalla de alta con código QR y la verificación del código en `LoginCubit`.
2. **Quitar la opción** de `seguridad_page.dart` y de `login_page.dart`, y pasar a "Ninguno", con un aviso, a quien la tenga elegida.
