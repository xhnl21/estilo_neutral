# Optimización de tamaño del APK

Este documento registra el trabajo de reducción de tamaño del binario Android, disparado por una auditoría externa (`informe_optimizacion_flutter.md`, en la raíz del repo) que detectó un APK release de ~111 MB con varias causas evitables. Acá queda qué se aplicó, los números reales medidos, y **cómo repetir/extender esto en el futuro** cuando cambien los assets o se agreguen plugins nuevos.

## Resultado medido

Build FAT (universal, 3 arquitecturas) y por ABI, antes/después de aplicar todo lo de este documento:

| Build | Antes | Después | Ahorro |
|---|---|---|---|
| APK universal (3 arch) | 113.2 MB | 79.2 MB | -30% |
| Split `arm64-v8a` | 76.8 MB | 42.2 MB | -45% |
| Split `armeabi-v7a` | 74.0 MB | 39.7 MB | -46% |
| Split `x86_64` | 78.3 MB | 43.7 MB | -44% |

Medido con `flutter build apk --release --flavor prod [--split-per-abi]` y comparando el tamaño del `.apk` resultante en `build/app/outputs/flutter-apk/`.

## 1. R8 (minify) + Resource Shrinking

`android/app/build.gradle.kts`, bloque `release`:

```kotlin
release {
    signingConfig = ...
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro"
    )
}
```

Ahorro aislado (medido comparando el mismo build FAT con y sin estas dos líneas, assets sin comprimir todavía): **~3.8 MB**. Es el menor de los tres factores, pero el de menor riesgo de romper algo si las reglas de ProGuard están bien puestas.

### `android/app/proguard-rules.pro`

Reglas para las librerías con código nativo/reflection que R8 puede romper si no se les hace `-keep` explícito:

- `com.google.android.gms.**` — Google Play Services / Google Sign-In (`google_sign_in_android`).
- `androidx.security.crypto.**` — `flutter_secure_storage` (Keystore / EncryptedSharedPreferences).
- `androidx.biometric.**` — `local_auth`.
- `androidx.media3.**` — `video_player` (ExoPlayer/Media3, splash con video).

**Si agregás un plugin nuevo con código nativo Android** (no Dart puro) y el build de release empieza a crashear en runtime pero funciona en debug, sospechá primero de R8 — agregá un `-keep class <paquete del plugin>.** { *; }` acá antes de desactivar `isMinifyEnabled` como parche.

**Validación pendiente de hacer manualmente:** un build de release con R8 activo compila sin error, pero eso no prueba que la app funcione — probá especialmente el login con Google (lo más sensible a reflection) en un dispositivo real antes de publicar.

## 2. Compresión de assets fuente (`icons.png` / `splash_screen.jpeg`)

Estas dos imágenes son la fuente de la mayoría del peso: `flutter_launcher_icons` y `flutter_native_splash` las usan para generar un set completo de PNGs por densidad en `android/app/src/main/res/` — si la fuente es gigante, cada copia generada también lo es, multiplicado por cada densidad (`mdpi` → `xxxhdpi`) y modo (claro/oscuro).

| Archivo | Antes | Después | Cómo |
|---|---|---|---|
| `assets/icons.png` | 7.0 MB (2048×2048) | 1.85 MB (1024×1024) | resize con `sips -z 1024 1024` |
| `assets/splash_screen.jpeg` | 2.77 MB (1536×2752) | 606 KB (misma resolución) | recompresión con `sips -s formatOptions 60` |

`android/app/src/main/res/` completo: **47 MB → 21 MB**.

### Cómo repetir esto si cambia el logo/splash

No hay `pngquant`/`optipng`/ImageMagick instalados en esta máquina — se usó `sips` (viene con macOS) y `cwebp` (instalado vía Homebrew, sin usar acá). Si el logo cambia:

```bash
# 1. Guardar el original en algún lado (git ya lo versiona, pero por las dudas).
cp assets/icons.png /tmp/icons_original.png

# 2. Redimensionar el ícono fuente a 1024x1024 (de sobra para cualquier
#    densidad de mipmap, incluyendo el ícono de Play Store de 512x512).
sips -z 1024 1024 assets/icons.png

# 3. Recomprimir el splash (JPEG) a calidad ~60 — visualmente sin pérdida
#    perceptible en pantalla de teléfono, ver antes/después con la
#    herramienta Read/Artifact antes de confiar en el número.
sips -s formatOptions 60 assets/splash_screen.jpeg

# 4. Regenerar íconos y splash nativos a partir de los archivos ya comprimidos.
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# 5. Medir.
flutter build apk --release --flavor prod --split-per-abi
ls -la build/app/outputs/flutter-apk/*.apk
```

**Siempre revisar visualmente el resultado antes de aplicarlo** (por ejemplo con la herramienta de lectura de imágenes de Claude Code, o simplemente abriendo el archivo) — la calidad JPEG y la resolución del ícono son ajustes con pérdida; 1024×1024 / calidad 60 funcionaron bien para esta imagen puntual (fondo de tela con texto), pero otra imagen con más detalle fino podría necesitar valores menos agresivos.

## 3. Por qué NO hay un `splits { abi {...} } }` fijo en `build.gradle.kts`

Se evaluó agregar la configuración nativa de Gradle para que cualquier build (incluso fuera del script, ej. Android Studio) genere APKs separados por ABI sin necesitar `--split-per-abi`. **Se decidió no hacerlo** — el propio plugin de Gradle de Flutter (`FlutterPlugin.kt`, función `configureAbis()`) advierte explícitamente:

> "abiFilters cannot be added to templates because it would break builds when `--split-per-abi` is used due to conflicting configuration."

En la práctica: si se fija `splits.abi.isEnable = true` a mano, la opción **"APK Universal"** del script (`scripts/build_app.sh`) dejaría de generar un APK universal — generaría splits igual, sin forma limpia de desactivarlo. El mecanismo correcto y soportado por Flutter es pasar `--split-per-abi` por línea de comandos, que es exactamente lo que ya hace `build_app.sh` para su opción 1 ("APK split-per-abi"), en los 3 flavors.

**Si necesitás splits desde fuera del script** (Android Studio, un `gradlew` directo): no hay forma de configurarlo permanentemente sin sacrificar el build universal — hay que invocar `flutter build apk --split-per-abi` como línea de comandos puntual.

## 4. `flutter_image_compress` — no es para estos assets

Se agregó esta dependencia en la misma sesión, pero **para un problema distinto**: comprimir las fotos que suben los usuarios a la galería de productos (`inventario_page.dart`), no las imágenes fuente de íconos/splash — ver [Galería de fotos § Recompresión antes de subir](google/galeria-fotos.md#recompresion-antes-de-subir-flutter_image_compress). Es un paquete de runtime (necesita el motor de Flutter corriendo, usa platform channels nativos) — no sirve como herramienta de línea de comandos para comprimir assets de build una sola vez; para eso se usó `sips` (punto 2 de este documento).

⚠️ Nota pendiente de seguimiento: el build tiró un warning de que `flutter_image_compress_common` todavía usa el Kotlin Gradle Plugin viejo (no el "Built-in Kotlin" nuevo) — compila bien hoy, pero Flutter avisa que en el futuro podría dejar de compilar si el paquete no se actualiza. Revisar el changelog del paquete si algún build futuro empieza a fallar por esto.

## Pendiente (del informe original, no aplicado todavía)

- **`video_player` + `assets/estilo_neutral.mp4`** (2.78 MB + libs nativas de ExoPlayer/Media3): sigue en uso para el splash con video. Reemplazarlo por una animación vectorial (Lottie o Flutter puro) ahorraría ese peso, pero implica una decisión de producto (cambiar la experiencia de apertura de la app), no solo técnica — no se tocó.
- **`change_app_package_name`** en `dev_dependencies`: sin uso activo en ningún script de build, pero documentado en `.agents/icon_splashScreen.md` como parte del procedimiento para renombrar el `applicationId` en el futuro — se dejó a propósito.
- **`Backups/`** en el repo (histórico de exports manuales del Sheet): fuera del alcance de este documento, ver [Troubleshooting](google/troubleshooting.md) si hace falta retomarlo.
