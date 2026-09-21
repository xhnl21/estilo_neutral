# Casos de Uso

Actor único: **Usuario autenticado** (una de las cuentas de Google en `ALLOWED_EMAILS`, ver [Google Sign-In](google/sign-in.md)). No hay roles distintos dentro de la app — cualquier usuario autenticado puede operar cualquier vista.

## Autenticación y sesión

### UC-01 — Iniciar sesión con Google

- **Precondición:** el usuario tiene una cuenta de Google autorizada (`ALLOWED_EMAILS`) y una credencial Android registrada para su combinación de app instalada (ver [Troubleshooting](google/troubleshooting.md)).
- **Flujo principal:**
  1. La app muestra el video de splash y navega a la pantalla de login.
  2. El usuario toca **"Continuar con Google"**.
  3. Elige su cuenta en el selector nativo de Android.
  4. La app valida el email contra la lista de autorizados y resuelve su organización.
  5. Si esa organización tiene activado **Biométrico** (ver UC-64), la app exige una verificación biométrica del dispositivo (huella/Face ID) antes de continuar.
  6. Navega a la vista de **Ventas** (pantalla inicial por defecto).
- **Flujos alternativos:**
  - *Cuenta no autorizada:* se cierra la sesión de Google inmediatamente y se muestra "La cuenta X no tiene acceso a este sistema".
  - *Cancela el selector de cuentas:* vuelve al botón de login sin error.
  - *Falla la comunicación con Google:* mensaje "No se pudo iniciar sesión con Google. Intenta nuevamente."
  - *Falla o cancela la verificación biométrica* (cuando está activada): se cierra la sesión de Google y se muestra "No se pudo verificar tu identidad con biometría. Intenta nuevamente." — no se otorga acceso.
  - *Dispositivo sin hardware biométrico o sin nada enrolado:* se omite el chequeo y el login continúa normalmente (no bloquea al usuario por una limitación del equipo).
- **Postcondición:** sesión activa; el email y la organización quedan disponibles en toda la app.

### UC-02 — Cerrar sesión

- **Flujo principal:** menú lateral (drawer) → **"Cerrar sesión"** → confirmar en el diálogo → se revoca la sesión de Google y vuelve a la pantalla de login.
- **Postcondición:** ya no se puede navegar a ninguna vista protegida sin volver a loguearse.

## Clientes

### UC-10 — Registrar un cliente nuevo
- **Flujo principal:** vista **Clientes** → botón **"Nuevo Cliente"** → completar nombre, teléfono (E.164), email, saldo de deuda inicial → guardar.
- **Postcondición:** aparece en el listado con un ID autogenerado (`c0000000X`).

### UC-11 — Buscar, editar o eliminar un cliente
- Buscar por nombre/teléfono/email con el campo de búsqueda.
- Editar: ícono de lápiz en la tarjeta del cliente → modificar datos → guardar.
- Eliminar: ícono de papelera → confirmar en el diálogo (acción irreversible).

## Inventario

### UC-20 — Registrar un producto nuevo
- **Flujo principal:** vista **Inventario** → **"Nuevo Producto"** → nombre, marca, modelo, talla, cantidad, precio USD, y opcionalmente el enlace/ID de una foto en Google Drive → guardar.

### UC-21 — Ajustar stock
- Botones **+ / −** en cada producto para sumar o restar unidades sin abrir el formulario completo.

### UC-22 — Actualizar la foto de un producto
- Ícono de imagen en la tarjeta → subir una foto nueva o pegar el enlace de Drive → se actualiza la miniatura.

### UC-23 — Buscar, editar o eliminar un producto
- Igual patrón que Clientes (buscador, editar, eliminar con confirmación).

## Ventas

### UC-30 — Registrar una venta
- **Flujo principal:** vista **Ventas** → **"Nueva Venta"** → elegir cliente y producto (de los ya registrados), cantidad, tasas (BCV/USD), método de pago, abono inicial → guardar.
- **Regla de negocio:** si el `cliente_id` o `item_id` no existen en sus catálogos, la operación se rechaza localmente (no se envía a la nube) para no crear referencias huérfanas.
- **Postcondición:** la venta calcula automáticamente monto en Bs/USD, deuda pendiente y estado (`Pendiente` / `Pagada`).

### UC-31 — Registrar un abono a una venta pendiente
- Botón **"Registrar Abono"** en el detalle de una venta con deuda → ingresar monto → se actualiza el saldo del cliente y el estado de la venta.

### UC-32 — Anular una venta
- Confirmación explícita ("¿Anular venta?") antes de ejecutar — es una acción destructiva sobre datos transaccionales.

## Tesorería (Compras de Divisas)

### UC-40 — Registrar una compra de divisas
- **Flujo principal:** vista **Tesorería** → **"Nueva Compra"** → capital USD, comisión, número de orden, plataforma, vendedor, tasas BCV/USD → guardar.
- La validación de consistencia matemática (`validacion == "OK"/"ERROR"`) se calcula automáticamente y se resalta en rojo si hay inconsistencias.

### UC-41 — Editar o eliminar una orden de compra
- Mismo patrón de edición/eliminación con confirmación.

## Resumen Diario

### UC-50 — Registrar el cierre del día
- **Flujo principal:** vista **Resumen Diario** → **"Nuevo Cierre"** → fecha, tasas del día → el sistema calcula automáticamente número de ventas, totales en Bs/USD y USD comprados/vendidos (fórmulas agregadas sobre `ventas` y `compras_divisas`).
- Es la única vista donde los datos combinan cálculo automático con un registro manual de tasas.

## Gobierno y Calidad ISO

### UC-60 — Consultar la bandeja de Cuarentena
- Muestra registros históricos que quedaron marcados como anómalos durante la migración inicial de datos. Se pueden **editar/resolver** (cambiar estado a `CORREGIDO`/`CONSOLIDADO` y documentar la resolución forense) o **purgar** definitivamente.

### UC-61 — Consultar y registrar en la Bitácora de Auditoría
- Lectura del historial de cambios del sistema (quién, qué hoja, qué celda, valor anterior/nuevo, norma aplicada).
- **"Nuevo Checkpoint"** permite agregar una entrada manual de auditoría; cada entrada puede editarse (solo observaciones) o revocarse.

### UC-62 — Consultar el Reporte de Migración
- Panel de métricas de la migración/auditoría original del sistema (integridad referencial, formatos, filas migradas, etc.), editable para mantenerlo actualizado.

### UC-63 — Marcar cumplimiento en el Checklist ISO
- Lista de controles normativos (ISO 27001, ISO 8000, WCAG, etc.). Tocar el ícono de estado alterna entre conforme (`☑`) y no conforme (`☐`); también se pueden agregar, editar o eliminar controles.

### UC-64 — Configurar métodos de autenticación (Seguridad)
- **Flujo principal:** vista **Seguridad** → activar/desactivar **Biométrico**, **Desbloqueo facial** o **2FA** con los switches.
- **Postcondición:** el cambio se guarda en la hoja `seguridad`, en la fila correspondiente a la organización del usuario (ver [Multi-organización](google/multi-organizacion.md)) — afecta a todos los usuarios de esa misma organización, no solo a quien lo cambió.
- **Efecto real:** activar **Biométrico** exige verificación biométrica en el próximo login de cualquier usuario de esa organización (ver UC-01). **Desbloqueo facial** y **2FA** todavía no tienen ningún efecto funcional — ver [Cumplimiento Normativo](cumplimiento-normativo.md#caso-especial-la-pantalla-seguridad--actualizado).

## Casos transversales

### UC-90 — Refrescar datos manualmente
- Todas las vistas tienen un botón de refresco explícito (política de **Cero Polling**: la app nunca refresca sola en segundo plano — ver [no_polling_policy.md](no_polling_policy.md)). El usuario decide cuándo volver a leer los datos de Google Sheets.

### UC-91 — Operar sin conexión / con datos en caché
- Si falla la lectura de Google Sheets, la app sigue mostrando los últimos datos cargados en memoria y notifica el error (documento privado, sin conexión, etc.) sin bloquear la navegación.
