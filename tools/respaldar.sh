#!/usr/bin/env bash
# Realiza un respaldo manual de la hoja activa llamando al Apps Script.
# Uso:
#   tools/respaldar.sh         # Usa .env (producción)
#   tools/respaldar.sh --test  # Usa .env.test (pruebas)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$REPO_ROOT/.env"
if [[ "${1:-}" == "--test" || "${1:-}" == "--qa" ]]; then
  ENV_FILE="$REPO_ROOT/.env.test"
  echo "==> Modo TEST activado: usando .env.test"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: No se encontró el archivo $ENV_FILE" >&2
  exit 1
fi

APPS_SCRIPT_URL="$(grep "^APPS_SCRIPT_URL=" "$ENV_FILE" | cut -d'=' -f2- | tr -d ' "' | tr -d "'" || true)"
if [[ -z "$APPS_SCRIPT_URL" ]]; then
  echo "ERROR: APPS_SCRIPT_URL no está definida en $ENV_FILE" >&2
  exit 1
fi

echo "==> Solicitando respaldo manual a Google Apps Script..."
# Ejecuta action=respaldar_hoja
RESPUESTA="$(curl -s -L \
  -H "Content-Type: application/json" \
  -d '{"action":"respaldar_hoja"}' \
  "$APPS_SCRIPT_URL" || true)"

echo "==> Respuesta del servidor:"
echo "$RESPUESTA"
