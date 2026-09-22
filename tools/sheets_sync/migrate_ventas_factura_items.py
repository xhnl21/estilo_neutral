#!/usr/bin/env python3
"""
Migra el Google Sheet real "Estilo Neutral" al esquema de factura con
múltiples ítems (ver docs/google/multi-organizacion.md y
docs/casos-de-uso.md UC-30/31/32):

  1. Lee las filas actuales de "ventas" (esquema viejo: item_id/cantidad en
     la misma fila) y el precio actual de cada producto en "inventario".
  2. Crea la hoja "venta_items" (id, venta_id, item_id, cantidad, precio_usd,
     subtotal_usd) con una fila por cada venta vieja, usando el precio
     ACTUAL del producto (decisión: más simple que reconstruir el precio
     histórico exacto).
  3. Reescribe "ventas" con el esquema nuevo de header (sin item_id/
     cantidad), con monto_bs/monto_usd como fórmulas que suman los
     subtotales de "venta_items".
  4. Corrige las fórmulas de "resumen_diario" para que apunten a las nuevas
     columnas de "ventas" (varias columnas se corrieron de lugar).

Usa las mismas credenciales OAuth que migrate_multiorg_schema.py
(client_secret.json / token.json en esta carpeta).
"""
import sys
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/drive"]
SPREADSHEET_ID = "1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI"
ORG_ID = "67774411-6aa1-4aa3-a4b2-d3fc6913b768"

SCRIPT_DIR = Path(__file__).resolve().parent
CLIENT_SECRET_FILE = SCRIPT_DIR / "client_secret.json"
TOKEN_FILE = SCRIPT_DIR / "token.json"


def get_credentials() -> Credentials:
    creds = None
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CLIENT_SECRET_FILE.exists():
                sys.exit(f"Falta {CLIENT_SECRET_FILE}.")
            flow = InstalledAppFlow.from_client_secrets_file(str(CLIENT_SECRET_FILE), SCOPES)
            creds = flow.run_local_server(port=0)
        TOKEN_FILE.write_text(creds.to_json())
    return creds


def to_float(value) -> float:
    """Convierte un valor leído con UNFORMATTED_VALUE (ya numérico) o texto a float."""
    if value is None or value == "":
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if "," in text:
        text = text.replace(".", "").replace(",", ".")
    try:
        return float(text)
    except ValueError:
        return 0.0


def main() -> None:
    creds = get_credentials()
    sheets = build("sheets", "v4", credentials=creds).spreadsheets()

    existing = sheets.get(spreadsheetId=SPREADSHEET_ID).execute()
    existing_titles = {s["properties"]["title"] for s in existing["sheets"]}
    print(f"Hojas actuales: {sorted(existing_titles)}")

    print("Leyendo 'ventas' (esquema viejo) e 'inventario'...")
    # Se leen las filas dos veces: FORMATTED_VALUE para columnas de texto (id,
    # fecha, tipo_pago, validacion, estado — para no arriesgar que una fecha
    # nativa de Sheets vuelva como número de serie) y UNFORMATTED_VALUE para
    # las numéricas (evita parsear el separador decimal "," del locale es-ES).
    ventas_texto = sheets.values().get(spreadsheetId=SPREADSHEET_ID, range="ventas!A2:Q").execute().get("values", [])
    ventas_numeros = sheets.values().get(
        spreadsheetId=SPREADSHEET_ID, range="ventas!A2:Q", valueRenderOption="UNFORMATTED_VALUE"
    ).execute().get("values", [])
    inventario_rows = sheets.values().get(
        spreadsheetId=SPREADSHEET_ID, range="inventario!A2:J", valueRenderOption="UNFORMATTED_VALUE"
    ).execute().get("values", [])
    precio_por_producto = {row[0]: to_float(row[6]) for row in inventario_rows if row}

    if not ventas_texto:
        sys.exit("No hay filas en 'ventas' para migrar (¿ya se migró antes?).")

    print(f"{len(ventas_texto)} venta(s) vieja(s) encontrada(s).")

    if "venta_items" not in existing_titles:
        sheets.batchUpdate(
            spreadsheetId=SPREADSHEET_ID,
            body={"requests": [{"addSheet": {"properties": {"title": "venta_items"}}}]},
        ).execute()
        print("Creada la hoja 'venta_items'.")
    else:
        print("'venta_items' ya existe, no se recrea.")

    venta_items_values = [["id", "venta_id", "item_id", "cantidad", "precio_usd", "subtotal_usd"]]
    ventas_nuevas_values = [
        ["id", "fecha", "cliente_id", "tasa_bcv", "tasa_usd", "tipo_pago", "comision_pago_movil_bs",
         "monto_bs", "monto_usd", "abono_usd", "deuda_usd", "total_pagar_usd", "validacion", "estado", "organizacion_id"]
    ]

    for i, (texto, numeros) in enumerate(zip(ventas_texto, ventas_numeros), start=1):
        texto = texto + [""] * (17 - len(texto))
        numeros = numeros + [0] * (17 - len(numeros))
        # Columnas de texto (id=0, fecha=1, cliente_id=2, item_id=3,
        # tipo_pago=7, validacion=14, estado=15, organizacion_id=16) vienen
        # de `texto`; las numéricas (cantidad=4, tasa_bcv=5, tasa_usd=6,
        # comision_pago_movil_bs=8, abono_usd=11) vienen de `numeros`.
        venta_id, fecha, cliente_id, item_id = texto[0], texto[1], texto[2], texto[3]
        tipo_pago, validacion, estado, organizacion_id = texto[7], texto[14], texto[15], texto[16]
        cantidad, tasa_bcv, tasa_usd, comision_pago_movil_bs, abono_usd = (
            numeros[4], numeros[5], numeros[6], numeros[8], numeros[11]
        )

        precio_usd = precio_por_producto.get(item_id, 0.0)
        cantidad_num = int(to_float(cantidad)) or 1
        item_row_num = i + 1  # +1 porque la fila 1 es encabezado
        venta_items_values.append([
            f"vi{i:08d}", venta_id, item_id, cantidad_num, precio_usd,
            f"=D{item_row_num}*E{item_row_num}",
        ])

        # Nota: estas fórmulas se escriben con USER_ENTERED vía la API de
        # Sheets, que respeta el separador de argumentos del locale de la
        # planilla (";", como ya usan las fórmulas existentes de
        # resumen_diario) — a diferencia de Apps Script, que siempre acepta
        # comas independientemente del locale.
        r = i + 1
        ventas_nuevas_values.append([
            venta_id, fecha, cliente_id, to_float(tasa_bcv), to_float(tasa_usd), tipo_pago or "Efectivo",
            to_float(comision_pago_movil_bs), f"=I{r}*D{r}",
            f"=SUMIF(venta_items!B:B; A{r}; venta_items!F:F)",
            to_float(abono_usd), f"=L{r}-J{r}", f"=I{r}",
            validacion or "OK", estado or "Pendiente", organizacion_id or ORG_ID,
        ])

    print("Escribiendo 'venta_items'...")
    sheets.values().update(
        spreadsheetId=SPREADSHEET_ID,
        range=f"venta_items!A1:F{len(venta_items_values)}",
        valueInputOption="USER_ENTERED",
        body={"values": venta_items_values},
    ).execute()

    print("Reescribiendo 'ventas' con el esquema nuevo...")
    # Limpia primero por si el layout viejo tenía más columnas (Q) que el nuevo (O).
    sheets.values().clear(spreadsheetId=SPREADSHEET_ID, range="ventas!A1:Q1000").execute()
    sheets.values().update(
        spreadsheetId=SPREADSHEET_ID,
        range=f"ventas!A1:O{len(ventas_nuevas_values)}",
        valueInputOption="USER_ENTERED",
        body={"values": ventas_nuevas_values},
    ).execute()

    print("Corrigiendo fórmulas de 'resumen_diario' (columnas de 'ventas' se corrieron)...")
    resumen_rows = sheets.values().get(
        spreadsheetId=SPREADSHEET_ID, range="resumen_diario!A2:I", valueRenderOption="FORMULA"
    ).execute().get("values", [])
    # Las fórmulas de nro_ventas (col. B, usa ventas!B:B fecha) y usd_comprados
    # (col. G, usa compras_divisas) no cambian de columna — solo se reescriben
    # las que sí referencian columnas de "ventas" que se corrieron de lugar.
    if resumen_rows:
        updates = []
        for idx, row in enumerate(resumen_rows):
            if not row:
                continue
            r = idx + 2
            updates.append({"range": f"resumen_diario!C{r}", "values": [[f"=SUMIF(ventas!B:B; A{r}; ventas!H:H)"]]})
            updates.append({"range": f"resumen_diario!D{r}", "values": [[f"=SUMIF(ventas!B:B; A{r}; ventas!I:I)"]]})
            updates.append({"range": f"resumen_diario!E{r}", "values": [[f'=IFERROR(AVERAGEIF(ventas!B:B; A{r}; ventas!D:D); "SIN DATOS")']]})
            updates.append({"range": f"resumen_diario!F{r}", "values": [[f'=IFERROR(AVERAGEIF(ventas!B:B; A{r}; ventas!E:E); "SIN DATOS")']]})
            updates.append({"range": f"resumen_diario!H{r}", "values": [[f"=SUMIF(ventas!B:B; A{r}; ventas!J:J)"]]})
        sheets.values().batchUpdate(
            spreadsheetId=SPREADSHEET_ID,
            body={"valueInputOption": "USER_ENTERED", "data": updates},
        ).execute()
        print(f"  {len(updates)} celda(s) de fórmula actualizadas en 'resumen_diario'.")
    else:
        print("  'resumen_diario' no tiene filas de datos, nada que corregir.")

    print("\nListo. Migración de ventas/venta_items aplicada.")
    print(f"https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit")


if __name__ == "__main__":
    main()
