# Informe de revisión de formularios — Pendientes

**Fecha de la revisión:** 2026-10-06 · **Última actualización:** 2026-10-07

Este documento conserva solo lo que **todavía no está resuelto**. Todos los hallazgos de código de la revisión ya se corrigieron y se quitaron de acá. Las reglas que evitan que vuelvan están en [docs/estandar-hojas.md](docs/estandar-hojas.md), y los tests de `test/standards/` y `test/shared/pendientes_informe_test.dart` las verifican.

Solo queda pendiente la [deuda técnica registrada](#1-deuda-técnica-registrada): decisiones de producto que se postergaron a propósito. Los datos de producción se corrigieron el 2026-10-07 (lotes `tx_limpieza_datos_2026-10-07` y `tx_cedulas_demo_2026-10-07`, registrados en la bitácora). Las cédulas V-99000002 a V-99000005 de los clientes son valores demo definitivos.

---

## 1. Deuda técnica registrada

| ID | Qué | Detalle |
|---|---|---|
| DT-1 | No hay roles: cualquier usuario con sesión administra usuarios y organizaciones | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-1-no-hay-roles-cualquier-usuario-con-sesión-administra-usuarios-y-organizaciones) |
| DT-3 | La opción "2FA" de Seguridad no pide un segundo factor | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-3-la-opción-2fa-de-seguridad-no-pide-un-segundo-factor) |

