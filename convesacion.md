###conversacion con deepseek IA

pregunta: analiza este documento /Users/programacion/Documents/sheets/estilo_neutral/Estilo Neutral.xlsx, como un profesional senior en Base de Datos de nivel paranoico, sanginario apegado profundamente a las normas internacionales relacionado a la base de datos.

respuesta:

1. Hallazgos críticos P0 — Rompen la base de datos
   1.1 Primary Keys duplicadas
   clientes.id = c00000002 aparece 2 veces con saldo_deuda_usd distinto (20.0 y 0.0) y fecha_registro distinta. Eso viola PK y hace que cualquier FK a clientes sea ambigua.

galeria.id = g00000002 aparece 2 veces y g00000003 aparece 2 veces, con URLs diferentes. El VLOOKUP de inventario.foto devolverá la primera coincidencia, no la correcta. Las fotos de productos pueden estar mal asignadas.

1.2 Multi-tenant roto
inventario.organizacion_id está vacío en p00000004, p00000005, p00000006, p00000007, p00000008.

tasas.organizacion_id está vacío en todas las filas.

audit_log.organizacion_id está vacío en muchísimos eventos de la App Móvil.

seguridad no tiene organizacion_id ni usuario_id; usa email como identificador.

Esto permite fuga de datos entre organizaciones y rompe aislamiento, RBAC y auditoría.

1.3 Integridad referencial inexistente
No hay FKs declaradas. Ejemplos de relaciones que deberían existir y no se validan:

ventas.cliente_id → clientes.id (y c00000002 está duplicado).

venta_items.venta_id → ventas.id.

venta_items.item_id → inventario.id.

abonos.venta_id → ventas.id.

abonos.metodo_pago → metodo pago.id.

abonos.tasa_id → tasas.id.

inventario.foto_id → galeria.id (y galeria.id está duplicado).

seguridad.usuario_email → usuarios.email.

usuario_organizacion.usuario_email → usuarios.email.

1.4 Stock negativo / imposible
p00000001 tiene cantidad = 2, pero en venta_items se vendieron:
v00000001: 1, v00000002: 9, v00000003: 10, v00000004: 1 → 21 unidades.

p00000003 tiene cantidad = 0, pero se vendieron 20 + 1 = 21 unidades.

p00000004 tiene cantidad = 0, pero se vendieron 5 unidades.

No hay CHECK (cantidad >= 0) ni trigger de stock. Esto es corrupción contable.

1.5 Saldos de clientes inconsistentes
clientes.c00000002 tiene dos filas: una con saldo_deuda_usd = 20.0 y otra con 0.0.

Pero ventas.v00000002 referencia c00000002, y su monto_usd calculado por SUMIF(venta_items) es 180.0 (9 × 20), con abono_usd = 0.0.

La deuda real debería ser 180.0, no 20.0 ni 0.0. El dato almacenado es basura.

1.6 Tasas incorrectas y mezcladas
ventas.v00000002 y v00000003 son de 2026-09-22 y usan tasa_bcv = 474.0. Pero tasas dice que para 2026-09-22 USD BCV es 852.4168.

ventas.v00000004 usa tasa_bcv = 976.5483 y tasa_usd = 976.5483. En tasas, t00000002 es EUR 976.54829408. Está usando tasa EUR como si fuera USD/BCV.

abonos.ab00000002 y ab00000003 usan tasa_id = t00000002, que es EUR. Pero las ventas asociadas parecen USD. Mezcla de monedas sin control.

ventas.v00000001, v00000002, v00000003 usan tasa_usd = 30.0, pero no existe ninguna tasa USD=30 en tasas. ¿De dónde sale? Sin FK ni evidencia.

1.7 Abono mayor que total pagar
ventas.v00000004: total_pagar_usd = 100.0, pero abono_usd = 300.0.
El sistema calcula deuda = MAX(0, 100 - 300) = 0, pero ignora 200 USD de sobrepago. No hay saldo a favor, devolución ni validación abono_usd <= total_pagar_usd.

1.8 Galería duplicada y VLOOKUP frágil
inventario.foto usa =IFERROR(IMAGE(VLOOKUP(H2,galeria!A:B,2,FALSE)),"").

Con g00000002 y g00000003 duplicados, el VLOOKUP devuelve la primera coincidencia, no la última.
p00000001 apunta a g00000002, pero hay dos g00000002. La foto mostrada puede ser incorrecta.

Además, p00000007 y p00000008 no tienen foto_id ni foto. Inventario multimedia inconsistente.

1.9 Duplicidad de productos
p00000004, p00000005, p00000006, p00000007, p00000008 son todos:
Gorra Deportiva | MarcaX | Pro | U | 12.0.

No hay UNIQUE (nombre, marca, modelo, talla, organizacion_id). Son SKUs duplicados. Eso destruye inventario y ventas.

1.10 Columna fantasma en ventas
La cabecera ventas termina en O = organizacion_id y P está vacía.

Pero v00000001 tiene P2 = "Pendiente".
Hay una columna sin nombre con datos. Eso viola ISO 8000 §4.1 y es un riesgo de migración.

2. Violaciones a normas internacionales
   Norma Violación concreta
   ISO 8000 Encabezados con espacio (metodo pago), columna vacía (ventas!P1), IDs fuera de patrón, duplicados, datos inconsistentes.
   ISO 8601 Fechas mezcladas: 2026-09-22 00:00:00, 2026-09-23T16:18:44.868993 sin zona, 2026-09-25 00:00:00, 2026-09-24T09:34:47.761799 sin zona, Z y -04:00 mezclados en audit_log.
   3FN clientes.saldo_deuda_usd es derivado y se almacena mal. resumen_diario materializa agregados. inventario.foto es derivado.
   ACID No hay transacciones, constraints, triggers, bloqueos, aislamiento. Google Sheets no ofrece ACID real.
   ISO/IEC 27001 Multi-tenant roto, auditoría con organizacion_id vacío, permisos no verificables, PII expuesta.
   GDPR usuarios y seguridad tienen emails reales (neidapulgar1989@gmail.com, xhnl21@gmail.com). clientes tiene teléfono 4120374325.0 no E.164. No hay minimización ni tokenización.
   NIST SP 800-53 audit_log no es inmutable ni completo; hay eventos duplicados, ruidosos y sin tenant.
   COBIT 2019 El reporte_migracion declara controles aprobados que la evidencia contradice.
3. Contradicciones documentales graves
   reporte_migracion dice “8 hojas refactorizadas”. Hay 19 hojas en el archivo.

Dice “0 celdas vacías en encabezados”. ventas!P1 está vacío.

Dice “100% columnas en snake_case”. Existe metodo pago con espacio.

Dice “100% IDs regex ^[a-z]\d{8}$”. Pero vi00000001, ab00000001, mp00000001, mo00000001 tienen dos letras.

Dice “0 fórmulas rotas”. Las fórmulas están sin evaluar en el volcado, pero además hay lógica rota: MAX(0,L-J) ignora sobrepagos.

Dice “Riesgos Residuales: Ninguno”. Falso. Hay riesgos P0 por todos lados.

checklist_iso control #1 está en ☐ (no cumplido), pero el reporte dice backup verificado. Contradicción directa.

4. Problemas por hoja
   Hoja Problemas principales
   seguridad Sin PK, sin organizacion_id, usa email como FK. No hay usuario_id.
   clientes PK duplicada c00000002. Saldo deuda inconsistente. Teléfono no E.164. Email vacío en una fila.
   inventario Stock insuficiente/negativo. organizacion_id vacío en 5 filas. Productos duplicados. foto_id roto por galería duplicada.
   ventas Columna fantasma P. Tasas mal calculadas. Abono > total. cliente_id ambiguo. Fechas no ISO.
   compras_divisas Vacía. Sin datos. Fórmula en L2 sin filas.
   resumen_diario Solo un día. Faltan resúmenes para 2026-09-22, 2026-09-23, etc.
   cuarentena JSON sin normalizar. Aceptable como evidencia, pero no es tabla de negocio.
   audit_log Timestamps inconsistentes. organizacion_id vacío. Eventos duplicados. Mezcla de usuarios.
   reporte_migracion Declaraciones falsas o no verificadas.
   checklist_iso Control 1 en ☐. Contradice reporte.
   usuarios Correcto en apariencia, pero sin organizacion_id directa.
   organizaciones Correcto.
   usuario_organizacion Correcto en estructura, pero sin FK declarada.
   venta_items Sin PK declarada. Stock no validado. Subtotales correctos pero sin moneda explícita.
   metodo pago Nombre con espacio. status en inglés. IDs de dos letras.
   abonos Fechas inconsistentes. tasa_id EUR para ventas USD. Sin organizacion_id.
   tasas organizacion_id vacío. Fechas mezcladas. No hay unicidad por fecha+moneda+fuente.
   moneda_organizacion actualizado_en sin zona horaria. ID de dos letras.
   galeria PK duplicada. fecha_subida sin zona. IDs de prueba (g_dio_test_delete_me).
5. Recomendaciones inmediatas — Plan de choque
   Detener toda operación manual sobre el archivo. Congelar como evidencia forense.

Migrar a un RDBMS real (PostgreSQL, MySQL, SQL Server). Google Sheets no es una base de datos.

Definir DDL con constraints:

PK en todas las tablas.

FK con ON DELETE RESTRICT / ON UPDATE CASCADE.

UNIQUE en clientes(organizacion_id, email), inventario(organizacion_id, nombre, marca, modelo, talla), galeria(id).

CHECK (cantidad >= 0), CHECK (precio_usd >= 0), CHECK (abono_usd >= 0), CHECK (abono_usd <= total_pagar_usd OR saldo_a_favor >= 0).

NOT NULL en organizacion_id, cliente_id, venta_id, item_id, tasa_id.

Reconciliar datos:

Eliminar duplicados c00000002, g00000002, g00000003.

Recalcular saldo_deuda_usd desde ventas + abonos.

Corregir tasas: usar t00000003 para 2026-09-22 USD, no 474. Usar t00000001 para 2026-09-23 USD, no EUR.

Ajustar stock por ventas reales o anular ventas imposibles.

Registrar sobrepago de v00000004 como saldo a favor.

Estandarizar fechas a TIMESTAMPTZ ISO 8601 con zona horaria explícita.

Unificar identidad:

Usar usuario_id en seguridad y usuario_organizacion.

Eliminar email como FK.

Auditoría inmutable:

audit_log con usuario_id, organizacion_id, timestamp_utc, hash_previo, hash_actual.

Append-only, sin updates ni deletes.

Cifrado y GDPR:

Tokenizar emails y teléfonos.

Separar PII en tabla cifrada.

Aplicar derecho al olvido con anonimización, no borrado físico.

Validar el reporte_migracion contra la realidad. Corregir todas sus afirmaciones falsas.

Implementar RBAC y RLS por organizacion_id. Ninguna fila sin tenant.

6. Conclusión final
   Como auditor senior paranoico, no firmaría este archivo ni para una prueba de laboratorio.
   Hay corrupción de datos, violación de PKs, FKs huérfanas, multi-tenant roto, stock negativo, tasas cruzadas, abonos imposibles, PII expuesta y auditoría falsa.
   Esto no pasa una auditoría ISO/IEC 27001 ni ISO 8000. Es un incidente de datos en potencia. La única salida profesional es migrar a un RDBMS con constraints, transacciones y auditoría real, reconciliar la información y volver a certificar desde cero.

pregunta:

se tiene conciencia de Google Sheets no es una base de datos. pero la empresa no reconoce la migracion, por lo tanto se requiere un plan para aplicar todas las normas sobre esta hoja de Google Sheets, esto incluye relaciones, toma encuenta que se va a usar para multiples empresas

repuesta:
PLAN DE IMPLEMENTACIÓN DE NORMAS DE BASE DE DATOS SOBRE GOOGLE SHEETS
Contexto: La empresa no acepta migración a RDBMS. Se debe operar multi-tenant sobre Google Sheets.
Premisa: Google Sheets no es una base de datos. Pero se puede simular un motor transaccional con capas de control. Este plan asume que el archivo es la única fuente de verdad y que cualquier humano con acceso puede romperlo. Por lo tanto, el diseño debe asumir el peor caso: usuario malicioso, usuario torpe y usuario concurrente.

Filosofía: Si no puedes prevenir, detecta. Si no puedes detectar, audita. Si no puedes auditar, respalda. Y si nada de eso funciona, bloquea.

FASE 0 — Congelamiento y respaldo forense
Antes de tocar una sola celda:

Congelar el archivo como evidencia forense. Crear copia inmutable con nombre Estilo Neutral_FORENSIC_SNAPSHOT_YYYYMMDD_HHMMSS.xlsx.

Calcular SHA-256 del archivo completo y de cada hoja exportada a CSV. Registrar en audit_log con timestamp ISO 8601 con zona horaria.

Exportar tripartito: XLSX + 19 CSV UTF-8 BOM + JSON de todas las hojas. Almacenar en carpeta con permisos de solo lectura.

Documentar el estado actual: número de filas por hoja, duplicados detectados, FKs huérfanas, stock negativo, tasas inconsistentes. Esto es la línea base de deuda técnica.

Ningún cambio se autoriza sin backup previo verificable. Cada fase posterior debe repetir este ciclo.

FASE 1 — Modelo multi-tenant canónico
1.1 Principio rector
Toda fila de negocio debe pertenecer a exactamente una organización. Sin excepción. Ninguna tabla operativa puede tener organizacion_id vacío, nulo o inferido.

1.2 Tablas maestras (catálogo global, solo lectura)
Hoja PK Propósito Tenant
organizaciones id (UUID v4) Catálogo de empresas Global
usuarios id (u00000001) Identidad global Global
usuario_organizacion (usuario_id, organizacion_id) Membresía N:M Global
moneda_organizacion (organizacion_id) Moneda base por tenant Por tenant
tasas id (t00000001) Tasas BCV/Binance por fecha+moneda Por tenant
metodo pago id (mp00000001) Catálogo de métodos Por tenant o global
1.3 Tablas transaccionales (siempre con organizacion_id)
Hoja PK FKs obligatorias
clientes id (c00000001) organizacion_id
inventario id (p00000001) organizacion_id, foto_id → galeria.id
galeria id (g00000001) organizacion_id
ventas id (v00000001) cliente_id → clientes.id, organizacion_id, tasa_bcv_id → tasas.id, tasa_usd_id → tasas.id, tipo_pago → metodo pago.id
venta_items id (vi00000001) venta_id → ventas.id, item_id → inventario.id
abonos id (ab00000001) venta_id → ventas.id, metodo_pago → metodo pago.id, tasa_id → tasas.id
compras_divisas id (cd00000001) organizacion_id
seguridad id (s00000001) usuario_id → usuarios.id, organizacion_id
audit_log id (al00000001) usuario_id, organizacion_id
cuarentena id (q00000001) organizacion_id
resumen_diario (fecha, organizacion_id) organizacion_id
1.4 Reglas de oro
Ninguna tabla operativa sin organizacion_id. Si falta, la fila se rechaza.

Ningún ID sin prefijo de tenant cuando aplique. Ej: c-67774411-00000001 o al menos organizacion_id + id compuesto.

Ninguna FK sin validación. Toda FK debe tener una regla de validación de datos o una fórmula de verificación.

Ningún derivado almacenado. saldo_deuda_usd, total_pagar_usd, deuda_usd, subtotal_usd se calculan, no se guardan. Si Sheets obliga a mostrarlos, van en columnas de solo lectura protegidas y se recalculan por script.

FASE 2 — Limpieza y reconciliación de datos existentes
2.1 Deduplicación
clientes: eliminar la fila duplicada de c00000002. Conservar una sola, con saldo_deuda_usd recalculado.

galeria: eliminar duplicados de g00000002 y g00000003. Conservar el registro más reciente y actualizar todas las referencias en inventario.foto_id.

inventario: consolidar p00000004 a p00000008 en un solo SKU por combinación única (nombre, marca, modelo, talla, organizacion_id). Reasignar venta_items.item_id al SKU consolidado.

2.2 Reconciliación de stock
Recalcular inventario.cantidad como stock_inicial + compras - ventas. Si el resultado es negativo, registrar en cuarentena con motivo stock_negativo_post_venta.

Anular o reclasificar ventas que excedan stock real. Toda anulación debe quedar en audit_log con accion = anulacion_venta_stock_insuficiente.

2.3 Reconciliación de tasas
ventas.v00000002 y v00000003 (2026-09-22) deben usar t00000003 (USD BCV 852.4168), no 474.

ventas.v00000004 usa 976.5483, que es EUR. Si la venta es en USD, debe usar t00000001 (USD BCV 853.4993). Si es en EUR, debe declararse explícitamente y la moneda de la venta debe ser EUR.

ventas.v00000001 (2026-04-03) usa 474, correcto según t00000005. Pero tasa_usd = 30.0 no existe en tasas. Registrar la tasa Binance del día o eliminar el campo si no aplica.

2.4 Reconciliación de abonos
abonos.ab00000002 y ab00000003 usan tasa_id = t00000002 (EUR). Si la venta es USD, deben usar t00000001. Corregir.

ventas.v00000004: abono_usd = 300 > total_pagar_usd = 100. Registrar saldo_a_favor_usd = 200 en una tabla nueva saldos_a_favor con FK a clientes.id y ventas.id.

2.5 Reconciliación de saldos de clientes
Recalcular saldo_deuda_usd para cada cliente como:
SUM(ventas.total_pagar_usd WHERE cliente_id = X) - SUM(abonos.monto_usd WHERE venta_id IN ventas de X).

No almacenar. Si se necesita mostrar, calcular por fórmula en columna protegida.

2.6 Corrección de encabezados
metodo pago → metodo_pago (sin espacio).

ventas!P1 vacío → eliminar columna o nombrarla estado (ya existe O = estado, así que P probablemente es residuo). Eliminar.

Estandarizar todos los encabezados a snake_case, sin tildes, sin mayúsculas, sin espacios.

2.7 Corrección de fechas
Todas las fechas a ISO 8601 con zona horaria explícita: YYYY-MM-DDTHH:MM:SS±HH:MM o YYYY-MM-DDTHH:MM:SSZ.

Si solo se conoce la fecha, usar YYYY-MM-DD y declarar que es fecha sin hora.

Prohibido mezclar 2026-09-22 00:00:00 con 2026-09-23T16:18:44.868993. Estandarizar.

2.8 Corrección de IDs
Regex canónico: ^[a-z]{2,3}\d{8}$ para IDs de dos o tres letras + 8 dígitos.

vi00000001 → válido con vi + 8 dígitos. mp00000001 → válido. mo00000001 → válido.

c_test_injection, g_dio_test_delete_me, g_dio_test_delete_me2 → eliminar o mover a cuarentena.

FASE 3 — Capas de control dentro de Google Sheets
Google Sheets no tiene constraints, triggers, transacciones ni locks nativos. Se deben simular con cinco capas. Ninguna capa sola es suficiente. Todas juntas forman el motor.

Capa 1 — Validación de datos (Data Validation)
Aplicar a todas las columnas de FK y a todas las columnas con dominio cerrado.

Columna Tipo Fórmula/Rango Rechazo
clientes.organizacion_id Lista =organizaciones!A2:A Rechazar si no está
inventario.organizacion_id Lista =organizaciones!A2:A Rechazar
inventario.foto_id Lista =galeria!A2:A Rechazar
ventas.cliente_id Lista =FILTER(clientes!A:A, clientes!G:G = INDIRECT("RC[-?]")) Rechazar si no pertenece al tenant
ventas.tipo_pago Lista =metodo_pago!A2:A Rechazar
ventas.estado Lista Pendiente, Pagada, Anulada, Cuarentena Rechazar
venta_items.venta_id Lista =ventas!A2:A Rechazar
venta_items.item_id Lista =inventario!A2:A Rechazar
abonos.venta_id Lista =ventas!A2:A Rechazar
abonos.metodo_pago Lista =metodo_pago!A2:A Rechazar
abonos.tasa_id Lista =tasas!A2:A Rechazar
tasas.moneda Lista USD, EUR, Bs Rechazar
seguridad.usuario_email Lista =usuarios!B2:B Rechazar
Limitación: Data Validation no impide pegar valores. Por eso se necesita la Capa 2.

Capa 2 — Fórmulas de verificación (columnas de control)
En cada hoja, agregar columnas de verificación protegidas y de solo lectura que evalúen integridad en tiempo real.

Hoja Columna Fórmula Propósito
clientes _fk_org_ok =IFERROR(IF(MATCH(G2,organizaciones!A:A,0)>0,"OK","ERROR"),"ERROR") Valida tenant
inventario \_fk_org_ok idem Valida tenant
inventario \_fk_foto_ok =IF(H2="","SIN_FOTO",IFERROR(IF(MATCH(H2,galeria!A:A,0)>0,"OK","ERROR"),"ERROR")) Valida foto
ventas \_fk_cliente_ok =IFERROR(IF(AND(MATCH(C2,clientes!A:A,0)>0, INDEX(clientes!G:G,MATCH(C2,clientes!A:A,0))=O2),"OK","ERROR"),"ERROR") Valida cliente y tenant
ventas \_fk_tasa_bcv_ok =IFERROR(IF(MATCH(D2,tasas!A:A,0)>0,"OK","ERROR"),"ERROR") Valida tasa
ventas \_math_ok =IF(ABS(H2 - (I2\*D2))<0.01,"OK","ERROR") Valida monto_bs
ventas \_abono_ok =IF(J2<=L2,"OK","SOBREPAGO") Detecta abono > total
venta_items \_fk_venta_ok =IFERROR(IF(MATCH(B2,ventas!A:A,0)>0,"OK","ERROR"),"ERROR") Valida venta
venta_items \_fk_item_ok =IFERROR(IF(MATCH(C2,inventario!A:A,0)>0,"OK","ERROR"),"ERROR") Valida item
abonos \_fk_venta_ok idem Valida venta
abonos \_fk_tasa_ok idem Valida tasa
tasas \_org_ok =IF(F2="","ERROR","OK") Exige tenant
Regla: Ninguna fila se considera válida si alguna columna _\*\_ok dice ERROR. El script de la Capa 3 rechaza y mueve a cuarentena.

Capa 3 — Apps Script como motor transaccional
Google Sheets no tiene transacciones. Apps Script puede simularlas con LockService y escritura atómica por lotes.

3.1 Bloqueo de concurrencia
javascript
const lock = LockService.getScriptLock();
lock.waitLock(30000); // 30s máximo
try {
// operación
} finally {
lock.releaseLock();
}
3.2 Validación pre-escritura
Toda función de escritura (crearVenta, crearCliente, registrarAbono, actualizarInventario) debe:

Validar organizacion_id no vacío.

Validar todas las FKs contra las hojas maestras.

Validar reglas de negocio (stock >= cantidad, abono <= total, tasa existe para fecha+moneda).

Validar unicidad de PK.

Si todo pasa, escribir en una sola operación setValues().

Si algo falla, no escribir en la hoja destino. Escribir en cuarentena con datos_originales_json y motivo_cuarentena.

Registrar en audit_log con hash_evidencia SHA-256 del payload.

3.3 Rollback simulado
Como no hay transacciones, se usa journaling:

Antes de escribir, guardar estado previo de las filas afectadas en audit_log.valor_anterior.

Si falla una escritura parcial, el script revierte usando valor_anterior.

Si no puede revertir, marca la fila con estado = Cuarentena y notifica.

3.4 Funciones obligatorias
Función Propósito
validarFila(hoja, fila) Ejecuta todas las validaciones de Capa 2
crearRegistro(hoja, datos) Lock + validación + escritura + audit
actualizarRegistro(hoja, id, datos) Lock + validación + diff + audit
eliminarLogico(hoja, id) No borra. Marca estado = Anulado + audit
recalcularDerivados() Recalcula saldos, stock, resumen*diario
sincronizarResumenDiario() Reconstruye resumen_diario desde ventas y compras_divisas
verificarIntegridadGlobal() Escanea todas las hojas y reporta errores
Capa 4 — Protección de hojas y rangos
Hoja Protección Quién puede editar
organizaciones Solo lectura Propietario
usuarios Solo lectura Propietario
usuario_organizacion Solo lectura Propietario
audit_log Solo lectura + append vía script Nadie directo
cuarentena Solo lectura + append vía script Nadie directo
resumen_diario Solo lectura + recálculo vía script Nadie directo
reporte_migracion Solo lectura Propietario
checklist_iso Solo lectura Auditor
tasas Edición restringida Admin financiero
metodo pago Solo lectura Propietario
clientes Edición por script + validación Operador con permiso
inventario Edición por script + validación Operador con permiso
ventas Edición por script + validación Operador con permiso
venta_items Edición por script + validación Operador con permiso
abonos Edición por script + validación Operador con permiso
galeria Edición por script + validación Operador con permiso
seguridad Edición por script + validación Admin
Columnas de control (*\*\_ok) siempre protegidas, invisibles o en hojas separadas.

Capa 5 — Triggers y notificaciones
Trigger Evento Acción
onEdit Cambio en hoja operativa Validar fila. Si error, mover a cuarentena y revertir.
onChange Cambio estructural Registrar en audit_log con hash.
timeDriven (cada hora) Recalcular derivados Ejecutar recalcularDerivados() y verificarIntegridadGlobal().
timeDriven (diario) Backup Exportar XLSX + CSV + JSON, calcular SHA-256, registrar.
onFormSubmit (si aplica) Nuevo registro Validar y escribir vía script.
Notificación: Cualquier ERROR en columnas de control dispara correo inmediato al admin del tenant y al auditor.

FASE 4 — Multi-tenant: aislamiento por organización
4.1 Regla de oro
Ningún usuario puede leer ni escribir filas de una organización a la que no pertenece.

4.2 Implementación en Sheets
Google Sheets no tiene Row-Level Security nativo. Se simula con:

Hojas por tenant (opción A, más simple):

clientes_67774411, inventario_67774411, ventas_67774411, etc.

Una hoja maestra organizaciones con el UUID.

El script enruta según usuario_organizacion.

Contra: duplica estructura por tenant. Pro: aislamiento físico.

Columna organizacion_id + vistas filtradas (opción B, más escalable):

Una sola tabla por entidad con organizacion_id.

Hojas de vista por tenant: v_clientes_67774411 con =QUERY(clientes!A:Z, "SELECT \* WHERE G = '67774411-...'").

El usuario solo ve su vista. La tabla cruda está protegida.

Contra: el admin ve todo. Pro: una sola fuente de verdad.

Apps Script con getActiveUser() + filtro (opción C, más segura):

El usuario nunca abre la hoja cruda. Solo usa una interfaz web (Web App de Apps Script) que filtra por usuario_organizacion.

La hoja está protegida a nivel de archivo.

Contra: requiere desarrollo. Pro: aislamiento real.

Recomendación: Opción B + Opción C combinadas. La hoja cruda protegida, vistas filtradas por tenant, y Web App para escritura.

4.3 Validación cross-tenant
Toda FK debe validar no solo existencia, sino pertenencia al mismo tenant:

text
=IF(AND(
MATCH(C2, clientes!A:A, 0) > 0,
INDEX(clientes!G:G, MATCH(C2, clientes!A:A, 0)) = O2
), "OK", "ERROR")
Esto evita que una venta de la organización A referencie un cliente de la organización B.

4.4 audit_log por tenant
Cada evento debe llevar organizacion_id. Si el evento es global (ej. creación de organización), organizacion_id = NULL y usuario_id del superadmin.

FASE 5 — Integridad referencial sin FKs reales
5.1 Estrategia
Data Validation en columnas FK (Capa 1).

Fórmulas de verificación _fk_\*\_ok (Capa 2).

Apps Script que rechaza escritura si la FK no existe (Capa 3).

Trigger onEdit que revierte si alguien pega un valor inválido (Capa 5).

Reporte diario de FKs huérfanas en verificarIntegridadGlobal().

5.2 Reglas de borrado
Prohibido borrar filas. Toda eliminación es lógica: estado = Anulado + fecha_anulacion + usuario_anulacion.

Si se debe borrar una fila padre, primero validar que no tenga hijos activos. Si los tiene, rechazar.

Si se borra lógicamente un padre, los hijos quedan huérfanos lógicamente pero referencialmente válidos. El reporte de integridad los marca como HIJO_DE_PADRE_ANULADO.

5.3 Cascada simulada
ON DELETE RESTRICT: por defecto. No se borra padre con hijos.

ON DELETE SET NULL: solo en columnas nullable explícitas (ej. inventario.foto_id si se elimina la foto).

ON UPDATE CASCADE: si cambia un PK, el script actualiza todas las FKs. Pero prohibido cambiar PKs. Si se necesita, se crea nueva fila y se anula la vieja.

FASE 6 — Normalización y eliminación de derivados
6.1 Violaciones actuales y corrección
Violación Corrección
clientes.saldo_deuda_usd almacenado Eliminar columna. Calcular por fórmula o script.
ventas.total_pagar_usd almacenado Eliminar. Calcular como monto_usd.
ventas.deuda_usd almacenado Eliminar. Calcular como MAX(0, total_pagar_usd - abono_usd).
ventas.monto_bs almacenado Eliminar. Calcular como monto_usd _ tasa_bcv.
resumen_diario con agregados Mantener como vista materializada recalculada por script. No editar a mano.
inventario.foto con IMAGE(VLOOKUP(...)) Mantener como vista. La fuente es galeria.url.
venta_items.subtotal_usd almacenado Eliminar. Calcular como cantidad _ precio_usd.
6.2 Regla
Si un dato se puede calcular desde otros datos, no se almacena. Si Sheets obliga a mostrarlo, va en columna protegida con fórmula y el script la sobrescribe en cada recálculo.

FASE 7 — Auditoría inmutable y trazabilidad
7.1 Diseño de audit_log
Columna Tipo Regla
id al00000001 PK, autogenerado
timestamp_utc ISO 8601 con Z Obligatorio, UTC
timestamp_local ISO 8601 con offset Obligatorio, zona del tenant
usuario_id u00000001 FK a usuarios.id
organizacion_id UUID FK a organizaciones.id
hoja string Hoja afectada
celda string Rango afectado
valor_anterior JSON Estado previo
valor_nuevo JSON Estado nuevo
accion enum crear, actualizar, anular, validar, rechazar
norma_aplicada string ISO 8000 §X, etc.
hash_previo SHA-256 Hash del registro anterior
hash_actual SHA-256 Hash de este registro
observaciones string Libre
7.2 Cadena de hash
Cada registro incluye hash_previo y hash_actual. Esto crea una cadena inmutable tipo blockchain. Si alguien altera un registro, todos los hashes posteriores se rompen y se detecta.

7.3 Append-only
audit_log solo permite append. No update, no delete.

Protegida a nivel de hoja. Solo el script escribe.

Backup diario con hash del rango completo.

7.4 Eventos obligatorios
Creación, actualización, anulación de cualquier entidad.

Cambio de configuración de seguridad.

Ejecución de scripts de recálculo.

Rechazo de fila por validación.

Backup generado.

Cambio de permisos.

FASE 8 — Respaldo, recuperación y continuidad
8.1 Estrategia 3-2-1
3 copias: Sheets + Drive + almacenamiento externo (S3, GCS, o disco local).

2 formatos: XLSX + CSV/JSON.

1 offsite: fuera de Google.

8.2 Frecuencia
Tipo Frecuencia Retención
Snapshot completo Diario 30 días
Snapshot semanal Semanal 12 semanas
Snapshot mensual Mensual 12 meses
Snapshot anual Anual 7 años
Journal de cambios Cada escritura 90 días
8.3 Verificación
Cada backup se verifica con SHA-256.

Cada backup se prueba restaurando en un archivo de prueba.

Si la restauración falla, alerta inmediata.

8.4 Recuperación
RTO (Recovery Time Objective): 4 horas.

RPO (Recovery Point Objective): 1 hora.

Procedimiento documentado y probado trimestralmente.

FASE 9 — RBAC y seguridad
9.1 Roles
Rol Permisos
Superadmin Todo. Solo propietario.
Admin tenant CRUD en su tenant. No ve otros tenants.
Operador Crear ventas, abonos, clientes, inventario. No anula.
Auditor Solo lectura. Ve audit_log, cuarentena, checklist_iso.
Financiero CRUD en tasas, compras_divisas, moneda_organizacion.
Solo lectura Ve vistas filtradas de su tenant.
9.2 Implementación
Google Sheets no tiene RBAC nativo. Se simula con:

Protección de hojas y rangos por rol.

Apps Script que valida Session.getActiveUser().getEmail() contra usuario_organizacion antes de cualquier operación.

Web App con autenticación Google Sign-In y scopes mínimos.

Vistas filtradas por tenant.

Prohibido compartir el archivo crudo con operadores. Solo admin y auditor ven la hoja cruda.

9.3 PII y GDPR
Emails y teléfonos tokenizados. Tabla pii_tokens con token → valor_cifrado.

clientes solo guarda token_pii.

Derecho al olvido: anonimizar token, no borrar fila.

Cifrado en reposo: Google Drive ya cifra. Para PII, cifrado adicional a nivel de campo con clave gestionada externamente.

FASE 10 — Gobernanza y operación continua
10.1 Comité de datos
Reunión semanal: revisar cuarentena, errores de integridad, backups.

Reunión mensual: revisar audit_log, métricas de calidad, incidentes.

Reunión trimestral: revisar checklist_iso, actualizar normas, probar recuperación.

10.2 Métricas de calidad
Métrica Objetivo Frecuencia
% filas sin error en columnas \_\*\_ok 100% Diario
% FKs válidas 100% Diario
% filas en cuarentena < 0.1% Diario
Tiempo medio de detección de error < 1 hora Semanal
Tiempo medio de resolución < 24 horas Semanal
Backups verificados 100% Diario
Restauraciones exitosas 100% Trimestral
10.3 Checklist ISO vivo
Actualizar checklist_iso en cada fase.

Cada control debe tener evidencia verificable.

Auditor externo revisa trimestralmente.

10.4 Documentación
docs/modelo_datos.md: DDL lógico, relaciones, cardinalidades.

docs/multitenant.md: aislamiento, RBAC, flujos.

docs/runbook.md: procedimientos de operación, incidentes, recuperación.

docs/normas.md: mapeo de cada norma a cada control.

FASE 11 — Hoja de ruta de implementación
Semana Entregable
1 Congelamiento, backup forense, línea base de deuda técnica
2 Modelo multi-tenant canónico, DDL lógico, documentación
3 Limpieza y reconciliación de datos existentes
4 Capa 1 (Data Validation) + Capa 2 (fórmulas de verificación)
5 Capa 3 (Apps Script: validación, lock, journaling)
6 Capa 4 (protección de hojas y rangos)
7 Capa 5 (triggers, notificaciones, recálculo)
8 Multi-tenant: vistas filtradas + Web App
9 Auditoría inmutable con cadena de hash
10 Backup 3-2-1 + pruebas de restauración
11 RBAC + PII + GDPR
12 Gobernanza, métricas, checklist ISO, auditoría externa
FASE 12 — Declaración final
Google Sheets no es una base de datos. Pero con estas 5 capas de control, se puede aproximar un motor transaccional multi-tenant con integridad referencial, auditoría inmutable y trazabilidad ISO.

Lo que este plan NO puede garantizar:

ACID real. Sheets no tiene transacciones. El journaling simula, pero no es atómico al 100%.

Concurrencia real. LockService tiene timeout y no es distribuido.

Rendimiento. A partir de 100k filas, Sheets se degrada.

Seguridad real. Cualquier usuario con acceso de edición puede romper todo si bypasea el script.

Cumplimiento ISO/IEC 27001 al 100%. Sheets no certifica.

Lo que este plan SÍ garantiza:

Detección temprana de errores.

Rechazo de filas inválidas.

Aislamiento lógico por tenant.

Auditoría inmutable con hash.

Backups verificados.

Trazabilidad completa.

Reconciliación de datos existentes.
