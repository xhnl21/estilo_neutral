#!/usr/bin/env python3
"""
Descarga el estado real y actual del Google Sheet "Estilo Neutral" y
sobreescribe la copia local de Estilo Neutral.xlsx — el paso inverso de
upload_sheet.py.

Correlo **antes** de editar el .xlsx a mano o de correr un script de
migración: si la copia local está desactualizada (por ejemplo, porque la app
o alguien más escribió directo en el Sheet real desde la última vez que se
bajó), cualquier cambio que hagas sobre esa copia vieja y después subas con
upload_sheet.py va a pisar y perder esos datos nuevos.

Uso:
    python3 download_sheet.py [ruta_de_salida]

Sin argumentos, sobreescribe "Estilo Neutral.xlsx" en la raíz del repo.

Primera vez: abre el navegador para autorizar acceso a Drive (una sola vez;
el token queda cacheado en token.json, compartido con upload_sheet.py).
Requiere client_secret.json en esta carpeta — ver README.md para cómo
generarlo.
"""
import sys
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload

SCOPES = ["https://www.googleapis.com/auth/drive"]
SPREADSHEET_ID = "1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI"
XLSX_MIME_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

SCRIPT_DIR = Path(__file__).resolve().parent
CLIENT_SECRET_FILE = SCRIPT_DIR / "client_secret.json"
TOKEN_FILE = SCRIPT_DIR / "token.json"
DEFAULT_XLSX = SCRIPT_DIR.parent.parent / "Estilo Neutral.xlsx"


def get_credentials() -> Credentials:
    creds = None
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CLIENT_SECRET_FILE.exists():
                sys.exit(
                    f"Falta {CLIENT_SECRET_FILE}.\n"
                    "Seguí las instrucciones de README.md para crear las "
                    "credenciales OAuth de tipo 'Desktop app' y descargar el JSON."
                )
            flow = InstalledAppFlow.from_client_secrets_file(
                str(CLIENT_SECRET_FILE), SCOPES
            )
            creds = flow.run_local_server(port=0)
        TOKEN_FILE.write_text(creds.to_json())
    return creds


def main() -> None:
    xlsx_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_XLSX

    if xlsx_path.exists():
        print(f"Copia local actual: {xlsx_path} ({xlsx_path.stat().st_size} bytes) — se va a sobreescribir.")
    else:
        print(f"No existe todavía copia local en {xlsx_path} — se va a crear.")

    print(f"Descargando el contenido real de Google Sheet {SPREADSHEET_ID}...")

    creds = get_credentials()
    drive = build("drive", "v3", credentials=creds)

    meta = drive.files().get(fileId=SPREADSHEET_ID, fields="name, modifiedTime").execute()

    request = drive.files().export_media(fileId=SPREADSHEET_ID, mimeType=XLSX_MIME_TYPE)
    xlsx_path.parent.mkdir(parents=True, exist_ok=True)
    with open(xlsx_path, "wb") as fh:
        downloader = MediaIoBaseDownload(fh, request)
        done = False
        while not done:
            _, done = downloader.next_chunk()

    print("Listo. Copia local actualizada:")
    print(f"  {xlsx_path}")
    print(f"  Nombre en Drive: {meta.get('name')}")
    print(f"  Última modificación real: {meta.get('modifiedTime')}")


if __name__ == "__main__":
    main()
