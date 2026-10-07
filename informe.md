# Informe de revisión de formularios — Pendientes

**Fecha de la revisión:** 2026-10-06 · **Última actualización:** 2026-10-07

Este documento conserva solo lo que **todavía no está resuelto**. Todos los hallazgos de código de la revisión ya se corrigieron y se quitaron de acá. Las reglas que evitan que vuelvan están en [docs/estandar-hojas.md](docs/estandar-hojas.md), y los tests de `test/standards/` y `test/shared/pendientes_informe_test.dart` las verifican.

Solo queda pendiente la [deuda técnica registrada](#1-deuda-técnica-registrada): decisiones de producto que se postergaron a propósito. Los datos de producción ya se corrigieron (ver [§2](#2-datos-de-producción)).

---

## 1. Deuda técnica registrada

| ID | Qué | Detalle |
|---|---|---|
| DT-1 | No hay roles: cualquier usuario con sesión administra usuarios y organizaciones | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-1-no-hay-roles-cualquier-usuario-con-sesión-administra-usuarios-y-organizaciones) |
| DT-3 | La opción "2FA" de Seguridad no pide un segundo factor | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-3-la-opción-2fa-de-seguridad-no-pide-un-segundo-factor) |

---

## 2. Datos de producción

Sin pendientes. El 2026-10-07 se corrigieron los datos que habían dejado los bugs y las pruebas. Antes de cada cambio se tomó un respaldo en `respaldos/`, y cada cambio se aplicó como un lote atómico registrado en la bitácora. Se verificó leyendo producción.

- `tx_limpieza_datos_2026-10-07`: deuda de c00000004 recalculada, abonos e ítems huérfanos borrados, créditos de prueba borrados, venta v00000006 (total 0) borrada y teléfonos pasados a `+58…`.
- `tx_cedulas_demo_2026-10-07`: los 4 clientes no tenían cédula. Se cargaron **cédulas demo**, `V-99000002` a `V-99000005` (el número sigue al del cliente; no son cédulas reales). Cuando se conozcan las reales, hay que reemplazarlas desde Clientes.
