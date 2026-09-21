#!/usr/bin/env bash
# Publica una nueva versión de google_apps_script.js en la implementación
# Web App EXISTENTE (misma URL /exec, no crea una implementación nueva).
#
# Se ejecuta con cwd = raíz del repo, porque clasp v3 no permite que rootDir
# en .clasp.json "escape" del directorio de trabajo (.clasp.json vive en la
# raíz del repo con rootDir=".").
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASP="$REPO_ROOT/tools/apps_script/node_modules/.bin/clasp"
DEPLOYMENT_ID="AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA"

cd "$REPO_ROOT"

echo "==> Subiendo google_apps_script.js y appsscript.json..."
"$CLASP" push --force

echo "==> Publicando nueva versión en la implementación existente..."
"$CLASP" deploy --deploymentId "$DEPLOYMENT_ID" --description "Deploy automático $(date '+%Y-%m-%d %H:%M:%S')"

echo "==> Listo. La URL /exec no cambió."
