Actúa como un Ingeniero DevOps / Mobile Release Engineer senior experto en Flutter y Bash scripting para entornos macOS y Linux.

Crea un script bash ejecutable llamado `scripts/build_app.sh` para la compilación local de la aplicación Flutter basada en el proyecto Estilo Neutral, extrayendo y adaptando la lógica de compilación de `scripts/build_and_distribute.sh`.

### ⚠️ Restricción Crítica

- **SOLO COMPILACIÓN**: No debe incluir ninguna lógica de Firebase CLI (ni instalación vía npm, ni comprobación de versión, ni subida a Firebase App Distribution, ni solicitud de release notes, ni IDs de aplicación/grupos de Firebase).

---

### Requerimientos Funcionales y Técnicos:

1. **Ubicación y Contexto de Ejecución**:
   - Garantizar que el script siempre cambie su directorio de trabajo a la raíz del proyecto Flutter, sin importar desde qué subdirectorio se invoque (`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, `cd "$SCRIPT_DIR/.."`).
   - Utilizar `set -e` para abortar inmediatamente ante cualquier error.

2. **Menú Interactivo de Selección de Entorno (Flavors)**:
   - Presentar un menú interactivo con las siguientes opciones:
     - `1) DEV` -> `flavor="dev"`, `env_file=".env.dev"`
     - `2) TEST (QA)` -> `flavor="qa"`, `env_file=".env.test"`
     - `3) PROD` -> `flavor="prod"`, `env_file=".env"`
   - Si la opción es inválida, emitir un mensaje de error claro y salir con código `1`.

3. **Menú de Tipo de Artefacto (Opcional o Configurable)**:
   - Permitir al usuario elegir qué compilar:
     - `1) APK (split-per-abi)`
     - `2) App Bundle (AAB para Google Play)`
     - `3) APK Universal`

4. **Validaciones Previas (Pre-flight Checks)**:
   - Verificar la existencia del archivo `.env` correspondiente al entorno seleccionado. Si no existe, detener la ejecución con error explicativo.
   - En caso de seleccionar `PROD`, verificar que exista `android/key.properties` para la firma de release. Si no existe, abortar la ejecución.

5. **Gestión de Versión en `pubspec.yaml`**:
   - Extraer la versión actual (`version: X.Y.Z+N`).
   - Incrementar automáticamente el build number (`+ (N + 1)`) manteniendo intacto el semantic version (`X.Y.Z`).
   - El reemplazo con `sed` debe ser portable y compatible tanto con macOS (BSD `sed -i ''`) como con Linux (GNU `sed -i`).
   - Imprimir en consola la transición de versión: `X.Y.Z+N -> X.Y.Z+(N+1)`.

6. **Limpieza y Preparación**:
   - Ejecutar `fvm flutter clean` y `fvm flutter pub get`.

7. **Parámetros de Compilación**:
   - Inyectar las variables de entorno mediante `--dart-define-from-file="$env_file"`.
   - Especificar `--flavor "$flavor"` y `--release`.
   - **Blindaje en Producción**:
     - Si el entorno es `PROD`, activar `--obfuscate` y guardar los símbolos de depuración en:
       `build/app/outputs/symbols/build/prod/v${new_version}` mediante `--split-debug-info`.
     - Si es `DEV` o `TEST`, desactivar la ofuscación para facilitar el profiling y depuración.

8. **Resumen de Resultados y Salida**:
   - Tras finalizar exitosamente, verificar la existencia del artefacto generado en `build/app/outputs/`.
   - Mostrar un banner de resumen en consola que indique:
     - Entorno (`DEV`, `TEST`, `PROD`).
     - Versión generada.
     - Ruta absoluta o relativa del artefacto (`.apk` o `.aab`).
     - Peso del archivo en formato legible para humanos (`ls -lh` / `du -h`).
     - Ruta de los símbolos de desofuscación (si aplica para `PROD`).
