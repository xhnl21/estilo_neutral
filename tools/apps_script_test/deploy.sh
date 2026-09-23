#!/usr/bin/env bash
# Publica una nueva versión de google_apps_script.js en la implementación
# Web App del proyecto de PRUEBA (hoja "Estilo Neutral - TEST", separada de
# producción). Copia el script real desde la raíz del repo antes de subir,
# para que la copia de test nunca quede desincronizada del código real.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLASP="$SCRIPT_DIR/node_modules/.bin/clasp"
DEPLOYMENT_ID="AKfycbx6GOO7X-T5L6sBYMfJX-3fzjcss21MxQFvk7ilx4huUwWOPKTk5pOmALdZcPunAw8kwA"

cp "$REPO_ROOT/google_apps_script.js" "$SCRIPT_DIR/google_apps_script.js"

cd "$SCRIPT_DIR"

echo "==> Subiendo google_apps_script.js y appsscript.json (proyecto de TEST)..."
"$CLASP" push --force

echo "==> Publicando nueva versión en la implementación de TEST existente..."
"$CLASP" deploy --deploymentId "$DEPLOYMENT_ID" --description "Deploy automático TEST $(date '+%Y-%m-%d %H:%M:%S')"

echo "==> Listo. La URL /exec de TEST no cambió."
