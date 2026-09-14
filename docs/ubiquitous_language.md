# Lenguaje Ubicuo (Ubiquitous Language) — Estilo Neutral

Este glosario unifica el vocabulario del negocio (Español) con su correspondiente identificador estricto en el código fuente (Inglés), en cumplimiento de los estándares de Domain-Driven Design (Eric Evans) e **ISO 8000** (Calidad de Datos).

---

## 1. Matriz de Equivalencias (Español ↔ Inglés)

| Término negocio (ES) | Término código (EN) | Tipo DDD | Definición | Hoja origen |
| :--- | :--- | :--- | :--- | :--- |
| **Cliente** | `Customer` | Aggregate Root | Persona natural o jurídica que adquiere prendas y puede mantener un balance deudor. | `clientes` |
| **Producto** | `Product` | Aggregate Root | Ítem del catálogo de inventario con stock físico controlado, tallas y precio en USD. | `inventario` |
| **Venta** | `Sale` | Aggregate Root | Transacción comercial donde se despachan uno o más productos a un cliente. | `ventas` |
| **Línea de Venta** | `SaleItem` | Entity | Detalle de ítem, cantidad, precio unitario y subtotal dentro de una venta. | `ventas` |
| **Compra de Divisas** | `CurrencyPurchase` | Aggregate Root | Operación cambiaria en plataforma externa (Binance, P2P, banco) para adquirir USD. | `compras_divisas` |
| **Tasa BCV** | `BcvRate` | Value Object | Tipo de cambio oficial establecido por el Banco Central de Venezuela. | `ventas.tasa_bcv` |
| **Tasa USD (Binance)** | `UsdRate` | Value Object | Tipo de cambio paralelo/mercado P2P en USD/USDT. | `ventas.tasa_usd` |
| **Abono** | `Payment` | Value Object | Monto entregado por el cliente que reduce o liquida el total a pagar de la venta. | `ventas.abono_usd` |
| **Deuda** | `Debt` | Value Object | Saldo pendiente por cobrar tras deducir los abonos del total de la venta. | `ventas.deuda_usd` |
| **Método de Pago** | `PaymentMethod` | Value Object | Canal financiero de cobro (Efectivo, Pago Móvil, Transferencia, Zelle, Binance, Otro). | `ventas.tipo_pago` |
| **Estado de Venta** | `SaleStatus` | Value Object | Estado del ciclo de vida (Pendiente, Pagada, Anulada, Cuarentena). | `ventas.estado` |
| **Resumen Diario** | `DailySummary` | Read Model | Vista agregada consolidada con indicadores de ventas y flujo de divisas del día. | `resumen_diario` |
| **Registro de Cuarentena** | `QuarantineRecord` | Read Model | Registro con inconsistencias o datos heredados desnormalizados para auditoría. | `cuarentena` |
| **Bitácora de Auditoría** | `AuditLogEntry` | Read Model | Registro inmutable de trazabilidad forense según ISO/IEC 27001 §12.4. | `audit_log` |
| **Reporte de Migración** | `MigrationReport` | Read Model | Resumen ejecutivo forense de controles y métricas del libro. | `reporte_migracion` |
| **Checklist ISO** | `ChecklistIsoItem` | Read Model | Control formal de auditoría con estado ☑ / ☐ y evidencias. | `checklist_iso` |

---

## 2. Reglas de Uso y Nomenclatura

1. **Capa de Dominio, Aplicación e Infraestructura (Código)**:
   - Todo identificador de clase, método, campo, DTO o tabla debe redactarse estrictamente en **Inglés (`EN`)**.
   - Ejemplo: `class Sale`, `customer.registerDebt(moneyUsd)`, `product.decrementStock(quantity)`.
2. **Capa de Presentación (Interfaz de Usuario)**:
   - Toda etiqueta, texto, diálogo, alerta o reporte visible para el usuario debe redactarse en **Español (`ES`)**.
   - Ejemplo: *"Nueva Venta"*, *"Saldo Deudor"*, *"Registrar Abono"*, *"Tasa Oficial BCV"*.
