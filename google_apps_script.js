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
    const action = payload.action; // "create", "update", "delete", "toggle_checklist", "upload_image"
    const sheetName = payload.sheet;
    const data = payload.data || {};
    const id = payload.id || (data ? data.id : null);

    const ss = getSpreadsheet();

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
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

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
    // CRUD DE HOJAS
    // =========================================================================
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      return respond({ status: "error", message: "Hoja '" + sheetName + "' no encontrada" }, 404);
    }

    let result = {};

    switch (action) {
      case "create":
        result = _handleCreate(ss, sheet, sheetName, data);
        break;

      case "update":
        result = _handleUpdate(ss, sheet, sheetName, id, data);
        break;

      case "delete":
        result = _handleDelete(ss, sheet, sheetName, id);
        break;

      case "toggle_checklist":
        result = _handleToggleChecklist(ss, sheet, payload.nro, payload.estado);
        break;

      case "toggle_seguridad":
        result = _handleToggleSeguridad(ss, sheet, payload.campo, payload.valor, payload.organizacion_id);
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
// HANDLERS CRUD
// =============================================================================

function _handleCreate(ss, sheet, sheetName, data) {
  const nextRow = sheet.getLastRow() + 1;
  let rowValues = [];

  if (sheetName === "clientes") {
    rowValues = [
      data.id,
      data.nombre || "",
      data.telefono || "",
      data.email || "",
      data.saldo_deuda_usd || 0.0,
      data.fecha_registro || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.organizacion_id || "67774411-6aa1-4aa3-a4b2-d3fc6913b768"
    ];
  } else if (sheetName === "inventario") {
    const fotoUrl = data.foto_url || "";
    const fotoFormula = fotoUrl ? '=IF(H' + nextRow + '="","",IMAGE(H' + nextRow + '))' : "";
    rowValues = [
      data.id,
      data.cantidad || 0,
      data.nombre || "",
      data.marca || "",
      data.modelo || "",
      data.talla || "",
      data.precio_usd || 0.0,
      fotoUrl,
      fotoFormula,
      data.organizacion_id || "67774411-6aa1-4aa3-a4b2-d3fc6913b768"
    ];
  } else if (sheetName === "ventas") {
    const r = nextRow;
    rowValues = [
      data.id,
      data.fecha || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.cliente_id || "",
      data.item_id || "",
      data.cantidad || 1,
      data.tasa_bcv || 0.0,
      data.tasa_usd || 0.0,
      data.tipo_pago || "Efectivo",
      data.comision_pago_movil_bs || 0.0,
      '=IFERROR(E' + r + '*INDEX(inventario!G:G, MATCH(D' + r + ', inventario!A:A, 0))*F' + r + ', "ERROR")',
      '=IFERROR(E' + r + '*INDEX(inventario!G:G, MATCH(D' + r + ', inventario!A:A, 0)), "ERROR")',
      data.abono_usd || 0.0,
      '=N' + r + '-L' + r,
      '=K' + r,
      '=IF(AND(ABS(J' + r + '-E' + r + '*INDEX(inventario!G:G,MATCH(D' + r + ',inventario!A:A,0))*F' + r + ')<0.01, ABS(K' + r + '-E' + r + '*INDEX(inventario!G:G,MATCH(D' + r + ',inventario!A:A,0)))<0.01, ABS(M' + r + '-(N' + r + '-L' + r + '))<0.01),"OK","ERROR")',
      data.estado || "Pendiente",
      data.organizacion_id || "67774411-6aa1-4aa3-a4b2-d3fc6913b768"
    ];
  } else if (sheetName === "compras_divisas") {
    rowValues = [
      data.id,
      data.fecha_compra || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.fecha_entrega || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"),
      data.capital_usd || 0.0,
      data.comision_binance_usd || 0.0,
      data.numero_orden || "",
      data.plataforma || "",
      data.vendedor || "",
      data.tasa_bcv || 0.0,
      data.tasa_usd || 0.0,
      data.validacion || "OK",
      data.organizacion_id || "67774411-6aa1-4aa3-a4b2-d3fc6913b768"
    ];
  } else {
    // Genérico
    rowValues = Object.values(data);
  }

  sheet.appendRow(rowValues);

  _appendAuditLog(ss, {
    hoja: sheetName,
    celda: "A" + nextRow,
    valorAnterior: "null",
    valorNuevo: data.id || "nuevo_registro",
    accion: "creacion_" + sheetName,
    norma: "ISO 8000 §4.2",
    observaciones: "Registro insertado vía App Móvil"
  });

  return { status: "success", message: "Registro creado exitosamente", row: nextRow, id: data.id };
}

function _handleUpdate(ss, sheet, sheetName, id, data) {
  const rowIndex = _findRowById(sheet, id);
  if (rowIndex === -1) {
    return { status: "error", message: "Registro con ID '" + id + "' no encontrado en " + sheetName };
  }

  if (sheetName === "clientes") {
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 2).setValue(data.nombre);
    if (data.telefono !== undefined) sheet.getRange(rowIndex, 3).setValue(data.telefono);
    if (data.email !== undefined) sheet.getRange(rowIndex, 4).setValue(data.email);
    if (data.saldo_deuda_usd !== undefined) sheet.getRange(rowIndex, 5).setValue(data.saldo_deuda_usd);
  } else if (sheetName === "inventario") {
    if (data.cantidad !== undefined) sheet.getRange(rowIndex, 2).setValue(data.cantidad);
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 3).setValue(data.nombre);
    if (data.marca !== undefined) sheet.getRange(rowIndex, 4).setValue(data.marca);
    if (data.modelo !== undefined) sheet.getRange(rowIndex, 5).setValue(data.modelo);
    if (data.talla !== undefined) sheet.getRange(rowIndex, 6).setValue(data.talla);
    if (data.precio_usd !== undefined) sheet.getRange(rowIndex, 7).setValue(data.precio_usd);
    if (data.foto_url !== undefined) {
      sheet.getRange(rowIndex, 8).setValue(data.foto_url);
      sheet.getRange(rowIndex, 9).setFormula('=IF(H' + rowIndex + '="","",IMAGE(H' + rowIndex + '))');
    }
  } else if (sheetName === "ventas") {
    if (data.cantidad !== undefined) sheet.getRange(rowIndex, 5).setValue(data.cantidad);
    if (data.tasa_bcv !== undefined) sheet.getRange(rowIndex, 6).setValue(data.tasa_bcv);
    if (data.tasa_usd !== undefined) sheet.getRange(rowIndex, 7).setValue(data.tasa_usd);
    if (data.tipo_pago !== undefined) sheet.getRange(rowIndex, 8).setValue(data.tipo_pago);
    if (data.comision_pago_movil_bs !== undefined) sheet.getRange(rowIndex, 9).setValue(data.comision_pago_movil_bs);
    if (data.abono_usd !== undefined) sheet.getRange(rowIndex, 12).setValue(data.abono_usd);
    if (data.estado !== undefined) sheet.getRange(rowIndex, 16).setValue(data.estado);
  } else if (sheetName === "compras_divisas") {
    if (data.fecha_entrega !== undefined) sheet.getRange(rowIndex, 3).setValue(data.fecha_entrega);
    if (data.capital_usd !== undefined) sheet.getRange(rowIndex, 4).setValue(data.capital_usd);
    if (data.comision_binance_usd !== undefined) sheet.getRange(rowIndex, 5).setValue(data.comision_binance_usd);
    if (data.numero_orden !== undefined) sheet.getRange(rowIndex, 6).setValue(data.numero_orden);
    if (data.plataforma !== undefined) sheet.getRange(rowIndex, 7).setValue(data.plataforma);
    if (data.vendedor !== undefined) sheet.getRange(rowIndex, 8).setValue(data.vendedor);
    if (data.tasa_bcv !== undefined) sheet.getRange(rowIndex, 9).setValue(data.tasa_bcv);
    if (data.tasa_usd !== undefined) sheet.getRange(rowIndex, 10).setValue(data.tasa_usd);
  }

  _appendAuditLog(ss, {
    hoja: sheetName,
    celda: "A" + rowIndex,
    valorAnterior: "registro_existente",
    valorNuevo: id,
    accion: "actualizacion_" + sheetName,
    norma: "ISO 8000 §4.2",
    observaciones: "Modificación de campos vía App Móvil"
  });

  return { status: "success", message: "Registro " + id + " actualizado correctamente" };
}

function _handleDelete(ss, sheet, sheetName, id) {
  const rowIndex = _findRowById(sheet, id);
  if (rowIndex === -1) {
    return { status: "error", message: "Registro con ID '" + id + "' no encontrado en " + sheetName };
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

function _handleToggleChecklist(ss, sheet, nro, nuevoEstado) {
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] == nro) {
      sheet.getRange(i + 1, 4).setValue(nuevoEstado);
      sheet.getRange(i + 1, 6).setValue(new Date().toISOString());

      _appendAuditLog(ss, {
        hoja: "checklist_iso",
        celda: "D" + (i + 1),
        valorAnterior: data[i][3],
        valorNuevo: nuevoEstado,
        accion: "toggle_checklist_iso",
        norma: data[i][2] || "ISO/IEC 27001",
        observaciones: "Control #" + nro + " actualizado a " + nuevoEstado
      });

      return { status: "success", message: "Checklist #" + nro + " actualizado a " + nuevoEstado };
    }
  }
  return { status: "error", message: "Control #" + nro + " no encontrado" };
}

function _handleToggleSeguridad(ss, sheet, campo, valor, organizacionId) {
  const columnMap = { biometrico: 1, desbloqueo_facial: 2, dos_factores: 3 };
  const col = columnMap[campo];
  if (!col) {
    return { status: "error", message: "Campo de seguridad inválido: " + campo };
  }

  const orgId = organizacionId || "67774411-6aa1-4aa3-a4b2-d3fc6913b768";
  const nuevoValor = !!valor;
  const rowIndex = _findRowByOrgId(sheet, orgId);

  let valorAnterior = "desconocido";
  if (rowIndex !== -1) {
    valorAnterior = sheet.getRange(rowIndex, col).getValue();
    sheet.getRange(rowIndex, col).setValue(nuevoValor);
  } else {
    // No existe fila para esta organización todavía: se crea una nueva
    // con valores por defecto (true), sobreescribiendo solo el campo alternado.
    const row = [true, true, true, orgId];
    row[col - 1] = nuevoValor;
    sheet.appendRow(row);
  }

  _appendAuditLog(ss, {
    hoja: "seguridad",
    celda: String.fromCharCode(64 + col) + (rowIndex !== -1 ? rowIndex : sheet.getLastRow()),
    valorAnterior: valorAnterior,
    valorNuevo: nuevoValor,
    accion: "cambio_config_seguridad",
    norma: "ISO/IEC 27001 §9.4",
    observaciones: "Campo '" + campo + "' de la organización '" + orgId + "' actualizado a " + nuevoValor
  });

  return { status: "success", campo: campo, valor: nuevoValor, organizacion_id: orgId };
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

function _findRowByOrgId(sheet, organizacionId) {
  if (!organizacionId) return -1;
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return -1;
  const values = sheet.getRange(1, 4, lastRow, 1).getValues();
  for (let i = 1; i < values.length; i++) {
    if (values[i][0] && values[i][0].toString().trim().toLowerCase() === organizacionId.toString().trim().toLowerCase()) {
      return i + 1;
    }
  }
  return -1;
}

function _appendAuditLog(ss, log) {
  try {
    const auditSheet = ss.getSheetByName("audit_log");
    if (!auditSheet) return;
    auditSheet.appendRow([
      new Date().toISOString(),
      "Operador App Móvil (Apps Script)",
      log.hoja,
      log.celda,
      log.valorAnterior,
      log.valorNuevo,
      log.accion,
      log.norma,
      log.observaciones
    ]);
  } catch (e) {
    // Evitar romper la transacción si falla el log
  }
}

function respond(data, code) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
