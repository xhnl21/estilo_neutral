#!/usr/bin/env bash
# Genera credencial_fcm.js (en la ruta $1) con la clave de la cuenta de
# servicio de FCM, para que deploy.sh la suba junto al script. El archivo
# generado NO se versiona (.gitignore) y la clave tampoco.
#
# Clave: $FCM_CLAVE, o el primer fcm-clave-*.json de la raíz del repo.
# Sin clave, genera FCM_SERVICE_ACCOUNT_EMBEBIDA = null y el script usa la
# propiedad del script FCM_SERVICE_ACCOUNT (ver docs/notificaciones-fcm.md §4.5).
set -euo pipefail

SALIDA="$1"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLAVE="${FCM_CLAVE:-$(ls "$REPO_ROOT"/fcm-clave-*.json 2>/dev/null | head -1 || true)}"

python3 - "$SALIDA" "$CLAVE" <<'PY'
import json, sys
salida, clave = sys.argv[1], sys.argv[2]
cuenta = None
if clave:
    d = json.load(open(clave))
    faltan = [k for k in ("client_email", "private_key", "project_id") if not d.get(k)]
    if d.get("type") != "service_account" or faltan:
        sys.exit(f"La clave {clave} no es una cuenta de servicio válida (faltan {faltan}).")
    cuenta = {k: d[k] for k in ("type", "project_id", "client_email", "private_key", "private_key_id", "token_uri")}
with open(salida, "w") as f:
    f.write("// GENERADO por tools/apps_script/generar_credencial_fcm.sh en cada deploy.\n")
    f.write("// No editar ni versionar: contiene la clave privada de la cuenta de servicio de FCM.\n")
    f.write("const FCM_SERVICE_ACCOUNT_EMBEBIDA = " + json.dumps(cuenta) + ";\n")
print(("==> Credencial FCM: " + cuenta["client_email"]) if cuenta else "==> Credencial FCM: sin clave local (se usa la propiedad del script).")
PY
