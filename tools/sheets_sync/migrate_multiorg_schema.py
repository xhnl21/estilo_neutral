#!/usr/bin/env python3
"""
Migra el Google Sheet real "Estilo Neutral" al esquema multi-organización
nuevo (ver docs/google/multi-organizacion.md), usando la API de Sheets con
escrituras quirúrgicas por rango — NO reemplaza el archivo completo (a
diferencia de upload_sheet.py), así que no hay riesgo de pisar datos
transaccionales (clientes, ventas, etc.) con una copia local desactualizada.

Cambios que aplica:
  1. Crea la hoja "organizaciones" (id, nombre) con la organización actual.
  2. Crea la hoja "usuario_organizacion" (usuario_email, organizacion_id)
     con la membresía de los usuarios actuales.
  3. Reescribe "usuarios" agregando la columna "id" (u00000001, u00000002...).
  4. Reescribe "seguridad" cambiando la columna D de "organizacion_id" a
     "usuario_email" — sin migrar ningún método activo (todos arrancan en
     "Ninguno"), según lo acordado.

Reutiliza las credenciales OAuth ya generadas para upload_sheet.py
(client_secret.json / token.json en esta misma carpeta).
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


def main() -> None:
    creds = get_credentials()
    sheets = build("sheets", "v4", credentials=creds).spreadsheets()

    existing = sheets.get(spreadsheetId=SPREADSHEET_ID).execute()
    existing_titles = {s["properties"]["title"] for s in existing["sheets"]}
    print(f"Hojas actuales: {sorted(existing_titles)}")

    add_requests = []
    for title in ("organizaciones", "usuario_organizacion"):
        if title in existing_titles:
            print(f"  '{title}' ya existe, no se recrea.")
        else:
            add_requests.append({"addSheet": {"properties": {"title": title}}})

    if add_requests:
        sheets.batchUpdate(spreadsheetId=SPREADSHEET_ID, body={"requests": add_requests}).execute()
        print(f"Creadas {len(add_requests)} hoja(s) nueva(s).")

    def write(range_name: str, values: list[list[str]]) -> None:
        sheets.values().update(
            spreadsheetId=SPREADSHEET_ID,
            range=range_name,
            valueInputOption="RAW",
            body={"values": values},
        ).execute()
        print(f"  Escrito {range_name} ({len(values)} filas).")

    print("Escribiendo 'organizaciones'...")
    write("organizaciones!A1:B2", [
        ["id", "nombre"],
        [ORG_ID, "Estilo Neutral"],
    ])

    print("Escribiendo 'usuario_organizacion'...")
    write("usuario_organizacion!A1:B3", [
        ["usuario_email", "organizacion_id"],
        ["neidapulgar1989@gmail.com", ORG_ID],
        ["xhnl21@gmail.com", ORG_ID],
    ])

    print("Reescribiendo 'usuarios' (agregando columna id)...")
    write("usuarios!A1:C3", [
        ["id", "email", "nombre"],
        ["u00000001", "neidapulgar1989@gmail.com", "Neida Chourio"],
        ["u00000002", "xhnl21@gmail.com", "Xavier Nuñez"],
    ])

    print("Reescribiendo 'seguridad' (organizacion_id -> usuario_email, sin método activo)...")
    # Importante: se escriben booleans nativos de Python (False), no el texto
    # "FALSE", para que la columna quede con el mismo tipo de celda que usa
    # google_apps_script.js al escribir después (Range.setValues() con un
    # boolean de JS). Si una fila queda como texto y otra como boolean nativo,
    # el endpoint GViz (que la app usa para leer) rompe la detección de
    # encabezado y devuelve un CSV corrupto — ver docs/google/troubleshooting.md.
    write("seguridad!A1:D3", [
        ["biometrico", "desbloqueo_facial", "dos_factores", "usuario_email"],
        [False, False, False, "neidapulgar1989@gmail.com"],
        [False, False, False, "xhnl21@gmail.com"],
    ])

    print("\nListo. Migración aplicada.")
    print(f"https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit")


if __name__ == "__main__":
    main()
