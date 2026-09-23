#!/usr/bin/env python3
"""
Migra el Google Sheet real "Estilo Neutral" para agregar:

  1. La hoja "metodo pago" (id, nombre, status) — reemplaza el enum fijo
     TipoPago como fuente de verdad de los métodos de pago disponibles.
     Se siembra con los 6 métodos que ya existían como enum, todos activos.
  2. La hoja "abonos" (id, venta_id, fecha, monto, metodo_pago) — historial
     de pagos parciales por factura (relación 1:N venta→abonos, análoga a
     venta_items). Se siembra con el abono inicial de la única venta real
     existente (v00000001, pagada de una vez con Efectivo).

Importante: la columna "status" de "metodo pago" se escribe como boolean
nativo de Python (True/False), no como texto "TRUE"/"FALSE" — Apps Script
(Range.setValues()) SIEMPRE coacciona esas cadenas a boolean nativo de todos
modos, así que hay que sembrar el mismo tipo para no mezclar tipos en la
columna y romper el parseo de GViz (ver docs/google/troubleshooting.md).

Usa las mismas credenciales OAuth que los demás scripts de esta carpeta
(client_secret.json / token.json).
"""
import sys
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/drive"]
SPREADSHEET_ID = "1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI"

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


def main() -> None:
    creds = get_credentials()
    sheets = build("sheets", "v4", credentials=creds).spreadsheets()

    existing = sheets.get(spreadsheetId=SPREADSHEET_ID).execute()
    existing_titles = {s["properties"]["title"] for s in existing["sheets"]}
    print(f"Hojas actuales: {sorted(existing_titles)}")

    add_requests = []
    for title in ("metodo pago", "abonos"):
        if title in existing_titles:
            print(f"  '{title}' ya existe, no se recrea.")
        else:
            add_requests.append({"addSheet": {"properties": {"title": title}}})

    if add_requests:
        sheets.batchUpdate(spreadsheetId=SPREADSHEET_ID, body={"requests": add_requests}).execute()
        print(f"Creadas {len(add_requests)} hoja(s) nueva(s).")

    def write(range_name: str, values: list) -> None:
        sheets.values().update(
            spreadsheetId=SPREADSHEET_ID,
            range=range_name,
            valueInputOption="RAW",
            body={"values": values},
        ).execute()
        print(f"  Escrito {range_name} ({len(values)} filas).")

    print("Escribiendo 'metodo pago'...")
    write("metodo pago!A1:C7", [
        ["id", "nombre", "status"],
        ["mp00000001", "Efectivo", True],
        ["mp00000002", "Pago Movil", True],
        ["mp00000003", "Transferencia", True],
        ["mp00000004", "Zelle", True],
        ["mp00000005", "Binance", True],
        ["mp00000006", "Otro", True],
    ])

    print("Escribiendo 'abonos' (backfill del abono inicial de v00000001)...")
    write("abonos!A1:E2", [
        ["id", "venta_id", "fecha", "monto", "metodo_pago"],
        ["ab00000001", "v00000001", "2026-04-03", 20.0, "Efectivo"],
    ])

    print("\nListo. Migración de metodo pago / abonos aplicada.")
    print(f"https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit")


if __name__ == "__main__":
    main()
