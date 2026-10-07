/**
 * =============================================================================
 * ESTILO NEUTRAL - GOOGLE APPS SCRIPT WEB APP (CRUD + DRIVE IMAGE UPLOADER)
 * =============================================================================
 * Este script se instala en el editor de Apps Script de tu hoja de Google Sheets.
 * Proporciona un endpoint HTTP (Web App) para recibir operaciones CRUD desde
 * la aplicación Flutter y sincronizar automáticamente en la nube.
 *
 * CARPETA DE GOOGLE DRIVE ASIGNADA:
 * https://drive.google.com/drive/folders/1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD
 * =============================================================================
 */

const DRIVE_FOLDER_ID = "1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD";
const DEFAULT_SPREADSHEET_ID = "1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI";
const ORGANIZACION_ID_DEFAULT = "67774411-6aa1-4aa3-a4b2-d3fc6913b768";

// Prefijo de ID por hoja, para las que siguen el patrón "prefijo + 8 dígitos"
// (ver los getters `nextXxxId` en sheets_data_service.dart — deben coincidir
// exactamente con este mapa). El ID que mande el cliente en `data.id` para
// estas hojas se IGNORA y se recalcula acá, porque el cliente lo arma a
// partir de una caché local que puede estar desactualizada frente a otra
// sesión — dos clientes calculando "el próximo ID" en paralelo sin este
// cambio terminan generando el mismo ID (fue exactamente lo que pasó con
// clientes.c00000002 y galeria.g00000002/g00000003, ver
// docs/google/troubleshooting.md). Acá adentro, bajo el lock global de
// doPost, calcularlo es atómico y no puede chocar.
const ID_PREFIXES = {
  clientes: "c",
  inventario: "p",
  galeria: "g",
  ventas: "v",
  venta_items: "vi",
  abonos: "ab",
  compras_divisas: "d",
  usuarios: "u",
  tasas: "t",
  moneda_organizacion: "mo",
  creditos_clientes: "cr",
  "codigo de telefonos": "ct",
  "tipo de documento": "td",
  resumen_diario: "rd",
  "metodo pago": "mp",
  usuario_organizacion: "uo",
  seguridad: "sg",
  checklist_iso: "ck",
  cuarentena: "cq",
  audit_log: "al",
  reporte_migracion: "rm",
  dispositivos: "dv",
  notificaciones: "nt"
};

/** Hojas que originalmente no tenían columna id (ver migrarEsquema). */
const HOJAS_MIGRABLES = [
  "resumen_diario", "usuario_organizacion", "seguridad", "checklist_iso",
  "cuarentena", "audit_log", "reporte_migracion"
];

function _siguienteIdServidor(sheet, prefijo) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return prefijo + "00000001";
  const ids = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  let maxN = 0;
  for (let i = 0; i < ids.length; i++) {
    const s = String(ids[i][0] || "");
    if (s.slice(0, prefijo.length) !== prefijo) continue;
    const num = parseInt(s.replace(/[^0-9]/g, ""), 10);
    if (!isNaN(num) && num > maxN) maxN = num;
  }
  return prefijo + String(maxN + 1).padStart(8, "0");
}

function getSpreadsheet() {
  try {
    const active = SpreadsheetApp.getActiveSpreadsheet();
    if (active) return active;
  } catch (e) {}
  return SpreadsheetApp.openById(DEFAULT_SPREADSHEET_ID);
}

function doGet(e) {
  const ss = getSpreadsheet();
  return ContentService.createTextOutput(JSON.stringify({
    status: "ok",
    message: "Estilo Neutral Apps Script Web App está activo",
    spreadsheetId: ss.getId(),
    spreadsheetName: ss.getName(),
    sheets: ss.getSheets().map(function(s) { return s.getName(); }),
    timestamp: new Date().toISOString()
  })).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    // Esperar hasta 10 segundos para concurrencia segura
    lock.waitLock(10000);
  } catch (err) {
    return respond({ status: "error", message: "Servidor ocupado. Reintente en un momento." }, 503);
  }

  try {
    if (!e || !e.postData || !e.postData.contents) {
      return respond({ status: "error", message: "Cuerpo de solicitud vacío" }, 400);
    }

    const payload = JSON.parse(e.postData.contents);
    const action = payload.action; // "create", "update", "delete", "toggle_checklist", "set_metodo_seguridad", "upload_image"
    const sheetName = payload.sheet;
    // Sanitizado contra inyección de fórmulas (CWE-1236): un nombre/email/
    // teléfono que empiece con =, +, -, @ o tab se interpreta como fórmula
    // al escribirlo con setValues(). Se antepone una comilla simple — la
    // misma convención que usa Sheets para forzar texto plano cuando el
    // usuario tipea a mano — a cualquier string de "data" que empiece así,
    // antes de que ningún handler la use. De paso evita que un teléfono
    // E.164 (empieza con "+") se guarde como número, perdiendo el signo.
    const data = _sanitizarContraFormulas(payload.data || {});
    const id = payload.id || (data ? data.id : null);

    const ss = getSpreadsheet();

    // La app envía el email de la sesión en cada escritura
    // (ver ControlAccesoSesion y docs/no_polling_policy.md). Si esa cuenta perdió el acceso (la borraron de
    // "usuarios", le quitaron la membresía o se borró su organización), se
    // rechaza sin escribir nada y la app cierra la sesión. Sin el campo
    // (builds viejas) se acepta como antes. No autentica: el email lo manda
    // el cliente (ver DT-1, punto 5).
    const usuarioSesion = String(payload.usuario_sesion || "").trim().toLowerCase();
    if (usuarioSesion) {
      const motivo = _motivoSinAcceso(ss, usuarioSesion);
      if (motivo) {
        return respond({ status: "error", code: "acceso_revocado", message: motivo }, 403);
      }
    }

    // =========================================================================
    // NOTIFICACIONES FCM (ver módulo NOTIFICACIONES más abajo)
    // =========================================================================
    if (action === "configurar_fcm_service_account") {
      if (!payload.fcm_service_account) {
        return respond({ status: "error", message: "Falta fcm_service_account en payload." }, 400);
      }
      PropertiesService.getScriptProperties().setProperty("FCM_SERVICE_ACCOUNT", payload.fcm_service_account);
      return respond({ status: "success", message: "Propiedad FCM_SERVICE_ACCOUNT guardada correctamente." });
    }

    if (action === "preparar_hojas_notificaciones") {
      return respond(prepararHojasNotificaciones());
    }

    if (action === "registrar_dispositivo" || action === "eliminar_dispositivo" || action === "enviar_notificacion" ||
        action === "preparar_notificaciones") {
      if (!usuarioSesion) {
        return respond({ status: "error", message: "Falta el usuario de la sesión." }, 401);
      }
      if (action === "registrar_dispositivo") return respond(_registrarDispositivo(ss, usuarioSesion, data));
      if (action === "eliminar_dispositivo") return respond(_eliminarDispositivo(ss, usuarioSesion, data));
      // Idempotente: crea las hojas con sus listas desplegables e instala el
      // disparador de envío desde la hoja (lo mismo que correr esas dos
      // funciones desde el editor).
      if (action === "preparar_notificaciones") {
        const hojas = prepararHojasNotificaciones();
        const disparador = crearTriggerNotificacionesDesdeHoja();
        return respond({ status: "success", message: hojas.message + " " + disparador.message });
      }
      // Título y mensaje sin sanitizar: viajan como texto de la notificación;
      // se sanitizan al escribirlos en la hoja.
      return respond(_enviarNotificacion(ss, usuarioSesion, payload.data || {}));
    }

    // =========================================================================
    // ACCIÓN ESPECIAL: SUBIR IMAGEN A GOOGLE DRIVE
    // =========================================================================
    if (action === "upload_image") {
      const base64Data = payload.base64Data;
      const fileName = payload.fileName || ("producto_" + new Date().getTime() + ".jpg");
      const mimeType = payload.mimeType || "image/jpeg";

      if (!base64Data) {
        return respond({ status: "error", message: "Falta base64Data para subir la imagen" }, 400);
      }

      const folder = DriveApp.getFolderById(DRIVE_FOLDER_ID);
      const decodedBytes = Utilities.base64Decode(base64Data);
      const blob = Utilities.newBlob(decodedBytes, mimeType, fileName);
      const file = folder.createFile(blob);
      // No se llama a file.setSharing(): Google bloquea a apps no verificadas
      // hacer públicos archivos vía API (prevención de abuso/malware). No hace
      // falta: el archivo hereda el permiso "cualquiera con el enlace" que ya
      // tiene configurado DRIVE_FOLDER_ID a nivel de carpeta.

      const directUrl = "https://lh3.googleusercontent.com/d/" + file.getId();

      _appendAuditLog(ss, {
        hoja: "inventario",
        celda: "H(Drive)",
        valorAnterior: "null",
        valorNuevo: directUrl,
        accion: "subida_imagen_drive",
        norma: "ISO 8000 §4.2 / RFC 3986",
        observaciones: "Subida de archivo " + fileName + " a Google Drive"
      });

      return respond({
        status: "success",
        fileId: file.getId(),
        fileUrl: directUrl,
        downloadUrl: file.getDownloadUrl()
      });
    }

    // =========================================================================
    // ACCIÓN ESPECIAL: EJECUCIÓN ATÓMICA POR LOTES (ALL-OR-NOTHING BATCH)
    // =========================================================================
    if (action === "migrar_esquema") {
      return respond(migrarEsquema(ss));
    }

    if (action === "batch") {
      const batchResult = _handleBatch(ss, payload);
      return respond(batchResult, batchResult.status === "error" ? 400 : 200);
    }

    // =========================================================================
    // CRUD DE HOJAS
    // =========================================================================
    let sheet = ss.getSheetByName(sheetName);
    if (!sheet && sheetName === "creditos_clientes") {
      sheet = ss.insertSheet("creditos_clientes");
      sheet.appendRow([
        "id", "cliente_id", "fecha", "monto_usd", "origen_venta_id",
        "estado", "organizacion_id", "aplicado_a_venta_id", "fecha_aplicacion",
        "saldo_usd", "usuario_email", "hash_evidencia"
      ]);
    }
    if (!sheet) {
      return respond({ status: "error", message: "Hoja '" + sheetName + "' no encontrada" }, 404);
    }
    _asegurarEsquema(sheet, sheetName);

    let result = {};

    // "resumen_diario" no tiene columna de ID: cada cierre se identifica por
    // fecha + organización (ver _handleResumenDiario).
    if (sheetName === "resumen_diario" && ["create", "update", "delete"].indexOf(action) !== -1) {
      return respond(_handleResumenDiario(ss, sheet, action, id, data));
    }

    switch (action) {
      case "create":
        result = _handleCreate(ss, sheet, sheetName, data);
        break;

      case "update":
        result = _handleUpdate(ss, sheet, sheetName, id, data);
        break;

      case "delete":
        result = _handleDelete(ss, sheet, sheetName, id, data);
        break;

      case "toggle_checklist":
        result = _handleToggleChecklist(ss, sheet, payload.id, payload.nro, payload.estado);
        break;

      case "set_metodo_seguridad":
        result = _handleSetMetodoSeguridad(
          ss,
          sheet,
          !!payload.biometrico,
          !!payload.desbloqueo_facial,
          !!payload.dos_factores,
          payload.usuario_email
        );
        break;

      case "refrescar_tasas":
        result = obtenerTasaBCV();
        break;

      case "configurar_validaciones":
        configurarValidacionesDatos();
        result = { status: "success", message: "Validaciones de datos (FK) configuradas." };
        break;

      case "auditar_integridad":
        result = auditarIntegridadReferencial();
        break;

      default:
        return respond({ status: "error", message: "Acción no reconocida: " + action }, 400);
    }

    return respond(result);

  } catch (err) {
    return respond({ status: "error", message: err.toString() }, 500);
  } finally {
    lock.releaseLock();
  }
}

// =============================================================================
// HANDLER DE TRANSACCIONES ATÓMICAS POR LOTES (ALL-OR-NOTHING BATCH)
// =============================================================================

/** Columnas (1-based) que una operación "increment" del lote puede tocar. */
const COLUMNAS_INCREMENTABLES = {
  inventario: { cantidad: 2 },
  clientes: { saldo_deuda_usd: 5 }
};

function _handleBatch(ss, payload) {
  const operations = payload.operations;
  const transactionId = payload.transactionId || ("tx_" + new Date().getTime());

  if (!operations || !Array.isArray(operations) || operations.length === 0) {
    return {
      status: "error",
      message: "Falta arreglo 'operations' válido en la transacción por lotes",
      transactionId: transactionId
    };
  }

  const rollbackTasks = [];
  const results = [];
  const generatedIds = {};
  let lastGeneratedId = null;

  try {
    // 1. Pre-validación: asegurar que todas las hojas referenciadas existan
    for (let i = 0; i < operations.length; i++) {
      const op = operations[i];
      if (!op || !op.sheet) {
        throw new Error("Operación #" + (i + 1) + " no especifica 'sheet'");
      }
      let sh = ss.getSheetByName(op.sheet);
      if (!sh && op.sheet === "creditos_clientes") {
        sh = ss.insertSheet("creditos_clientes");
        sh.appendRow([
          "id", "cliente_id", "fecha", "monto_usd", "origen_venta_id",
          "estado", "organizacion_id", "aplicado_a_venta_id", "fecha_aplicacion",
          "saldo_usd", "usuario_email", "hash_evidencia"
        ]);
      }
      if (!sh) {
        throw new Error("Hoja '" + op.sheet + "' no encontrada en operación #" + (i + 1));
      }
      _asegurarEsquema(sh, op.sheet);
    }

    // 2. Ejecutar cada operación en orden secuencial registrando puntos de rollback
    for (let i = 0; i < operations.length; i++) {
      const op = operations[i];
      const targetSheet = ss.getSheetByName(op.sheet);
      const opAction = op.action;

      if (opAction === "create") {
        const rowData = _sanitizarContraFormulas(op.data || {});

        // Resolver referencias a IDs previos (ej. venta_id: "$last_id" o "$ventas.id")
        for (const k in rowData) {
          if (rowData[k] === "$last_id" && lastGeneratedId) {
            rowData[k] = lastGeneratedId;
          } else if (typeof rowData[k] === "string" && rowData[k].startsWith("$") && rowData[k].endsWith(".id")) {
            const refSheet = rowData[k].slice(1, -3);
            if (generatedIds[refSheet]) {
              rowData[k] = generatedIds[refSheet];
            }
          }
        }

        const createRes = _handleCreate(ss, targetSheet, op.sheet, rowData, true);
        if (createRes.status === "error") {
          throw new Error("Fallo en create (" + op.sheet + "): " + createRes.message);
        }

        const createdId = createRes.id;
        if (createdId) {
          generatedIds[op.sheet] = createdId;
          lastGeneratedId = createdId;
        }

        rollbackTasks.push({
          type: "delete_row",
          sheet: targetSheet,
          row: createRes.row
        });

        results.push({ opIndex: i, action: "create", sheet: op.sheet, id: createdId, row: createRes.row });

      } else if (opAction === "batch_create") {
        const dataList = op.dataList || [];
        for (let j = 0; j < dataList.length; j++) {
          const itemData = _sanitizarContraFormulas(dataList[j] || {});
          for (const k in itemData) {
            if (itemData[k] === "$last_id" && lastGeneratedId) {
              itemData[k] = lastGeneratedId;
            } else if (typeof itemData[k] === "string" && itemData[k].startsWith("$") && itemData[k].endsWith(".id")) {
              const refSheet = itemData[k].slice(1, -3);
              if (generatedIds[refSheet]) {
                itemData[k] = generatedIds[refSheet];
              }
            }
          }

          const itemRes = _handleCreate(ss, targetSheet, op.sheet, itemData, true);
          if (itemRes.status === "error") {
            throw new Error("Fallo en batch_create (" + op.sheet + ", item " + j + "): " + itemRes.message);
          }

          rollbackTasks.push({
            type: "delete_row",
            sheet: targetSheet,
            row: itemRes.row
          });

          results.push({ opIndex: i, itemIndex: j, action: "batch_create", sheet: op.sheet, id: itemRes.id, row: itemRes.row });
        }

      } else if (opAction === "update" || opAction === "update_cell") {
        const targetId = op.id;
        if (!targetId) {
          throw new Error("Operación de actualización #" + (i + 1) + " en " + op.sheet + " requiere 'id'");
        }

        let rowIndex = _findRowById(targetSheet, targetId);
        if (rowIndex === -1 && op.sheet === "creditos_clientes") {
          const createData = Object.assign({ id: targetId }, _sanitizarContraFormulas(op.data || {}));
          const createRes = _handleCreate(ss, targetSheet, op.sheet, createData, true);
          if (createRes && createRes.status === "error") {
            throw new Error(createRes.message);
          }
          rowIndex = createRes.row;
          rollbackTasks.push({
            type: "delete_row",
            sheet: targetSheet,
            row: rowIndex
          });
          results.push({ opIndex: i, action: "upsert_create", sheet: op.sheet, id: targetId, row: rowIndex });
          continue;
        }

        if (rowIndex === -1) {
          throw new Error("Registro con ID '" + targetId + "' no encontrado en " + op.sheet);
        }

        const lastCol = Math.max(targetSheet.getLastColumn(), 1);
        const prevRowValues = targetSheet.getRange(rowIndex, 1, 1, lastCol).getValues()[0];

        rollbackTasks.push({
          type: "restore_row",
          sheet: targetSheet,
          row: rowIndex,
          values: prevRowValues
        });

        if (opAction === "update_cell") {
          const updateData = {};
          updateData[op.field] = op.newValue;
          const sanitizedUpdate = _sanitizarContraFormulas(updateData);
          const updateRes = _handleUpdate(ss, targetSheet, op.sheet, targetId, sanitizedUpdate, true);
          if (updateRes && updateRes.status === "error") {
            throw new Error(updateRes.message);
          }
        } else {
          const updateData = _sanitizarContraFormulas(op.data || {});
          const updateRes = _handleUpdate(ss, targetSheet, op.sheet, targetId, updateData, true);
          if (updateRes && updateRes.status === "error") {
            throw new Error(updateRes.message);
          }
        }

        results.push({ opIndex: i, action: opAction, sheet: op.sheet, id: targetId, row: rowIndex });

      } else if (opAction === "increment") {
        // Suma op.delta al valor ACTUAL de la celda (no a un valor calculado
        // en el teléfono): dos dispositivos que descuentan stock o deuda a la
        // vez no se pisan. Solo columnas declaradas en COLUMNAS_INCREMENTABLES.
        const columna = (COLUMNAS_INCREMENTABLES[op.sheet] || {})[op.field];
        if (!columna) {
          throw new Error("No se puede incrementar " + op.sheet + "." + op.field);
        }
        const delta = Number(op.delta);
        if (!isFinite(delta)) {
          throw new Error("Incremento inválido en " + op.sheet + "." + op.field);
        }
        const rowIndex = _findRowById(targetSheet, op.id);
        if (rowIndex === -1) {
          throw new Error("Registro con ID '" + op.id + "' no encontrado en " + op.sheet);
        }
        const lastCol = Math.max(targetSheet.getLastColumn(), 1);
        rollbackTasks.push({
          type: "restore_row",
          sheet: targetSheet,
          row: rowIndex,
          values: targetSheet.getRange(rowIndex, 1, 1, lastCol).getValues()[0]
        });
        const celda = targetSheet.getRange(rowIndex, columna);
        const actual = Number(celda.getValue()) || 0;
        let nuevo = Math.round((actual + delta) * 100) / 100;
        if (op.min !== undefined && op.min !== null && nuevo < Number(op.min)) nuevo = Number(op.min);
        celda.setValue(nuevo);
        results.push({ opIndex: i, action: "increment", sheet: op.sheet, id: op.id, field: op.field, value: nuevo });

      } else if (opAction === "delete") {
        const targetId = op.id;
        const rowIndex = _findRowById(targetSheet, targetId);
        if (rowIndex === -1) {
          throw new Error("Registro con ID '" + targetId + "' no encontrado para eliminar en " + op.sheet);
        }

        const lastCol = Math.max(targetSheet.getLastColumn(), 1);
        const prevRowValues = targetSheet.getRange(rowIndex, 1, 1, lastCol).getValues()[0];

        rollbackTasks.push({
          type: "insert_row",
          sheet: targetSheet,
          row: rowIndex,
          values: prevRowValues
        });

        const delRes = _handleDelete(ss, targetSheet, op.sheet, targetId);
        if (delRes && delRes.status === "error") {
          throw new Error(delRes.message);
        }
        results.push({ opIndex: i, action: "delete", sheet: op.sheet, id: targetId });

      } else {
        throw new Error("Acción desconocida en lote: " + opAction);
      }
    }

    // 3. Si todo concluyó sin error, asentar en audit_log la transacción atómica
    _appendAuditLog(ss, {
      hoja: "batch_transactions",
      celda: "A",
      valorAnterior: "null",
      valorNuevo: transactionId,
      accion: "batch_atomic_commit",
      norma: "ISO 8000 §5.3 / ACID",
      observaciones: "Transacción atómica completada (" + operations.length + " operaciones)"
    });

    return {
      status: "success",
      transactionId: transactionId,
      message: "Transacción atómica ejecutada con éxito",
      operationsCount: operations.length,
      generatedIds: generatedIds,
      results: results
    };

  } catch (err) {
    // 4. ATOMIC ROLLBACK: Revertir en orden inverso todas las operaciones aplicadas
    for (let r = rollbackTasks.length - 1; r >= 0; r--) {
      try {
        const task = rollbackTasks[r];
        if (task.type === "delete_row") {
          task.sheet.deleteRow(task.row);
        } else if (task.type === "restore_row") {
          task.sheet.getRange(task.row, 1, 1, task.values.length).setValues([task.values]);
        } else if (task.type === "insert_row") {
          task.sheet.insertRowBefore(task.row);
          task.sheet.getRange(task.row, 1, 1, task.values.length).setValues([task.values]);
        }
      } catch (rollbackErr) {
        Logger.log("Error crítico durante rollback en tarea " + r + ": " + rollbackErr.toString());
      }
    }

    _appendAuditLog(ss, {
      hoja: "batch_transactions",
      celda: "A",
      valorAnterior: transactionId,
      valorNuevo: "ROLLBACK_APPLIED",
      accion: "batch_atomic_rollback",
      norma: "ISO 8000 §5.3 / ACID",
      observaciones: "Transacción abortada y revertida: " + err.toString()
    });

    return {
      status: "error",
      transactionId: transactionId,
      message: "Transacción abortada (Rollback ejecutado): " + err.toString()
    };
  }
}

// =============================================================================
// HANDLERS CRUD
// =============================================================================

// Relaciones obligatorias a validar antes de crear una fila: sheetName ->
// lista de [columna_en_data, hoja_destino]. Si el valor de esa columna no
// existe como ID en la hoja destino, se rechaza la creación completa.
const FK_OBLIGATORIAS = {
  ventas: [["cliente_id", "clientes"]],
  venta_items: [["venta_id", "ventas"], ["item_id", "inventario"]],
  abonos: [["venta_id", "ventas"]],
  creditos_clientes: [["cliente_id", "clientes"], ["origen_venta_id", "ventas"]]
};

function _existeId(sheet, id) {
  if (!id) return false;
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return false;
  const ids = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  for (let i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === String(id)) return true;
  }
  return false;
}

function _validarForeignKeys(ss, sheetName, data) {
  const reglas = FK_OBLIGATORIAS[sheetName];
  if (!reglas) return null;
  for (let i = 0; i < reglas.length; i++) {
    const columna = reglas[i][0];
    const hojaDestino = reglas[i][1];
    const valor = data[columna];
    if (!valor) continue; // los campos opcionales (ej. foto_id) se validan aparte si hace falta
    const destino = ss.getSheetByName(hojaDestino);
    if (!destino || !_existeId(destino, valor)) {
      return "FK inválida: " + sheetName + "." + columna + " = '" + valor + "' no existe en " + hojaDestino + ".id";
    }
  }
  return null;
}

function _handleCreate(ss, sheet, sheetName, data, skipAudit) {
  const nextRow = sheet.getLastRow() + 1;
  let rowValues = [];

  // ID generado del lado del servidor (ver ID_PREFIXES) — pisa lo que haya
  // mandado el cliente. Tiene que ir antes de cualquier validación de FK que
  // dependa de él (ninguna acá lo necesita todavía, pero por orden).
  if (ID_PREFIXES[sheetName] && !data.id) {
    data.id = _siguienteIdServidor(sheet, ID_PREFIXES[sheetName]);
  }

  // Validación de integridad referencial: rechazar (sin escribir nada) si
  // una FK obligatoria no existe todavía en su hoja maestra. Cubre las
  // relaciones que aparecieron rotas en la auditoría de datos (ver
  // docs/cumplimiento-normativo.md) — venta sin cliente real, ítem sin
  // producto real, abono sin venta real.
  const fkError = _validarForeignKeys(ss, sheetName, data);
  if (fkError) {
    throw new Error(fkError);
  }

  if (sheetName === "clientes") {
    rowValues = [
      data.id,
      data.nombre || "",
      data.telefono || "",
      data.email || "",
      data.saldo_deuda_usd || 0.0,
      data.fecha_registro || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.organizacion_id || ORGANIZACION_ID_DEFAULT,
      data.tipo_documento || "V",
      _comoTexto(data.cedula)
    ];
  } else if (sheetName === "inventario") {
    // foto_id es una FK a "galeria".id (nunca la URL directa) — la columna
    // de imagen se resuelve con un VLOOKUP contra esa hoja, así la URL real
    // vive en un solo lugar.
    const fotoId = data.foto_id || "";
    const fotoFormula = fotoId
      ? '=IFERROR(IMAGE(VLOOKUP(H' + nextRow + ';galeria!A:B;2;FALSE));"")'
      : "";
    rowValues = [
      data.id,
      data.cantidad || 0,
      data.nombre || "",
      _comoTexto(data.marca),
      _comoTexto(data.modelo),
      _comoTexto(data.talla),
      data.precio_usd || 0.0,
      fotoId,
      fotoFormula,
      data.organizacion_id || ORGANIZACION_ID_DEFAULT
    ];
  } else if (sheetName === "galeria") {
    rowValues = [
      data.id,
      data.url || "",
      data.drive_file_id || "",
      data.nombre_archivo || "",
      data.fecha_subida || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd'T'HH:mm:ss")
    ];
  } else if (sheetName === "ventas") {
    // "ventas" es el header de la factura (esquema nuevo): ya no lleva
    // item_id/cantidad — eso vive en "venta_items", una fila por producto.
    // monto_bs/monto_usd se calculan sumando los subtotales de esa hoja.
    const r = nextRow;
    rowValues = [
      data.id,
      data.fecha || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.cliente_id || "",
      data.tasa_bcv || 0.0,
      data.tasa_usd || 0.0,
      // Clave foránea a "metodo pago".id (no el nombre) — ver esa hoja para
      // resolver el nombre a mostrar. "mp00000001" = Efectivo por defecto.
      data.tipo_pago || "mp00000001",
      data.comision_pago_movil_bs || 0.0,
      '=I' + r + '*D' + r,
      // IMPORTANTE: el separador de argumentos de esta función (";") debe
      // coincidir con el locale configurado en el Sheet real — a diferencia
      // de una expresión aritmética simple (=A*B), un SUMIF/COUNTIF/etc. con
      // comas como separador da "Formula parse error" si el locale espera
      // punto y coma (como este Sheet). No es "más seguro con Apps Script";
      // hay que probarlo contra el Sheet real. Ver docs/google/troubleshooting.md.
      '=SUMIF(venta_items!B:B; A' + r + '; venta_items!F:F)',
      data.abono_usd || 0.0,
      // MAX(0, ...): si el cliente abona más de lo que costaba esta
      // factura puntual, esto NO debe quedar como un número negativo (eso
      // es un excedente, no una deuda) — ver Venta.excedenteUsd en Dart,
      // que calcula ese exceso aparte a partir de abono_usd/total_pagar_usd.
      '=MAX(0;L' + r + '-J' + r + ')',
      '=I' + r,
      data.validacion || "OK",
      data.estado || "Pendiente",
      data.organizacion_id || ORGANIZACION_ID_DEFAULT
    ];
  } else if (sheetName === "venta_items") {
    const r = nextRow;
    rowValues = [
      data.id,
      data.venta_id || "",
      data.item_id || "",
      data.cantidad || 1,
      data.precio_usd || 0.0,
      '=D' + r + '*E' + r
    ];
  } else if (sheetName === "abonos") {
    rowValues = [
      data.id,
      data.venta_id || "",
      // Fecha Y HORA exacta del abono (ISO 8601 completo) — a diferencia de
      // otras fechas del sistema, aquí importa el momento exacto del pago.
      data.fecha || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd'T'HH:mm:ss"),
      data.monto || 0.0,
      // Clave foránea a "metodo pago".id (no el nombre), igual que
      // ventas.tipo_pago.
      data.metodo_pago || "",
      // Clave foránea a "tasas".id — el valor y el origen ('bcv'/'manual')
      // se resuelven haciendo el JOIN lógico contra esa hoja, nunca se
      // duplican acá.
      data.tasa_id || ""
    ];
  } else if (sheetName === "tasas") {
    rowValues = [
      data.id,
      data.fecha || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.moneda || "USD",
      data.valor || 0.0,
      data.fuente || "bcv",
      // Antes caía en "" — por eso todas las filas de tasas tenían
      // organizacion_id vacío (ver docs/cumplimiento-normativo.md).
      data.organizacion_id || ORGANIZACION_ID_DEFAULT
    ];
  } else if (sheetName === "compras_divisas") {
    rowValues = [
      data.id,
      data.fecha_compra || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.fecha_entrega || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.capital_usd || 0.0,
      data.comision_binance_usd || 0.0,
      _comoTexto(data.numero_orden),
      data.plataforma || "",
      _comoTexto(data.vendedor),
      data.tasa_bcv || 0.0,
      data.tasa_usd || 0.0,
      data.validacion || "OK",
      data.organizacion_id || ORGANIZACION_ID_DEFAULT
    ];
  } else if (sheetName === "usuarios") {
    rowValues = [
      data.id,
      (data.email || "").toString().trim().toLowerCase(),
      data.nombre || "",
      data.tipo_documento || "V",
      _comoTexto(data.cedula)
    ];
  } else if (sheetName === "organizaciones") {
    rowValues = [
      data.id,
      data.nombre || ""
    ];
  } else if (sheetName === "moneda_organizacion") {
    rowValues = [
      data.id,
      data.organizacion_id || "",
      data.moneda || "USD",
      data.actualizado_en || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd'T'HH:mm:ss")
    ];
  } else if (sheetName === "usuario_organizacion") {
    rowValues = [
      data.id,
      (data.usuario_email || "").toString().trim().toLowerCase(),
      data.organizacion_id || ""
    ];
  } else if (sheetName === "checklist_iso") {
    // El nro lo asigna el servidor (máximo + 1): contarlo en la app repetía
    // números cuando había huecos o varias organizaciones.
    rowValues = [
      data.id,
      _siguienteNroChecklist(sheet),
      data.control || "",
      data.norma || "",
      data.estado || "☐",
      data.evidencia || "",
      data.timestamp || new Date().toISOString(),
      data.organizacion_id || ORGANIZACION_ID_DEFAULT
    ];
  } else if (sheetName === "cuarentena") {
    rowValues = [
      data.id,
      data.id_registro_original || "",
      data.hoja_origen || "",
      data.fecha_deteccion || new Date().toISOString(),
      data.motivo_cuarentena || "",
      data.datos_originales_json || "",
      data.estado || "PENDIENTE_REVISION",
      data.resolucion || "",
      data.hash_evidencia || "",
      data.organizacion_id || ORGANIZACION_ID_DEFAULT
    ];
  } else if (sheetName === "audit_log") {
    rowValues = [
      data.id,
      data.timestamp_iso8601 || new Date().toISOString(),
      data.usuario || "",
      data.hoja || "",
      data.celda || "",
      data.valor_anterior || "",
      data.valor_nuevo || "",
      data.accion || "",
      data.norma_aplicada || "",
      data.observaciones || "",
      data.organizacion_id || ""
    ];
  } else if (sheetName === "reporte_migracion") {
    rowValues = [
      data.id,
      data.metrica || "",
      data.valor_estado || "",
      data.norma_aplicada || "",
      data.observaciones || "",
      data.organizacion_id || ORGANIZACION_ID_DEFAULT
    ];
  } else if (sheetName === "metodo pago") {
    rowValues = [
      data.id,
      data.nombre || "",
      data.status !== undefined ? data.status : true
    ];
  } else if (sheetName === "codigo de telefonos") {
    // El código va con comilla: sin ella appendRow convierte "0414" en 414.
    rowValues = [
      data.id,
      "'" + _normalizarCodigoTelefono(data.codigo),
      data.status !== undefined ? data.status : true
    ];
  } else if (sheetName === "tipo de documento") {
    rowValues = [
      data.id,
      (data.tipo || "").toString().trim().toUpperCase(),
      data.descripcion || "",
      data.status !== undefined ? data.status : true
    ];
  } else if (sheetName === "creditos_clientes") {
    rowValues = [
      data.id,
      data.cliente_id || "",
      data.fecha || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd'T'HH:mm:ssXXX"),
      data.monto_usd !== undefined ? data.monto_usd : 0.0,
      data.origen_venta_id || "",
      data.estado || "DISPONIBLE",
      data.organizacion_id || ORGANIZACION_ID_DEFAULT,
      data.aplicado_a_venta_id || "",
      data.fecha_aplicacion || "",
      data.saldo_usd !== undefined ? data.saldo_usd : (data.monto_usd || 0.0),
      data.usuario_email || "",
      data.hash_evidencia || ""
    ];
  } else {
    // Genérico
    rowValues = Object.values(data);
  }

  sheet.appendRow(rowValues);
  if (sheetName === "codigo de telefonos") _repararColumnaCodigosTelefono(sheet);

  // Sincronizar abono acumulado en la cabecera de la factura si se creó un abono
  if (sheetName === "abonos" && data.venta_id && data.monto !== undefined) {
    const vSheet = ss.getSheetByName("ventas");
    if (vSheet) {
      const vRow = _findRowById(vSheet, data.venta_id);
      if (vRow !== -1) {
        const abonoPrev = Number(vSheet.getRange(vRow, 10).getValue()) || 0.0;
        const nuevoAbono = abonoPrev + Number(data.monto);
        vSheet.getRange(vRow, 10).setValue(nuevoAbono);
        const totalPagar = Number(vSheet.getRange(vRow, 12).getValue()) || 0.0;
        if (totalPagar > 0 && nuevoAbono >= totalPagar) {
          vSheet.getRange(vRow, 14).setValue("Pagada");
        }
      }
    }
  }

  if (!skipAudit) {
    _appendAuditLog(ss, {
      hoja: sheetName,
      celda: "A" + nextRow,
      valorAnterior: "null",
      valorNuevo: data.id || data.usuario_email || "nuevo_registro",
      accion: "creacion_" + sheetName,
      norma: "ISO 8000 §4.2",
      observaciones: "Registro insertado vía App Móvil"
    });
  }

  return { status: "success", message: "Registro creado exitosamente", row: nextRow, id: data.id || data.usuario_email };
}

function _handleUpdate(ss, sheet, sheetName, id, data, skipAudit) {
  let rowIndex = _findRowById(sheet, id);
  if (rowIndex === -1 && sheetName === "creditos_clientes") {
    const createData = Object.assign({ id: id }, data);
    return _handleCreate(ss, sheet, sheetName, createData, skipAudit);
  }
  if (rowIndex === -1) {
    return { status: "error", message: "Registro con ID '" + id + "' no encontrado en " + sheetName };
  }

  if (sheetName === "clientes") {
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 2).setValue(data.nombre);
    if (data.telefono !== undefined) sheet.getRange(rowIndex, 3).setValue(data.telefono);
    if (data.email !== undefined) sheet.getRange(rowIndex, 4).setValue(data.email);
    if (data.saldo_deuda_usd !== undefined) sheet.getRange(rowIndex, 5).setValue(data.saldo_deuda_usd);
    if (data.tipo_documento !== undefined) sheet.getRange(rowIndex, 8).setValue(data.tipo_documento);
    if (data.cedula !== undefined) sheet.getRange(rowIndex, 9).setValue(_comoTexto(data.cedula));
  } else if (sheetName === "inventario") {
    if (data.cantidad !== undefined) sheet.getRange(rowIndex, 2).setValue(data.cantidad);
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 3).setValue(data.nombre);
    if (data.marca !== undefined) sheet.getRange(rowIndex, 4).setValue(_comoTexto(data.marca));
    if (data.modelo !== undefined) sheet.getRange(rowIndex, 5).setValue(_comoTexto(data.modelo));
    if (data.talla !== undefined) sheet.getRange(rowIndex, 6).setValue(_comoTexto(data.talla));
    if (data.precio_usd !== undefined) sheet.getRange(rowIndex, 7).setValue(data.precio_usd);
    if (data.foto_id !== undefined) {
      sheet.getRange(rowIndex, 8).setValue(data.foto_id);
      sheet.getRange(rowIndex, 9).setFormula(
        data.foto_id
          ? '=IFERROR(IMAGE(VLOOKUP(H' + rowIndex + ';galeria!A:B;2;FALSE));"")'
          : ''
      );
    }
  } else if (sheetName === "ventas") {
    // Solo los campos editables del header (nunca las columnas fórmula:
    // monto_bs=H, monto_usd=I, deuda_usd=K, total_pagar_usd=L — se
    // recalculan solas a partir de "venta_items" y de estos valores).
    if (data.tasa_bcv !== undefined) sheet.getRange(rowIndex, 4).setValue(data.tasa_bcv);
    if (data.tasa_usd !== undefined) sheet.getRange(rowIndex, 5).setValue(data.tasa_usd);
    if (data.tipo_pago !== undefined) sheet.getRange(rowIndex, 6).setValue(data.tipo_pago);
    if (data.comision_pago_movil_bs !== undefined) sheet.getRange(rowIndex, 7).setValue(data.comision_pago_movil_bs);
    if (data.abono_usd !== undefined) sheet.getRange(rowIndex, 10).setValue(data.abono_usd);
    if (data.estado !== undefined) sheet.getRange(rowIndex, 14).setValue(data.estado);
  } else if (sheetName === "venta_items") {
    if (data.cantidad !== undefined) sheet.getRange(rowIndex, 4).setValue(data.cantidad);
    if (data.precio_usd !== undefined) sheet.getRange(rowIndex, 5).setValue(data.precio_usd);
  } else if (sheetName === "compras_divisas") {
    if (data.fecha_entrega !== undefined) sheet.getRange(rowIndex, 3).setValue(data.fecha_entrega);
    if (data.capital_usd !== undefined) sheet.getRange(rowIndex, 4).setValue(data.capital_usd);
    if (data.comision_binance_usd !== undefined) sheet.getRange(rowIndex, 5).setValue(data.comision_binance_usd);
    if (data.numero_orden !== undefined) sheet.getRange(rowIndex, 6).setValue(_comoTexto(data.numero_orden));
    if (data.plataforma !== undefined) sheet.getRange(rowIndex, 7).setValue(data.plataforma);
    if (data.vendedor !== undefined) sheet.getRange(rowIndex, 8).setValue(_comoTexto(data.vendedor));
    if (data.tasa_bcv !== undefined) sheet.getRange(rowIndex, 9).setValue(data.tasa_bcv);
    if (data.tasa_usd !== undefined) sheet.getRange(rowIndex, 10).setValue(data.tasa_usd);
  } else if (sheetName === "usuarios") {
    if (data.email !== undefined) sheet.getRange(rowIndex, 2).setValue(data.email.toString().trim().toLowerCase());
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 3).setValue(data.nombre);
    if (data.tipo_documento !== undefined) sheet.getRange(rowIndex, 4).setValue(data.tipo_documento);
    if (data.cedula !== undefined) sheet.getRange(rowIndex, 5).setValue(_comoTexto(data.cedula));
  } else if (sheetName === "organizaciones") {
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 2).setValue(data.nombre);
  } else if (sheetName === "moneda_organizacion") {
    if (data.moneda !== undefined) sheet.getRange(rowIndex, 3).setValue(data.moneda);
    if (data.actualizado_en !== undefined) sheet.getRange(rowIndex, 4).setValue(data.actualizado_en);
  } else if (sheetName === "tasas") {
    if (data.fecha !== undefined) sheet.getRange(rowIndex, 2).setValue(data.fecha);
    if (data.moneda !== undefined) sheet.getRange(rowIndex, 3).setValue(data.moneda);
    if (data.valor !== undefined) sheet.getRange(rowIndex, 4).setValue(data.valor);
    if (data.fuente !== undefined) sheet.getRange(rowIndex, 5).setValue(data.fuente);
    if (data.organizacion_id !== undefined) sheet.getRange(rowIndex, 6).setValue(data.organizacion_id);
  } else if (sheetName === "usuario_organizacion") {
    if (data.organizacion_id !== undefined) sheet.getRange(rowIndex, 3).setValue(data.organizacion_id);
  } else if (sheetName === "checklist_iso") {
    const errOrg = _verificarOrganizacion(sheet, rowIndex, 8, data);
    if (errOrg) return errOrg;
    if (data.control !== undefined) sheet.getRange(rowIndex, 3).setValue(data.control);
    if (data.norma !== undefined) sheet.getRange(rowIndex, 4).setValue(data.norma);
    if (data.estado !== undefined) sheet.getRange(rowIndex, 5).setValue(data.estado);
    if (data.evidencia !== undefined) sheet.getRange(rowIndex, 6).setValue(data.evidencia);
    if (data.timestamp !== undefined) sheet.getRange(rowIndex, 7).setValue(data.timestamp);
  } else if (sheetName === "cuarentena") {
    const errOrg = _verificarOrganizacion(sheet, rowIndex, 10, data);
    if (errOrg) return errOrg;
    if (data.estado !== undefined) sheet.getRange(rowIndex, 7).setValue(data.estado);
    if (data.resolucion !== undefined) sheet.getRange(rowIndex, 8).setValue(data.resolucion);
  } else if (sheetName === "reporte_migracion") {
    const errOrg = _verificarOrganizacion(sheet, rowIndex, 6, data);
    if (errOrg) return errOrg;
    if (data.metrica !== undefined) sheet.getRange(rowIndex, 2).setValue(data.metrica);
    if (data.valor_estado !== undefined) sheet.getRange(rowIndex, 3).setValue(data.valor_estado);
    if (data.norma_aplicada !== undefined) sheet.getRange(rowIndex, 4).setValue(data.norma_aplicada);
    if (data.observaciones !== undefined) sheet.getRange(rowIndex, 5).setValue(data.observaciones);
  } else if (sheetName === "audit_log") {
    return { status: "error", message: "La bitácora de auditoría es inmutable: no se puede editar." };
  } else if (sheetName === "metodo pago") {
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 2).setValue(data.nombre);
    if (data.status !== undefined) sheet.getRange(rowIndex, 3).setValue(data.status);
  } else if (sheetName === "codigo de telefonos") {
    if (data.codigo !== undefined) {
      sheet.getRange(rowIndex, 2).setValue("'" + _normalizarCodigoTelefono(data.codigo));
    }
    if (data.status !== undefined) sheet.getRange(rowIndex, 3).setValue(data.status);
    _repararColumnaCodigosTelefono(sheet);
  } else if (sheetName === "tipo de documento") {
    if (data.tipo !== undefined) sheet.getRange(rowIndex, 2).setValue(data.tipo.toString().trim().toUpperCase());
    if (data.descripcion !== undefined) sheet.getRange(rowIndex, 3).setValue(data.descripcion);
    if (data.status !== undefined) sheet.getRange(rowIndex, 4).setValue(data.status);
  } else if (sheetName === "creditos_clientes") {
    if (data.estado !== undefined) sheet.getRange(rowIndex, 6).setValue(data.estado);
    if (data.aplicado_a_venta_id !== undefined) sheet.getRange(rowIndex, 8).setValue(data.aplicado_a_venta_id);
    if (data.fecha_aplicacion !== undefined) sheet.getRange(rowIndex, 9).setValue(data.fecha_aplicacion);
    if (data.saldo_usd !== undefined) sheet.getRange(rowIndex, 10).setValue(data.saldo_usd);
    if (data.usuario_email !== undefined) sheet.getRange(rowIndex, 11).setValue(data.usuario_email);
    if (data.hash_evidencia !== undefined) sheet.getRange(rowIndex, 12).setValue(data.hash_evidencia);
  } else if (sheetName === "abonos") {
    if (data.monto !== undefined) sheet.getRange(rowIndex, 4).setValue(data.monto);
    if (data.metodo_pago !== undefined) sheet.getRange(rowIndex, 5).setValue(data.metodo_pago);
  }

  if (!skipAudit) {
    _appendAuditLog(ss, {
      hoja: sheetName,
      celda: "A" + rowIndex,
      valorAnterior: "registro_existente",
      valorNuevo: id,
      accion: "actualizacion_" + sheetName,
      norma: "ISO 8000 §4.2",
      observaciones: "Modificación de campos vía App Móvil"
    });
  }

  return { status: "success", message: "Registro " + id + " actualizado correctamente" };
}

function _handleDelete(ss, sheet, sheetName, id, data) {
  if (sheetName === "audit_log") {
    return { status: "error", message: "La bitácora de auditoría es inmutable: no se puede eliminar." };
  }
  const rowIndex = _findRowById(sheet, id);
  if (rowIndex === -1) {
    return { status: "error", message: "Registro con ID '" + id + "' no encontrado en " + sheetName };
  }
  const colOrg = { checklist_iso: 8, cuarentena: 10, reporte_migracion: 6 }[sheetName];
  if (colOrg) {
    const errOrg = _verificarOrganizacion(sheet, rowIndex, colOrg, data || {});
    if (errOrg) return errOrg;
  }

  sheet.deleteRow(rowIndex);

  _appendAuditLog(ss, {
    hoja: sheetName,
    celda: "A" + rowIndex,
    valorAnterior: id,
    valorNuevo: "ELIMINADO",
    accion: "eliminacion_" + sheetName,
    norma: "GDPR Art. 17 / ISO 27001",
    observaciones: "Eliminación de registro vía App Móvil"
  });

  return { status: "success", message: "Registro " + id + " eliminado correctamente" };
}

function _handleToggleChecklist(ss, sheet, id, nro, nuevoEstado) {
  // Por id (app actual); por nro solo para builds viejas, que no envían id.
  const filas = sheet.getDataRange().getValues();
  for (let i = 1; i < filas.length; i++) {
    const coincide = id ? String(filas[i][0]).trim() === String(id).trim() : filas[i][1] == nro;
    if (coincide) {
      sheet.getRange(i + 1, 5).setValue(nuevoEstado);
      sheet.getRange(i + 1, 7).setValue(new Date().toISOString());

      _appendAuditLog(ss, {
        hoja: "checklist_iso",
        celda: "E" + (i + 1),
        valorAnterior: filas[i][4],
        valorNuevo: nuevoEstado,
        accion: "toggle_checklist_iso",
        norma: filas[i][3] || "ISO/IEC 27001",
        observaciones: "Control " + filas[i][0] + " (#" + filas[i][1] + ") actualizado a " + nuevoEstado,
        organizacionId: filas[i][7]
      });

      return { status: "success", message: "Control " + filas[i][0] + " actualizado a " + nuevoEstado };
    }
  }
  return { status: "error", message: "Control " + (id || ("#" + nro)) + " no encontrado." };
}

function _handleSetMetodoSeguridad(ss, sheet, biometrico, desbloqueoFacial, dosFactores, usuarioEmail) {
  const email = (usuarioEmail || "").toString().trim().toLowerCase();
  const rowIndex = _findRowByColumnValue(sheet, 5, email);
  // IMPORTANTE: Range.setValues() en Apps Script auto-convierte las cadenas
  // "TRUE"/"FALSE" a boolean nativo de Sheets igual que si se pasara un
  // boolean de JS directamente — no hay forma de forzar texto plano acá. Por
  // eso se pasan booleans tal cual: lo que sí importa es que TODAS las filas
  // de esta columna sean del mismo tipo (boolean nativo). Si una fila queda
  // como boolean nativo y otra como texto "FALSE" (por ejemplo, si se
  // insertó a mano o vía la API de Sheets con valueInputOption=RAW), el
  // endpoint GViz que usa la app para leer (out:csv) rompe la detección de
  // encabezado y devuelve un CSV corrupto (encabezado fusionado con la
  // primera fila de datos). Ver docs/google/troubleshooting.md.
  const rowValues = [biometrico, desbloqueoFacial, dosFactores, email];

  let anterior = "desconocido";
  if (rowIndex !== -1) {
    const prev = sheet.getRange(rowIndex, 2, 1, 3).getValues()[0];
    anterior = JSON.stringify(prev);
    sheet.getRange(rowIndex, 2, 1, 4).setValues([rowValues]);
  } else {
    sheet.appendRow([_siguienteIdServidor(sheet, ID_PREFIXES.seguridad)].concat(rowValues));
  }

  const etiquetas = { biometrico: "Biométrico", desbloqueo_facial: "Desbloqueo facial", dos_factores: "2FA" };
  let metodoActivo = "Ninguno";
  if (biometrico) metodoActivo = etiquetas.biometrico;
  else if (desbloqueoFacial) metodoActivo = etiquetas.desbloqueo_facial;
  else if (dosFactores) metodoActivo = etiquetas.dos_factores;

  _appendAuditLog(ss, {
    hoja: "seguridad",
    celda: "A" + (rowIndex !== -1 ? rowIndex : sheet.getLastRow()) + ":C" + (rowIndex !== -1 ? rowIndex : sheet.getLastRow()),
    valorAnterior: anterior,
    valorNuevo: JSON.stringify(rowValues),
    accion: "cambio_metodo_seguridad",
    norma: "ISO/IEC 27001 §9.4",
    observaciones: "Método de seguridad del usuario '" + email + "' cambiado a '" + metodoActivo + "'"
  });

  return {
    status: "success",
    biometrico: biometrico,
    desbloqueo_facial: desbloqueoFacial,
    dos_factores: dosFactores,
    usuario_email: email
  };
}

// =============================================================================
// AUDITORÍA ISO 27001 Y BÚSQUEDA
// =============================================================================

function _findRowById(sheet, id) {
  if (!id) return -1;
  const values = sheet.getRange(1, 1, sheet.getLastRow(), 1).getValues();
  for (let i = 1; i < values.length; i++) {
    if (values[i][0] && values[i][0].toString().trim().toLowerCase() === id.toString().trim().toLowerCase()) {
      return i + 1;
    }
  }
  return -1;
}

/**
 * Motivo por el que [email] no tiene acceso a la app, o null si lo tiene.
 * Mismas reglas que SheetsDataService.resolverAcceso: estar en "usuarios",
 * tener membresía en "usuario_organizacion" y que esa organización exista.
 * Si falta alguna de las hojas (esquema sin migrar) no bloquea.
 */
function _motivoSinAcceso(ss, email) {
  const filas = function (nombre) {
    const sh = ss.getSheetByName(nombre);
    if (!sh || sh.getLastRow() < 1) return null;
    return sh.getDataRange().getValues();
  };
  const columna = function (tabla, encabezado) {
    return tabla[0].map(function (h) { return String(h).trim().toLowerCase(); }).indexOf(encabezado);
  };
  const usuarios = filas("usuarios");
  const membresias = filas("usuario_organizacion");
  const organizaciones = filas("organizaciones");
  if (!usuarios || !membresias || !organizaciones) return null;

  const cEmail = columna(usuarios, "email");
  const cMiembro = columna(membresias, "usuario_email");
  const cOrg = columna(membresias, "organizacion_id");
  const cIdOrg = columna(organizaciones, "id");
  if (cEmail < 0 || cMiembro < 0 || cOrg < 0 || cIdOrg < 0) return null;

  const igual = function (v) { return String(v).trim().toLowerCase() === email; };
  if (!usuarios.slice(1).some(function (f) { return igual(f[cEmail]); })) {
    return "La cuenta " + email + " ya no está autorizada.";
  }
  const membresia = membresias.slice(1).filter(function (f) { return igual(f[cMiembro]); })[0];
  if (!membresia) return "La cuenta " + email + " ya no pertenece a ninguna organización.";
  const orgId = String(membresia[cOrg]).trim();
  if (!organizaciones.slice(1).some(function (f) { return String(f[cIdOrg]).trim() === orgId; })) {
    return "La organización de la cuenta " + email + " ya no existe.";
  }
  return null;
}

// =============================================================================
// MÓDULO NOTIFICACIONES — Firebase Cloud Messaging (HTTP v1)
// =============================================================================
// Hojas:
//   dispositivos:   id | usuario_email | organizacion_id | token | plataforma | actualizado
//   notificaciones: id | fecha | remitente_email | alcance | organizacion_ids |
//                   usuarios | titulo | cuerpo | ruta | estado | enviados |
//                   fallidos | detalle
//
// Cualquier usuario con acceso (está en "usuarios", tiene membresía y su
// organización existe) puede enviar a: todos ("global"), una o varias
// organizaciones ("organizaciones") o usuarios puntuales de cualquier
// organización ("usuarios"). Solo reciben los dispositivos de usuarios que
// siguen teniendo acceso, según la organización a la que pertenecen HOY.
//
// Formas de enviar:
//   1. Desde la app (acción "enviar_notificacion").
//   2. Desde la hoja: escribir una fila en "notificaciones" con estado
//      PENDIENTE y correr enviarNotificacionesPendientes() (o instalar el
//      disparador con crearTriggerNotificacionesDesdeHoja(), que envía al
//      cambiar el estado a PENDIENTE).
//
// Credencial: propiedad del script FCM_SERVICE_ACCOUNT con el JSON completo
// de una cuenta de servicio del proyecto de Firebase (rol "Firebase Cloud
// Messaging API Admin"). No se guarda en el código ni en la hoja.

const HOJA_DISPOSITIVOS = "dispositivos";
const HOJA_NOTIFICACIONES = "notificaciones";
const ENCABEZADO_DISPOSITIVOS = ["id", "usuario_email", "organizacion_id", "token", "plataforma", "actualizado"];
const ENCABEZADO_NOTIFICACIONES = [
  "id", "fecha", "remitente_email", "alcance", "organizacion_ids", "usuarios",
  "titulo", "cuerpo", "ruta", "estado", "enviados", "fallidos", "detalle"
];
const COL_NOTIF = { estado: 10, enviados: 11, fallidos: 12, detalle: 13 };
const ALCANCES_NOTIFICACION = ["global", "organizaciones", "usuarios"];
const ESTADOS_NOTIFICACION = ["PENDIENTE", "ENVIADA", "SIN_DESTINATARIOS", "ERROR"];
const CANAL_ANDROID_NOTIFICACIONES = "estilo_neutral_general";
// En Android se envían mensajes SOLO DE DATOS (titulo, cuerpo, ruta…): la app
// arma la notificación con la marca (monograma, color y logo apaisado) que
// trae en el APK, sin descargar imágenes. Con `notification` + `image`, la
// imagen la descargaba el teléfono y en Xiaomi/MIUI, con la app dormida, no
// llegaba a tiempo. iOS (si algún día se configura) usa el bloque `apns`.

/** Devuelve la hoja, creándola con su encabezado si no existe. */
function _hojaConEncabezado(ss, nombre, encabezado) {
  let sh = ss.getSheetByName(nombre);
  if (!sh) {
    sh = ss.insertSheet(nombre);
    sh.appendRow(encabezado);
    sh.setFrozenRows(1);
  }
  return sh;
}

/**
 * Crea las hojas de notificaciones (si faltan) y las prepara para usarlas a
 * mano: listas desplegables de alcance y estado, y columnas de texto.
 * Se puede correr desde el editor; es idempotente.
 */
function prepararHojasNotificaciones() {
  const ss = getSpreadsheet();
  const disp = _hojaConEncabezado(ss, HOJA_DISPOSITIVOS, ENCABEZADO_DISPOSITIVOS);
  disp.getRange("A:F").setNumberFormat("@");
  const notif = _hojaConEncabezado(ss, HOJA_NOTIFICACIONES, ENCABEZADO_NOTIFICACIONES);
  notif.getRange("A:J").setNumberFormat("@");
  notif.getRange("M:M").setNumberFormat("@");
  notif.getRange("D2:D").setDataValidation(
    SpreadsheetApp.newDataValidation().requireValueInList(ALCANCES_NOTIFICACION, true).build()
  );
  notif.getRange("J2:J").setDataValidation(
    SpreadsheetApp.newDataValidation().requireValueInList(ESTADOS_NOTIFICACION, true).build()
  );
  notif.getRange("A1").setNote(
    "Para enviar desde la hoja: completá remitente_email (tiene que estar en usuarios), alcance " +
    "(global | organizaciones | usuarios), organizacion_ids (IDs o nombres separados por coma) o " +
    "usuarios (emails separados por coma), titulo y cuerpo; poné estado = PENDIENTE. " +
    "Dejá vacíos id, fecha, enviados, fallidos y detalle: los completa el script."
  );
  return { status: "success", message: "Hojas de notificaciones listas." };
}

/** Quién tiene acceso hoy y a qué organización pertenece. */
function _mapaAcceso(ss) {
  const tabla = function (nombre) {
    const sh = ss.getSheetByName(nombre);
    return sh && sh.getLastRow() >= 1 ? sh.getDataRange().getValues() : [[]];
  };
  const col = function (t, h) {
    return t[0].map(function (x) { return String(x).trim().toLowerCase(); }).indexOf(h);
  };
  const usuarios = tabla("usuarios");
  const membresias = tabla("usuario_organizacion");
  const organizaciones = tabla("organizaciones");
  const cEmail = col(usuarios, "email");
  const cMiembro = col(membresias, "usuario_email");
  const cOrg = col(membresias, "organizacion_id");
  const cIdOrg = col(organizaciones, "id");
  const cNombreOrg = col(organizaciones, "nombre");

  const orgs = {};
  organizaciones.slice(1).forEach(function (f) {
    if (cIdOrg >= 0 && f[cIdOrg]) orgs[String(f[cIdOrg]).trim()] = cNombreOrg >= 0 ? String(f[cNombreOrg]).trim() : "";
  });
  const enUsuarios = {};
  usuarios.slice(1).forEach(function (f) {
    if (cEmail >= 0 && f[cEmail]) enUsuarios[String(f[cEmail]).trim().toLowerCase()] = true;
  });
  const orgDe = {};
  membresias.slice(1).forEach(function (f) {
    if (cMiembro < 0 || cOrg < 0) return;
    const email = String(f[cMiembro]).trim().toLowerCase();
    const org = String(f[cOrg]).trim();
    if (enUsuarios[email] && orgs[org] !== undefined) orgDe[email] = org;
  });
  return { orgs: orgs, orgDe: orgDe };
}

/** Registra (o actualiza) el token de un dispositivo del usuario de la sesión. */
function _registrarDispositivo(ss, usuario, data) {
  const token = String(data.token || "").replace(/^'/, "").trim();
  if (!token) return { status: "error", message: "Falta el token del dispositivo." };
  const plataforma = String(data.plataforma || "").trim();
  const org = _mapaAcceso(ss).orgDe[usuario] || "";
  const sh = _hojaConEncabezado(ss, HOJA_DISPOSITIVOS, ENCABEZADO_DISPOSITIVOS);
  const ahora = new Date().toISOString();
  const fila = _findRowByColumnValue(sh, 4, token);
  if (fila !== -1) {
    // El mismo teléfono con otra cuenta: el token pasa al usuario actual.
    sh.getRange(fila, 2, 1, 5).setValues([[usuario, org, token, plataforma, ahora]]);
    return { status: "success", id: String(sh.getRange(fila, 1).getValue()) };
  }
  const id = _siguienteIdServidor(sh, ID_PREFIXES.dispositivos);
  sh.appendRow([id, usuario, org, token, plataforma, ahora]);
  return { status: "success", id: id };
}

/** Borra el token (al cerrar sesión). Solo el dueño del dispositivo. */
function _eliminarDispositivo(ss, usuario, data) {
  const token = String(data.token || "").replace(/^'/, "").trim();
  const sh = ss.getSheetByName(HOJA_DISPOSITIVOS);
  if (!sh || !token) return { status: "success", eliminados: 0 };
  const fila = _findRowByColumnValue(sh, 4, token);
  if (fila === -1) return { status: "success", eliminados: 0 };
  if (String(sh.getRange(fila, 2).getValue()).trim().toLowerCase() !== usuario) {
    return { status: "error", message: "Ese dispositivo es de otro usuario." };
  }
  sh.deleteRow(fila);
  return { status: "success", eliminados: 1 };
}

/** Lista de valores: acepta array o texto separado por comas. */
function _lista(valor) {
  const arr = Array.isArray(valor) ? valor : String(valor || "").split(",");
  return arr.map(function (v) { return String(v).replace(/^'/, "").trim(); }).filter(function (v) { return v; });
}

/**
 * Valida una solicitud de envío y la normaliza. Las organizaciones se pueden
 * indicar por ID o por nombre. Devuelve { error } o { solicitud }.
 */
function _normalizarSolicitud(ss, remitente, datos) {
  const acceso = _mapaAcceso(ss);
  if (!acceso.orgDe[remitente]) {
    return { error: "El remitente " + remitente + " no tiene acceso: tiene que estar en usuarios y pertenecer a una organización." };
  }
  const titulo = String(datos.titulo || "").replace(/^'/, "").trim();
  const cuerpo = String(datos.cuerpo || "").replace(/^'/, "").trim();
  if (!titulo || titulo.length > 100) return { error: "El título es obligatorio (hasta 100 caracteres)." };
  if (!cuerpo || cuerpo.length > 500) return { error: "El mensaje es obligatorio (hasta 500 caracteres)." };
  const alcance = String(datos.alcance || "").trim().toLowerCase();
  if (ALCANCES_NOTIFICACION.indexOf(alcance) === -1) {
    return { error: "Alcance inválido: usá global, organizaciones o usuarios." };
  }

  let organizacionIds = [];
  let usuarios = [];
  if (alcance === "organizaciones") {
    const porNombre = {};
    Object.keys(acceso.orgs).forEach(function (id) { porNombre[acceso.orgs[id].toLowerCase()] = id; });
    const desconocidas = [];
    _lista(datos.organizacion_ids).forEach(function (v) {
      const id = acceso.orgs[v] !== undefined ? v : porNombre[v.toLowerCase()];
      if (id) { if (organizacionIds.indexOf(id) === -1) organizacionIds.push(id); } else desconocidas.push(v);
    });
    if (desconocidas.length) return { error: "Organizaciones inexistentes: " + desconocidas.join(", ") };
    if (!organizacionIds.length) return { error: "Elegí al menos una organización." };
  }
  if (alcance === "usuarios") {
    const desconocidos = [];
    _lista(datos.usuarios).forEach(function (v) {
      const email = v.toLowerCase();
      if (acceso.orgDe[email]) { if (usuarios.indexOf(email) === -1) usuarios.push(email); } else desconocidos.push(v);
    });
    if (desconocidos.length) return { error: "Usuarios sin acceso o inexistentes: " + desconocidos.join(", ") };
    if (!usuarios.length) return { error: "Elegí al menos un usuario." };
  }

  const extra = {};
  const datosExtra = datos.datos && typeof datos.datos === "object" ? datos.datos : {};
  Object.keys(datosExtra).forEach(function (k) { extra[k] = String(datosExtra[k]); });
  if (datos.ruta) extra.ruta = String(datos.ruta).trim();

  return {
    acceso: acceso,
    solicitud: {
      remitente: remitente, alcance: alcance, organizacionIds: organizacionIds,
      usuarios: usuarios, titulo: titulo, cuerpo: cuerpo, datos: extra
    }
  };
}

/** Tokens de los dispositivos destinatarios (sin repetir). */
function _tokensDestino(ss, solicitud, acceso) {
  const sh = ss.getSheetByName(HOJA_DISPOSITIVOS);
  if (!sh || sh.getLastRow() < 2) return [];
  const filas = sh.getRange(2, 1, sh.getLastRow() - 1, 4).getValues();
  const tokens = [];
  filas.forEach(function (f) {
    const email = String(f[1]).trim().toLowerCase();
    const token = String(f[3]).replace(/^'/, "").trim();
    const org = acceso.orgDe[email]; // organización de HOY; sin acceso → no recibe
    if (!token || !org) return;
    const va =
      solicitud.alcance === "global" ||
      (solicitud.alcance === "organizaciones" && solicitud.organizacionIds.indexOf(org) !== -1) ||
      (solicitud.alcance === "usuarios" && solicitud.usuarios.indexOf(email) !== -1);
    if (va && tokens.indexOf(token) === -1) tokens.push(token);
  });
  return tokens;
}

function _base64Url(bytesOTexto) {
  return Utilities.base64EncodeWebSafe(bytesOTexto).replace(/=+$/, "");
}

/** Token OAuth para FCM a partir de la cuenta de servicio (JWT RS256). */
function _credencialFcm() {
  // 1) Propiedad del script FCM_SERVICE_ACCOUNT (si se cargó a mano).
  // 2) Si no, la credencial que embebe deploy.sh en credencial_fcm.js, un
  //    archivo generado desde la clave local que no se versiona.
  const crudo = PropertiesService.getScriptProperties().getProperty("FCM_SERVICE_ACCOUNT");
  let cuenta;
  if (crudo) {
    try { cuenta = JSON.parse(crudo); } catch (e) { return { error: "FCM_SERVICE_ACCOUNT no es un JSON válido." }; }
  } else if (typeof FCM_SERVICE_ACCOUNT_EMBEBIDA !== "undefined" && FCM_SERVICE_ACCOUNT_EMBEBIDA) {
    cuenta = FCM_SERVICE_ACCOUNT_EMBEBIDA;
  } else {
    return { error: "FCM no está configurado: falta la propiedad del script FCM_SERVICE_ACCOUNT (o desplegar con la clave local, ver deploy.sh)." };
  }
  if (!cuenta.client_email || !cuenta.private_key || !cuenta.project_id) {
    return { error: "FCM_SERVICE_ACCOUNT incompleto (faltan client_email, private_key o project_id)." };
  }
  const cache = CacheService.getScriptCache();
  const guardado = cache.get("fcm_access_token");
  if (guardado) return { token: guardado, proyecto: cuenta.project_id };

  const ahora = Math.floor(Date.now() / 1000);
  const cabecera = _base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const reclamo = _base64Url(JSON.stringify({
    iss: cuenta.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: ahora,
    exp: ahora + 3600
  }));
  const firma = _base64Url(Utilities.computeRsaSha256Signature(cabecera + "." + reclamo, cuenta.private_key));
  const res = UrlFetchApp.fetch("https://oauth2.googleapis.com/token", {
    method: "post",
    payload: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: cabecera + "." + reclamo + "." + firma },
    muteHttpExceptions: true
  });
  if (res.getResponseCode() !== 200) {
    return { error: "Google rechazó la cuenta de servicio de FCM: " + res.getContentText().slice(0, 200) };
  }
  const token = JSON.parse(res.getContentText()).access_token;
  cache.put("fcm_access_token", token, 3000); // 50 min (el token dura 60)
  return { token: token, proyecto: cuenta.project_id };
}

/** Envía a cada token. Devuelve { enviados, fallidos, invalidos[], errores[] }. */
function _enviarFcm(credencial, tokens, solicitud, notificacionId) {
  const url = "https://fcm.googleapis.com/v1/projects/" + credencial.proyecto + "/messages:send";
  const datos = Object.assign({}, solicitud.datos, {
    notificacion_id: notificacionId,
    titulo: solicitud.titulo,
    cuerpo: solicitud.cuerpo,
    canal: CANAL_ANDROID_NOTIFICACIONES
  });
  const resultado = { enviados: 0, fallidos: 0, invalidos: [], errores: [] };
  for (let i = 0; i < tokens.length; i += 50) {
    const lote = tokens.slice(i, i + 50);
    const pedidos = lote.map(function (token) {
      return {
        url: url,
        method: "post",
        contentType: "application/json",
        headers: { Authorization: "Bearer " + credencial.token },
        muteHttpExceptions: true,
        payload: JSON.stringify({
          message: {
            token: token,
            data: datos,
            android: { priority: "HIGH" },
            apns: { payload: { aps: { alert: { title: solicitud.titulo, body: solicitud.cuerpo }, sound: "default" } } }
          }
        })
      };
    });
    UrlFetchApp.fetchAll(pedidos).forEach(function (res, j) {
      const codigo = res.getResponseCode();
      if (codigo === 200) { resultado.enviados++; return; }
      resultado.fallidos++;
      const texto = res.getContentText();
      // Token vencido o de otra app: se borra para no reintentarlo.
      if (codigo === 404 || /UNREGISTERED|SENDER_ID_MISMATCH|registration token is not a valid/i.test(texto)) {
        resultado.invalidos.push(lote[j]);
      } else if (resultado.errores.length < 3) {
        resultado.errores.push(codigo + ": " + texto.slice(0, 150));
      }
    });
  }
  return resultado;
}

function _borrarTokens(ss, tokens) {
  const sh = ss.getSheetByName(HOJA_DISPOSITIVOS);
  if (!sh || !tokens.length) return;
  for (let r = sh.getLastRow(); r >= 2; r--) {
    if (tokens.indexOf(String(sh.getRange(r, 4).getValue()).replace(/^'/, "").trim()) !== -1) sh.deleteRow(r);
  }
}

/**
 * Valida, envía y deja el resultado en "notificaciones". Si [fila] viene
 * (envío desde la hoja), actualiza esa fila; si no, agrega una.
 */
function _procesarNotificacion(ss, remitente, datos, fila) {
  const sh = _hojaConEncabezado(ss, HOJA_NOTIFICACIONES, ENCABEZADO_NOTIFICACIONES);
  const norm = _normalizarSolicitud(ss, remitente, datos);
  let id = fila ? String(sh.getRange(fila, 1).getValue()).trim() : "";
  if (!id) id = _siguienteIdServidor(sh, ID_PREFIXES.notificaciones);

  const escribir = function (estado, enviados, fallidos, detalle) {
    const s = norm.solicitud || {};
    const valores = [
      id, new Date().toISOString(), remitente,
      s.alcance || String(datos.alcance || ""),
      (s.organizacionIds || _lista(datos.organizacion_ids)).join(", "),
      (s.usuarios || _lista(datos.usuarios)).join(", "),
      _sanitizarContraFormulas(s.titulo || String(datos.titulo || "")),
      _sanitizarContraFormulas(s.cuerpo || String(datos.cuerpo || "")),
      (s.datos && s.datos.ruta) || "",
      estado, enviados, fallidos, _sanitizarContraFormulas(detalle)
    ];
    if (fila) sh.getRange(fila, 1, 1, valores.length).setValues([valores]);
    else sh.appendRow(valores);
  };

  if (norm.error) {
    escribir("ERROR", 0, 0, norm.error);
    return { status: "error", id: id, message: norm.error };
  }
  const tokens = _tokensDestino(ss, norm.solicitud, norm.acceso);
  if (!tokens.length) {
    escribir("SIN_DESTINATARIOS", 0, 0, "Ningún destinatario tiene un dispositivo registrado.");
    return { status: "success", id: id, enviados: 0, fallidos: 0 };
  }
  const credencial = _credencialFcm();
  if (credencial.error) {
    escribir("ERROR", 0, tokens.length, credencial.error);
    return { status: "error", id: id, message: credencial.error };
  }
  const r = _enviarFcm(credencial, tokens, norm.solicitud, id);
  _borrarTokens(ss, r.invalidos);
  const detalle = (r.invalidos.length ? r.invalidos.length + " dispositivos dados de baja (token vencido). " : "") + r.errores.join(" | ");
  escribir(r.enviados > 0 || r.fallidos === 0 ? "ENVIADA" : "ERROR", r.enviados, r.fallidos, detalle);
  _appendAuditLog(ss, {
    usuario: remitente,
    hoja: HOJA_NOTIFICACIONES,
    celda: "A",
    valorAnterior: "null",
    valorNuevo: id + ": " + norm.solicitud.titulo,
    accion: "envio_notificacion",
    norma: "ISO/IEC 27001 §5.14",
    observaciones: "Alcance " + norm.solicitud.alcance + ": " + r.enviados + " enviadas, " + r.fallidos + " fallidas",
    organizacionId: norm.acceso.orgDe[remitente]
  });
  return { status: "success", id: id, enviados: r.enviados, fallidos: r.fallidos };
}

/** Envíos permitidos por remitente y por hora desde la app (anti-spam, ver DT-1). */
const LIMITE_NOTIFICACIONES_POR_HORA = 30;

/** Acción "enviar_notificacion" de la app. */
function _enviarNotificacion(ss, remitente, datos) {
  // El /exec es anónimo y el remitente lo declara la app (DT-1): se limita
  // la cantidad de envíos por remitente para acotar el abuso.
  const cache = CacheService.getScriptCache();
  const clave = "notif_" + Utilities.base64EncodeWebSafe(remitente).slice(0, 200);
  const usados = Number(cache.get(clave) || 0);
  if (usados >= LIMITE_NOTIFICACIONES_POR_HORA) {
    return { status: "error", message: "Límite de " + LIMITE_NOTIFICACIONES_POR_HORA + " notificaciones por hora alcanzado. Probá más tarde." };
  }
  cache.put(clave, String(usados + 1), 3600);
  return _procesarNotificacion(ss, remitente, datos, null);
}

/**
 * Envía las filas de "notificaciones" con estado PENDIENTE (cargadas a mano
 * en la hoja). Se puede correr desde el editor o con el disparador.
 */
function enviarNotificacionesPendientes() {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const ss = getSpreadsheet();
    const sh = _hojaConEncabezado(ss, HOJA_NOTIFICACIONES, ENCABEZADO_NOTIFICACIONES);
    const procesadas = [];
    for (let fila = 2; fila <= sh.getLastRow(); fila++) {
      const f = sh.getRange(fila, 1, 1, ENCABEZADO_NOTIFICACIONES.length).getValues()[0];
      if (String(f[COL_NOTIF.estado - 1]).trim().toUpperCase() !== "PENDIENTE") continue;
      const remitente = String(f[2]).trim().toLowerCase();
      const r = _procesarNotificacion(ss, remitente, {
        alcance: f[3], organizacion_ids: f[4], usuarios: f[5], titulo: f[6], cuerpo: f[7], ruta: f[8]
      }, fila);
      procesadas.push(r);
    }
    return { status: "success", procesadas: procesadas.length, resultados: procesadas };
  } finally {
    lock.releaseLock();
  }
}

/** Disparador al editar: si en "notificaciones" el estado pasa a PENDIENTE, envía. */
function alEditarNotificaciones(e) {
  if (!e || !e.range) return;
  const sh = e.range.getSheet();
  if (sh.getName() !== HOJA_NOTIFICACIONES) return;
  if (e.range.getColumn() > COL_NOTIF.estado || e.range.getLastColumn() < COL_NOTIF.estado) return;
  enviarNotificacionesPendientes();
}

/** Instala (una vez) el disparador que envía al marcar una fila PENDIENTE. */
function crearTriggerNotificacionesDesdeHoja() {
  ScriptApp.getProjectTriggers()
    .filter(function (t) { return t.getHandlerFunction() === "alEditarNotificaciones"; })
    .forEach(function (t) { ScriptApp.deleteTrigger(t); });
  ScriptApp.newTrigger("alEditarNotificaciones").forSpreadsheet(getSpreadsheet()).onEdit().create();
  return { status: "success", message: "Disparador de notificaciones instalado." };
}

function _findRowByColumnValue(sheet, columnIndex, value) {
  if (!value) return -1;
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return -1;
  const values = sheet.getRange(1, columnIndex, lastRow, 1).getValues();
  for (let i = 1; i < values.length; i++) {
    if (values[i][0] && values[i][0].toString().trim().toLowerCase() === value.toString().trim().toLowerCase()) {
      return i + 1;
    }
  }
  return -1;
}

function _appendAuditLog(ss, log) {
  try {
    const auditSheet = ss.getSheetByName("audit_log");
    if (!auditSheet) return;
    _asegurarEsquema(auditSheet, "audit_log");
    auditSheet.appendRow([
      _siguienteIdServidor(auditSheet, ID_PREFIXES.audit_log),
      new Date().toISOString(),
      log.usuario || "Sistema (Apps Script)",
      log.hoja,
      log.celda,
      log.valorAnterior,
      log.valorNuevo,
      log.accion,
      log.norma,
      log.observaciones,
      log.organizacionId || ""
    ]);
  } catch (e) {
    // Evitar romper la transacción si falla el log
  }
}

// =============================================================================
// MÓDULO TASAS — tasa oficial BCV (USD/EUR) vía dolarvzla.com
// =============================================================================
// Se eligió el endpoint SIN API key (https://rates.dolarvzla.com/bcv/current.json)
// en vez del que requiere generar/gestionar una x-dolarvzla-key: no hay
// autenticación que renovar ni credenciales que guardar en Apps Script
// (PropertiesService), la respuesta ya trae current/previous/changePercentage
// en la forma exacta que necesitamos, y con UrlFetchApp.fetch basta una sola
// llamada GET — cero pasos adicionales de setup.

/**
 * Convierte una fecha (Date o string) al formato 'yyyy-MM-dd', para poder
 * comparar la columna "fecha" (que Sheets suele autodetectar como Date real,
 * no texto) contra un string sin que la comparación falle siempre por tipo.
 */
function _fechaComoString(ss, valor) {
  return valor instanceof Date
    ? Utilities.formatDate(valor, ss.getSpreadsheetTimeZone(), 'yyyy-MM-dd')
    : valor.toString();
}

/** Siguiente id correlativo para la hoja "tasas" (formato t00000001). */
function _siguienteTasaId(sheet) {
  const totalDatos = Math.max(sheet.getLastRow() - 1, 0);
  const ids = totalDatos > 0 ? sheet.getRange(2, 1, totalDatos, 1).getValues() : [];
  let maxId = 0;
  ids.forEach(function (row) {
    const n = parseInt(row[0].toString().replace(/[^0-9]/g, ''), 10);
    if (!isNaN(n) && n > maxId) maxId = n;
  });
  return 't' + (maxId + 1).toString().padStart(8, '0');
}

/**
 * Crea o actualiza, en la hoja "tasas", la fila BCV global (organizacion_id
 * vacío) de [moneda] para la fecha [fecha] con [valor] — evita duplicar si
 * el trigger corre más de una vez el mismo día o si el BCV corrige la tasa
 * publicada.
 */
function _upsertTasaBcv(ss, sheet, fecha, moneda, valor) {
  const totalDatos = Math.max(sheet.getLastRow() - 1, 0);
  const filas = totalDatos > 0 ? sheet.getRange(2, 1, totalDatos, 6).getValues() : [];
  for (let i = 0; i < filas.length; i++) {
    const [id, filaFecha, filaMoneda, , filaFuente, filaOrgId] = filas[i];
    if (
      filaFuente === 'bcv' &&
      (filaOrgId || '') === '' &&
      filaMoneda === moneda &&
      _fechaComoString(ss, filaFecha) === fecha
    ) {
      sheet.getRange(i + 2, 4).setValue(valor);
      return id;
    }
  }
  const id = _siguienteTasaId(sheet);
  sheet.appendRow([id, fecha, moneda, valor, 'bcv', '']);
  return id;
}

/**
 * Obtiene la tasa oficial del BCV (USD y EUR) y la registra en la hoja
 * "tasas" — una fila por moneda (3FN: no empaqueta USD/EUR en la misma
 * fila). Si ya existe una fila BCV para esa fecha+moneda, la actualiza en
 * vez de duplicarla.
 */
function obtenerTasaBCV() {
  const URL = 'https://rates.dolarvzla.com/bcv/current.json';

  try {
    const response = UrlFetchApp.fetch(URL, { muteHttpExceptions: true });
    const codigo = response.getResponseCode();
    if (codigo !== 200) {
      throw new Error('HTTP ' + codigo + ': ' + response.getContentText());
    }

    const data = JSON.parse(response.getContentText());

    // Validar la forma esperada antes de leer campos anidados: si
    // dolarvzla.com cambia su contrato, esto falla rápido y claro en vez de
    // escribir "undefined" silenciosamente en la hoja.
    if (!data.current || !data.current.date || data.current.usd === undefined || data.current.eur === undefined) {
      throw new Error('Estructura de respuesta inesperada: ' + response.getContentText());
    }

    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName('tasas');
    if (!sheet) {
      sheet = ss.insertSheet('tasas');
      sheet.appendRow(['id', 'fecha', 'moneda', 'valor', 'fuente', 'organizacion_id']);
    }

    _upsertTasaBcv(ss, sheet, data.current.date, 'USD', data.current.usd);
    _upsertTasaBcv(ss, sheet, data.current.date, 'EUR', data.current.eur);

    return { status: "success", message: "Tasa del " + data.current.date + " actualizada.", fecha: data.current.date };
  } catch (err) {
    // El trigger diario llama a esta función e ignora el valor de retorno,
    // así que un fallo transitorio de red no genera un correo de fallo por
    // cada corte — queda en los logs de ejecución (Ver > Registros de
    // ejecución en el editor). El botón "Obtener tasa de hoy" de la app SÍ
    // usa este valor de retorno para avisarle al usuario si falló.
    Logger.log('obtenerTasaBCV: error al obtener/registrar la tasa BCV: ' + err.toString());
    return { status: "error", message: err.toString() };
  }
}

/**
 * Crea (reemplazando cualquier trigger previo de la misma función) el
 * disparador diario que ejecuta obtenerTasaBCV() automáticamente. Se corre
 * UNA sola vez a mano desde el editor — no hace falta repetirla salvo que
 * se quiera cambiar el horario.
 */
function crearTriggerDiarioTasas() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'obtenerTasaBCV') {
      ScriptApp.deleteTrigger(t);
    }
  });

  ScriptApp.newTrigger('obtenerTasaBCV')
    .timeBased()
    .everyDays(1)
    .atHour(8) // 8:00 am, zona horaria del proyecto (America/Caracas)
    .create();

  Logger.log('Trigger diario creado: obtenerTasaBCV se ejecutará todos los días a las 8am.');
}

// =============================================================================
// VALIDACIONES DE DATOS — enforcement de FK a nivel de Sheet
// =============================================================================
// Google Sheets no impone integridad referencial de forma nativa: nada evita
// que alguien edite una celda a mano y escriba un id que no existe. Esta
// función agrega listas desplegables (Data Validation) en las columnas que
// son FK, para que el propio Sheet rechace valores fuera del catálogo real
// — la defensa más barata contra "usar el nombre/valor en vez del ID".
// Se corre UNA sola vez a mano desde el editor (o de nuevo si cambian los
// rangos de alguna hoja catálogo).
function configurarValidacionesDatos() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  function requireListFromSheet(sourceSheetName, sourceColumnLetter) {
    const sourceRange = ss.getSheetByName(sourceSheetName)
      .getRange(sourceColumnLetter + '2:' + sourceColumnLetter + '1000');
    return SpreadsheetApp.newDataValidation()
      .requireValueInRange(sourceRange, true)
      .setAllowInvalid(false)
      .build();
  }

  const abonos = ss.getSheetByName('abonos');
  if (abonos) {
    abonos.getRange('E2:E1000').setDataValidation(requireListFromSheet('metodo pago', 'A'));
    abonos.getRange('F2:F1000').setDataValidation(requireListFromSheet('tasas', 'A'));
  }

  const ventas = ss.getSheetByName('ventas');
  if (ventas) {
    ventas.getRange('F2:F1000').setDataValidation(requireListFromSheet('metodo pago', 'A'));
  }

  Logger.log('Validaciones de datos (FK) configuradas en abonos.metodo_pago, abonos.tasa_id y ventas.tipo_pago.');
}

// =============================================================================
// AUDITORÍA DE INTEGRIDAD REFERENCIAL — mover huérfanos a "cuarentena"
// =============================================================================
// Las validaciones de datos de arriba previenen huérfanos NUEVOS, pero no
// dicen nada de los que ya existan (datos cargados antes de la validación,
// o filas editadas a mano en el Sheet saltándose la lista desplegable). Esta
// función es el chequeo de fondo: recorre las hojas transaccionales,
// confirma que cada FK resuelve a una fila real en su catálogo, y mueve a
// "cuarentena" (sin borrar el dato — queda el JSON original completo) toda
// fila que referencia algo que no existe. Se corre a mano cuando se
// sospecha de datos sucios (después de una migración, o periódicamente).
function auditarIntegridadReferencial() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  function idsDe(sheetName) {
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet || sheet.getLastRow() < 2) return {};
    const valores = sheet.getRange(2, 1, sheet.getLastRow() - 1, 1).getValues();
    const set = {};
    valores.forEach(function (r) { if (r[0]) set[r[0].toString().trim()] = true; });
    return set;
  }

  const clientesIds = idsDe('clientes');
  const ventasIds = idsDe('ventas');
  const metodoPagoIds = idsDe('metodo pago');
  const tasasIds = idsDe('tasas');

  let cuarentenaSheet = ss.getSheetByName('cuarentena');
  if (!cuarentenaSheet) {
    cuarentenaSheet = ss.insertSheet('cuarentena');
    cuarentenaSheet.appendRow([
      'id', 'id_registro_original', 'hoja_origen', 'fecha_deteccion', 'motivo_cuarentena',
      'datos_originales_json', 'estado', 'resolucion', 'hash_evidencia', 'organizacion_id'
    ]);
  }
  _asegurarEsquema(cuarentenaSheet, 'cuarentena');

  let totalCuarentena = 0;

  function moverACuarentena(sheetName, fila, headers, rowIndex, motivo) {
    const registro = {};
    headers.forEach(function (h, i) { registro[h] = fila[i]; });
    const json = JSON.stringify(registro);
    const hash = Utilities.base64Encode(
      Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, json)
    );
    cuarentenaSheet.appendRow([
      _siguienteIdServidor(cuarentenaSheet, ID_PREFIXES.cuarentena),
      fila[0], sheetName, new Date().toISOString(), motivo,
      json, 'PENDIENTE_REVISION', '', hash, registro['organizacion_id'] || ''
    ]);
    ss.getSheetByName(sheetName).deleteRow(rowIndex);
    totalCuarentena++;
  }

  // --- abonos: venta_id, metodo_pago y tasa_id deben resolver a algo real ---
  const abonosSheet = ss.getSheetByName('abonos');
  if (abonosSheet && abonosSheet.getLastRow() >= 2) {
    const headers = abonosSheet.getRange(1, 1, 1, abonosSheet.getLastColumn()).getValues()[0];
    // De abajo hacia arriba: deleteRow desplaza los índices de las filas
    // siguientes, así que iterar en reversa evita saltarse una fila.
    for (let r = abonosSheet.getLastRow(); r >= 2; r--) {
      const fila = abonosSheet.getRange(r, 1, 1, abonosSheet.getLastColumn()).getValues()[0];
      const [, ventaId, , , metodoPago, tasaId] = fila;
      if (ventaId && !ventasIds[ventaId.toString().trim()]) {
        moverACuarentena('abonos', fila, headers, r, 'venta_id "' + ventaId + '" no existe en ventas');
      } else if (metodoPago && !metodoPagoIds[metodoPago.toString().trim()]) {
        moverACuarentena('abonos', fila, headers, r, 'metodo_pago "' + metodoPago + '" no existe en metodo pago');
      } else if (tasaId && !tasasIds[tasaId.toString().trim()]) {
        moverACuarentena('abonos', fila, headers, r, 'tasa_id "' + tasaId + '" no existe en tasas');
      }
    }
  }

  // --- ventas: cliente_id debe resolver a un cliente real ---
  const ventasSheet = ss.getSheetByName('ventas');
  if (ventasSheet && ventasSheet.getLastRow() >= 2) {
    const headers = ventasSheet.getRange(1, 1, 1, ventasSheet.getLastColumn()).getValues()[0];
    for (let r = ventasSheet.getLastRow(); r >= 2; r--) {
      const fila = ventasSheet.getRange(r, 1, 1, ventasSheet.getLastColumn()).getValues()[0];
      const clienteId = fila[2];
      if (clienteId && !clientesIds[clienteId.toString().trim()]) {
        moverACuarentena('ventas', fila, headers, r, 'cliente_id "' + clienteId + '" no existe en clientes');
      }
    }
  }

  Logger.log('Auditoría de integridad referencial completa: ' + totalCuarentena + ' registro(s) movido(s) a cuarentena.');
  return { status: 'success', message: totalCuarentena + ' registro(s) huérfano(s) movido(s) a cuarentena.' };
}

function respond(data, code) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

// Caracteres que Sheets interpreta como inicio de fórmula/expresión al
// escribirlos con setValues() (CWE-1236 / CSV-Formula Injection): '=', '+',
// '-', '@' y tab. Anteponer una comilla simple fuerza texto plano — es la
// misma convención que usa la UI de Sheets cuando el usuario tipea un valor
// así a mano, y setValues()/setValue() la respetan igual (mismo parseo que
// "USER_ENTERED").
const _CARACTERES_FORMULA = ['=', '+', '-', '@', '\t'];

function _sanitizarContraFormulas(valor) {
  if (typeof valor === 'string') {
    if (valor.length > 0 && _CARACTERES_FORMULA.indexOf(valor.charAt(0)) !== -1) {
      return "'" + valor;
    }
    return valor;
  }
  if (Array.isArray(valor)) {
    return valor.map(_sanitizarContraFormulas);
  }
  if (valor && typeof valor === 'object') {
    const limpio = {};
    for (const key in valor) {
      if (Object.prototype.hasOwnProperty.call(valor, key)) {
        limpio[key] = _sanitizarContraFormulas(valor[key]);
      }
    }
    return limpio;
  }
  return valor;
}

// =============================================================================
// CÓDIGOS DE TELÉFONO Y CÉDULAS COMO TEXTO
// =============================================================================
// Sheets convierte "0414" en el número 414 al escribirlo. Además la app lee
// las hojas por gviz CSV, que tipa cada columna por mayoría y devuelve VACÍOS
// los valores del tipo minoritario: no alcanza con guardar los códigos nuevos
// como texto, toda la columna tiene que ser texto. Por eso cada escritura en
// "codigo de telefonos" repara la columna completa.

/**
 * Fuerza texto plano en una celda: sin la comilla, Sheets convierte
 * "070133805" (RIF) en el número 70133805 y se pierde el 0 inicial.
 * Vacío queda vacío.
 */
function _comoTexto(valor) {
  const s = (valor === null || valor === undefined ? "" : valor).toString().trim();
  if (s === "") return "";
  return s.charAt(0) === "'" ? s : "'" + s;
}

/** "414" / 414 → "0414". Deja intacto lo que no sea un número de 1 a 3 dígitos. */
function _normalizarCodigoTelefono(valor) {
  const s = (valor === null || valor === undefined ? "" : valor).toString().trim();
  return /^\d{1,3}$/.test(s) ? ("0000" + s).slice(-4) : s;
}

/** Pone la columna B (código) en formato texto y restaura el 0 inicial perdido. */
function _repararColumnaCodigosTelefono(sheet) {
  const ultimaFila = sheet.getLastRow();
  if (ultimaFila < 2) return;
  const rango = sheet.getRange(2, 2, ultimaFila - 1, 1);
  const valores = rango.getValues().map(function (fila) {
    return [_normalizarCodigoTelefono(fila[0])];
  });
  rango.setNumberFormat("@");
  rango.setValues(valores);
}

/**
 * Reparación manual (una sola vez, desde el editor de Apps Script):
 * convierte a texto los códigos que Sheets ya guardó como número.
 */
function repararCodigosTelefono() {
  const sheet = getSpreadsheet().getSheetByName("codigo de telefonos");
  if (!sheet) throw new Error('No existe la hoja "codigo de telefonos"');
  _repararColumnaCodigosTelefono(sheet);
}

// =============================================================================
// RESUMEN DIARIO (CIERRES)
// =============================================================================
// Columnas: id | fecha | nro_ventas | total_bs | total_usd | tasa_bcv |
//           tasa_usd | usd_comprados | usd_vendidos | organizacion_id
// El id (rd00000001…) lo genera el servidor. Además, solo puede haber un
// cierre por (fecha, organizacion_id).

const _COL_FECHA_RESUMEN = 2;
const _COL_ORG_RESUMEN = 10;

/** Fila (1-based) del cierre de [fecha] para [organizacionId], o -1. */
function _filaResumenPorFecha(ss, sheet, fecha, organizacionId) {
  const filas = sheet.getDataRange().getValues();
  for (let i = 1; i < filas.length; i++) {
    if (_fechaComoString(ss, filas[i][_COL_FECHA_RESUMEN - 1]) === fecha &&
        String(filas[i][_COL_ORG_RESUMEN - 1]).trim() === organizacionId) {
      return i + 1;
    }
  }
  return -1;
}

/**
 * La fecha se guarda como texto ISO (yyyy-MM-dd): si Sheets la convierte en
 * fecha, gviz la devuelve con el formato local (p. ej. 6/10/2026) y la app no
 * la puede leer. Además gviz devuelve vacíos si la columna mezcla tipos, así
 * que se normaliza la columna completa.
 */
function _repararColumnaFechasResumen(ss, sheet) {
  const ultimaFila = sheet.getLastRow();
  if (ultimaFila < 2) return;
  const rango = sheet.getRange(2, _COL_FECHA_RESUMEN, ultimaFila - 1, 1);
  const valores = rango.getValues().map(function (fila) {
    return [fila[0] === "" ? "" : _fechaComoString(ss, fila[0])];
  });
  rango.setNumberFormat("@");
  rango.setValues(valores);
}

function _handleResumenDiario(ss, sheet, action, id, data) {
  _asegurarEsquema(sheet, "resumen_diario");

  const organizacionId = (data.organizacion_id || "").toString().trim();
  if (!organizacionId) {
    return { status: "error", message: "Cierre inválido: falta organizacion_id." };
  }
  const valores = [
    data.nro_ventas || 0,
    data.total_bs || 0,
    data.total_usd || 0,
    data.tasa_bcv || 0,
    data.tasa_usd || 0,
    data.usd_comprados || 0,
    data.usd_vendidos || 0
  ];

  let fila;
  let idCierre = (id || data.id || "").toString().trim();
  let fecha;

  if (action === "create") {
    fecha = (data.fecha || "").toString().trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
      return { status: "error", message: "Cierre inválido: la fecha debe ser yyyy-MM-dd." };
    }
    if (_filaResumenPorFecha(ss, sheet, fecha, organizacionId) !== -1) {
      return { status: "error", message: "Ya existe un cierre para " + fecha + " en esta organización." };
    }
    idCierre = _siguienteIdServidor(sheet, ID_PREFIXES.resumen_diario);
    sheet.appendRow([idCierre, "'" + fecha].concat(valores).concat([organizacionId]));
    fila = sheet.getLastRow();
  } else {
    fila = idCierre ? _findRowById(sheet, idCierre) : -1;
    const actual = fila === -1 ? null : sheet.getRange(fila, 1, 1, _COL_ORG_RESUMEN).getValues()[0];
    // Un cierre de otra organización se trata como inexistente.
    if (!actual || String(actual[_COL_ORG_RESUMEN - 1]).trim() !== organizacionId) {
      return { status: "error", message: "No existe el cierre " + idCierre + " en esta organización." };
    }
    fecha = _fechaComoString(ss, actual[_COL_FECHA_RESUMEN - 1]);
    if (action === "update") {
      // La fecha y la organización no cambian: solo los montos.
      sheet.getRange(fila, 3, 1, valores.length).setValues([valores]);
    } else {
      sheet.deleteRow(fila);
    }
  }
  _repararColumnaFechasResumen(ss, sheet);

  _appendAuditLog(ss, {
    hoja: "resumen_diario",
    celda: "A" + fila,
    valorAnterior: action === "create" ? "null" : idCierre,
    valorNuevo: action === "delete" ? "ELIMINADO" : idCierre + " " + fecha + ": USD " + (data.total_usd || 0),
    accion: action === "create" ? "cierre_diario" : (action === "update" ? "actualizacion_resumen_diario" : "eliminacion_resumen_diario"),
    norma: "COBIT 2019",
    observaciones: "Cierre " + idCierre + " (" + fecha + ", " + organizacionId + ") vía App Móvil"
  });
  return { status: "success", message: "Cierre " + idCierre + " guardado", id: idCierre };
}

// =============================================================================
// MIGRACIÓN DE ESQUEMA: COLUMNA id EN TODAS LAS HOJAS (docs/estandar-hojas.md)
// =============================================================================

/** Migra [sheet] si es una de HOJAS_MIGRABLES y todavía no tiene columna id. */
function _asegurarEsquema(sheet, sheetName) {
  if (HOJAS_MIGRABLES.indexOf(sheetName) === -1) return;
  if (sheetName === "reporte_migracion") _quitarFilasDeTituloReporte(sheet);
  _migrarColumnaId(sheet, ID_PREFIXES[sheetName]);
}

/**
 * Si la columna A no es "id", la inserta y numera las filas existentes
 * (<prefijo>00000001…). Idempotente: no hace nada si ya está migrada.
 */
function _migrarColumnaId(sheet, prefijo) {
  const encabezado = String(sheet.getRange(1, 1).getValue()).trim().toLowerCase();
  if (encabezado === "id") return false;
  sheet.insertColumnBefore(1);
  sheet.getRange(1, 1).setValue("id");
  const ultimaFila = sheet.getLastRow();
  if (ultimaFila >= 2) {
    const ids = [];
    for (let i = 0; i < ultimaFila - 1; i++) {
      ids.push([prefijo + String(i + 1).padStart(8, "0")]);
    }
    sheet.getRange(2, 1, ids.length, 1).setValues(ids);
  }
  return true;
}

/**
 * "reporte_migracion" empezaba con 2 filas de título antes del encabezado.
 * Se convierten en filas de datos (métrica "Título" / "Estándares") para que
 * la hoja sea una tabla y no se pierda el texto. El encabezado pasa a
 * snake_case como el resto de las hojas.
 */
function _quitarFilasDeTituloReporte(sheet) {
  const valores = sheet.getDataRange().getValues();
  let fila = -1;
  for (let i = 0; i < valores.length; i++) {
    const a = String(valores[i][0]).trim().toLowerCase();
    if (a === "id" || a === "metrica") return; // ya es una tabla
    if (a.indexOf("métrica") === 0 || a.indexOf("metrica") === 0) { fila = i; break; }
  }
  if (fila <= 0) return;
  const etiquetas = ["Título del reporte", "Estándares aplicados"];
  const titulos = valores.slice(0, fila)
    .map(function (r, i) {
      return [etiquetas[i] || "Encabezado", String(r[0]), "", "", ORGANIZACION_ID_DEFAULT];
    })
    .filter(function (r) { return r[1].trim() !== ""; });
  sheet.deleteRows(1, fila);
  sheet.getRange(1, 1, 1, 5).setValues([["metrica", "valor_estado", "norma_aplicada", "observaciones", "organizacion_id"]]);
  if (titulos.length) {
    sheet.insertRowsAfter(1, titulos.length);
    sheet.getRange(2, 1, titulos.length, 5).setValues(titulos);
  }
}

/** Corre todas las migraciones pendientes. Idempotente. */
function migrarEsquema(ss) {
  ss = ss || getSpreadsheet();
  const migradas = [];
  HOJAS_MIGRABLES.forEach(function (nombre) {
    const sheet = ss.getSheetByName(nombre);
    if (!sheet) return;
    const antes = String(sheet.getRange(1, 1).getValue()).trim().toLowerCase();
    _asegurarEsquema(sheet, nombre);
    if (antes !== "id") migradas.push(nombre);
  });
  return { status: "success", message: "Esquema al día", migradas: migradas };
}

/** Error si la fila [rowIndex] no pertenece a data.organizacion_id. */
function _verificarOrganizacion(sheet, rowIndex, columna, data) {
  const esperada = (data.organizacion_id || "").toString().trim();
  const actual = String(sheet.getRange(rowIndex, columna).getValue()).trim();
  if (!esperada || esperada !== actual) {
    return { status: "error", message: "El registro no pertenece a esta organización." };
  }
  return null;
}

/** Siguiente nro de control del checklist (máximo + 1, columna B). */
function _siguienteNroChecklist(sheet) {
  const ultimaFila = sheet.getLastRow();
  if (ultimaFila < 2) return 1;
  const nros = sheet.getRange(2, 2, ultimaFila - 1, 1).getValues();
  let max = 0;
  nros.forEach(function (r) { const n = parseInt(r[0], 10); if (!isNaN(n) && n > max) max = n; });
  return max + 1;
}
