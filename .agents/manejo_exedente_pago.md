ROL
Eres un Diseñador de Producto Senior + Arquitecto DDD, trabajando en Flutter/Dart
bajo Material 3 + Apple HIG, ISO 8000 §5.3, ISO/IEC 27001, COBIT 2019 DSS05 y
OWASP MASVS. Ya existe el Design System "Estilo Neutral" con CupertinoIcons
exclusivos, paleta azul de 5 tonos (#005187, #4D82BC, #84B6F4, #C4DAFA, #FCFFFF),
tipografía Inter con tabular figures, y arquitectura DDD/Clean Architecture
con lotes atómicos (AtomicBatch). Cero polling.

═══════════════════════════════════════════════════════════════════════════════
NARRATIVA DE NEGOCIO (es la fuente de verdad — todo el diseño y la lógica
deben poder explicarse con estas 5 frases)
═══════════════════════════════════════════════════════════════════════════════

"Es como si Neyza te diera $280 en efectivo:

1.  Cobras los $180 de la primera factura → quedan $100 en tu mano.
2.  Esos $100 no son tuyos, son de Neyza (un saldo a favor).
3.  Neyza tiene otra factura pendiente de $100 → le dices:
    '¿quieres que use tus $100 a favor para pagar esta otra factura?'
4.  Acepta → usas los $100 para saldar la factura.
5.  Ahora Neyza no debe nada y tú no tienes dinero ajeno en la mano."

Eso es 'abonar el excedente a la deuda pendiente'. No es un cobro nuevo,
es reutilizar un pago ya hecho.

═══════════════════════════════════════════════════════════════════════════════
OBJETIVO
═══════════════════════════════════════════════════════════════════════════════

Implementar end-to-end (diseño visual + lógica de dominio + aplicación + UI)
la funcionalidad "Aplicar saldo a favor del cliente a una factura pendiente",
mapeando cada paso de la narrativa a un elemento concreto de la app.

La funcionalidad NO debe parecer un cobro. Debe sentirse como una
COMPENSACIÓN entre dos cosas que ya existen: un crédito del cliente y una
deuda del cliente.

───────────────────────────────────────────────────────────────────────────────
PARTE 1 — DISEÑO (UX / UI)
───────────────────────────────────────────────────────────────────────────────

1.1. PUNTOS DE ENTRADA
Debe haber dos formas de iniciar la operación:

A. Desde la tarjeta de la factura PENDIENTE (flujo principal, contexto claro): - Si el cliente tiene saldo a favor > 0, mostrar un botón secundario
dentro de la tarjeta:
[ CupertinoIcons.money_dollar_circle ]
"Aplicar saldo a favor ($$X.XX)" - El monto entre paréntesis = MIN(saldo_a_favor, deuda_de_esta_factura).

B. Desde el detalle del cliente (flujo global): - Chip verde: "Saldo a favor: $100.00" - Al tocar el chip → bottom sheet con:
· Lista de créditos DISPONIBLES (fecha + monto + factura origen)
· Lista de facturas PENDIENTES del cliente
· Sugerencia automática: "Aplicar $100.00 a la factura #v00000005"

1.2. BOTTOM SHEET DE CONFIRMACIÓN (el momento clave)
Cuando el usuario toca "Aplicar saldo a favor", se abre un bottom sheet
que narra visualmente las 5 frases de la narrativa:

┌─────────────────────────────────────────────────────┐
│ Aplicar saldo a favor ✕ │
├─────────────────────────────────────────────────────┤
│ │
│ 📌 Cliente: Neyza Chourio │
│ │
│ Saldo a favor disponible $100.00 │
│ Deuda de la factura #v00000005 $100.00 │
│ ─────────────────────────────────────── │
│ Se aplicará $100.00 │
│ Saldo restante después $0.00 │
│ Deuda restante después $0.00 │
│ │
│ ℹ️ No entra dinero nuevo. Se reutiliza el pago │
│ que ya hiciste en la factura #v00000002. │
│ │
│ [ Cancelar ] [ Confirmar aplicación ] │
└─────────────────────────────────────────────────────┘

Reglas del sheet:

- Cifras con tabularFigures alineadas a la derecha.
- Verde para saldo a favor, rojo para deuda, azul para el monto aplicado.
- Solo 3 tonos de azul por pantalla (regla del Design System).
- Iconografía 100% CupertinoIcons.
- Tap target de botones >= 48dp (WCAG 2.2 AA).
- Si saldo_a_favor > deuda, mostrar aviso: "Quedarán $X.XX disponibles
  para futuras facturas."

  1.3. ESTADOS DEL BOTÓN "Aplicar saldo a favor"
  idle → normal
  loading → CupertinoActivityIndicator + texto "Aplicando…"
  success → SnackBar verde "Saldo aplicado. Factura #vX marcada como Pagada."
  error → SnackBar rojo con botón "Reintentar"
  disabled → si saldo_a_favor <= 0 o no hay facturas pendientes
  (tooltip: "El cliente no tiene saldo a favor disponible.")

  1.4. FEEDBACK VISUAL POST-APLICACIÓN
  Después de aplicar:

- La tarjeta de la factura desaparece del filtro "Pendiente" y aparece
  en "Pagada" con un badge discreto "Pagada con saldo a favor".
- El chip verde del cliente baja el monto o desaparece si llega a 0.
- Micro-animación de 300ms con Curves.easeOutCubic al reordenar la lista.
- NO confeti, NO colores chillones: respetar el estilo minimalista.

  1.5. ACCESIBILIDAD

- Semantics label en cada cifra: "Saldo a favor: cien dólares con cero centavos".
- Contraste verificado WCAG 2.2 AA sobre #FCFFFF.
- Todo navegable por teclado / lector de pantalla.

───────────────────────────────────────────────────────────────────────────────
PARTE 2 — LÓGICA (DOMINIO + APLICACIÓN)
───────────────────────────────────────────────────────────────────────────────

2.1. MAPEO NARRATIVA → CÓDIGO
Cada frase de la narrativa debe tener su contraparte en el dominio:

Frase 1 "Cobras los $180 → quedan $100 en tu mano"
→ ClientCredit(monto: 100) generado al detectar sobrepago en abonos.
→ Usecase: RegisterClientCredit
→ Invariante: monto == SUM(abonos) - ventas.total_pagar_usd ± 0.01

Frase 2 "Esos $100 no son tuyos, son de Neyza"
→ El crédito pertenece al cliente, no a la organización.
→ Invariante: credit.clienteId == ventaOrigen.clienteId
→ El crédito NUNCA se mezcla con fondos de la empresa.

Frase 3 "¿Quieres que use tus $100 a favor para pagar esta otra factura?"
→ Caso de uso: PreviewApplyCredit
· Entrada: clienteId, ventaDestinoId
· Salida: ApplyCreditPreview {
montoAplicable, saldoRestante, deudaRestante,
creditosConsumidos[], advertencias[]
}
→ Este preview se muestra en el bottom sheet (nada se persiste aún).

Frase 4 "Acepta → usas los $100 para saldar la factura"
→ Caso de uso: ApplyClientCredit (transaccional, ver 2.4)
→ Cambia el estado del crédito a APLICADO y crea un abono con
metodo_pago = mp00000009 ("Saldo a Favor").

Frase 5 "Ahora Neyza no debe nada y tú no tienes dinero ajeno"
→ Invariantes post-condición:
· credit.estado == APLICADO
· venta.abonoUsd == venta.totalPagarUsd
· venta.deudaUsd == 0
· venta.estado == 'Pagada'
· SUM(creditos DISPONIBLES del cliente) refleja el remanente real.

2.2. MODELO DE DOMINIO
Entidad ClientCredit (inmutable):

- id: CreditId (VO, regex ^cr\d{8}$)
- clienteId: ClienteId
- fecha: DateTime (ISO 8601 con zona -04:00)
- montoUsd: CreditAmount (VO, > 0)
- origenVentaId: VentaId
- estado: CreditStatus { DISPONIBLE, APLICADO, ANULADO }
- aplicadoAVentaId: VentaId?
- fechaAplicacion: DateTime?
- organizacionId: String
- hashEvidencia: String (SHA-256, NIST SP 800-53)

Value Objects:

- CreditId: valida regex, inmutable.
- CreditAmount: rechaza <= 0, redondea a 2 decimales.
- ApplyCreditResult: montoAplicado, saldoRestante, deudaRestante.

Servicio de dominio puro (sin dependencias externas):
CreditApplier.compute(
credits: List<ClientCredit>, // solo DISPONIBLES, orden FIFO
venta: Venta,
) → ApplyCreditPlan
Reglas:
· montoAplicable = MIN( SUM(credits), venta.deudaUsd )
· Consume créditos FIFO por fecha ascendente.
· Si un crédito cubre más que lo necesario, se divide: - fila APLICADO con el monto consumido - fila DISPONIBLE con el remanente (mismo id + sufijo o nuevo id)
· Nunca produce montoAplicable <= 0.

2.3. CONTRATO DEL REPOSITORIO (interfaz pura)
abstract class ClientCreditRepository {
Future<List<ClientCredit>> findDisponiblesByCliente(String clienteId);
Future<ClientCredit> findById(String id);
Future<void> create(ClientCredit credit);
Future<void> markApplied(String creditId, String ventaDestinoId,
double montoConsumido, DateTime fecha);
Future<void> annul(String creditId, String motivo);
}

abstract class ApplyClientCreditUseCase {
Future<Result<ApplyCreditResult, AtomicException>> call({
required String clienteId,
required String ventaDestinoId,
});
}

2.4. OPERACIÓN ATÓMICA (todo o nada)
ApplyClientCredit debe ejecutarse como AtomicBatch con 4 operaciones.
Si CUALQUIERA falla, se revierte TODO en orden inverso.

AtomicBatch(
id: IdGenerator.next('batch'),
name: 'Aplicar saldo a favor a venta $ventaDestinoId',
stopOnFirstError: true,
autoRollback: true,
operations: [

      // Paso 1 — crear abono con Saldo a Favor
      AtomicOperation(
        id: 'op_abono_saldo_favor',
        description: 'Registrar abono con metodo_pago = Saldo a Favor',
        execute: () => abonosRepo.create(Abono(
          id: IdGenerator.next('ab'),
          ventaId: ventaDestinoId,
          fecha: DateTime.now(),
          monto: montoAplicar,
          metodoPago: 'mp00000009',
          tasaId: tasaActual.id,
          usuarioEmail: currentUser.email,
        )),
        rollback: () => abonosRepo.delete(abonoId),
      ),

      // Paso 2 — consumir créditos (FIFO, puede ser N créditos)
      AtomicOperation(
        id: 'op_consumir_creditos',
        description: 'Marcar créditos como APLICADO / dividir remanente',
        execute: () async {
          for (final c in plan.consumos) {
            await creditosRepo.markApplied(
              c.creditId, ventaDestinoId, c.montoConsumido, DateTime.now());
            if (c.remanente > 0) {
              await creditosRepo.create(c.creditoRemanente);
            }
          }
        },
        rollback: () async {
          for (final c in plan.consumos.reversed) {
            if (c.remanente > 0) {
              await creditosRepo.delete(c.creditoRemanente.id);
            }
            await creditosRepo.revertirAplicacion(c.creditId);
          }
        },
      ),

      // Paso 3 — refrescar la venta (fórmulas dinámicas)
      AtomicOperation(
        id: 'op_refresh_venta',
        description: 'Recalcular abono_usd, deuda_usd y estado',
        execute: () => ventasRepo.refresh(ventaDestinoId),
        rollback: () => ventasRepo.refresh(ventaDestinoId), // idempotente
      ),

      // Paso 4 — auditoría forense (append-only, sin rollback)
      AtomicOperation(
        id: 'op_audit_log',
        description: 'Registrar aplicación en bitácora ISO',
        execute: () => auditRepo.log(AuditEntry(
          timestampIso8601: DateTime.now().toIso8601String(),
          usuario: currentUser.email,
          hoja: 'creditos_clientes',
          celda: plan.consumos.map((c) => c.creditId).join(','),
          valorAnterior: 'DISPONIBLE',
          valorNuevo: 'APLICADO',
          accion: 'aplicacion_credito_cliente',
          normaAplicada: 'ISO 8000 §5.3 / COBIT 2019 DSS05',
          observaciones:
            'Saldo a favor aplicado a $ventaDestinoId por \$${montoAplicar}. '
            'Origen: ${plan.origenes.join(",")}. Cliente: $clienteId.',
          organizacionId: organizacionId,
        )),
      ),
    ],

)

2.5. REGLAS DE NEGOCIO (invariantes duras)
R1. Solo se aplica a facturas del MISMO cliente.
R2. montoAplicable = MIN(saldoDisponible, deudaFactura).
R3. Nunca se crea deuda nueva ni se toca otra factura.
R4. Nunca se borra un crédito; solo cambia de estado (DISPONIBLE→APLICADO/ANULADO).
R5. Si saldo > deuda, el remanente queda DISPONIBLE en un crédito nuevo.
R6. metodo_pago DEBE ser mp00000009 ("Saldo a Favor"). Nunca un método real.
R7. Cada aplicación deja exactamente 1 fila en audit_log con hash SHA-256.
R8. Consistencia matemática verificable:
ABS( montoAplicar - MIN(saldo,deuda) ) < 0.01
Si no se cumple → cuarentena con motivo 'aplicacion_inconsistente'.
R9. Cero polling. Toda operación es pull manual del usuario.
R10. Multi-org: filtrar SIEMPRE por organizacion_id.

───────────────────────────────────────────────────────────────────────────────
PARTE 3 — ESTRUCTURA DE ARCHIVOS (< 500 líneas cada uno)
───────────────────────────────────────────────────────────────────────────────

lib/features/credits/
├── domain/
│ ├── entities/
│ │ ├── client_credit.dart (< 140 líneas)
│ │ └── credit_status.dart (< 30 líneas)
│ ├── value_objects/
│ │ ├── credit_id.dart (< 40 líneas)
│ │ ├── credit_amount.dart (< 50 líneas)
│ │ └── apply_credit_plan.dart (< 90 líneas)
│ ├── services/
│ │ └── credit_applier.dart (< 120 líneas, PURO)
│ └── repositories/
│ └── client_credit_repository.dart (< 40 líneas, interfaz)
├── application/
│ └── usecases/
│ ├── preview_apply_credit.dart (< 80 líneas)
│ ├── apply_client_credit.dart (< 150 líneas)
│ └── register_client_credit.dart (< 100 líneas)
├── infrastructure/
│ ├── models/
│ │ └── client_credit_model.dart (< 100 líneas)
│ ├── mappers/
│ │ └── credit_mapper.dart (< 80 líneas)
│ └── datasources/
│ └── sheets_credits_datasource.dart (< 180 líneas)
└── presentation/
├── controllers/
│ └── apply_credit_controller.dart (< 120 líneas)
├── pages/
│ └── apply_credit_sheet.dart (< 200 líneas)
└── widgets/
├── apply_credit_button.dart (< 90 líneas)
├── credit_summary_row.dart (< 60 líneas)
└── credit_chip.dart (< 60 líneas)

Reglas:

- Una clase pública por archivo.
- domain/ NO importa Flutter ni infraestructura.
- Serialización bidireccional (fromSheet / toSheet) en infrastructure.
- Si un archivo se acerca a 400 líneas, dividir.

───────────────────────────────────────────────────────────────────────────────
PARTE 4 — TESTS (mínimo 14, cobertura ≥ 90%)
───────────────────────────────────────────────────────────────────────────────

Dominio puro:
T01. CreditAmount rechaza 0 y negativos.
T02. CreditId valida regex y es inmutable.
T03. ClientCredit no puede estar APLICADO sin aplicadoAVentaId.
T04. CreditApplier: saldo > deuda → aplica deuda completa.
T05. CreditApplier: saldo < deuda → aplica saldo completo.
T06. CreditApplier: saldo == deuda → ambos a cero.
T07. CreditApplier: múltiples créditos → FIFO por fecha.
T08. CreditApplier: remanente genera crédito DISPONIBLE nuevo.

Aplicación:
T09. PreviewApplyCredit devuelve montos correctos sin persistir.
T10. ApplyClientCredit éxito total → 4 filas escritas.
T11. ApplyClientCredit falla en op_abono → rollback total (0 cambios).
T12. ApplyClientCredit falla en op_consumir → rollback del abono.
T13. ApplyClientCredit falla en op_audit → rollback de op_consumir y op_abono.

UI:
T14. ApplyCreditButton deshabilitado si saldo <= 0.
T15. ApplyCreditSheet muestra 4 cifras con tabularFigures.
T16. Semantics label correcto en cada cifra.

Ejecutar: flutter test → 100% verde.
Ejecutar: dart analyze → 0 warnings, 0 errors.

───────────────────────────────────────────────────────────────────────────────
PARTE 5 — CRITERIOS DE ACEPTACIÓN
───────────────────────────────────────────────────────────────────────────────

[ ] Cada frase de la narrativa mapeada a un elemento del dominio o UI.
[ ] Bottom sheet de confirmación con 4 cifras (saldo, deuda, aplicar, restante).
[ ] Aviso explícito "No entra dinero nuevo" en el sheet.
[ ] metodo_pago = mp00000009 en TODOS los abonos generados.
[ ] Crédito cambia a APLICADO (nunca se borra).
[ ] Remanente genera crédito DISPONIBLE nuevo (si aplica).
[ ] Operación ejecutada como AtomicBatch con 4 operaciones y rollback probado.
[ ] audit_log con 1 fila por aplicación, hash SHA-256 incluido.
[ ] Cero polling verificable (grep Timer.periodic = 0).
[ ] Semantics + contraste WCAG 2.2 AA en el sheet.
[ ] CupertinoIcons exclusivos (0 Material Icons en UI de créditos).
[ ] Cada archivo Dart < 500 líneas.
[ ] 14+ tests pasando, dart analyze limpio.
[ ] Caso Neyza Chourio funcionando end-to-end en la app.
[ ] Reporte final: archivos, líneas máximas, tests, hallazgos analyzer.

───────────────────────────────────────────────────────────────────────────────
PARTE 6 — RESTRICCIONES FINALES
───────────────────────────────────────────────────────────────────────────────

- NO implementar polling.
- NO duplicar ingresos: el saldo a favor NUNCA es un cobro nuevo.
- NO usar VLOOKUP; usar INDEX/MATCH o SUMIFS.
- NO hardcodear tasas; siempre referenciar hoja `tasas`.
- NO exceder 500 líneas por archivo.
- NO eliminar créditos; solo cambiar estado.
- SÍ mantener nomenclatura snake_case en Sheets y camelCase en Dart.
- SÍ timestamps ISO 8601 con zona -04:00.
- SÍ registrar cada fase firmada con "Antigravity Senior Agent" en audit_log.

ENTREGABLE
Commit único con:

1. Modelo de dominio, repositorios, usecases y datasource.
2. UI completa (botón, bottom sheet, chips, animaciones).
3. Suite de tests verde + dart analyze limpio.
4. Migración del caso Neyza (crédito retroactivo DISPONIBLE).
5. Actualización de audit_log, checklist_iso y reporte_migracion.
6. Reporte final con narrativa → código → UI mapeado 1:1.
   Notas de uso
   Ajuste Cuándo aplicarlo
   Cambiar mp00000009 Si tu método "Saldo a Favor" tiene otro ID
   Reducir a 10 tests Si hay prisa; nunca bajar de 8
   Omitir micro-animación Si el Design System no la contempla aún
   Añadir moneda Si el saldo puede ser en Bs o EUR
   Multi-org dinámico Reemplazar organizacionId hardcodeado por variable de sesión
