🧠 Prompt de Nivel Paranoico para Refactorización de Google Sheets
Modo: Paranoico / Auditoría Forense
Estándares: ISO/IEC 25010, ISO 8601, ISO/IEC 27001, ISO 8000, RFC 4180, NIST SP 800-53, COBIT 2019, GDPR Art. 5
Objetivo: Transformar la hoja Estilo Neutral.xlsx sin pérdida de datos, sin ambigüedad semántica y con trazabilidad completa.

📋 PROMPT (copiar y pegar completo)
text
ACTÚA COMO: Auditor de Datos Senior + Arquitecto de Información certificado en ISO/IEC 25010, ISO 8000 (Calidad de Datos), ISO 8601 (Fechas), ISO/IEC 27001 (Seguridad), RFC 4180 (CSV), COBIT 2019 y NIST SP 800-53.

MISIÓN: Refactorizar completamente el archivo Google Sheets llamado "Estilo Neutral" aplicando nivel de rigurosidad PARANOICO y cumplimiento de normas internacionales. NO puedes asumir nada. Debes validar, documentar y respaldar cada decisión.

═══════════════════════════════════════════════════════════
FASE 0 — PROTOCOLO DE SEGURIDAD PREVIO (OBLIGATORIO)
═══════════════════════════════════════════════════════════

Antes de modificar CUALQUIER celda:

0.1. Crea una copia de seguridad íntegra: - Nombre: "Estilo Neutral_BACKUP_YYYYMMDD_HHMMSS" - Archivo → Hacer una copia → ubicar en carpeta "Backups/2026" - Verifica que la copia tenga las 5 hojas originales antes de continuar.

0.2. Exporta respaldo adicional en 3 formatos: - .xlsx (Excel) - .csv por cada hoja (UTF-8 con BOM) - .json (estructurado con metadata)
Almacena en Google Drive con permisos restringidos (solo propietario).

0.3. Registra el hash SHA-256 del archivo original (Archivo → Historial de versiones → captura ID de versión).

0.4. Documenta en una nueva hoja "audit_log" (ver Fase 7) el estado ANTES de cualquier cambio.

0.5. BLOQUEA la edición a terceros durante la migración (Compartir → Configuración → Solo propietario puede editar).

═══════════════════════════════════════════════════════════
FASE 1 — VALIDACIÓN DE INTEGRIDAD ESTRUCTURAL
═══════════════════════════════════════════════════════════

Para CADA hoja, valida y reporta:

1.1. Encabezados únicos (sin duplicados, sin celdas vacías).
1.2. Ningún encabezado con espacios al inicio/final ni dobles espacios internos.
1.3. Codificación de caracteres UTF-8 (verificar tildes: DÓLAR → conservar tilde).
1.4. Tipos de datos por columna: - id → string UUID v4 o prefijo+N - fecha → ISO 8601 (YYYY-MM-DD) - montos → número decimal con punto (no coma) y 2 decimales - tasas → número decimal con 2 decimales - texto → string sin caracteres de control
1.5. Detectar celdas con fórmulas ocultas o referencias rotas (#REF!, #N/A, #VALUE!).
1.6. Detectar filas completamente vacías entre datos (rompen QUERY y ORM).
1.7. Detectar formato condicional, validación de datos y filtros existentes.
1.8. Reportar en hoja "audit_log" cualquier anomalía con celda exacta (ej: ventas!D5).

═══════════════════════════════════════════════════════════
FASE 2 — NORMALIZACIÓN SEGÚN ISO 8000 (Calidad de Datos)
═══════════════════════════════════════════════════════════

Aplica a TODAS las hojas:

2.1. NOMBRES DE COLUMNAS → snake_case, sin tildes, sin espacios, sin mayúsculas:
❌ "NRO DE VENTAS DIARIAS" → ✅ "nro_ventas"
❌ "TASA DEL DIA BCV DÓLAR" → ✅ "tasa_bcv"
❌ "FECHA" → ✅ "fecha"
❌ "PAGO DEL CLIENTE EN BS" → ✅ "monto_bs"
❌ "VALOR EN DOLARES" → ✅ "monto_usd"

2.2. NOMBRES DE HOJAS → snake_case, sin tildes, sin espacios:
❌ "registro de ventas diarias" → ✅ (eliminar, duplica)
❌ "registro de compras de dolares" → ✅ (eliminar, mal nombrada)
❌ "compras" → ✅ "compras_divisas"

2.3. IDs → prefijo por entidad + número secuencial (8 dígitos): - cliente: c00000001 - producto: p00000001 - venta: v00000001 - compra: d00000001 - pago: g00000001
Garantiza unicidad con COUNTIF antes de asignar.

2.4. FECHAS → ISO 8601 estricto: YYYY-MM-DD
❌ 03/04/2026 → ✅ 2026-04-03
Configura formato de celda: Formato → Número → Fecha personalizada → yyyy-mm-dd.
Valida con REGEXMATCH: =REGEXMATCH(TO_TEXT(A2),"^\d{4}-\d{2}-\d{2}$")

2.5. MONTOS Y TASAS → punto como separador decimal, 2 decimales exactos.
❌ 474 → ✅ 474.00
Configura formato numérico: 0.00

2.6. TEXTO → eliminar espacios dobles, aplicar TRIM, evitar caracteres de control.
Fórmula de auditoría: =A2<>TRIM(A2) → debe dar FALSE.

2.7. Sin filas vacías intermedias. Sin columnas vacías intermedias.

═══════════════════════════════════════════════════════════
FASE 3 — REDISEÑO DEL ESQUEMA (Normalización 3FN)
═══════════════════════════════════════════════════════════

3.1. CREAR hoja "clientes" (nueva, hoja 1):
Columnas: id | nombre | telefono | email | saldo_deuda_usd | fecha_registro - id: c00000001 (único, validado con COUNTIF=1) - telefono: formato +58XXXXXXXXXX (E.164, ITU-T) - email: validar con REGEXMATCH - saldo_deuda_usd: 0.00 por defecto - fecha_registro: ISO 8601

3.2. RENOMBRAR "inventario" (hoja 2):
Columnas: id | cantidad | nombre | marca | modelo | talla | precio_usd - id: p00000001 - cantidad: entero ≥ 0 - precio_usd: 0.00

3.3. RENOMBRAR "ventas" (hoja 3):
Columnas: id | fecha | cliente_id | item_id | cantidad | tasa_bcv | tasa_usd |
tipo_pago | comision_pago_movil_bs | monto_bs | monto_usd |
abono_usd | deuda_usd | total_pagar_usd - cliente_id: FK → clientes.id (validar con MATCH) - item_id: FK → inventario.id (validar con MATCH) - tipo_pago: enum {Efectivo, Pago Movil, Transferencia, Zelle, Binance, Otro} - Validación cruzada:
monto_bs = cantidad × precio_usd × tasa_bcv
monto_usd = cantidad × precio_usd
deuda_usd = total_pagar_usd - abono_usd

3.4. RENOMBRAR "compras" → "compras_divisas" (hoja 4):
Columnas: id | fecha_compra | fecha_entrega | capital_usd |
comision_binance_usd | numero_orden | plataforma | vendedor |
tasa_bcv | tasa_usd - fecha_entrega ≥ fecha_compra (validación) - comision_binance_usd ≥ 0

3.5. CREAR hoja "resumen_diario" (hoja 5, solo lectura):
Columnas: fecha | nro_ventas | total_bs | total_usd | tasa_bcv | tasa_usd |
usd_comprados | usd_vendidos
Fórmulas:
B2: =COUNTIF(ventas!B:B, A2)
C2: =SUMIF(ventas!B:B, A2, ventas!I:I)
D2: =SUMIF(ventas!B:B, A2, ventas!J:J)
Proteger la hoja: Datos → Hojas y rangos protegidos → Solo propietario.

3.6. ELIMINAR hojas: - "registro de ventas diarias" (duplicada) - "registro de compras de dolares" (nombre engañoso, contenido inválido)
Antes de eliminar: mover datos útiles a la hoja correspondiente.

═══════════════════════════════════════════════════════════
FASE 4 — VALIDACIÓN DE DATOS (Data Validation)
═══════════════════════════════════════════════════════════

Aplica en cada columna según tipo:

4.1. Fechas: Datos → Validación → Fecha es válida → Rechazar entrada.
4.2. Montos: Número mayor o igual a 0 → Rechazar entrada.
4.3. tipo_pago: Lista desplegable → {Efectivo, Pago Movil, Transferencia, Zelle, Binance, Otro}.
4.4. IDs: Texto personalizado → =REGEXMATCH(A2,"^[a-z]\d{8}$") → Rechazar.
4.5. Emails: =REGEXMATCH(C2,"^[^@]+@[^@]+\.[^@]+$") → Rechazar.
4.6. Teléfonos: =REGEXMATCH(C2,"^\+58\d{10}$") → Rechazar.
4.7. FK cliente_id: =COUNTIF(clientes!A:A, C2)>0 → Rechazar.
4.8. FK item_id: =COUNTIF(inventario!A:A, D2)>0 → Rechazar.

Documenta cada validación en "audit_log".

═══════════════════════════════════════════════════════════
FASE 5 — CONSISTENCIA MATEMÁTICA (ISO 8000 §5.3)
═══════════════════════════════════════════════════════════

Agrega columna "validacion" al final de cada hoja transaccional:

5.1. ventas!O2:
=IF(AND(
ABS(monto_bs - cantidad*precio_usd*tasa_bcv) < 0.01,
ABS(monto_usd - cantidad\*precio_usd) < 0.01,
ABS(deuda_usd - (total_pagar_usd - abono_usd)) < 0.01
),"OK","ERROR")

5.2. Filtra filas con "ERROR" y corrígelas o márcalas como cuarentena en hoja "cuarentena".

5.3. Los datos de ejemplo actuales NO cuadran matemáticamente.
Corrígelos o elimínalos antes de publicar.

═══════════════════════════════════════════════════════════
FASE 6 — SEGURIDAD Y PRIVACIDAD (ISO 27001 / GDPR Art. 5)
═══════════════════════════════════════════════════════════

6.1. Minimización de datos: elimina columnas sin uso probado.
6.2. Anonimiza datos de ejemplo que parezcan reales (nombres, teléfonos).
6.3. Configura permisos: - Propietario: edición total. - Colaboradores: solo hojas específicas. - resumen_diario: solo lectura.
6.4. Activa "Alertas de cambios" (Herramientas → Notificaciones).
6.5. Habilita historial de versiones con nombres descriptivos:
"v1.0_original", "v2.0_normalizado", "v3.0_validado".
6.6. Registra en "audit_log" cada cambio con: timestamp ISO 8601, usuario, celda, valor_anterior, valor_nuevo, motivo.

═══════════════════════════════════════════════════════════
FASE 7 — CREAR HOJA "audit_log" (trazabilidad)
═══════════════════════════════════════════════════════════

Columnas:
| timestamp_iso8601 | usuario | hoja | celda | valor_anterior | valor_nuevo | accion | norma_aplicada | observaciones |

Ejemplo:
| 2026-04-03T14:22:00-04:00 | admin@mail.com | ventas | D1 | TASA DEL DIA BCV DÓLAR | tasa_bcv | renombrado_columna | ISO 8000 §4.2 | sin pérdida de datos |

═══════════════════════════════════════════════════════════
FASE 8 — VERIFICACIÓN FINAL (Checklist paranoico)
═══════════════════════════════════════════════════════════

Marca cada ítem antes de declarar la migración completa:

[ ] Backup creado y verificado (3 formatos).
[ ] Hash SHA-256 original registrado.
[ ] 0 encabezados duplicados.
[ ] 0 celdas vacías en encabezados.
[ ] 100% columnas en snake_case.
[ ] 100% fechas en ISO 8601.
[ ] 100% montos con 2 decimales y punto decimal.
[ ] 100% IDs con formato prefijo+8dígitos.
[ ] 0 filas vacías intermedias.
[ ] 0 fórmulas rotas (#REF!, #N/A, #VALUE!).
[ ] Todas las FK validadas con COUNTIF>0.
[ ] Todas las validaciones de datos activas.
[ ] Columna "validacion" = OK en todas las filas.
[ ] Hoja "resumen_diario" protegida.
[ ] Hoja "audit_log" creada con ≥1 entrada.
[ ] Permisos configurados según ISO 27001.
[ ] Historial de versiones etiquetado v1.0/v2.0/v3.0.
[ ] Datos de ejemplo matemáticamente consistentes.
[ ] Datos personales minimizados/anonimizados.
[ ] Notificaciones de cambios activadas.

Si ALGÚN ítem falla → DETENER migración y reportar en "audit_log".

═══════════════════════════════════════════════════════════
FASE 9 — REPORTE FINAL
═══════════════════════════════════════════════════════════

Genera un reporte en hoja "reporte_migracion" con:

- Fecha/hora inicio y fin (ISO 8601 con zona horaria).
- Versión original vs versión final.
- Número de filas migradas, corregidas, en cuarentena.
- Normas aplicadas y su justificación.
- Riesgos residuales.
- Próximos pasos (ej: conectar con google_sheets_orm en Flutter).
- Firma digital del responsable (nombre + timestamp).

═══════════════════════════════════════════════════════════
REGLAS DE ORO (NO NEGOCIABLES)
═══════════════════════════════════════════════════════════

1. NUNCA elimines datos sin respaldo previo.
2. NUNCA asumas el significado de una columna: si es ambiguo, documéntalo.
3. NUNCA mezcles tasas y montos en la misma columna.
4. NUNCA uses nombres con tildes, espacios o mayúsculas en encabezados.
5. SIEMPRE valida FKs antes de aceptar una fila.
6. SIEMPRE registra cada cambio en audit_log.
7. SIEMPRE verifica matemáticamente los datos de ejemplo.
8. SIEMPRE usa ISO 8601 para fechas.
9. SIEMPRE usa UTF-8.
10. SI FALLAS EN ALGO → DETENTE Y REPORTA. No improvises.
    🎯 Cómo usar este prompt
    Escenario Acción
    Google Sheets + Gemini/IA Pega el prompt en un chat con acceso a la hoja (ej: Gemini en Sheets)
    Automatización con Apps Script Usa el prompt como especificación para escribir el script
    Ejecución manual Síguelo fase por fase como checklist
    Auditoría externa Entrégalo junto con la hoja para que un tercero valide
