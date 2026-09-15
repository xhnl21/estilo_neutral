Prompt Maestro — Fase 11: Arquitectura DDD sobre Google Sheets + Flutter
Modo: Paranoico / Auditoría Forense / Arquitectura Limpia
Estándares: Eric Evans (DDD), Vaughn Vernon (IDDD), Robert C. Martin (Clean Architecture), ISO/IEC 25010, ISO 8000, ISO/IEC 27001, OWASP MASVS
Objetivo: Aplicar Arquitectura Orientada al Dominio (DDD) al sistema actual, sin romper la hoja ni la conexión Flutter existente. Sin polling.

📋 PROMPT (copiar y pegar completo)
text
ACTÚA COMO: Arquitecto de Software Senior especializado en Domain-Driven Design (Eric Evans, Vaughn Vernon), Clean Architecture (Robert C. Martin), y sistemas Flutter + Google Sheets. Certificado en ISO/IEC 25010, ISO 8000, ISO/IEC 27001 y OWASP MASVS.

CONTEXTO: Existe un sistema en Google Sheets llamado "Estilo Neutral" con 8 hojas refactorizadas:

- clientes (entidad)
- inventario (entidad)
- ventas (transaccional)
- compras_divisas (transaccional)
- resumen_diario, cuarentena, audit_log, reporte_migracion (solo lectura)

Existe también un mapeo Flutter con google_sheets_orm (Cliente, Producto, Venta, CompraDivisa, etc.). NO se implementó polling: la actualización es bajo demanda del usuario.

MISIÓN: Refactorizar la capa de software aplicando Arquitectura DDD + Clean Architecture. Modelar el negocio en Lenguaje Ubicuo (español), definir Bounded Contexts, Aggregates, Value Objects, Domain Events, Repositorios e Infraestructura. NO romper la hoja. NO implementar polling. NO duplicar lógica entre capas.

═══════════════════════════════════════════════════════════
FASE 11.0 — PREPARACIÓN Y BACKUP
═══════════════════════════════════════════════════════════

11.0.1. Backup "Estilo Neutral_BACKUP_DDD_YYYYMMDD_HHMMSS" en 3 formatos.
11.0.2. Verificar SHA-256 previo.
11.0.3. Confirmar que la columna validacion = "OK" en todas las filas de ventas y compras_divisas.
11.0.4. Registrar en audit_log: acción "inicio_refactor_ddd", norma DDD/Clean Arch, timestamp ISO 8601.
11.0.5. NO tocar la hoja durante esta fase. DDD es una refactorización de SOFTWARE, no de datos.

═══════════════════════════════════════════════════════════
FASE 11.1 — LENGUAJE UBICUO (Ubiquitous Language)
═══════════════════════════════════════════════════════════

Definir un glosario en español (idioma del negocio) y mapearlo a inglés solo en código.

11.1.1. Crear archivo docs/ubiquitous_language.md con:

| Término negocio (ES) | Término código (EN) | Definición                                        | Hoja origen      |
| -------------------- | ------------------- | ------------------------------------------------- | ---------------- |
| Cliente              | Customer            | Persona que compra productos y puede tener deuda  | clientes         |
| Producto             | Product             | Ítem del catálogo con stock y precio en USD       | inventario       |
| Venta                | Sale                | Transacción de venta de 1+ productos a un cliente | ventas           |
| Compra de Divisas    | CurrencyPurchase    | Operación de compra de USDT/dólares               | compras_divisas  |
| Tasa BCV             | BcvRate             | Tasa oficial del Banco Central de Venezuela       | ventas.tasa_bcv  |
| Tasa USD (Binance)   | UsdRate             | Tasa paralela/cripto                              | ventas.tasa_usd  |
| Abono                | Payment             | Pago parcial o total de una venta                 | ventas.abono_usd |
| Deuda                | Debt                | Saldo pendiente de una venta                      | ventas.deuda_usd |
| Pago Móvil           | MobilePayment       | Método de pago venezolano                         | enum tipo_pago   |
| Resumen Diario       | DailySummary        | Vista agregada de operaciones del día             | resumen_diario   |
| Cuarentena           | QuarantineRecord    | Registro con anomalías preservado                 | cuarentena       |

11.1.2. Regla: TODO nombre de clase, método y variable debe usar el término EN del glosario. Los textos de UI usan el término ES.
11.1.3. Documentar en audit_log: "lenguaje_ubicuo_definido".

═══════════════════════════════════════════════════════════
FASE 11.2 — BOUNDED CONTEXTS
═══════════════════════════════════════════════════════════

Identificar y documentar los contextos delimitados del negocio:

11.2.1. Contexto 1: VENTAS (Sales Context)
Responsabilidad: gestionar clientes, productos, ventas, abonos, deudas.
Aggregates: Cliente, Producto, Venta.
Hojas: clientes, inventario, ventas.

11.2.2. Contexto 2: TESORERÍA (Treasury Context)
Responsabilidad: gestionar compras de divisas, tasas, capital.
Aggregates: CompraDivisa, TasaCambio.
Hojas: compras_divisas.

11.2.3. Contexto 3: REPORTES (Reporting Context)
Responsabilidad: agregar datos, generar resúmenes, alertas.
Aggregates: ResumenDiario (read model).
Hojas: resumen_diario.

11.2.4. Contexto 4: AUDITORÍA (Audit Context)
Responsabilidad: trazabilidad forense, cuarentena, logs.
Aggregates: RegistroCuarentena, EntradaAuditLog, ReporteMigracion, ChecklistISO.
Hojas: cuarentena, audit_log, reporte_migracion, checklist_iso.

11.2.5. Crear Context Map en docs/context_map.md con relaciones: - VENTAS → REPORTES: Customer/Supplier (REPORTES consume eventos de VENTAS) - TESORERÍA → REPORTES: Customer/Supplier - VENTAS ↔ TESORERÍA: Shared Kernel (TasaCambio) - AUDITORÍA: Conformist (observa a todos, no es observado)

11.2.6. Regla: ningún contexto importa clases de otro contexto directamente. Solo se comunican vía Domain Events o DTOs explícitos en la capa de aplicación.

═══════════════════════════════════════════════════════════
FASE 11.3 — ESTRUCTURA DE CARPETAS (Clean Architecture)
═══════════════════════════════════════════════════════════

Crear la siguiente estructura en el proyecto Flutter:

lib/
├── main.dart
├── app/
│ ├── app.dart
│ ├── di/ # Inyección de dependencias
│ │ └── injection.dart
│ └── router/
│ └── app_router.dart
│
├── core/ # Compartido entre contextos
│ ├── error/
│ │ ├── failures.dart
│ │ └── exceptions.dart
│ ├── types/
│ │ ├── either.dart # Result<T, Failure>
│ │ ├── entity.dart
│ │ ├── value_object.dart
│ │ ├── aggregate_root.dart
│ │ └── domain_event.dart
│ ├── value_objects/ # Compartidos entre contextos
│ │ ├── money_usd.dart
│ │ ├── money_bs.dart
│ │ ├── exchange_rate.dart
│ │ ├── entity_id.dart
│ │ └── iso_date.dart
│ └── usecase/
│ └── use_case.dart
│
├── features/
│ ├── sales/ # Bounded Context: VENTAS
│ │ ├── domain/
│ │ │ ├── entities/
│ │ │ │ ├── customer.dart
│ │ │ │ ├── product.dart
│ │ │ │ └── sale.dart
│ │ │ ├── value_objects/
│ │ │ │ ├── customer_id.dart
│ │ │ │ ├── product_id.dart
│ │ │ │ ├── sale_id.dart
│ │ │ │ ├── payment_method.dart
│ │ │ │ ├── sale_status.dart
│ │ │ │ └── stock_quantity.dart
│ │ │ ├── events/
│ │ │ │ ├── sale_created.dart
│ │ │ │ ├── sale_paid.dart
│ │ │ │ └── stock_depleted.dart
│ │ │ ├── repositories/ # Interfaces (contratos)
│ │ │ │ ├── customer_repository.dart
│ │ │ │ ├── product_repository.dart
│ │ │ │ └── sale_repository.dart
│ │ │ └── services/
│ │ │ └── sale_calculator.dart # Domain Service
│ │ ├── application/
│ │ │ ├── usecases/
│ │ │ │ ├── create_sale.dart
│ │ │ │ ├── register_payment.dart
│ │ │ │ ├── get_customer_debt.dart
│ │ │ │ └── list_products.dart
│ │ │ └── dtos/
│ │ │ ├── sale_dto.dart
│ │ │ └── customer_dto.dart
│ │ ├── infrastructure/
│ │ │ ├── datasources/
│ │ │ │ └── sales_sheets_datasource.dart
│ │ │ ├── models/ # Mapeo 1:1 con hoja
│ │ │ │ ├── customer_model.dart
│ │ │ │ ├── product_model.dart
│ │ │ │ └── sale_model.dart
│ │ │ └── repositories/ # Implementación de contratos
│ │ │ ├── customer_repository_impl.dart
│ │ │ ├── product_repository_impl.dart
│ │ │ └── sale_repository_impl.dart
│ │ └── presentation/
│ │ ├── pages/
│ │ ├── widgets/
│ │ └── controllers/
│ │
│ ├── treasury/ # Bounded Context: TESORERÍA
│ │ └── (misma estructura que sales)
│ │
│ ├── reporting/ # Bounded Context: REPORTES (read-only)
│ │ └── (misma estructura, sin usecases de escritura)
│ │
│ └── audit/ # Bounded Context: AUDITORÍA (read-only)
│ └── (misma estructura, sin usecases de escritura)
│
└── shared/ # Infra transversal
├── google_sheets/
│ ├── sheets_client.dart
│ ├── sheets_auth.dart
│ └── sheets_config.dart
└── storage/
└── secure_token_storage.dart

11.3.1. Regla de dependencia (Clean Architecture):
presentation → application → domain ← infrastructure
domain NO depende de NADA externo (ni Flutter, ni Sheets, ni ORM).

11.3.2. Documentar estructura en audit_log: "estructura_ddd_creada".

═══════════════════════════════════════════════════════════
FASE 11.4 — VALUE OBJECTS (inmutables, auto-validados)
═══════════════════════════════════════════════════════════

Crear en core/value_objects/ y en cada dominio:

11.4.1. EntityId (abstracto) + CustomerId, ProductId, SaleId, PurchaseId - Validan regex ^[a-z]\d{8}$ - Igualdad por valor - Método value() → String

11.4.2. MoneyUsd y MoneyBs - double amount, >= 0, <= 1e9 - 2 decimales exactos - Operaciones: +, -, \*, scalar - NUNCA mezclar MoneyUsd con MoneyBs (type safety)

11.4.3. ExchangeRate (BcvRate, UsdRate) - double value, > 0, < 1e9 - 2 decimales - Método convert(MoneyBs, MoneyUsd)

11.4.4. IsoDate - DateTime normalizado a UTC - Serialización ISO 8601 estricta - Comparaciones >=, <=, ==

11.4.5. PaymentMethod (enum sellado) - Efectivo, PagoMovil, Transferencia, Zelle, Binance, Otro

11.4.6. SaleStatus (enum sellado) - Pendiente, Pagada, Anulada, Cuarentena

11.4.7. StockQuantity - int >= 0 - Métodos: decrement(), increment()

11.4.8. Cada Value Object debe: - Ser inmutable (final fields) - Validar en constructor de fábrica - Lanzar Failure si inválido - Tener == y hashCode - Tener toString() legible

═══════════════════════════════════════════════════════════
FASE 11.5 — ENTIDADES Y AGGREGATES
═══════════════════════════════════════════════════════════

11.5.1. Aggregate Root: Customer (Cliente) - Identidad: CustomerId - Atributos: nombre, telefono (E.164), email, saldoDeudaUsd, fechaRegistro - Invariantes:
_ saldoDeudaUsd >= 0
_ telefono cumple E.164
_ email cumple RFC 5322 - Comportamiento:
_ registrarDeuda(MoneyUsd)
_ abonarDeuda(MoneyUsd)
_ actualizarContacto(telefono, email) - Eventos: CustomerDebtIncreased, CustomerDebtCleared

11.5.2. Aggregate Root: Product (Producto) - Identidad: ProductId - Atributos: cantidad, nombre, marca, modelo, talla, precioUsd, fotoUrl - Invariantes:
_ cantidad >= 0
_ precioUsd > 0 - Comportamiento:
_ decrementarStock(StockQuantity)
_ incrementarStock(StockQuantity) \* actualizarPrecio(MoneyUsd) - Eventos: StockDepleted, StockReplenished, PriceChanged

11.5.3. Aggregate Root: Sale (Venta) - Identidad: SaleId - Atributos: fecha, customerId, items, tasaBcv, tasaUsd, tipoPago, comisionPagoMovilBs, abonoUsd, estado - Entidades internas: SaleItem (itemId, cantidad, precioUnitarioUsd, subtotalUsd) - Invariantes:
_ totalPagarUsd = sum(items.subtotal)
_ deudaUsd = totalPagarUsd - abonoUsd
_ abonoUsd >= 0 y <= totalPagarUsd
_ estado = Pagada ⟺ deudaUsd == 0 - Comportamiento:
_ agregarItem(Product, cantidad)
_ registrarAbono(MoneyUsd, PaymentMethod) \* anular(motivo) - Eventos: SaleCreated, SalePaid, SaleCancelled, PaymentRegistered

11.5.4. Aggregate Root: CompraDivisa (CurrencyPurchase) - Identidad: PurchaseId - Atributos: fechaCompra, fechaEntrega, capitalUsd, comisionBinanceUsd, numeroOrden, plataforma, vendedor, tasaBcv, tasaUsd - Invariantes:
_ fechaEntrega >= fechaCompra
_ capitalUsd > 0 \* comisionBinanceUsd >= 0 - Eventos: CurrencyPurchaseCreated, CurrencyPurchaseCompleted

11.5.5. Read Models (sin Aggregate Root): - ResumenDiario, RegistroCuarentena, EntradaAuditLog, ReporteMigracion, ChecklistISO - Se modelan como DTOs inmutables, no como entidades de dominio.

═══════════════════════════════════════════════════════════
FASE 11.6 — DOMAIN EVENTS
═══════════════════════════════════════════════════════════

11.6.1. Clase base en core/types/domain_event.dart: - eventId (uuid) - occurredOn (IsoDate) - aggregateId (EntityId) - eventName (String)

11.6.2. Definir eventos por contexto (ver 11.5).
11.6.3. Los eventos se publican post-persistencia, no antes.
11.6.4. Ningún contexto importa eventos de otro; se suscriben vía bus de eventos en la capa de aplicación.
11.6.5. Implementar EventBus simple en memoria (stream controller). NO usar polling.

═══════════════════════════════════════════════════════════
FASE 11.7 — DOMAIN SERVICES
═══════════════════════════════════════════════════════════

11.7.1. SaleCalculator (VENTAS) - calcularTotalPagar(items, tasaBcv): MoneyUsd - calcularMontoBs(totalUsd, tasaBcv): MoneyBs - calcularDeuda(totalPagarUsd, abonoUsd): MoneyUsd - Sin estado, puro, testeable.

11.7.2. StockValidator (VENTAS) - puedeVender(Product, cantidad): bool - Sin estado.

11.7.3. RateConverter (compartido TESORERÍA↔VENTAS) - convert(MoneyBs, ExchangeRate): MoneyUsd - convert(MoneyUsd, ExchangeRate): MoneyBs - Sin estado.

═══════════════════════════════════════════════════════════
FASE 11.8 — REPOSITORIOS (contratos en domain, impl en infra)
═══════════════════════════════════════════════════════════

11.8.1. Interfaces en domain/repositories/: - CustomerRepository: findById, findAll, save, update, delete - ProductRepository: findById, findAll, save, update, delete, findLowStock - SaleRepository: findById, findByCustomer, findByDate, save, update, delete - PurchaseRepository: análogo

11.8.2. Métodos retornan Result<T, Failure> (Either).
11.8.3. NO exponer tipos de Google Sheets ni de ORM en el contrato.
11.8.4. Los IDs son Value Objects (CustomerId, no String).

═══════════════════════════════════════════════════════════
FASE 11.9 — INFRAESTRUCTURA (Google Sheets + ORM)
═══════════════════════════════════════════════════════════

11.9.1. Models (infrastructure/models/) mapean 1:1 con las hojas. - customer_model.dart ↔ clientes - product_model.dart ↔ inventario - sale_model.dart ↔ ventas - purchase_model.dart ↔ compras_divisas - daily_summary_model.dart ↔ resumen_diario (read-only) - quarantine_model.dart ↔ cuarentena (read-only) - audit_log_model.dart ↔ audit_log (read-only) - migration_report_model.dart ↔ reporte_migracion (read-only) - checklist_iso_model.dart ↔ checklist_iso (read-only)

11.9.2. Mappers: Model ↔ Entity ↔ DTO - toEntity() y fromEntity() en cada Model. - Conversión DateTime ↔ ISO 8601 (usar IsoDate). - Conversión double ↔ String con punto decimal (2 decimales). - Conversión enum ↔ String exacto del sheet.

11.9.3. Datasource único por contexto (sales_sheets_datasource.dart). - Usa google_sheets_orm bajo el capó. - Lee rangos acotados (A1:O1000, no columnas completas). - Escritura: UNA operación por acción. - Post-escritura: UNA relectura de confirmación. - NO polling. NO Timer. NO Stream.periodic.

11.9.4. Repositorios impl: - Implementan los contratos del dominio. - Atrapan excepciones del ORM → las convierten a Failure. - NO exponen stack traces a la capa de aplicación.

11.9.5. Autenticación: - google_sign_in con scopes: spreadsheets, drive.readonly. - Tokens en flutter_secure_storage. - Refresh silencioso al expirar.

═══════════════════════════════════════════════════════════
FASE 11.10 — APLICACIÓN (Use Cases)
═══════════════════════════════════════════════════════════

11.10.1. Cada Use Case: UNA responsabilidad, UNA acción.
11.10.2. Firma: Future<Result<Output, Failure>> call(Input).
11.10.3. Ejemplos: - CreateSaleUseCase(CreateSaleInput) → SaleDto - RegisterPaymentUseCase(RegisterPaymentInput) → SaleDto - GetCustomerDebtUseCase(CustomerId) → MoneyUsd - ListProductsUseCase(NoInput) → List<ProductDto> - RefreshDataUseCase(NoInput) → void // Equivalente al botón "Actualizar"
11.10.4. Los Use Cases orquestan dominio + repositorios + eventos.
11.10.5. NO contienen lógica de negocio (esa vive en el dominio).

═══════════════════════════════════════════════════════════
FASE 11.11 — PRESENTACIÓN (Flutter UI)
═══════════════════════════════════════════════════════════

11.11.1. Separar páginas, widgets y controllers.
11.11.2. Usar Riverpod / Bloc / Provider (elegir UNO y justificarlo).
11.11.3. Los controllers SOLO llaman Use Cases; nunca repositorios directos.
11.11.4. Estado manejado con sealed classes (Loading, Success, Failure).
11.11.5. NO polling en la UI.
11.11.6. Refresco manual: botón "Actualizar" que dispara RefreshDataUseCase.
11.11.7. Manejo de errores: mostrar mensaje legible, nunca stack trace.

═══════════════════════════════════════════════════════════
FASE 11.12 — TESTING
═══════════════════════════════════════════════════════════

11.12.1. Tests unitarios de Value Objects (validación, igualdad).
11.12.2. Tests unitarios de Aggregates (invariantes, eventos).
11.12.3. Tests unitarios de Domain Services (cálculos).
11.12.4. Tests de Use Cases con repositorios mockeados.
11.12.5. Tests de integración con un Sheet de prueba (no producción).
11.12.6. Cobertura mínima: 80% en domain, 60% en application.
11.12.7. NO testear infraestructura con dependencias externas reales.

═══════════════════════════════════════════════════════════
FASE 11.13 — DOCUMENTACIÓN
═══════════════════════════════════════════════════════════

11.13.1. docs/ubiquitous_language.md (Fase 11.1).
11.13.2. docs/context_map.md (Fase 11.2).
11.13.3. docs/architecture.md con diagrama de capas.
11.13.4. docs/domain_model.md con Aggregates y Value Objects.
11.13.5. docs/events.md con catálogo de Domain Events.
11.13.6. docs/no_polling_policy.md explicando la decisión y alternativas descartadas.
11.13.7. README.md actualizado con instrucciones de setup.

═══════════════════════════════════════════════════════════
FASE 11.14 — AUDITORÍA Y CIERRE
═══════════════════════════════════════════════════════════

11.14.1. Verificar que domain/ no importa Flutter, ni Sheets, ni ORM.
11.14.2. Verificar que ningún contexto importa clases de otro contexto directamente.
11.14.3. Verificar que NO existe ningún Timer.periodic ni Stream.periodic.
11.14.4. Verificar que resumen_diario, cuarentena, audit_log, reporte_migracion y checklist_iso son SOLO LECTURA en el cliente.
11.14.5. Verificar que la columna validacion de la hoja sigue = "OK".
11.14.6. Verificar SHA-256 de la hoja (debe ser idéntico al de Fase 11.0).
11.14.7. Registrar en audit_log al menos 10 entradas nuevas con acciones DDD.
11.14.8. Actualizar reporte_migracion con sección "Fase 11 — DDD".

═══════════════════════════════════════════════════════════
REGLAS DE ORO DDD (NO NEGOCIABLES)
═══════════════════════════════════════════════════════════

1. El dominio NO depende de frameworks, ni de Google Sheets, ni de Flutter.
2. Los Value Objects son inmutables y auto-validados.
3. Los Aggregates protegen sus invariantes y son la única puerta de entrada a sus entidades internas.
4. Los Repositorios son contratos en el dominio; la implementación vive en infraestructura.
5. Los Domain Events se publican DESPUÉS de persistir.
6. Los Use Cases tienen UNA responsabilidad y orquestan, no contienen lógica de negocio.
7. NO polling. Actualización bajo demanda del usuario.
8. Cada Bounded Context tiene su propio lenguaje y no filtra tipos a otros.
9. Los nombres de código usan el término EN del Lenguaje Ubicuo; la UI usa ES.
10. SI ALGO NO ENCAJA EN DDD → simplificar, no forzar. DDD no es una meta, es una herramienta.

═══════════════════════════════════════════════════════════
ENTREGABLES FINALES
═══════════════════════════════════════════════════════════

E1. Estructura de carpetas completa (Fase 11.3) con archivos creados.
E2. Glosario de Lenguaje Ubicuo (ES ↔ EN) en docs/ubiquitous_language.md.
E3. Context Map con 4 Bounded Contexts en docs/context_map.md.
E4. 5 Aggregates implementados (Customer, Product, Sale, CompraDivisa + read models).
E5. Value Objects compartidos y por contexto (MoneyUsd, MoneyBs, ExchangeRate, IsoDate, IDs, enums).
E6. Domain Events catalogados y bus en memoria.
E7. Repositorios: contratos + implementaciones.
E8. Use Cases funcionales (CreateSale, RegisterPayment, RefreshData, etc.).
E9. UI Flutter con botón "Actualizar" (refresco manual).
E10. Tests: unitarios de dominio + use cases.
E11. Documentación completa en /docs.
E12. audit_log con 10+ entradas DDD.
E13. reporte_migracion actualizado con sección "Fase 11 — DDD".
E14. Declaración explícita: "Arquitectura DDD aplicada. NO se implementó polling."

Firma final: Arquitecto DDD Senior + timestamp ISO 8601 con zona horaria.
🎯 Cómo usar este prompt
Entorno Acción
Cursor / Copilot / Windsurf Pegar como instrucción de proyecto y ejecutar fase por fase
ChatGPT / Claude / Gemini Pedir que genere la estructura completa o por contexto
Auditoría externa Entregar como contrato de arquitectura
Onboarding de equipo Usar como guía de estilo y convenciones
