/// Código fuente completo de Google Apps Script para copiar y pegar en Extensiones > Apps Script
const String googleAppsScriptSourceCode = r'''
const DRIVE_FOLDER_ID = "1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD";

function doGet(e) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  return ContentService.createTextOutput(JSON.stringify({
    status: "ok",
    message: "Estilo Neutral Apps Script Web App activo",
    spreadsheetId: ss.getId(),
    sheets: ss.getSheets().map(function(s) { return s.getName(); })
  })).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(10000);
  } catch (err) {
    return respond({ status: "error", message: "Servidor ocupado" }, 503);
  }

  try {
    const payload = JSON.parse(e.postData.contents);
    const action = payload.action;
    const sheetName = payload.sheet;
    const data = payload.data || {};
    const id = payload.id || (data ? data.id : null);
    const ss = SpreadsheetApp.getActiveSpreadsheet();

    if (action === "upload_image") {
      const folder = DriveApp.getFolderById(DRIVE_FOLDER_ID);
      const decodedBytes = Utilities.base64Decode(payload.base64Data);
      const blob = Utilities.newBlob(decodedBytes, payload.mimeType || "image/jpeg", payload.fileName || "foto.jpg");
      const file = folder.createFile(blob);
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      return respond({ status: "success", fileId: file.getId(), fileUrl: "https://lh3.googleusercontent.com/d/" + file.getId() });
    }

    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) return respond({ status: "error", message: "Hoja no encontrada" }, 404);

    let result = {};
    if (action === "create") {
      const nextRow = sheet.getLastRow() + 1;
      let rowValues = [];
      if (sheetName === "clientes") {
        rowValues = [data.id, data.nombre || "", data.telefono || "", data.email || "", data.saldo_deuda_usd || 0.0, data.fecha_registro || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd")];
      } else if (sheetName === "inventario") {
        const fUrl = data.foto_url || "";
        rowValues = [data.id, data.cantidad || 0, data.nombre || "", data.marca || "", data.modelo || "", data.talla || "", data.precio_usd || 0.0, fUrl, fUrl ? '=IF(H' + nextRow + '="","",IMAGE(H' + nextRow + '))' : ""];
      } else if (sheetName === "ventas") {
        const r = nextRow;
        rowValues = [data.id, data.fecha || Utilities.formatDate(new Date(), "GMT-4", "yyyy-MM-dd"), data.cliente_id || "", data.item_id || "", data.cantidad || 1, data.tasa_bcv || 0.0, data.tasa_usd || 0.0, data.tipo_pago || "Efectivo", data.comision_pago_movil_bs || 0.0, '=IFERROR(E' + r + '*INDEX(inventario!G:G, MATCH(D' + r + ', inventario!A:A, 0))*F' + r + ', "ERROR")', '=IFERROR(E' + r + '*INDEX(inventario!G:G, MATCH(D' + r + ', inventario!A:A, 0)), "ERROR")', data.abono_usd || 0.0, '=N' + r + '-L' + r, '=K' + r, '=IF(AND(ABS(J' + r + '-E' + r + '*INDEX(inventario!G:G,MATCH(D' + r + ',inventario!A:A,0))*F' + r + ')<0.01, ABS(K' + r + '-E' + r + '*INDEX(inventario!G:G,MATCH(D' + r + ',inventario!A:A,0)))<0.01, ABS(M' + r + '-(N' + r + '-L' + r + '))<0.01),"OK","ERROR")', data.estado || "Pendiente"];
      } else if (sheetName === "compras_divisas") {
        rowValues = [data.id, data.fecha_compra, data.fecha_entrega, data.capital_usd || 0.0, data.comision_binance_usd || 0.0, data.numero_orden || "", data.plataforma || "", data.vendedor || "", data.tasa_bcv || 0.0, data.tasa_usd || 0.0, data.validacion || "OK"];
      } else {
        rowValues = Object.values(data);
      }
      sheet.appendRow(rowValues);
      result = { status: "success", row: nextRow, id: data.id };
    } else if (action === "update") {
      const rowIndex = _findRowById(sheet, id);
      if (rowIndex !== -1) {
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
        }
        result = { status: "success", id: id };
      } else {
        result = { status: "error", message: "ID no encontrado" };
      }
    } else if (action === "delete") {
      const rowIndex = _findRowById(sheet, id);
      if (rowIndex !== -1) {
        sheet.deleteRow(rowIndex);
        result = { status: "success", id: id };
      } else {
        result = { status: "error", message: "ID no encontrado" };
      }
    }
    return respond(result);
  } catch (err) {
    return respond({ status: "error", message: err.toString() }, 500);
  } finally {
    lock.releaseLock();
  }
}

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

function respond(data) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);
}
''';
