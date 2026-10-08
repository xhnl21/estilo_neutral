#!/usr/bin/env bash
# ==============================================================================
# Script de Compilación para Producción (Release) - Estilo Neutral
# ==============================================================================
# Permite generar los artefactos de producción (APK y/o AppBundle AAB)
# utilizando la configuración del flavor "prod" y las variables de entorno de .env
# ==============================================================================

set -euo pipefail

# Colores para salida estructurada
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # Sin color

# Directorio raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Los errores de cada paso se guardan en script/log_script.txt (se reescribe
# en cada ejecución). En la terminal se sigue viendo la salida completa.
LOG_ERRORES="$SCRIPT_DIR/log_script.txt"
SALIDA_PASO="$(mktemp -t estilo_neutral_paso)"
PASO_ACTUAL=""
{
    echo "Log de errores de script/script.sh"
    echo "Fecha:   $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Args:    ${*:-(ninguno)}"
    echo "Commit:  $(git rev-parse --short HEAD 2>/dev/null || echo '?')$( [ -n "$(git status --porcelain 2>/dev/null)" ] && echo ' (con cambios sin commitear)')"
    echo "Flutter: $(flutter --version 2>/dev/null | head -1 || echo '?')"
    echo ""
} > "$LOG_ERRORES"

# Al salir (bien, con error o con Ctrl+C) deja el resultado final en el log.
finalizar() {
    local codigo=$?
    rm -f "$SALIDA_PASO"
    if [ $codigo -eq 0 ]; then
        echo "RESULTADO: compilación finalizada con éxito." >> "$LOG_ERRORES"
    else
        echo "RESULTADO: el script se detuvo con código $codigo${PASO_ACTUAL:+ en el paso \"$PASO_ACTUAL\"}." >> "$LOG_ERRORES"
        echo -e "${RED}❌ Falló. Detalle de los errores: $LOG_ERRORES${NC}" >&2
    fi
}
trap finalizar EXIT

# Ejecuta un comando mostrando su salida y, al terminar, agrega sus errores
# a $LOG_ERRORES (script/extraer_errores.py). Si el comando falla, corta el script.
paso() {
    PASO_ACTUAL="$1"; shift
    set +e
    "$@" 2>&1 | tee "$SALIDA_PASO"
    local codigo=${PIPESTATUS[0]}
    set -e
    python3 "$SCRIPT_DIR/extraer_errores.py" "$PASO_ACTUAL" "$codigo" "$SALIDA_PASO" "$LOG_ERRORES" \
        || echo "PASO: $PASO_ACTUAL — no se pudieron extraer los errores (código $codigo)." >> "$LOG_ERRORES"
    if [ "$codigo" -ne 0 ]; then
        exit "$codigo"
    fi
    PASO_ACTUAL=""
}

echo -e "${BLUE}${BOLD}================================================================${NC}"
echo -e "${BLUE}${BOLD}   COMPILACIÓN DE PRODUCCIÓN (RELEASE) - ESTILO NEUTRAL         ${NC}"
echo -e "${BLUE}${BOLD}================================================================${NC}"

# 1. Validación de dependencias y herramientas del sistema
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Error: Flutter SDK no está disponible en el PATH del sistema.${NC}"
    exit 1
fi

ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Error: No se encontró el archivo de entorno '$ENV_FILE' en la raíz.${NC}"
    exit 1
fi

# Extraer metadatos de configuración
APP_NAME=$(grep '^APP_NAME=' "$ENV_FILE" | cut -d '=' -f2- || echo "Estilo Neutral")
APP_PACKAGE_NAME=$(grep '^APP_PACKAGE_NAME=' "$ENV_FILE" | cut -d '=' -f2- || echo "com.estiloneutral.es")
ENVIRONMENT=$(grep '^ENVIRONMENT=' "$ENV_FILE" | cut -d '=' -f2- || echo "prod")

echo -e "${CYAN}ℹ️  Configuración detectada:${NC}"
echo -e "   • Entorno:       ${BOLD}$ENVIRONMENT${NC}"
echo -e "   • App Name:      ${BOLD}$APP_NAME${NC}"
echo -e "   • Package ID:    ${BOLD}$APP_PACKAGE_NAME${NC}"
echo -e "   • Archivo .env:  ${BOLD}$ENV_FILE${NC}"
echo ""

# Parámetros opcionales: --apk (por defecto), --bundle, --all, --skip-tests
BUILD_TYPE="apk"
RUN_TESTS=true

for arg in "$@"; do
    case $arg in
        --bundle|--aab)
            BUILD_TYPE="bundle"
            shift
            ;;
        --all)
            BUILD_TYPE="all"
            shift
            ;;
        --skip-tests)
            RUN_TESTS=false
            shift
            ;;
        --help|-h)
            echo "Uso: ./script/script.sh [OPCIONES]"
            echo ""
            echo "Opciones:"
            echo "  --apk         Compilar APK Release para producción (predeterminado)"
            echo "  --bundle      Compilar App Bundle (.aab) para Google Play Store"
            echo "  --all         Compilar tanto APK como App Bundle"
            echo "  --skip-tests  Omitir la suite de análisis y pruebas previas"
            echo "  --help, -h    Mostrar esta ayuda"
            exit 0
            ;;
    esac
done

# 2. Resolución de dependencias
echo -e "${CYAN}📦 Paso 1/4: Obteniendo dependencias actualizadas...${NC}"
paso "flutter pub get" flutter pub get

# 3. Pruebas de calidad y análisis estático
if [ "$RUN_TESTS" = true ]; then
    echo -e "${CYAN}🔍 Paso 2/4: Ejecutando análisis estático y pruebas unitarias...${NC}"
    paso "flutter analyze" flutter analyze
    paso "flutter test" flutter test
else
    echo -e "${YELLOW}⚠️  Paso 2/4: Omitiendo suite de pruebas (--skip-tests activado).${NC}"
fi

# 4. Compilación según el tipo seleccionado
echo -e "${CYAN}🚀 Paso 3/4: Compilando binarios de Release (Flavor: prod)...${NC}"

if [ "$BUILD_TYPE" = "apk" ] || [ "$BUILD_TYPE" = "all" ]; then
    # APKs de compilaciones anteriores (otros flavors, debug, versiones
    # viejas): se borran para que en la carpeta quede solo el de esta.
    APK_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
    if [ -d "$APK_DIR" ]; then
        echo -e "   🧹 Vaciando build/app/outputs/flutter-apk/..."
        find "$APK_DIR" -mindepth 1 -delete
    fi
    echo -e "   🔨 Generando APK de producción..."
    paso "build apk" flutter build apk \
        --flavor prod \
        --release \
        --dart-define-from-file="$ENV_FILE"

    APK_OUTPUT="build/app/outputs/flutter-apk/app-prod-release.apk"
    if [ -f "$APK_OUTPUT" ]; then
        APK_SIZE=$(du -h "$APK_OUTPUT" | cut -f1)
        echo -e "${GREEN}   ✅ APK generado exitosamente:${NC} $APK_OUTPUT ($APK_SIZE)"
    fi
fi

if [ "$BUILD_TYPE" = "bundle" ] || [ "$BUILD_TYPE" = "all" ]; then
    echo -e "   🔨 Generando Android App Bundle (.aab) para Google Play Store..."
    paso "build appbundle" flutter build appbundle \
        --flavor prod \
        --release \
        --dart-define-from-file="$ENV_FILE"

    AAB_OUTPUT="build/app/outputs/bundle/prodRelease/app-prod-release.aab"
    if [ -f "$AAB_OUTPUT" ]; then
        AAB_SIZE=$(du -h "$AAB_OUTPUT" | cut -f1)
        echo -e "${GREEN}   ✅ App Bundle generado exitosamente:${NC} $AAB_OUTPUT ($AAB_SIZE)"
    fi
fi

# 5. Resumen final
echo ""
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo -e "${GREEN}${BOLD}   ¡COMPILACIÓN DE PRODUCCIÓN FINALIZADA CON ÉXITO!            ${NC}"
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo -e "Errores y advertencias de cada paso: ${BOLD}$LOG_ERRORES${NC}"
echo -e "Artefactos listos para distribución:"
if [ "$BUILD_TYPE" = "apk" ] || [ "$BUILD_TYPE" = "all" ]; then
    echo -e " • ${BOLD}APK Directo (Sideload / QA / Tiendas alternativas):${NC}"
    echo -e "   build/app/outputs/flutter-apk/app-prod-release.apk"
fi
if [ "$BUILD_TYPE" = "bundle" ] || [ "$BUILD_TYPE" = "all" ]; then
    echo -e " • ${BOLD}App Bundle AAB (Google Play Console):${NC}"
    echo -e "   build/app/outputs/bundle/prodRelease/app-prod-release.aab"
fi
echo ""
