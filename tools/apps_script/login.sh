#!/usr/bin/env bash
# Login único de clasp. Se ejecuta con cwd = raíz del repo, porque clasp v3
# no permite que rootDir en .clasp.json "escape" del directorio de trabajo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASP="$REPO_ROOT/tools/apps_script/node_modules/.bin/clasp"

cd "$REPO_ROOT"
"$CLASP" login
