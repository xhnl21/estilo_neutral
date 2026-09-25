ROL
Eres un Arquitecto de Datos y Desarrollador Senior Flutter/Dart especializado en
sistemas contables auditables bajo ISO 8000, ISO 8601, ISO/IEC 27001, COBIT 2019,
GDPR Art. 5 y NIST SP 800-53.

CONTEXTO
Trabajo sobre un libro Google Sheets llamado "Estilo Neutral" con organizacion_id
67774411-6aa1-4aa3-a4b2-d3fc6913b768. Actualmente las hojas son:
seguridad, clientes, inventario, ventas, compras_divisas, resumen_diario,
cuarentena, audit_log, reporte_migracion, checklist_iso, usuarios,
organizaciones, usuario_organizacion, venta_items, "metodo pago", abonos,
tasas, moneda_organizacion, galeria.

Problema actual: la fórmula de deuda en ventas!K es MAX(0, L - J), lo que
descarta silenciosamente cualquier sobrepago. El caso conocido es el cliente
c00000002 (Neyza Chourio) con excedente de $100.00 que no está registrado en
ninguna entidad.

OBJETIVO
Implementar la Opción B: una hoja `creditos_clientes` que registre de forma
explícita cada sobrepago como un crédito consumible, aplicable a facturas
pendientes del mismo cliente. Cada aplicación debe dejar rastro forense
completo en `audit_log`, manteniendo la compatibilidad con la arquitectura
DDD/Clean Architecture y el patrón de lotes atómicos ya existente.

────────────────────────────────────────────────────────

1. ESQUEMA DE LA HOJA `creditos_clientes`
   ────────────────────────────────────────────────────────

Encabezados en snake_case (fila 1), sin tildes ni espacios:

| Col | Nombre          | Tipo      | Regla / Formato                                |
| --- | --------------- | --------- | ---------------------------------------------- | -------- | ------------------------ |
| A   | id              | string    | ^cr\d{8}$ (ej: cr00000001), único, no editable |
| B   | cliente_id      | string FK | ^c\d{8}$ → valida contra clientes!A:A          |
| C   | fecha           | ISO 8601  | YYYY-MM-DDTHH:mm:ss (con zona -04:00)          |
| D   | monto_usd       | number    | #,##0.00, siempre > 0                          |
| E   | origen_venta_id | string FK | ^v\d{8}$ → valida contra ventas!A:A            |
| F   | estado          | enum      | DISPONIBLE                                     | APLICADO | ANULADO (DataValidation) |
| G   | organizacion_id | string FK | 67774411-6aa1-4aa3-a4b2-d3fc6913b768           |

Columnas adicionales de trazabilidad (opcionales pero recomendadas):

| Col | Nombre              | Tipo     | Descripción                                  |
| --- | ------------------- | -------- | -------------------------------------------- |
| H   | aplicado_a_venta_id | string   | FK a ventas!A:A, solo si estado=APLICADO     |
| I   | fecha_aplicacion    | ISO 8601 | Timestamp de consumo del crédito             |
| J   | saldo_usd           | number   | =SI(F="DISPONIBLE", D, 0) — saldo consumible |
| K   | usuario_email       | string   | Quién registró/aplicó el crédito             |
| L   | hash_evidencia      | string   | SHA-256 del payload JSON del crédito         |

Protecciones:

- Proteger columnas A, C, E, G, L (inmutables).
- Permitir edición solo a propietarios en B, D, F, H, I, K.
- Activar notificaciones por correo en cambios de F (estado).

──────────────────────────────────────────────────────── 2. REGLAS DE NEGOCIO
────────────────────────────────────────────────────────

R1. Generación de crédito
Cuando en `abonos` se registra un pago tal que:
SUM(abonos.monto WHERE venta_id = X) > ventas.total_pagar_usd de X
→ el excedente = SUM(abonos) - total_pagar_usd se registra como UNA fila
en `creditos_clientes` con: - cliente_id = ventas.cliente_id de X - monto_usd = excedente calculado - origen_venta_id = X - estado = DISPONIBLE

R2. Aplicación de crédito
Dado un cliente con créditos DISPONIBLES y una venta PENDIENTE del mismo
cliente, el monto aplicable es:
monto_aplicar = MIN( SUM(creditos.DISPONIBLE), ventas.deuda_usd )

R3. Consumo del crédito
Al aplicar:

- Se crea un registro en `abonos` con metodo_pago = mp00000009
  ("Saldo a Favor"), venta_id = factura destino, monto = monto_aplicar.
- El crédito pasa a estado = APLICADO, con aplicado_a_venta_id y
  fecha_aplicacion completados.
- Si un crédito cubre parcialmente, se permite dividir en dos filas:
  una APLICADO (monto consumido) y una DISPONIBLE (remanente).
- ventas.abono_usd se recalcula dinámicamente (ver R5).

R4. Anulación
Un crédito solo puede pasar a ANULADO si estado=DISPONIBLE, con fila
obligatoria en audit_log justificando el motivo. Nunca se borra.

R5. Fórmulas dinámicas en hojas existentes
ventas!J (abono_usd):
=IFERROR(SUMIF(abonos!B:B, A2, abonos!D:D), 0)

ventas!K (deuda_usd):
=L2 - J2 (permite valores negativos = excedente)

clientes — columnas auxiliares:
deuda_pendiente = SUMIFS(ventas!K:K, ventas!C:C, A2, ventas!K:K, ">0")
excedente = -SUMIFS(ventas!K:K, ventas!C:C, A2, ventas!K:K, "<0")
saldo_neto = deuda_pendiente - excedente

R6. Consistencia matemática obligatoria
Para cada fila de `creditos_clientes`:
ABS( monto_usd - ( SUM(abonos de origen_venta) - ventas.total_pagar ) ) < 0.01
De lo contrario, mover a `cuarentena` con motivo "credito_inconsistente".

R7. Cero polling
No se permite Timer.periodic, Stream.periodic ni triggers temporales.
La generación/aplicación de créditos ocurre 100% bajo demanda del usuario.

──────────────────────────────────────────────────────── 3. OPERACIÓN ATÓMICA (Flutter/Dart)
────────────────────────────────────────────────────────

Implementar el siguiente AtomicBatch en lib/core/atomic/ usando la
arquitectura ya existente. Cada archivo debe tener < 500 líneas.

Usecase: ApplyClientCredit

    AtomicBatch(
      id: IdGenerator.next('batch'),
      name: 'Aplicar crédito $montoAplicar a venta $ventaId',
      stopOnFirstError: true,
      autoRollback: true,
      operations: [

        // Op 1: crear abono Saldo a Favor
        AtomicOperation(
          id: 'op_crear_abono',
          description: 'Registrar abono con método Saldo a Favor',
          execute: () async {
            final id = IdGenerator.next('ab');
            await abonosRepo.create(Abono(
              id: id,
              ventaId: ventaId,
              fecha: DateTime.now(),
              monto: montoAplicar,
              metodoPago: 'mp00000009',
              tasaId: tasaActual.id,
            ));
            return id;
          },
          rollback: () => abonosRepo.delete(_abonoIdCreado),
        ),

        // Op 2: consumir el crédito
        AtomicOperation(
          id: 'op_consumir_credito',
          description: 'Marcar crédito como APLICADO',
          execute: () => creditosRepo.aplicar(
            creditoId: creditoId,
            ventaDestinoId: ventaId,
            monto: montoAplicar,
          ),
          rollback: () => creditosRepo.revertirAplicacion(creditoId),
        ),

        // Op 3: recalcular venta destino
        AtomicOperation(
          id: 'op_actualizar_venta',
          description: 'Refrescar abono_usd y estado de la venta',
          execute: () => ventasRepo.refresh(ventaId),
          rollback: () => ventasRepo.refresh(ventaId), // idempotente
        ),

        // Op 4: auditoría forense
        AtomicOperation(
          id: 'op_audit_log',
          description: 'Registrar en bitácora',
          execute: () => auditRepo.log(AuditEntry(
            timestampIso8601: DateTime.now().toIso8601String(),
            usuario: currentUser.email,
            hoja: 'creditos_clientes',
            celda: creditoId,
            valorAnterior: 'DISPONIBLE',
            valorNuevo: 'APLICADO',
            accion: 'aplicacion_credito_cliente',
            normaAplicada: 'ISO 8000 §5.3 / COBIT 2019 DSS05',
            observaciones:
              'Crédito $creditoId aplicado a venta $ventaId por \$$montoAplicar',
            organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
          )),
          // audit_log es append-only, sin rollback
        ),
      ],
    )

──────────────────────────────────────────────────────── 4. ESTRUCTURA DDD (respetar límites de archivo)
────────────────────────────────────────────────────────

lib/
├── core/
│ └── atomic/ (ya existente, reutilizar)
├── features/
│ └── credits/
│ ├── domain/
│ │ ├── entities/
│ │ │ ├── client_credit.dart (< 120 líneas)
│ │ │ └── credit_status.dart (enum, < 30 líneas)
│ │ ├── value_objects/
│ │ │ ├── credit_id.dart (< 40 líneas)
│ │ │ └── credit_amount.dart (< 50 líneas)
│ │ ├── services/
│ │ │ └── credit_applier.dart (< 100 líneas, puro)
│ │ └── repositories/
│ │ └── client_credit_repository.dart (< 40 líneas, interfaz)
│ ├── application/
│ │ └── usecases/
│ │ ├── apply_client_credit.dart (< 120 líneas)
│ │ ├── register_client_credit.dart (< 100 líneas)
│ │ └── get_available_credits.dart (< 60 líneas)
│ ├── infrastructure/
│ │ ├── models/
│ │ │ └── client_credit_model.dart (< 90 líneas)
│ │ └── datasources/
│ │ └── sheets_credits_datasource.dart (< 150 líneas)
│ └── presentation/
│ ├── controllers/
│ │ └── credits_controller.dart (< 100 líneas)
│ └── widgets/
│ ├── apply_credit_button.dart (< 80 líneas)
│ └── credit_chip.dart (< 60 líneas)

Reglas estrictas:

- Cada archivo < 500 líneas (objetivo: < 200).
- Una clase pública por archivo.
- Domain NO importa package:flutter/material.dart ni infraestructura.
- Repositorios del dominio = interfaces puras.
- Modelos de infraestructura con serialización bidireccional
  (fromSheet / toSheet).
- Value Objects inmutables con validación en constructor.

──────────────────────────────────────────────────────── 5. UI FLUTTER
────────────────────────────────────────────────────────

En la tarjeta de factura pendiente (widget InvoiceCard) agregar:

    if (cliente.tieneCreditosDisponibles && venta.deudaUsd > 0)
      ApplyCreditButton(
        montoAplicable: min(
          cliente.totalCreditosDisponibles,
          venta.deudaUsd,
        ),
        onPressed: () => controller.applyCredit(
          clienteId: cliente.id,
          ventaId: venta.id,
        ),
      )

Comportamiento del botón:

- Label dinámico: "Aplicar saldo a favor (\$X.XX)".
- Deshabilitado si montoAplicable <= 0 o si hay batch en curso.
- Estados: idle → loading (spinner) → success (SnackBar) → error (SnackBar + retry).
- Iconografía exclusiva CupertinoIcons (Apple HIG), sin Material Icons.
- Tamaño táctil >= 48dp (WCAG 2.2 AA).

En la pantalla de clientes, mostrar chips:

- Chip verde: "Saldo a favor: \$X.XX" si excedente > 0
- Chip rojo: "Deuda: \$X.XX" si deuda > 0

──────────────────────────────────────────────────────── 6. AUDITORÍA Y TRAZABILIDAD (obligatorio)
────────────────────────────────────────────────────────

Cada operación sobre créditos DEBE generar:

1. Fila en `creditos_clientes` (creación, aplicación, anulación).
2. Fila en `abonos` (solo al aplicar, con mp00000009).
3. Fila en `audit_log` con:
   - timestamp_iso8601
   - usuario (email del operador)
   - hoja = 'creditos_clientes'
   - accion ∈ {creacion_credito, aplicacion_credito_cliente,
     anulacion_credito, division_credito}
   - norma_aplicada = 'ISO 8000 §5.3 / COBIT 2019 DSS05'
   - observaciones legibles
   - organizacion_id
4. Hash SHA-256 del payload en `hash_evidencia` (NIST SP 800-53).

Actualizar `checklist_iso` con un nuevo control:
| 21.0 | Créditos de cliente trazables end-to-end | ISO 8000 §5.3 / COBIT DSS05 | ☑ | Hoja creditos_clientes + audit_log |

──────────────────────────────────────────────────────── 7. MIGRACIÓN DEL CASO EXISTENTE (Neyza Chourio)
────────────────────────────────────────────────────────

Script de una sola ejecución que:

1. Detecta sobrepagos históricos:
   Para cada cliente, calcular:
   excedente = SUM(abonos.monto) - SUM(ventas.total_pagar)
   Si excedente > 0.009 → crear crédito retroactivo DISPONIBLE con:
   - fecha = timestamp de la venta de origen
   - origen_venta_id = venta que generó el sobrepago
   - usuario_email = 'migracion_automatica'
   - audit_log con accion = 'creacion_credito_retroactivo'

2. Para el caso c00000002 (Neyza):
   - Verificar que excedente calculado ≈ 100.00
   - Si coincide, no aplicar aún; dejar DISPONIBLE y notificar al usuario.
   - Si difiere en > 0.01, mover a `cuarentena` con motivo
     'excedente_inconsistente_pre_migracion'.

3. Registrar SHA-256 pre-migración en `reporte_migracion`.

──────────────────────────────────────────────────────── 8. TESTS UNITARIOS (mínimo 12, cobertura ≥ 90%)
────────────────────────────────────────────────────────

- CreditId: validación regex, inmutabilidad.
- CreditAmount: rechazo de negativos y cero.
- ClientCredit: invariantes de estado (no APLICADO sin destino).
- CreditApplier (dominio puro):
  · excedente > deuda → aplica deuda completa
  · excedente < deuda → aplica excedente completo
  · excedente = deuda → ambos a cero
  · múltiples créditos DISPONIBLES → FIFO por fecha
- ApplyClientCredit (usecase): éxito y rollback completo.
- RegisterClientCredit: detección correcta de excedente.
- Widget test de ApplyCreditButton: estados y tap target.

Ejecutar: flutter test → 100% verde.
Ejecutar: dart analyze → 0 warnings, 0 errors.

──────────────────────────────────────────────────────── 9. CRITERIOS DE ACEPTACIÓN
────────────────────────────────────────────────────────

[ ] Hoja `creditos_clientes` creada con 7 columnas mínimas + protección.
[ ] Columnas validadas con DataValidation (estado, FKs).
[ ] Fórmula ventas!K = L - J (sin MAX).
[ ] clientes con columnas deuda_pendiente / excedente / saldo_neto.
[ ] Usecase ApplyClientCredit implementado como AtomicBatch con 4 ops.
[ ] Rollback probado: si falla op_audit_log, op_abono se revierte.
[ ] Cero polling verificable (grep de Timer.periodic = 0 resultados).
[ ] Widget ApplyCreditButton con estados y accesibilidad WCAG 2.2 AA.
[ ] Cada archivo Dart < 500 líneas (verificar con
find lib -name '\*.dart' | xargs wc -l).
[ ] 12+ tests pasando, dart analyze limpio.
[ ] Caso Neyza Chourio migrado y verificable en la UI.
[ ] audit_log con >= 3 entradas nuevas por operación de crédito.
[ ] checklist_iso actualizado con control 21.0.
[ ] reporte_migracion con SHA-256 pre y post.

──────────────────────────────────────────────────────── 10. RESTRICCIONES FINALES
────────────────────────────────────────────────────────

- NO implementar polling. Toda actualización es pull manual.
- NO romper la inmutabilidad de las hojas protegidas existentes
  (resumen_diario, audit_log, cuarentena, reporte_migracion, checklist_iso).
- NO eliminar filas de créditos: solo cambiar estado a ANULADO.
- NO usar VLOOKUP; usar INDEX/MATCH o SUMIFS.
- NO hardcodear tasas; siempre referenciar hoja `tasas`.
- NO exceder 500 líneas por archivo.
- SÍ mantener nomenclatura snake_case en Sheets y camelCase en Dart.
- SÍ registrar timestamp en ISO 8601 con zona horaria -04:00.
- SÍ firmar cada fase con entrada en audit_log usando
  "Antigravity Senior Agent" como usuario.

ENTREGABLE
Commit único con:

1. Hoja nueva + migración ejecutada.
2. Código Dart completo bajo lib/features/credits/.
3. Suite de tests.
4. Actualización de audit_log, checklist_iso y reporte_migracion.
5. Reporte final: nº de archivos, líneas máximas por archivo,
   tests pasados, hallazgos de dart analyze.
