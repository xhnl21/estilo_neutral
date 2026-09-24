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
      data.marca || "",
      data.modelo || "",
      data.talla || "",
      data.precio_usd || 0.0,
      fotoId,
      fotoFormula,
      data.organizacion_id || "67774411-6aa1-4aa3-a4b2-d3fc6913b768"
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
      data.organizacion_id || "67774411-6aa1-4aa3-a4b2-d3fc6913b768"
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
      data.organizacion_id || ""
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
  } else if (sheetName === "usuarios") {
    rowValues = [
      data.id,
      (data.email || "").toString().trim().toLowerCase(),
      data.nombre || ""
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
      (data.usuario_email || "").toString().trim().toLowerCase(),
      data.organizacion_id || ""
    ];
  } else if (sheetName === "metodo pago") {
    rowValues = [
      data.id,
      data.nombre || "",
      data.status !== undefined ? data.status : true
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
    valorNuevo: data.id || data.usuario_email || "nuevo_registro",
    accion: "creacion_" + sheetName,
    norma: "ISO 8000 §4.2",
    observaciones: "Registro insertado vía App Móvil"
  });

  return { status: "success", message: "Registro creado exitosamente", row: nextRow, id: data.id || data.usuario_email };
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
    if (data.numero_orden !== undefined) sheet.getRange(rowIndex, 6).setValue(data.numero_orden);
    if (data.plataforma !== undefined) sheet.getRange(rowIndex, 7).setValue(data.plataforma);
    if (data.vendedor !== undefined) sheet.getRange(rowIndex, 8).setValue(data.vendedor);
    if (data.tasa_bcv !== undefined) sheet.getRange(rowIndex, 9).setValue(data.tasa_bcv);
    if (data.tasa_usd !== undefined) sheet.getRange(rowIndex, 10).setValue(data.tasa_usd);
  } else if (sheetName === "usuarios") {
    if (data.email !== undefined) sheet.getRange(rowIndex, 2).setValue(data.email.toString().trim().toLowerCase());
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 3).setValue(data.nombre);
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
    if (data.organizacion_id !== undefined) sheet.getRange(rowIndex, 2).setValue(data.organizacion_id);
  } else if (sheetName === "metodo pago") {
    if (data.nombre !== undefined) sheet.getRange(rowIndex, 2).setValue(data.nombre);
    if (data.status !== undefined) sheet.getRange(rowIndex, 3).setValue(data.status);
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

function _handleSetMetodoSeguridad(ss, sheet, biometrico, desbloqueoFacial, dosFactores, usuarioEmail) {
  const email = (usuarioEmail || "").toString().trim().toLowerCase();
  const rowIndex = _findRowByColumnValue(sheet, 4, email);
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
    const prev = sheet.getRange(rowIndex, 1, 1, 3).getValues()[0];
    anterior = JSON.stringify(prev);
    sheet.getRange(rowIndex, 1, 1, 4).setValues([rowValues]);
  } else {
    sheet.appendRow(rowValues);
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
      'id_registro_original', 'hoja_origen', 'fecha_deteccion', 'motivo_cuarentena',
      'datos_originales_json', 'estado', 'resolucion', 'hash_evidencia', 'organizacion_id'
    ]);
  }

  let totalCuarentena = 0;

  function moverACuarentena(sheetName, fila, headers, rowIndex, motivo) {
    const registro = {};
    headers.forEach(function (h, i) { registro[h] = fila[i]; });
    const json = JSON.stringify(registro);
    const hash = Utilities.base64Encode(
      Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, json)
    );
    cuarentenaSheet.appendRow([
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
