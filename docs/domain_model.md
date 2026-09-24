# Modelo de Dominio (Domain Model) — Estilo Neutral

Este documento detalla los **Aggregates**, **Entidades**, **Value Objects** y sus **invariantes de negocio** según Domain-Driven Design (Eric Evans, Vaughn Vernon).

---

## 1. Value Objects Compartidos (`lib/core/value_objects/`)

Todos los Value Objects son **inmutables**, **auto-validados** en sus constructores de fábrica y comparables por valor (`==` y `hashCode`).

### 1.1 `EntityId` (Jerarquía de Identificadores)
- **Regex**: `^[a-z]\d{8}$` (ej: `c00000001`, `p00000001`, `v00000001`, `d00000001`).
- Clases derivadas: `CustomerId`, `ProductId`, `SaleId`, `PurchaseId`.

### 1.2 `MoneyUsd` y `MoneyBs` (Seguridad de Tipos Monetarios)
- **Invariante**: $\text{amount} \ge 0.00$ y $\text{amount} \le 10^9$.
- Redondeo exacto a 2 decimales bancarios.
- **Type Safety**: No es posible sumar un `MoneyUsd` con un `MoneyBs` sin una conversión explícita mediante `ExchangeRate`.

### 1.3 `ExchangeRate` (Tasas de Cambio)
- **Invariante**: $\text{rate} > 0.00$.
- Métodos puros de conversión: `convertBsToUsd(MoneyBs)` y `convertUsdToBs(MoneyUsd)`.

### 1.4 `IsoDate` (Fechas ISO 8601)
- Almacena fecha y hora en UTC. Formateo `YYYY-MM-DD` para compatibilidad con la hoja de cálculo.

---

## 2. Aggregates y Entidades

### 2.1 Aggregate Root: `Customer` (Cliente)
- **Identidad**: `CustomerId`.
- **Atributos**: `name`, `phone` (E.164), `email` (RFC 5322), `debtBalance` (`MoneyUsd`), `registeredAt` (`IsoDate`).
- **Invariantes**:
  - El saldo deudor no puede ser negativo ($\text{debtBalance} \ge 0$).
  - El formato de teléfono debe cumplir con la norma internacional ITU-T E.164 (`+58...`).
- **Comportamiento**:
  - `increaseDebt(MoneyUsd)`: incrementa el balance deudor y emite `CustomerDebtIncreased`.
  - `payDebt(MoneyUsd)`: reduce el balance deudor y emite `CustomerDebtCleared` si llega a 0.

### 2.2 Aggregate Root: `Product` (Producto)
- **Identidad**: `ProductId`.
- **Atributos**: `stock` (`StockQuantity`), `name`, `brand`, `model`, `size`, `priceUsd` (`MoneyUsd`), `photoId` (FK a la hoja `galeria`, nunca una URL directa — ver [Galería de fotos](google/galeria-fotos.md)).
- **Invariantes**:
  - El stock físico nunca puede ser negativo ($\text{quantity} \ge 0$).
  - El precio en USD debe ser estrictamente mayor a cero ($> 0.00$).
- **Comportamiento**:
  - `decrementStock(int)`: reduce inventario y emite `StockDepleted` si el stock llega a 0.
  - `replenishStock(int)`: repone inventario y emite `StockReplenished`.

### 2.3 Aggregate Root: `Sale` (Venta)
- **Identidad**: `SaleId`.
- **Atributos**: `date` (`IsoDate`), `customerId` (`CustomerId`), `items` (`List<SaleItem>`), `bcvRate` (`ExchangeRate`), `usdRate` (`ExchangeRate`), `paymentMethod` (`PaymentMethod`), `mobilePaymentFeeBs` (`MoneyBs`), `paidAmount` (`MoneyUsd`), `status` (`SaleStatus`).
- **Entidad Interna**: `SaleItem` (`productId`, `quantity`, `unitPriceUsd`, `subtotalUsd`).
- **Invariantes**:
  - $\text{totalUsd} = \sum \text{subtotales de items}$.
  - $\text{debtUsd} = \text{totalUsd} - \text{paidAmount}$.
  - $\text{paidAmount} \ge 0$ y $\text{paidAmount} \le \text{totalUsd}$.
  - $\text{status} = \text{Pagada} \iff \text{debtUsd} == 0.00$.
- **Comportamiento**:
  - `addItem(Product, quantity)`: agrega una línea de venta y recalcula totales.
  - `registerPayment(MoneyUsd)`: abona a la venta y emite `SalePaid` si se cancela en su totalidad.
  - `cancel(String reason)`: anula la venta y emite `SaleCancelled`.

### 2.4 Aggregate Root: `CurrencyPurchase` (Compra de Divisas)
- **Identidad**: `PurchaseId`.
- **Atributos**: `purchaseDate` (`IsoDate`), `deliveryDate` (`IsoDate`), `capitalUsd` (`MoneyUsd`), `platformFeeUsd` (`MoneyUsd`), `orderNumber`, `platform`, `seller`, `bcvRate`, `usdRate`.
- **Invariantes**:
  - $\text{deliveryDate} \ge \text{purchaseDate}$.
  - $\text{capitalUsd} > 0.00$ y $\text{platformFeeUsd} \ge 0.00$.
