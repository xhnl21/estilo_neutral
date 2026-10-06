# Informe de revisión de formularios — Pendientes

**Fecha de la revisión:** 2026-10-06 · **Última actualización:** 2026-10-06

Este documento conserva solo lo que **todavía no está resuelto**. Todos los hallazgos de código de la revisión ya se corrigieron y se quitaron de acá. Las reglas que evitan que vuelvan están en [docs/estandar-hojas.md](docs/estandar-hojas.md), y los tests de `test/standards/` y `test/shared/pendientes_informe_test.dart` las verifican.

Quedan dos tipos de pendientes:

1. [Deuda técnica registrada](#1-deuda-técnica-registrada): decisiones de producto que se postergaron a propósito.
2. [Datos de producción por corregir](#2-datos-de-producción-por-corregir): datos que dejaron los bugs ya corregidos o las pruebas. Corregirlos implica escribir en la hoja de producción, así que **requiere aprobación**.

---

## 1. Deuda técnica registrada

| ID | Qué | Detalle |
|---|---|---|
| DT-1 | No hay roles: cualquier usuario con sesión administra usuarios y organizaciones | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-1-no-hay-roles-cualquier-usuario-con-sesión-administra-usuarios-y-organizaciones) |
| DT-2 | Un acceso revocado se detecta recién cuando llegan datos nuevos | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-2-un-acceso-revocado-se-detecta-recién-cuando-llegan-datos-nuevos) |
| DT-3 | La opción "2FA" de Seguridad no pide un segundo factor | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-3-la-opción-2fa-de-seguridad-no-pide-un-segundo-factor) |

---

## 2. Datos de producción por corregir

Resultado de leer la hoja de producción con los parsers de la app el 2026-10-06. Fue una lectura sin modificaciones. Hay una sola organización (Estilo Neutral), así que el bug que movía registros a la organización por defecto no dejó datos mal ubicados. No hay abonos duplicados.

### 2.1 Deuda del cliente desactualizada en la hoja

Antes, la columna `saldo_deuda_usd` de `clientes` no se actualizaba al abonar. Ahora la app la actualiza sumando o restando la diferencia en cada venta, abono, anulación o crédito aplicado. Por eso **el valor de partida tiene que ser correcto**.

| Cliente | `saldo_deuda_usd` en la hoja | Deuda según sus ventas |
|---|---|---|
| c00000004 (Zayda Pulgar) | 0.00 | 20.00 (v00000002) |

Los otros tres clientes coinciden (0.00). **Propuesta:** recalcular la columna una sola vez como la suma de la deuda de las ventas de cada cliente.

### 2.2 Abonos e ítems de ventas que ya no existen

Quedaron de anulaciones hechas antes de que anular una venta fuera una operación atómica: se borraba la venta, pero no sus ítems ni sus abonos.

| Hoja | Registro | Venta (inexistente) | Datos |
|---|---|---|---|
| abonos | ab00000002 | v00000003 | USD 600.00, 2026-09-23 |
| abonos | ab00000008 | v00000007 | USD 150.00, 2026-09-25 |
| venta_items | vi00000003 | v00000003 | p00000001 × 10 |
| venta_items | vi00000004 | v00000003 | p00000003 × 20 |
| venta_items | vi00000007 | v00000004 | p00000004 × 5 |

Las anulaciones viejas tampoco devolvían el stock, así que conviene revisar el stock de p00000001, p00000003 y p00000004. **Propuesta:** borrar estas 5 filas, después de confirmar que esas ventas se anularon a propósito.

### 2.3 Créditos (saldo a favor) inconsistentes

Los 8 registros de `creditos_clientes` tienen saldo 0 (aplicados o anulados), así que hoy no afectan ningún monto. Pero sus referencias no cierran, y parecen datos de prueba:

- **cr00000004 a cr00000008**: cliente `c00000001`, que no existe, y ventas de origen y destino que tampoco existen (v00000007 a v00000013).
- **cr00000001 y cr00000002**: cliente c00000002, pero su venta de origen, v00000002, es de otro cliente (c00000004).
- **cr00000003**: origen en v00000006, una venta con total 0.

**Propuesta:** confirmar si son pruebas y, en ese caso, borrarlos.

### 2.4 Venta con total 0

**v00000006** (cliente c00000005, 2026-10-06) tiene total 0, monto 0 y estado "Pendiente". **Propuesta:** revisar si fue una prueba y anularla desde la app.

### 2.5 Datos incompletos o en formato viejo (no requieren acción urgente)

- Los 4 clientes tienen la cédula vacía. No se puede saber si la perdieron por el bug de ventas ya corregido o si nunca se cargó. Hay que completarlas desde Clientes.
- Tres teléfonos están guardados sin el 0 inicial (`4144414473`), del tiempo en que Sheets se lo quitaba. La app los lee bien y los guarda en formato `+58…` la próxima vez que se edita el cliente.
