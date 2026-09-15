ACTÚA COMO: Auditor de Datos Senior + Arquitecto de Información certificado en ISO/IEC 25010, ISO 8000, ISO 8601, ISO/IEC 27001, RFC 4180, COBIT 2019, GDPR Art. 5, NIST SP 800-53 y OWASP MASVS.

CONTEXTO: La hoja "Estilo Neutral" ya fue refactorizada en una migración previa (Fase 0 a Fase 9). Existen 8 hojas: clientes, inventario, ventas, compras_divisas, resumen_diario, cuarentena, audit_log y reporte_migracion. Hay hallazgos pendientes de corrección y controles de seguridad incompletos. Debes ejecutar la Fase 10 sin destruir trazabilidad ni romper la estructura existente.

MISIÓN: Ejecutar 4 bloques secuenciales de trabajo (10.A a 10.D). NO implementar polling. NO eliminar columnas existentes. NO romper fórmulas. Documentar TODO en audit_log.

═══════════════════════════════════════════════════════════
BLOQUE 10.A — APLICAR PATCH DE 10 PUNTOS
═══════════════════════════════════════════════════════════

Antes de aplicar el patch:

- Crea backup "Estilo Neutral_BACKUP_FASE10_YYYYMMDD_HHMMSS".
- Exporta .xlsx + .csv por hoja + .json.
- Registra SHA-256 previo en audit_log.
- Bloquea edición a terceros durante el patch.

Aplica EXACTAMENTE estos 10 cambios, sin alterar nada más:

10.A.1. resumen_diario!H2 — Corregir duplicidad de usd_vendidos
ANTES: =SUMIF(ventas!B:B, A2, ventas!K:K)
DESPUÉS: =SUMIF(ventas!B:B, A2, ventas!L:L)
Motivo: K = monto_usd, L = abono_usd. Evita duplicar total_usd.

10.A.2. resumen_diario!E2 — Reemplazar VLOOKUP frágil por AVERAGEIF
ANTES: =IFERROR(VLOOKUP(A2, ventas!B:F, 5, FALSE), 474.00)
DESPUÉS: =IFERROR(AVERAGEIF(ventas!B:B, A2, ventas!F:F), "SIN DATOS")
Motivo: Elimina hardcodeo, promedia multi-venta del día.

10.A.3. resumen_diario!F2 — Eliminar hardcodeo de tasa_usd
ANTES: 800
DESPUÉS: =IFERROR(AVERAGEIF(ventas!B:B, A2, ventas!G:G), "SIN DATOS")
Motivo: Fuente única de verdad.

10.A.4. clientes!E2 — Auto-calcular saldo_deuda_usd
ANTES: 0 (estático)
DESPUÉS: =IFERROR(SUMIF(ventas!C:C, A2, ventas!M:M), 0)
Motivo: Evitar desincronización manual.

10.A.5. compras_divisas — Añadir columna K "validacion"
K1: validacion
K2: =IF(AND(C2>=B2, E2>=0, D2>0), "OK", "ERROR")
Protección: si fila vacía, devolver "" (usar IF(B2="","",...)).

10.A.6. ventas — Añadir columna P "estado"
P1: estado
P2: Pendiente
Validación de datos: lista {Pendiente, Pagada, Anulada, Cuarentena}.
Aplicar a P2:P1000.

10.A.7. ventas — Reemplazar VLOOKUP por INDEX/MATCH en J, K y O
J2: =IFERROR(E2*INDEX(inventario!G:G, MATCH(D2, inventario!A:A, 0))*F2, "ERROR")
K2: =IFERROR(E2*INDEX(inventario!G:G, MATCH(D2, inventario!A:A, 0)), "ERROR")
O2: =IF(AND(ABS(J2-E2*INDEX(inventario!G:G,MATCH(D2,inventario!A:A,0))*F2)<0.01,
ABS(K2-E2*INDEX(inventario!G:G,MATCH(D2,inventario!A:A,0)))<0.01,
ABS(M2-(N2-L2))<0.01),"OK","ERROR")
Motivo: Inmune a inserción de columnas en inventario.

10.A.8. cuarentena — Añadir columna H "hash_evidencia"
H1: hash_evidencia
H2: =IF(E2="","",SHA256(E2))
Motivo: Integridad criptográfica de la evidencia original.

10.A.9. Crear hoja "checklist_iso" con los 20 ítems de Fase 8
Columnas: nro | control | norma | estado | evidencia | timestamp
Estado: ☑ / ☐ / N/A
Poblar los 20 ítems del prompt original (Fase 8).
Cada "☑" debe tener enlace o referencia a la evidencia.

10.A.10. Verificación de integridad post-patch
Calcular SHA-256 del archivo completo post-patch.
Registrar en audit_log y en reporte_migracion como "SHA-256 Fase 10".
Comparar con SHA-256 original (8c669061392782d04aaa4ef43ecbd227d8f8fb7d0c8af7572f3d0c33c224743d).
Documentar si hay diferencias y por qué.

Regla: si CUALQUIER fórmula da ERROR después del patch, revertir ESA celda específica, documentar en cuarentena y continuar con las demás.

═══════════════════════════════════════════════════════════
BLOQUE 10.B — VERIFICAR PERMISOS (Fase 6.3 del prompt original)
═══════════════════════════════════════════════════════════

Ejecuta y documenta cada punto con captura o evidencia textual:

10.B.1. Abrir Compartir → Configuración avanzada.
10.B.2. Propietario: edición total (verificar email del propietario).
10.B.3. Colaboradores: solo hojas específicas si aplica.
10.B.4. resumen_diario: solo lectura → Datos → Hojas y rangos protegidos → "Solo propietario puede editar".
10.B.5. audit_log: solo lectura (evitar manipulación de evidencia).
10.B.6. cuarentena: solo lectura (evitar alteración de evidencia forense).
10.B.7. reporte_migracion: solo lectura.
10.B.8. checklist_iso: solo lectura.
10.B.9. clientes, inventario, ventas, compras_divisas: edición restringida a propietario + roles autorizados.
10.B.10. Deshabilitar "Cualquier persona con el enlace puede editar".
10.B.11. Deshabilitar "Cualquier persona con el enlace puede ver" (si los datos contienen PII — GDPR Art. 5).
10.B.12. Registrar en audit_log: usuario, fecha ISO 8601, hoja, cambio de permiso, norma aplicada (ISO/IEC 27001 §9.2).

Si algún permiso NO se puede aplicar por limitación de plan (ej: Workspace gratuito), DOCUMENTARLO como riesgo residual en reporte_migracion.

═══════════════════════════════════════════════════════════
BLOQUE 10.C — ACTIVAR NOTIFICACIONES DE CAMBIO (Fase 6.4)
═══════════════════════════════════════════════════════════

10.C.1. Herramientas → Notificaciones → Configuración de notificaciones.
10.C.2. Activar "Se realizan cambios" → "Notificación por correo electrónico" → "Cualquier cambio".
10.C.3. Frecuencia: "Enviar correo inmediatamente".
10.C.4. Activar notificaciones para: - clientes - inventario - ventas - compras_divisas
10.C.5. NO activar para: resumen_diario, audit_log, cuarentena, reporte_migracion, checklist_iso (son de solo lectura).
10.C.6. Configurar filtro: solo cambios en columnas críticas (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P) para evitar ruido por formato.
10.C.7. Activar alertas de cambios en: - Fórmulas protegidas - Permisos modificados - Hojas eliminadas
10.C.8. Registrar en audit_log: acción "activacion_notificaciones", norma ISO/IEC 27001 §12.4, timestamp.
10.C.9. Adjuntar en reporte_migracion la evidencia (captura o descripción textual) de la configuración.

═══════════════════════════════════════════════════════════
BLOQUE 10.D — CONEXIÓN CON FLUTTER + google_sheets_orm
═══════════════════════════════════════════════════════════

NO implementar polling. La app leerá datos bajo demanda (pull manual / acción del usuario / carga inicial).

10.D.1. Mapeo de entidades → clases Dart

       clientes         → Cliente
       inventario       → Producto
       ventas           → Venta
       compras_divisas  → CompraDivisa
       resumen_diario   → solo lectura → ResumenDiario
       cuarentena       → solo lectura → RegistroCuarentena
       audit_log        → solo lectura → AuditLog
       reporte_migracion→ solo lectura → ReporteMigracion
       checklist_iso    → solo lectura → ChecklistISO

10.D.2. Definición de clases (estructura esperada)

       class Cliente {
         String id;                  // c00000001
         String nombre;
         String telefono;            // E.164
         String email;
         double saldoDeudaUsd;
         DateTime fechaRegistro;     // ISO 8601
       }

       class Producto {
         String id;                  // p00000001
         int cantidad;
         String nombre;
         String marca;
         String modelo;
         String talla;
         double precioUsd;
         String? fotoUrl;
         // foto → no se mapea, es fórmula IMAGE()
       }

       class Venta {
         String id;                  // v00000001
         DateTime fecha;
         String clienteId;
         String itemId;
         int cantidad;
         double tasaBcv;
         double tasaUsd;
         String tipoPago;            // enum
         double comisionPagoMovilBs;
         double montoBs;             // calculado, leer como valor
         double montoUsd;            // calculado
         double abonoUsd;
         double deudaUsd;            // calculado
         double totalPagarUsd;       // calculado
         String validacion;          // OK | ERROR
         String estado;              // Pendiente | Pagada | Anulada | Cuarentena
       }

       class CompraDivisa {
         String id;                  // d00000001
         DateTime fechaCompra;
         DateTime fechaEntrega;
         double capitalUsd;
         double comisionBinanceUsd;
         String numeroOrden;
         String plataforma;
         String vendedor;
         double tasaBcv;
         double tasaUsd;
         String validacion;
       }

       // Solo lectura
       class ResumenDiario { DateTime fecha; int nroVentas; double totalBs; double totalUsd; double tasaBcv; double tasaUsd; double usdComprados; double usdVendidos; }
       class RegistroCuarentena { String idRegistroOriginal; String hojaOrigen; DateTime fechaDeteccion; String motivoCuarentena; String datosOriginalesJson; String estado; String resolucion; String hashEvidencia; }
       class AuditLog { DateTime timestampIso8601; String usuario; String hoja; String celda; String valorAnterior; String valorNuevo; String accion; String normaAplicada; String observaciones; }
       class ReporteMigracion { String metrica; String valorEstado; String normaAplicada; String observaciones; }
       class ChecklistISO { int nro; String control; String norma; String estado; String evidencia; DateTime timestamp; }

10.D.3. Anotaciones del ORM

       Aplicar anotaciones de google_sheets_orm según su versión vigente:
       - @SheetTable(name: "...")
       - @SheetColumn(name: "...")
       - @SheetId()
       - Conversión DateTime ↔ ISO 8601
       - Conversión double ↔ número con punto decimal

       Si la librería no soporta anotaciones nativas, usar mapeo manual con Map<String, dynamic>.

10.D.4. Estrategia de acceso a datos (SIN polling)

       - Carga inicial: al abrir la pantalla, hacer UNA lectura de la hoja requerida.
       - Refresco manual: botón "Actualizar" en la UI que dispara una nueva lectura.
       - Escritura: cada operación CRUD dispara UNA escritura y luego UNA relectura de confirmación.
       - NUNCA usar Timer.periodic ni Streams reactivos basados en tiempo.
       - El usuario controla cuándo se actualizan los datos.
       - Documentar en el código: "// No polling. Actualización bajo demanda del usuario."

10.D.5. Autenticación

       - Usar google_sign_in con scope:
         * https://www.googleapis.com/auth/spreadsheets
         * https://www.googleapis.com/auth/drive.readonly (para fotos)
       - Almacenar tokens de forma segura (flutter_secure_storage).
       - NUNCA hardcodear credenciales en el código.
       - Manejar expiración de tokens con refresh silencioso.

10.D.6. Manejo de errores

       - Si validacion == "ERROR" → NO mostrar la fila como válida, marcarla visualmente.
       - Si el ORM devuelve excepción → mostrar SnackBar con mensaje y no romper la UI.
       - Si falta una FK (cliente_id o item_id) → mostrar "Referencia huérfana" y enlazar a cuarentena.

10.D.7. Rendimiento

       - Lecturas limitadas al rango usado (A1:O1000, no A:O completo).
       - Cache en memoria con TTL manual (sin Timer): se invalida al escribir.
       - Para listas grandes, paginar con batchGet.

10.D.8. Reglas de negocio en el cliente

       - tipo_pago debe venir de un enum cerrado: {Efectivo, Pago Movil, Transferencia, Zelle, Binance, Otro}.
       - estado debe validarse antes de enviar: {Pendiente, Pagada, Anulada, Cuarentena}.
       - montos y tasas: validar rango (>0, <1e9) antes de enviar.
       - fechas: validar ISO 8601 antes de enviar.

10.D.9. Documentación obligatoria en el código

       - Cada clase con docstring indicando hoja origen.
       - Cada campo con comentario indicando columna exacta.
       - Archivo README.md con:
         * Instrucciones de configuración de Google Cloud.
         * Scopes requeridos.
         * Estructura de hojas.
         * Política de NO polling.
         * Política de manejo de errores.

10.D.10. Auditoría final de la conexión

       - Verificar que cada clase mapea TODAS las columnas de su hoja.
       - Verificar que resumen_diario, cuarentena, audit_log, reporte_migracion y checklist_iso son SOLO LECTURA en el cliente.
       - Verificar que NO existe ningún Timer.periodic ni Stream.periodic en el código.
       - Registrar en audit_log: acción "conexion_flutter_orm_establecida", norma OWASP MASVS, timestamp.
       - Adjuntar en reporte_migracion el diagrama de mapeo hoja ↔ clase.

═══════════════════════════════════════════════════════════
REGLAS DE ORO (NO NEGOCIABLES)
═══════════════════════════════════════════════════════════

1. NUNCA aplicar un cambio sin backup previo.
2. NUNCA eliminar columnas existentes; solo agregar o corregir fórmulas.
3. NUNCA romper fórmulas de validación (columna validacion debe seguir dando OK).
4. NUNCA exponer PII con permisos de "cualquiera con el enlace".
5. NUNCA implementar polling (ni Timer.periodic, ni Stream.periodic, ni cron interno).
6. SIEMPRE documentar cada cambio en audit_log con timestamp ISO 8601.
7. SIEMPRE verificar SHA-256 antes y después del patch.
8. SIEMPRE registrar evidencia de permisos y notificaciones en reporte_migracion.
9. SIEMPRE tratar hojas de solo lectura como inmutables desde el cliente Flutter.
10. SI ALGO FALLA → DETENER el bloque, documentar en cuarentena y continuar con el siguiente bloque solo si el fallo es aislado.

═══════════════════════════════════════════════════════════
ENTREGABLES FINALES
═══════════════════════════════════════════════════════════

Al terminar los 4 bloques, entregar:

E1. Hoja "Estilo Neutral" con los 10 patches aplicados y sin errores en columna validacion.
E2. Hoja checklist_iso con los 20 ítems marcados.
E3. Hoja audit_log con al menos 15 entradas nuevas (10 del patch + 1 permisos + 1 notificaciones + 3 Flutter).
E4. Hoja reporte_migracion actualizada con SHA-256 Fase 10, permisos, notificaciones y mapeo Flutter.
E5. Código Dart completo con las 9 clases + repositorios + configuración de google_sign_in + README.md.
E6. Declaración explícita: "NO se implementó polling. La actualización es bajo demanda del usuario."

Firma final en reporte_migracion: Auditor Forense ISO + timestamp ISO 8601 con zona horaria.
🎯 Cómo usar este prompt
Entorno Acción
Google Sheets + IA Pegar en Gemini/ChatGPT con acceso a la hoja
Apps Script Usar como especificación para automatizar 10.A
Desarrollo Flutter Pasar 10.D directamente a tu IDE / Cursor / Copilot
Auditoría externa Entregar junto con la hoja como evidencia de cierre
