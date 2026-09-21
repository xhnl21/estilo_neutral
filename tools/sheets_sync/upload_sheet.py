#!/usr/bin/env python3
"""
Reemplaza el contenido del Google Sheet "Estilo Neutral" con una copia local
de Estilo Neutral.xlsx, preservando el mismo ID de spreadsheet (y por lo
tanto el Apps Script vinculado, la URL y los permisos compartidos).

Uso:
    python3 upload_sheet.py [ruta_al_xlsx]

Sin argumentos, usa "Estilo Neutral.xlsx" en la raíz del repo.

Primera vez: abre el navegador para autorizar acceso a Drive (una sola vez;
el token queda cacheado en token.json). Requiere client_secret.json en esta
carpeta — ver README.md para cómo generarlo.
"""
import sys
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/drive"]
SPREADSHEET_ID = "1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI"

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
    if not xlsx_path.exists():
        sys.exit(f"No se encontró el archivo: {xlsx_path}")

    print(f"Reemplazando el contenido de Google Sheet {SPREADSHEET_ID} con:")
    print(f"  {xlsx_path}")

    creds = get_credentials()
    drive = build("drive", "v3", credentials=creds)

    media = MediaFileUpload(
        str(xlsx_path),
        mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        resumable=True,
    )

    updated = (
        drive.files()
        .update(fileId=SPREADSHEET_ID, media_body=media, fields="id, name, modifiedTime")
        .execute()
    )

    print("Listo. Google Sheet actualizado:")
    print(f"  Nombre: {updated.get('name')}")
    print(f"  Última modificación: {updated.get('modifiedTime')}")
    print(f"  https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit")


if __name__ == "__main__":
    main()
