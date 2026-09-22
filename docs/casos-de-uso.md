# Casos de Uso

Actor único: **Usuario autenticado** (una de las cuentas de Google en `ALLOWED_EMAILS`, ver [Google Sign-In](google/sign-in.md)). No hay roles distintos dentro de la app — cualquier usuario autenticado puede operar cualquier vista.

## Autenticación y sesión

### UC-01 — Iniciar sesión con Google (primera vez o después de cerrar sesión)

- **Precondición:** el usuario tiene una cuenta de Google autorizada (`ALLOWED_EMAILS`) y una credencial Android registrada para su combinación de app instalada (ver [Troubleshooting](google/troubleshooting.md)).
- **Flujo principal:**
  1. La app muestra el video de splash y navega a la pantalla de login.
  2. El botón dice **"Continuar con Google"** con un ícono de globo, y debajo un texto aclara qué va a pasar: *"La primera vez, ingresá con tu cuenta de Google. Las próximas veces vas a poder confirmar con Biométrico, Face ID o 2FA si tu organización lo activó en Seguridad."*
  3. El usuario toca el botón y elige su cuenta en el selector nativo de Android.
  4. La app valida el email contra la lista de autorizados y resuelve su organización.
  5. Si esa organización tiene un método activo en Seguridad (ver UC-64), el botón cambia a mostrar el ícono y la etiqueta de ese método específico (ver UC-01b) y hay que tocarlo para confirmar.
  6. Navega a la vista de **Ventas** (pantalla inicial por defecto).
- **Flujos alternativos:**
  - *Cuenta no autorizada:* se cierra la sesión de Google inmediatamente y se muestra "La cuenta X no tiene acceso a este sistema".
  - *Cancela el selector de cuentas:* vuelve al botón de login sin error.
  - *Falla la comunicación con Google:* mensaje "No se pudo iniciar sesión con Google. Intenta nuevamente."
- **Postcondición:** sesión activa; el email y la organización quedan disponibles en toda la app.

### UC-01b — Reabrir la app sin haber cerrado sesión (desbloqueo rápido)

- **Precondición:** el usuario ya inició sesión antes con Google (UC-01) y no tocó "Cerrar sesión".
- **Flujo principal:**
  1. Al abrir la app, restaura la sesión de Google en silencio (sin mostrar el selector de cuentas).
  2. Si la organización tiene un método activo, el botón muestra su ícono y etiqueta propios en vez de "Continuar con Google", para que quede claro qué va a pedir **antes** de tocarlo:
     | Método | Ícono | Etiqueta del botón |
     |---|---|---|
     | Biométrico | mano (huella) | "Verificar con Biométrico" |
     | Desbloqueo facial | rostro enmarcado | "Verificar con Face ID" |
     | 2FA | candado con flecha | "Verificar con 2FA" |
  3. El usuario toca el botón → recién ahí se dispara la verificación real (no se pide sola, apenas se abre la app).
  4. Si no tiene ningún método activo, entra directo sin pedir nada (no aparece ningún botón intermedio).
- **Flujo alternativo:** *falla o cancela la verificación* → no se cierra la sesión de Google (a diferencia de UC-01); el mismo botón queda disponible para volver a tocarlo, sin tener que elegir cuenta de nuevo.
- **Nota técnica:** "Biométrico" y "Desbloqueo facial" disparan el mismo mecanismo del sistema operativo (`local_auth`). Android no permite pedirle a `BiometricPrompt` "solo rostro" — por eso, antes de mostrar el botón, la app consulta si el dispositivo realmente tiene Face ID disponible (`BiometricAuthService.hasFaceId()`); si no lo tiene, muestra "Verificar con Biométrico" (genérico) en vez de "Face ID", para no prometer algo que el equipo no va a cumplir. En iOS, donde Face ID y Touch ID son excluyentes por hardware, el botón sí puede mostrar "Face ID". "2FA" todavía no tiene un segundo factor real implementado: se deja pasar sin bloquear, registrando una advertencia en el log (ver [Cumplimiento Normativo](cumplimiento-normativo.md#caso-especial-la-pantalla-seguridad--actualizado)).
- **Postcondición:** igual que UC-01, pero sin la fricción de re-elegir cuenta en cada apertura.

### UC-02 — Cerrar sesión

- **Flujo principal:** menú lateral (drawer) → **"Cerrar sesión"** → confirmar en el diálogo → vuelve a la pantalla de login.
- **Regla de negocio:** qué pasa con la sesión de Google depende de si el usuario que cierra sesión tiene un método de Seguridad activo (`seguridad.metodoActivo`, ver UC-64 — es una preferencia por usuario, no por organización):
  - **Sin método activo:** se revoca la sesión de Google (`sheetsAuth.signOut()`). El próximo ingreso vuelve a mostrar el selector de cuentas (UC-01).
  - **Con un método activo** (Biométrico, Desbloqueo facial o 2FA): la sesión de Google **no se revoca** — el método de Seguridad ya cumple el rol de "candado" de la app. El próximo ingreso restaura la sesión de Google en silencio y pide directamente ese método, sin volver a mostrar el selector de cuentas (mismo flujo que UC-01b, aunque haya pasado por un logout explícito).
  - El diálogo de confirmación muestra un texto distinto según el caso, para que quede claro qué va a pasar antes de confirmar.
- **Postcondición:** ya no se puede navegar a ninguna vista protegida sin volver a autenticarse (con Google, o con el método de Seguridad configurado, según el caso de arriba).

## Clientes

### UC-10 — Registrar un cliente nuevo
- **Flujo principal:** vista **Clientes** → botón **"Nuevo Cliente"** → completar nombre, teléfono (E.164), email, saldo de deuda inicial → guardar.
- **Postcondición:** aparece en el listado con un ID autogenerado (`c0000000X`).

### UC-11 — Buscar, editar o eliminar un cliente
- Buscar por nombre/teléfono/email con el campo de búsqueda.
- Editar: ícono de lápiz en la tarjeta del cliente → modificar datos → guardar.
- Eliminar: ícono de papelera → confirmar en el diálogo (acción irreversible).
- **Ver compras:** ícono de carrito 🛒 en la tarjeta del cliente → abre **Ventas** filtrada a las facturas de ese cliente (ver UC-30b), con un chip para quitar el filtro y volver a ver todas las ventas.

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

Una venta es una **factura**: un cliente, uno o más productos, y un solo pago/abono para el total. La hoja `ventas` guarda el header de la factura (cliente, tasas, pago, totales); la hoja `venta_items` guarda una fila por cada producto comprado dentro de esa factura (relación 1:N venta→ítems).

### UC-30 — Registrar una venta (factura con uno o más productos)
- **Flujo principal:** vista **Ventas** → **"Nueva Venta"** → elegir el cliente → armar el carrito: elegir un producto, cantidad, **"Agregar"** (se repite para cada producto que se quiera incluir en la misma factura, viendo el subtotal de cada renglón y el total acumulado) → tasas (BCV/USD), método de pago, abono inicial → **"Guardar Venta"**.
- **Regla de negocio:** no se puede agregar más cantidad de un producto que el stock disponible (se avisa en el momento). Al guardar, se crea una fila en `ventas` (el header) y una fila en `venta_items` por cada producto del carrito; el stock de cada producto se descuenta por su cantidad.
- **Postcondición:** el monto en Bs/USD del header se calcula automáticamente como la suma de los subtotales de sus ítems; la deuda pendiente y el estado (`Pendiente` / `Pagada`) se calculan a partir del abono ingresado contra ese total.

### UC-30b — Ver el detalle de una factura
- **Flujo principal:** tocar una factura en la lista de **Ventas** (o entrar por el deep link `/ventas/:id`) → se abre el detalle: cliente, fecha, método de pago y tasas, y la lista de productos comprados (imagen, nombre, código de producto, cantidad, precio unitario y subtotal de cada uno), con el total, lo abonado y la deuda pendiente al final.
- **Nota:** también se llega acá tocando el ícono de carrito 🛒 en un cliente (vista **Clientes**, ver UC-11), que abre **Ventas** ya filtrada a las facturas de ese cliente.

### UC-31 — Registrar un abono a una venta pendiente
- Botón **"Registrar Abono"** en la tarjeta de una factura con deuda → ingresar monto → se actualiza el saldo del cliente y el estado de la factura (afecta el header, no ítems individuales — el pago es por toda la factura).

### UC-32 — Anular una venta
- Confirmación explícita ("¿Anular venta?") antes de ejecutar — es una acción destructiva sobre datos transaccionales.
- **Postcondición:** se elimina la factura y **todos** sus ítems, y se repone en Inventario el stock que esos ítems habían descontado (espejo exacto de lo que UC-30 descontó).

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

### UC-64 — Elegir el método de autenticación adicional (Seguridad)
- **Precondición:** al entrar a la vista, la app consulta en el dispositivo actual si hay biometría disponible (`BiometricAuthService.isAvailable()`) y si hay reconocimiento facial real (`hasFaceId()`), mientras muestra un indicador de carga breve.
- **Flujo principal:** vista **Seguridad** → elegir **una sola** opción de la lista: **Ninguno**, **Biométrico**, **Desbloqueo facial** o **2FA**. Son mutuamente excluyentes (selección única, como un grupo de radio buttons) — elegir una desactiva automáticamente la anterior.
- **Regla de visibilidad:** la opción **Biométrico** solo aparece si el dispositivo tiene algún método biométrico enrolado (huella o rostro); **Desbloqueo facial** solo aparece si el dispositivo tiene reconocimiento facial real (`hasFaceId()`). Si el dispositivo no soporta ninguno de los dos, la lista solo muestra **Ninguno** y **2FA**, más un texto aclaratorio.
- **Regla de auto-corrección:** si el método activo del usuario no es compatible con el equipo desde el que se abre esta vista — por ejemplo, **Desbloqueo facial** activado desde un iPhone y esta vista abierta ahora desde un Android sin cámara de profundidad — la app lo restablece automáticamente a **Ninguno** apenas termina de detectar las capacidades del dispositivo, y persiste ese cambio en la hoja `seguridad`, quedando registrado en Auditoría. No se deja seleccionada una opción que el dispositivo que abrió la vista no puede cumplir.
- **Postcondición:** el cambio se guarda en la hoja `seguridad`, en la fila correspondiente **al usuario que inició sesión** (ver [Multi-organización](google/multi-organizacion.md)) — es una preferencia por usuario, no por organización: no afecta el método configurado por otros usuarios de la misma organización, ni se ve afectado por el hardware de sus dispositivos.
- **Efecto real:** elegir **Biométrico** o **Desbloqueo facial** exige verificación biométrica en el próximo login de **ese mismo usuario** (ver UC-01 / UC-01b) — no de otros usuarios. **2FA** todavía no tiene ningún efecto funcional al momento de escribir esto — ver [Cumplimiento Normativo](cumplimiento-normativo.md#caso-especial-la-pantalla-seguridad--actualizado).

## Administración (multi-organización)

### UC-70 — Dar de alta un usuario autorizado
- **Flujo principal:** vista **Usuarios** → **"Nuevo Usuario"** → completar email (cuenta de Google), nombre (opcional) y elegir la **Organización** a la que pertenece → guardar.
- **Regla de negocio:** crea a la vez la fila en `usuarios` y su membresía en `usuario_organizacion` (relación 1:N organización→usuarios, ver [Multi-organización](google/multi-organizacion.md)). El `id` se autogenera (`u0000000X`).
- **Postcondición:** ese email queda habilitado para iniciar sesión (siempre que también esté en `ALLOWED_EMAILS`, ver [Google Sign-In](google/sign-in.md)) y resuelve automáticamente a la organización elegida.

### UC-71 — Editar o eliminar un usuario
- **Editar:** ícono de lápiz → se puede cambiar el nombre y reasignar la organización. El **email no se puede editar** (es la clave que usan `seguridad` y el login) — para cambiarlo hay que eliminar el usuario y crear uno nuevo.
- **Eliminar:** ícono de papelera → confirmar. Borra la fila de `usuarios` y su membresía en `usuario_organizacion`; ese email deja de poder iniciar sesión aunque siga en `ALLOWED_EMAILS`. Su fila de `seguridad` (si tenía un método configurado) queda huérfana pero inofensiva.

### UC-72 — Crear, editar o eliminar una organización
- **Crear:** vista **Organizaciones** → **"Nueva Organización"** → nombre → guardar. El `id` se autogenera como UUID v4.
- **Editar:** solo el nombre es editable; el `id` es inmutable.
- **Eliminar:** **bloqueado** si la organización todavía tiene usuarios asignados (la app muestra cuántos y pide reasignarlos o eliminarlos primero desde **Usuarios**) — evita dejar membresías apuntando a una organización inexistente.

### UC-73 — Ver y asignar los usuarios de una organización (desde Organizaciones)
- **Flujo principal:** vista **Organizaciones** → ícono de personas en la tarjeta de una organización → se abre la lista de sus usuarios actuales.
- **Agregar un usuario existente:** elegir de un desplegable (solo lista usuarios que **no** pertenecen ya a esta organización) → **"Agregar"** → queda reasignado a esta organización.
- **Mover un usuario a otra organización:** ícono de flechas cruzadas en la fila del usuario → elegir la organización destino (de las que existan, salvo la actual) → **"Mover"**.
- **Regla de negocio:** ambas acciones llaman a `SheetsDataService.updateUsuario(usuario, organizacionId: nuevaOrg)` — la misma función que usa UC-71, solo que iniciada desde el lado de la organización en vez de desde Usuarios. Un usuario pertenece a una única organización a la vez (relación 1:N): asignarlo a una nueva reemplaza la membresía anterior, no la duplica.

## Casos transversales

### UC-90 — Refrescar datos manualmente
- Todas las vistas tienen un botón de refresco explícito (política de **Cero Polling**: la app nunca refresca sola en segundo plano — ver [no_polling_policy.md](no_polling_policy.md)). El usuario decide cuándo volver a leer los datos de Google Sheets.

### UC-91 — Operar sin conexión / con datos en caché
- Si falla la lectura de Google Sheets, la app sigue mostrando los últimos datos cargados en memoria y notifica el error (documento privado, sin conexión, etc.) sin bloquear la navegación.
