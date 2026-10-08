#!/usr/bin/env bash
# Deploy de Estilo Neutral: tests, Apps Script (test → producción), build de
# release de la app y, opcionalmente, instalación en un teléfono por adb.
#
# Uso:
#   bash tools/deploy.sh [opciones]
#
# Opciones:
#   --script              Despliega el Apps Script: primero test, después producción.
#   --app VARIANTE        Compila el release de la app: prod | qa | dev (APK + AAB).
#   --instalar            Instala el APK en el teléfono conectado por USB (requiere --app).
#   --version X.Y.Z+N     Cambia la versión de pubspec.yaml antes de compilar.
#   --sin-tests           Omite flutter analyze/test y los tests del script.
#   --simular             Muestra los pasos sin ejecutar nada.
#   --todo                Equivale a: --script --app prod --instalar
#   -h, --ayuda           Esta ayuda.
#
# Ejemplos:
#   bash tools/deploy.sh --todo
#   bash tools/deploy.sh --app qa --instalar
#   bash tools/deploy.sh --script
#   bash tools/deploy.sh --app prod --version 1.0.1+11
#
# Detalle de cada archivo que usa (y que no está en git):
# docs/configuracion-local.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SCRIPT=false
VARIANTE=""
INSTALAR=false
VERSION=""
TESTS=true
SIMULAR=false

ayuda() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --script) SCRIPT=true ;;
    --app) VARIANTE="${2:-}"; shift ;;
    --instalar) INSTALAR=true ;;
    --version) VERSION="${2:-}"; shift ;;
    --sin-tests) TESTS=false ;;
    --simular) SIMULAR=true ;;
    --todo) SCRIPT=true; VARIANTE="prod"; INSTALAR=true ;;
    -h|--ayuda) ayuda; exit 0 ;;
    *) echo "Opción desconocida: $1"; echo; ayuda; exit 2 ;;
  esac
  shift
done

paso() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '\033[0;32m    ✔ %s\033[0m\n' "$*"; }
falla() { printf '\033[0;31m    ✘ %s\033[0m\n' "$*" >&2; exit 1; }
aviso() { printf '\033[0;33m    ! %s\033[0m\n' "$*"; }
ejecutar() {
  printf '    $ %s\n' "$*"
  if [[ "$SIMULAR" == false ]]; then "$@"; fi
}

if [[ "$SCRIPT" == false && -z "$VARIANTE" ]]; then
  echo "No se indicó qué desplegar."; echo; ayuda; exit 2
fi
if [[ "$INSTALAR" == true && -z "$VARIANTE" ]]; then
  falla "--instalar necesita --app VARIANTE."
fi

case "$VARIANTE" in
  "") ;;
  prod) ENV_FILE=".env" ;;
  qa) ENV_FILE=".env.test" ;;
  dev) ENV_FILE=".env.dev" ;;
  *) falla "Variante inválida: '$VARIANTE' (prod | qa | dev)." ;;
esac

ADB="$(command -v adb || true)"
[[ -z "$ADB" && -x "$HOME/Library/Android/sdk/platform-tools/adb" ]] && ADB="$HOME/Library/Android/sdk/platform-tools/adb"

# -----------------------------------------------------------------------------
paso "Chequeos previos"
[[ "$SIMULAR" == true ]] && aviso "Modo simulación: no se ejecuta nada."

if [[ -n "$(git status --porcelain)" ]]; then
  aviso "Hay cambios sin commitear: el deploy usa el código tal como está en disco."
else
  ok "Árbol de git limpio ($(git rev-parse --short HEAD))."
fi

if [[ "$SCRIPT" == true ]]; then
  command -v node >/dev/null || falla "Falta node (para clasp)."
  [[ -x tools/apps_script/node_modules/.bin/clasp ]] || falla "Falta clasp: cd tools/apps_script && npm install"
  [[ -x tools/apps_script_test/node_modules/.bin/clasp ]] || falla "Falta clasp de test: cd tools/apps_script_test && npm install"
  [[ -f "$HOME/.clasprc.json" ]] || falla "Sin sesión de clasp: bash tools/apps_script/login.sh"
  if ls fcm-clave-*.json >/dev/null 2>&1 || [[ -n "${FCM_CLAVE:-}" ]]; then
    ok "Clave de FCM local encontrada (se embebe en credencial_fcm.js)."
  else
    aviso "Sin clave local de FCM: el script usará la propiedad FCM_SERVICE_ACCOUNT."
  fi
  ok "Herramientas del Apps Script listas."
fi

if [[ -n "$VARIANTE" ]]; then
  command -v flutter >/dev/null || falla "Falta flutter en el PATH."
  [[ -f "$ENV_FILE" ]] || falla "Falta $ENV_FILE (copiar .env.example; ver docs/configuracion-local.md §2.1)."
  ok "Variables: $ENV_FILE"
  if [[ -f android/key.properties ]]; then
    ok "Firma de release: android/key.properties"
  else
    aviso "Sin android/key.properties: el release se firma con la clave de DEBUG (Google Play no la acepta)."
  fi
  if [[ -f android/app/google-services.json ]]; then
    ok "Firebase: android/app/google-services.json"
  else
    aviso "Sin android/app/google-services.json: la app se compila SIN notificaciones."
  fi
fi

if [[ "$INSTALAR" == true ]]; then
  [[ -n "$ADB" ]] || falla "No se encontró adb (Android SDK platform-tools)."
  if [[ "$SIMULAR" == false ]]; then
    DISPOSITIVOS="$("$ADB" devices | sed 1d | grep -w device || true)"
    [[ -n "$DISPOSITIVOS" ]] || falla "No hay ningún teléfono conectado con depuración USB activada (adb devices)."
    ok "Teléfono conectado: $(echo "$DISPOSITIVOS" | head -1 | cut -f1)"
  fi
fi

# -----------------------------------------------------------------------------
if [[ -n "$VERSION" ]]; then
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] || falla "Versión inválida: '$VERSION' (formato X.Y.Z+N)."
fi
VERSION_ANTERIOR="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
VERSION_ACTUAL="${VERSION:-$VERSION_ANTERIOR}"

# Android no instala encima una versión con versionCode menor
# (INSTALL_FAILED_VERSION_DOWNGRADE). Builds viejos con --split-per-abi
# suman 1000 × ABI al código (p. ej. 2009 en arm64). Se comprueba ANTES de
# tocar pubspec.yaml.
if [[ "$INSTALAR" == true && "$SIMULAR" == false ]]; then
  case "$VARIANTE" in prod) PAQUETE="com.estiloneutral.es" ;; *) PAQUETE="com.estiloneutral.es.$VARIANTE" ;; esac
  INSTALADA="$("$ADB" shell dumpsys package "$PAQUETE" 2>/dev/null | grep -m1 -oE 'versionCode=[0-9]+' | cut -d= -f2 || true)"
  NUEVA="${VERSION_ACTUAL##*+}"
  if [[ -n "$INSTALADA" && "$NUEVA" -lt "$INSTALADA" ]]; then
    falla "El teléfono tiene $PAQUETE con versionCode $INSTALADA y el nuevo es $NUEVA. Usá --version X.Y.Z+$((INSTALADA + 1)) o mayor."
  fi
fi

if [[ -n "$VERSION" ]]; then
  paso "Versión"
  printf '    %s → %s\n' "$VERSION_ANTERIOR" "$VERSION"
  if [[ "$SIMULAR" == false ]]; then
    sed -i.bak -E "s/^version: .*/version: $VERSION/" pubspec.yaml && rm -f pubspec.yaml.bak
  fi
fi

# -----------------------------------------------------------------------------
if [[ "$TESTS" == true ]]; then
  paso "Tests"
  ejecutar flutter analyze
  ejecutar flutter test
  ejecutar node tools/apps_script/tests/notificaciones.test.js
  ejecutar node tools/apps_script/tests/acceso.test.js
  ejecutar node tools/apps_script/tests/datos_bancarios.test.js
  ejecutar node tools/apps_script/tests/correo.test.js
  ok "Tests en verde."
else
  aviso "Tests omitidos (--sin-tests)."
fi

# -----------------------------------------------------------------------------
if [[ "$SCRIPT" == true ]]; then
  paso "Apps Script: test"
  ejecutar bash tools/apps_script_test/deploy.sh
  paso "Apps Script: producción"
  ejecutar bash tools/apps_script/deploy.sh
  ok "Apps Script desplegado (la URL /exec no cambia)."
fi

# -----------------------------------------------------------------------------
if [[ -n "$VARIANTE" ]]; then
  paso "Build de release: $VARIANTE ($VERSION_ACTUAL)"
  ejecutar flutter build apk --flavor "$VARIANTE" --release --dart-define-from-file="$ENV_FILE"
  ejecutar flutter build appbundle --flavor "$VARIANTE" --release --dart-define-from-file="$ENV_FILE"

  DIST="dist/$VERSION_ACTUAL"
  APK_ORIGEN="build/app/outputs/flutter-apk/app-$VARIANTE-release.apk"
  AAB_ORIGEN="build/app/outputs/bundle/${VARIANTE}Release/app-$VARIANTE-release.aab"
  APK="$DIST/estilo-neutral-$VARIANTE-$VERSION_ACTUAL.apk"
  AAB="$DIST/estilo-neutral-$VARIANTE-$VERSION_ACTUAL.aab"
  ejecutar mkdir -p "$DIST"
  ejecutar cp "$APK_ORIGEN" "$APK"
  ejecutar cp "$AAB_ORIGEN" "$AAB"
  ok "APK: $APK"
  ok "AAB: $AAB"

  if [[ "$INSTALAR" == true ]]; then
    paso "Instalación en el teléfono"
    if [[ "$SIMULAR" == true ]]; then
      ejecutar "$ADB" install -r "$APK"
    else
      printf '    $ %s\n' "$ADB install -r $APK"
      SALIDA_ADB="$("$ADB" install -r "$APK" 2>&1 || true)"
      echo "    $SALIDA_ADB" | tail -1
      if grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE" <<<"$SALIDA_ADB"; then
        falla "La app instalada está firmada con otra clave (p. ej. la de debug de 'flutter run'). Sin desinstalar: flutter build apk --flavor $VARIANTE --debug --dart-define-from-file=$ENV_FILE && $ADB install -r build/app/outputs/flutter-apk/app-$VARIANTE-debug.apk. Para el release, desinstalarla primero (se pierden sus datos locales)."
      fi
      grep -q "^Success" <<<"$SALIDA_ADB" || falla "No se pudo instalar."
    fi
    ok "Instalada. Abrila, iniciá sesión y aceptá el permiso de notificaciones."
  fi
fi

paso "Listo"
