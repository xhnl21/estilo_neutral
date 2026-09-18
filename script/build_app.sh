#!/bin/bash
set -e

# ==============================================================================
# Script de Compilación Local para Flutter (Estilo Neutral)
# Soporta entornos: DEV, TEST (QA) y PROD
# Soporta artefactos: APK (split-per-abi), App Bundle (AAB), APK Universal
# Aplica incremento SemVer, blindaje y ofuscación en PROD.
# ==============================================================================

# Colores para salida estructurada
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # Sin color

# 1. Ubicación y Contexto de Ejecución:
# Asegurar que el script siempre se ejecute desde la raíz del proyecto Flutter
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}${BOLD}================================================================${NC}"
echo -e "${BLUE}${BOLD}   COMPILACIÓN LOCAL DE FLUTTER (ESTILO NEUTRAL)          ${NC}"
echo -e "${BLUE}${BOLD}================================================================${NC}"

# 2. Menú Interactivo de Selección de Entorno (Flavors)
echo -e "\n${BOLD}Selecciona el entorno para compilar:${NC}"
echo "1) DEV"
echo "2) TEST (QA)"
echo "3) PROD"
read -p "Ingresa una opción (1-3): " env_option

case $env_option in
    1)
        env_name="DEV"
        flavor="dev"
        env_file=".env.dev"
        ;;
    2)
        env_name="TEST"
        flavor="qa"
        env_file=".env.test"
        ;;
    3)
        env_name="PROD"
        flavor="prod"
        env_file=".env"
        ;;
    *)
        echo -e "${RED}❌ Error: Opción de entorno inválida ($env_option). Saliendo...${NC}"
        exit 1
        ;;
esac

# 3. Menú de Tipo de Artefacto
echo -e "\n${BOLD}Selecciona el tipo de artefacto a compilar:${NC}"
echo "1) APK (split-per-abi)"
echo "2) App Bundle (AAB para Google Play)"
echo "3) APK Universal"
read -p "Ingresa una opción (1-3): " artifact_option

case $artifact_option in
    1)
        artifact_type="apk_split"
        artifact_label="APK (split-per-abi)"
        ;;
    2)
        artifact_type="bundle"
        artifact_label="App Bundle (AAB para Google Play)"
        ;;
    3)
        artifact_type="apk_universal"
        artifact_label="APK Universal"
        ;;
    *)
        echo -e "${RED}❌ Error: Opción de artefacto inválida ($artifact_option). Saliendo...${NC}"
        exit 1
        ;;
esac

echo -e "\n${CYAN}ℹ️  Configuración seleccionada:${NC}"
echo -e "   • Entorno:       ${BOLD}$env_name${NC}"
echo -e "   • Flavor:        ${BOLD}$flavor${NC}"
echo -e "   • Archivo .env:  ${BOLD}$env_file${NC}"
echo -e "   • Artefacto:     ${BOLD}$artifact_label${NC}"

# 4. Validaciones Previas (Pre-flight Checks)
if [[ ! -f "$env_file" ]]; then
    echo -e "${RED}❌ Error crítico: Falta el archivo de entorno '$env_file' en la raíz del proyecto.${NC}"
    exit 1
fi

if [ "$env_name" = "PROD" ]; then
    echo -e "\n${CYAN}🔒 Verificando credenciales de firma para PRODUCCIÓN...${NC}"
    if [[ ! -f "android/key.properties" ]]; then
        echo -e "${RED}❌ Error crítico: Falta 'android/key.properties' para firmar en producción.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Archivo android/key.properties verificado.${NC}"
fi

# 5. Gestión de Versión en pubspec.yaml
raw_version=$(grep -E '^[[:space:]]*version:' pubspec.yaml || true)
if [ -z "$raw_version" ]; then
    echo -e "${RED}❌ Error crítico: No se encontró el campo 'version:' en pubspec.yaml${NC}"
    exit 1
fi

current_version=$(echo "$raw_version" | sed -E 's/^[[:space:]]*version:[[:space:]]*//' | tr -d '"' | tr -d "'")
version_name=$(echo "$current_version" | cut -d '+' -f 1)
build_number=$(echo "$current_version" | cut -d '+' -f 2)

if [ -z "$build_number" ] || [ "$version_name" = "$build_number" ]; then
    echo -e "${YELLOW}⚠️ Advertencia: No se detectó build number (+N). Inicializando en 1...${NC}"
    new_build_number=1
else
    new_build_number=$((build_number + 1))
fi

new_version="${version_name}+${new_build_number}"

# Reemplazo portable en pubspec.yaml (macOS BSD sed vs Linux GNU sed)
if sed --version 2>&1 | grep -q GNU; then
    sed -i "s/^[[:space:]]*version:.*/version: $new_version/" pubspec.yaml
else
    sed -i '' "s/^[[:space:]]*version:.*/version: $new_version/" pubspec.yaml
fi

echo -e "\n=================================================="
echo -e "🚀 Versión pubspec.yaml actualizada: ${YELLOW}$current_version${NC} -> ${GREEN}$new_version${NC}"
echo -e "=================================================="

# 6. Limpieza y Preparación
FLUTTER_CMD="fvm flutter"
if ! command -v fvm >/dev/null 2>&1; then
    FLUTTER_CMD="flutter"
fi

echo -e "\n${CYAN}🧹 Limpiando caché y obteniendo dependencias (${FLUTTER_CMD})...${NC}"
$FLUTTER_CMD clean
$FLUTTER_CMD pub get

# 7. Parámetros de Compilación
BUILD_ARGS=()
case $artifact_type in
    apk_split)
        BUILD_ARGS=(
            apk
            --release
            --flavor "$flavor"
            --split-per-abi
            --dart-define-from-file="$env_file"
        )
        ;;
    bundle)
        BUILD_ARGS=(
            appbundle
            --release
            --flavor "$flavor"
            --dart-define-from-file="$env_file"
        )
        ;;
    apk_universal)
        BUILD_ARGS=(
            apk
            --release
            --flavor "$flavor"
            --dart-define-from-file="$env_file"
        )
        ;;
esac

# Blindaje en Producción: Ofuscación y guardado de símbolos
SYMBOLS_DIR=""
if [ "$env_name" = "PROD" ]; then
    SYMBOLS_DIR="build/app/outputs/symbols/build/prod/v${new_version}"
    mkdir -p "$SYMBOLS_DIR"
    BUILD_ARGS+=(
        --obfuscate
        --split-debug-info="$SYMBOLS_DIR"
    )
    echo -e "${GREEN}🛡️  Ofuscación ACTIVA. Los símbolos se resguardarán en: $SYMBOLS_DIR${NC}"
else
    echo -e "${YELLOW}ℹ️  Modo $env_name: Ofuscación desactivada para facilitar depuración.${NC}"
fi

echo -e "\n${CYAN}⚙️  Iniciando compilación de $env_name ($artifact_label)...${NC}"
$FLUTTER_CMD build "${BUILD_ARGS[@]}"

# 8. Resumen de Resultados y Salida
found_artifacts=()
case $artifact_type in
    apk_split)
        for candidate in \
            "build/app/outputs/flutter-apk/app-arm64-v8a-$flavor-release.apk" \
            "build/app/outputs/flutter-apk/app-armeabi-v7a-$flavor-release.apk" \
            "build/app/outputs/flutter-apk/app-x86_64-$flavor-release.apk" \
            "build/app/outputs/apk/$flavor/release/app-$flavor-arm64-v8a-release.apk" \
            "build/app/outputs/apk/$flavor/release/app-$flavor-armeabi-v7a-release.apk" \
            "build/app/outputs/apk/$flavor/release/app-$flavor-x86_64-release.apk"; do
            if [[ -f "$candidate" ]]; then
                found_artifacts+=("$candidate")
            fi
        done
        ;;
    bundle)
        for candidate in \
            "build/app/outputs/bundle/${flavor}Release/app-${flavor}-release.aab" \
            "build/app/outputs/bundle/${flavor}Release/app.aab" \
            "build/app/outputs/bundle/release/app-release.aab"; do
            if [[ -f "$candidate" ]]; then
                found_artifacts+=("$candidate")
            fi
        done
        ;;
    apk_universal)
        for candidate in \
            "build/app/outputs/flutter-apk/app-$flavor-release.apk" \
            "build/app/outputs/apk/$flavor/release/app-$flavor-release.apk" \
            "build/app/outputs/flutter-apk/app-release.apk"; do
            if [[ -f "$candidate" ]]; then
                found_artifacts+=("$candidate")
            fi
        done
        ;;
esac

# Fallback si no se encontró en las rutas exactas
if [ ${#found_artifacts[@]} -eq 0 ]; then
    if [ "$artifact_type" = "bundle" ]; then
        while IFS= read -r f; do
            [[ -n "$f" ]] && found_artifacts+=("$f")
        done < <(find build/app/outputs/bundle -type f -name "*.aab" 2>/dev/null | sort -u)
    else
        while IFS= read -r f; do
            [[ -n "$f" ]] && found_artifacts+=("$f")
        done < <(find build/app/outputs/flutter-apk build/app/outputs/apk -type f -name "*$flavor*release.apk" 2>/dev/null | sort -u)
    fi
fi

if [ ${#found_artifacts[@]} -eq 0 ]; then
    echo -e "${RED}❌ Error: No se localizó ningún artefacto generado en build/app/outputs/${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo -e "${GREEN}${BOLD}         🎉 RESUMEN DE COMPILACIÓN EXITOSA                      ${NC}"
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo -e "  • ${BOLD}Entorno:${NC}                  $env_name"
echo -e "  • ${BOLD}Flavor:${NC}                   $flavor"
echo -e "  • ${BOLD}Tipo de Artefacto:${NC}        $artifact_label"
echo -e "  • ${BOLD}Versión Generada:${NC}         $new_version"
echo -e "  • ${BOLD}Artefacto(s) Generado(s):${NC}"
for art in "${found_artifacts[@]}"; do
    size=$(ls -lh "$art" | awk '{print $5}')
    echo -e "    - Ruta:   ${CYAN}$art${NC}"
    echo -e "      Tamaño: ${BOLD}$size${NC}"
done

if [ "$env_name" = "PROD" ] && [ -n "$SYMBOLS_DIR" ]; then
    echo -e "  • ${BOLD}Símbolos de Desofuscación:${NC}"
    echo -e "    - Ruta:   ${CYAN}$SYMBOLS_DIR${NC}"
fi
echo -e "${GREEN}${BOLD}================================================================${NC}"
