# Catálogo de Eventos de Dominio (Domain Events) — Estilo Neutral

Este catálogo describe los **Domain Events** generados por los Aggregates para notificar cambios de estado significativos a otros contextos delimitados o capas de la aplicación.

---

## 1. Clase Base: `DomainEvent`

Todos los eventos heredan de `DomainEvent` y contienen:
- `eventId`: UUID v4 inmutable.
- `occurredOn`: `DateTime` en UTC (timestamp de ocurrencia).
- `aggregateId`: Identificador del Aggregate que originó el evento.
- `eventName`: Nombre del evento para propósitos de auditoría y serialización.

---

## 2. Catálogo por Bounded Context

### 2.1 Sales Context (Ventas)
| Evento | Origen | Descripción | Payload relevante |
| :--- | :--- | :--- | :--- |
| `SaleCreated` | `Sale` | Se ha creado y registrado una nueva venta. | `saleId`, `customerId`, `totalUsd`, `paidAmount` |
| `SalePaid` | `Sale` | Una venta ha sido pagada en su totalidad (deuda = 0). | `saleId`, `totalUsd`, `closedAt` |
| `SaleCancelled` | `Sale` | Se ha anulado una venta previamente registrada. | `saleId`, `reason` |
| `CustomerDebtIncreased` | `Customer` | Se ha incrementado el balance deudor del cliente. | `customerId`, `amountAdded`, `newBalance` |
| `CustomerDebtCleared` | `Customer` | El cliente ha liquidado el 100% de su saldo deudor. | `customerId`, `clearedAt` |
| `StockDepleted` | `Product` | El stock de un producto ha llegado a 0. | `productId`, `depletedAt` |
| `StockReplenished` | `Product` | Se ha repuesto inventario de un producto. | `productId`, `newQuantity` |

### 2.2 Treasury Context (Tesorería)
| Evento | Origen | Descripción | Payload relevante |
| :--- | :--- | :--- | :--- |
| `CurrencyPurchaseCreated` | `CurrencyPurchase` | Se ha registrado una compra de divisas (USDT/USD). | `purchaseId`, `capitalUsd`, `platform` |
| `CurrencyPurchaseCompleted`| `CurrencyPurchase` | Se ha confirmado la entrega efectiva de las divisas. | `purchaseId`, `deliveredAt` |

---

## 3. Bus de Eventos en Memoria (`EventBus`)

- **Patrón Publish/Subscribe**: Los Aggregates emiten eventos que se publican en el `EventBus` **únicamente después de que la persistencia en Google Sheets haya concluido exitosamente** (post-commit).
- **Implementación**: `StreamController<DomainEvent>.broadcast()` en memoria.
- **Sin Polling**: El bus es reactivo a eventos generados por acciones del usuario; no utiliza temporizadores de ningún tipo.
