# Informe de Auditoría y Optimización de Tamaño de Aplicación Flutter
**Proyecto:** Estilo Neutral (`com.innovo.zas`)  
**Fecha:** 17 de septiembre de 2026  
**Especialista:** Ingeniero Senior Flutter / Mobile Optimization  
**Plataformas Objetivo:** Android e iOS únicamente  
**Entorno:** Flutter 3.47.1 • Dart 3.13.1 • macOS Darwin 24.x  

---

## 1. Resumen Ejecutivo

Se ha completado una auditoría integral técnica, estática y de artefactos sobre el proyecto **Estilo Neutral**, orientada a maximizar la reducción del tamaño final del binario (APK, AAB e IPA) y a sanear la estructura del repositorio.

### Hallazgos Principales:
1. **Tamaño actual del APK Release Universal:** **111.0 MB** (`app-prod-release.apk`).
2. **Assets innecesariamente empaquetados en el bundle de Flutter:** **16.0 MB** directos. Se declararon imágenes fuente de build-time (`icon.png`, `icons.png`, `splash_screen.jpeg`) dentro de `flutter.assets:` en `pubspec.yaml`, las cuales no son consumidas por ningún widget Dart (`Image.asset`). Además, `icon.png` e `icons.png` son **100% idénticos** (mismo hash MD5), duplicando 6.7 MB.
3. **Drawables nativos sobredimensionados por splash e iconos:** Más de **40 MB** en `android/app/src/main/res/` y **12.5 MB** en `ios/Runner/Assets.xcassets/`. Las imágenes fuente de 2048x2048 (PNG sin comprimir) y 1536x2752 (JPEG de 2.6 MB) fueron copiadas/escaladas por las herramientas generadoras sin compresión previa a múltiples carpetas de densidad.
4. **Dependencia pesada de Video para Splash:** La dependencia `video_player: ^2.9.2` y el archivo `estilo_neutral.mp4` (6.2 MB) se utilizan exclusivamente para reproducir un video de introducción en `SplashScreen`. Esto arrastra librerías nativas como Google ExoPlayer en Android y frameworks AVFoundation en iOS (~4 a 8 MB adicionales).
5. **Dependencia HTTP duplicada y no implementada (`dio`):** Se identificó la presencia de `dio: ^5.11.1` en `pubspec.yaml`. Solo existe una clase wrapper `DioClient` y un test unitario; todo el flujo real de datos (Sheets, Drive, Auth, Apps Script) opera sobre `package:http`.
6. **Configuración de Release en Android subóptima:** En `android/app/build.gradle.kts`, `isMinifyEnabled` (R8 code shrinking) y `isShrinkResources` (resource shrinking) están desactivados por defecto. Además, la compilación produce un APK FAT multi-ABI (con `armeabi-v7a`, `arm64-v8a` y `x86_64` embebidos, sumando ~54 MB de librerías `.so`).
7. **Proyección de Reducción:** Aplicando las optimizaciones recomendadas, el tamaño de descarga por dispositivo (AAB o APK split `arm64-v8a`) descenderá de **111 MB a un rango estimado de 12 MB a 18 MB** (reducción superior al **85%**).

---

## 2. Alcance, Supuestos y Limitaciones

### Alcance
- **Código y configuración:** `pubspec.yaml`, `pubspec.lock`, `lib/`, `test/`, `android/app/build.gradle.kts`, `ios/Podfile`, carpetas de recursos y assets.
- **Plataformas evaluadas:** Android e iOS.
- **Herramientas utilizadas:** Flutter CLI (`flutter analyze`, `flutter pub deps`, `flutter pub outdated`, `flutter test`), utilidades de inspección de binarios (`unzip`, `sips`, `md5`, Python static scanner).

### Supuestos
- La funcionalidad corporativa de autenticación con Google (`google_sign_in`, `googleapis`) y almacenamiento seguro (`flutter_secure_storage`) es prioritaria y no prescindible.
- Los iconos de lanzador y la pantalla de splash nativa ya fueron generados en las carpetas nativas de Android e iOS.
- El proyecto no tiene como objetivo la web ni sistemas de escritorio (Linux, macOS, Windows).

### Limitaciones
- De acuerdo con las directrices de seguridad, no se han modificado archivos ni dependencias; este informe constituye la fase de diagnóstico, evidencia y planificación previa a cualquier cambio en rama controlada.
- La medición de iOS IPA se proyecta con base en el análisis de `Assets.xcassets` y pods declarados, sin ejecución de build de distribución Xcode en esta fase.

---

## 3. Inventario de `pubspec.yaml`

| Paquete | Versión Declarada | Versión Resuelta | Tipo | Clasificación | Propósito en el Proyecto |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `flutter` | sdk flutter | 0.0.0 (3.47.1) | SDK | Esencial / Core | Framework principal |
| `google_sign_in` | ^6.2.1 | 6.3.0 | Directa | Usada (Nativa) | Autenticación OAuth 2.0 con Google |
| `googleapis` | ^13.1.0 | 13.2.0 | Directa | Usada (Dart) | Clientes API Sheets v4 y Drive v3 |
| `http` | ^1.2.0 | 1.6.0 | Directa | Usada (Dart) | Cliente HTTP activo para Apps Script y APIs |
| `flutter_secure_storage` | ^9.0.0 | 9.2.4 | Directa | Usada (Nativa) | Keystore/Keychain para credenciales y tokens |
| `cupertino_icons` | ^1.0.8 | 1.0.9 | Directa | Usada (Assets) | Iconografía de diseño (tree-shaked en release) |
| `google_fonts` | ^6.1.0 | 6.3.3 | Directa | Usada (Red/Cache)| Tipografía `Inter` en `AppTypography` |
| `url_launcher` | ^6.3.2 | 6.3.2 | Directa | Usada (Nativa) | Apertura de URLs externas y Google Drive |
| `dio` | ^5.11.1 | 5.11.1 | Directa | **No Usada / Redundante** | Cliente HTTP wrapper sin uso en features |
| `flutter_bloc` | ^9.1.1 | 9.1.1 | Directa | Usada (Dart) | Gestión de estado reactivo (Cubit) |
| `equatable` | ^2.1.0 | 2.1.0 | Directa | Usada (Dart) | Igualdad de estados y entidades de dominio |
| `go_router` | ^14.8.1 | 14.8.1 | Directa | Usada (Dart) | Enrutamiento declarativo de pantallas |
| `video_player` | ^2.9.2 | 2.14.0 | Directa | **Sospechosa / Pesada** | Reproducción exclusiva de video splash corporativo |
| `flutter_native_splash` | ^2.4.8 | 2.4.8 | Directa | Config / Build | Generador de splash nativo + remove() runtime |
| `flutter_test` | sdk flutter | 0.0.0 | Dev | Esencial | Suite de pruebas automatizadas (133 tests) |
| `flutter_lints` | ^3.0.0 | 3.0.2 | Dev | Esencial | Análisis estático de código |
| `change_app_package_name`| ^1.5.0 | 1.5.0 | Dev | Obsoleta (Un solo uso) | Utilidad CLI para renombrar bundle ID |
| `flutter_launcher_icons` | ^0.14.4 | 0.14.4 | Dev | Generación (Build) | Generador de iconos nativos |

---

## 4. Análisis de Dependencias: Usadas, No Usadas y Redundantes

### 4.1. Dependencia No Usada / Redundante: `dio: ^5.11.1`
- **Evidencia:**
  - En `lib/`, la única coincidencia de `package:dio` es `lib/core/network/dio_client.dart:1`.
  - En `lib/core/core.dart:5` se exporta `'network/dio_client.dart'`.
  - Solo existe una prueba aislada en `test/core/dio_client_test.dart`.
  - Ninguna clase de negocio, repositorio (`SheetsRepository`), datasource (`AppsScriptSource`, `SheetsDataService`) ni BLoC utiliza `DioClient` ni `Dio`. Todo el consumo HTTP real se ejecuta a través de `package:http/http.dart`.
- **Diagnóstico:** Duplica clientes de red y arrastra librerías transitivas innecesarias (`dio_web_adapter`, etc.).
- **Recomendación:** Eliminar `dio` de `pubspec.yaml`, retirar `lib/core/network/dio_client.dart` y `test/core/dio_client_test.dart`, o en su defecto unificar el cliente HTTP con `http`.

### 4.2. Dependencia Pesada y Candidata a Reemplazo: `video_player: ^2.9.2`
- **Evidencia:**
  - Utilizado exclusivamente en `lib/presentation/screens/splash/splash_screen.dart:5` y `lib/presentation/screens/splash/views/splash_animation_view.dart:2`.
  - Reproduce únicamente el archivo `assets/estilo_neutral.mp4` (6.2 MB) durante el arranque.
- **Diagnóstico:**
  - `video_player` introduce librerías nativas completas: ExoPlayer (Media3) en Android y AVKit/AVFoundation en iOS.
  - Genera lentitud en el inicio en frío (cold start), consumo elevado de memoria y eleva el binario en ~10 a 14 MB (video + código nativo).
- **Recomendación:** Reemplazar el splash de video por una animación ligera basada en vectores (Lottie o CustomPainter nativo de Flutter), o depender directamente del splash nativo de `flutter_native_splash`.

### 4.3. Dependencia de un solo uso en `dev_dependencies`: `change_app_package_name`
- **Evidencia:** Utilidad CLI que ya cumplió su función para fijar el namespace `com.innovo.zas`.
- **Recomendación:** Retirar de `pubspec.yaml`.

### 4.4. `google_fonts: ^6.1.0`
- **Evidencia:** Utilizada únicamente en `lib/core/design_system/tokens/typography.dart` para la fuente `Inter`.
- **Diagnóstico:** Descarga fuentes dinámicamente vía HTTP o requiere empaquetado. No es crítica de eliminar, pero si se desea rendimiento offline estricto, una fuente local `.ttf` optimizada (subsetting) puede sustituir la librería completa.

---

## 5. Assets, Fuentes e Imágenes

### 5.1. Desglose de Archivos en `assets/`

| Archivo | Tamaño en Disco | Declarado en `pubspec.yaml` | Consumido en Dart (`lib/`) | Rol Real / Diagnóstico |
| :--- | :--- | :--- | :--- | :--- |
| `icon.png` | **6.7 MB** | **SÍ** | **NO** | Duplicado idéntico de `icons.png`. Solo sirve como imagen de origen para launcher icons. |
| `icons.png` | **6.7 MB** | **SÍ** | **NO** | Imagen de 2048x2048 sin comprimir. Origen para build-time de launcher icons y splash. |
| `splash_screen.jpeg` | **2.6 MB** | **SÍ** | **NO** | Imagen de 1536x2752 sin comprimir. Origen para build-time de `flutter_native_splash`. |
| `estilo_neutral.mp4` | **6.2 MB** | **SÍ** | **SÍ** | Video corporativo consumido en `SplashScreen`. |
| `estilo_neutral_video_audio.mp4` | **4.2 MB** | **NO** | **NO** | **Archivo huérfano** no declarado ni consumido. |
| `paleta_de_color_azul_pastel.png`| **6.2 KB** | **NO** | **NO** | **Archivo huérfano** de guía de diseño. |

### 5.2. El Grave Problema de los Assets Declarados en `pubspec.yaml`
En `pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/icon.png
    - assets/icons.png
    - assets/splash_screen.jpeg
    - assets/estilo_neutral.mp4
```
**Impacto en el Binario Móvil:**
Flutter incluye en el archivo empaquetado `flutter_assets/` **todos y cada uno de los archivos listados en la sección `assets:`**, sin importar si son referenciados en código Dart o no.
Al estar listados `icon.png`, `icons.png` y `splash_screen.jpeg`, el binario final (tanto APK como IPA) incluye **16.0 MB de imágenes no utilizadas en runtime**:
- `assets/flutter_assets/assets/icon.png` (7.0 MB descomprimido en el APK).
- `assets/flutter_assets/assets/icons.png` (7.0 MB descomprimido en el APK).
- `assets/flutter_assets/assets/splash_screen.jpeg` (2.7 MB descomprimido en el APK).

**Evidencia Verificable en `app-prod-release.apk`:**
```text
  2766263 bytes  assets/flutter_assets/assets/splash_screen.jpeg
  7017772 bytes  assets/flutter_assets/assets/icon.png
  7017772 bytes  assets/flutter_assets/assets/icons.png
```
**Acción Inmediata:** Quitar `assets/icon.png`, `assets/icons.png` y `assets/splash_screen.jpeg` de `pubspec.yaml`.

### 5.3. Inflado de Drawables Nativos en Android e iOS
Dado que `icons.png` (6.7 MB, 2048x2048) y `splash_screen.jpeg` (2.6 MB, 1536x2752) se utilizaron directamente en `flutter_launcher_icons.yaml` y `flutter_native_splash.yaml` sin compresión previa:
- **Android `android/app/src/main/res/`:**
  - `drawable/background.png`: **5.50 MB**
  - `drawable-v21/background.png`: **5.50 MB**
  - `drawable-night/background.png`: **5.50 MB**
  - `drawable-night-v21/background.png`: **5.50 MB**
  - `drawable-xxxhdpi/android12splash.png`: **5.57 MB**
  - `drawable-night-xxxhdpi/android12splash.png`: **5.57 MB**
  - `drawable-xxhdpi/android12splash.png`: **3.43 MB**
  - `drawable-night-xxhdpi/android12splash.png`: **3.43 MB**
  - `drawable-xhdpi/android12splash.png`: **1.71 MB**
  - `drawable-night-xhdpi/android12splash.png`: **1.71 MB**
  - **Total de recursos gráficos nativos en Android:** **> 40 MB**.
- **iOS `ios/Runner/Assets.xcassets/`:**
  - `LaunchBackground.imageset/background.png`: **5.50 MB**
  - `LaunchBackground.imageset/darkbackground.png`: **5.50 MB**
  - `AppIcon.appiconset/Icon-App-1024x1024@1x.png`: **1.57 MB**
  - **Total en iOS:** **> 12.5 MB**.

---

## 6. Carpetas y Archivos Innecesarios en el Repositorio

Se debe diferenciar estrictamente entre **peso del repositorio / workspace** y **peso del binario móvil final**:

| Ruta | Tamaño | Afecta Binario Móvil | Diagnóstico | Recomendación |
| :--- | :--- | :--- | :--- | :--- |
| `doc/api/` | **18.0 MB** | No | Salida de documentación HTML de `dartdoc`. | Eliminar del repositorio y añadir `doc/api/` a `.gitignore`. |
| `Backups/` | **252 KB** | No | Volcados locales de datos JSON, XLSX y CSV de pruebas. | Mover fuera del proyecto o archivar en almacenamiento secundario. |
| `web/` | **64 KB** | No | Plataforma no objetivo según las especificaciones del proyecto. | Puede conservarse si se prevé futuro soporte, o removerse del repositorio para sanear. |
| `assets/estilo_neutral_video_audio.mp4` | **4.2 MB** | No (no declarado) | Video huérfano alternativo en `assets/`. | Eliminar para reducir peso del repo y clonación Git. |
| `assets/paleta_de_color_azul_pastel.png`| **6.2 KB** | No (no declarado) | Imagen huérfana de diseño en `assets/`. | Mover a carpeta documental `docs/design/` o eliminar. |
| `assets/icon.png` | **6.7 MB** | Sí (está en pubspec) | Duplicado idéntico de `icons.png`. | Eliminar `icon.png` y conservar únicamente una versión comprimida de `icons.png`. |
| `.DS_Store` | Varios KB | No | Basura generada por macOS Finder en 7 rutas. | Eliminar recursivamente y asegurar su inclusión en `.gitignore`. |
| `.widget_preview/` | Variable | No | Artefactos temporales de visualizadores. | Añadir a `.gitignore`. |

---

## 7. Configuración de Compilación y Análisis de Binario

### 7.1. Diagnóstico del APK Actual (`app-prod-release.apk`)
- **Tamaño Total:** **111 MB** (116,518,912 bytes).
- **Desglose interno de los 111 MB:**
  1. **Librerías Nativas C++ / Dart VM (`lib/`):** **~54 MB** (FAT APK con 3 arquitecturas: `armeabi-v7a` ~15.8 MB, `arm64-v8a` ~18.2 MB, `x86_64` ~19.7 MB).
  2. **Recursos de Lanzador y Splash Nativo (`res/`):** **~35 MB**.
  3. **Flutter Assets (`assets/flutter_assets/`):** **~23 MB** (`icon.png` 7 MB + `icons.png` 7 MB + `splash_screen.jpeg` 2.7 MB + `estilo_neutral.mp4` 6.5 MB).
  4. **Código Java/Kotlin compilado (`classes.dex`):** **2.3 MB**.

### 7.2. Configuración en `android/app/build.gradle.kts`
Actualmente en `buildTypes.release`:
```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```
**Carencias detectadas:**
1. **R8 Minification inactivo:** No se tiene `isMinifyEnabled = true`. Sin esto, el código Java/Kotlin y los plugins de Android no sufren tree shaking ni optimización de bytecode.
2. **Resource Shrinking inactivo:** No se tiene `isShrinkResources = true`. Sin esto, Android no elimina recursos XML y drawables no referenciados de librerías de soporte.
3. **Ausencia de `proguard-rules.pro`:** No hay reglas configuradas para proteger reflection de plugins esenciales mientras se optimiza el resto.

### 7.3. Estrategia de Formato de Empaquetado: APK FAT vs App Bundle (AAB) / Splits
- El APK FAT incluye los binarios de 32 bits, 64 bits y emulador x86_64.
- Al generar un **Android App Bundle (`flutter build appbundle --release`)**, Google Play genera dinámicamente un APK específico para el dispositivo del usuario, descartando las otras dos arquitecturas (~35 MB de ahorro directo).
- Para pruebas directas de APK, compilar con `flutter build apk --release --split-per-abi` reduce el tamaño a un tercio de las librerías nativas.

---

## 8. Tabla Consolidada de Incidencias

| ID | Categoría | Severidad | Descripción | Evidencia | Impacto | Recomendación | Riesgo | Prioridad | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **INC-001** | Asset | **Crítica** | Assets de build-time declarados en `pubspec.yaml` sin ser consumidos en Flutter runtime. | `pubspec.yaml:36-38`; `app-prod-release.apk` contiene `icon.png`, `icons.png` y `splash_screen.jpeg`. | **16.0 MB** de peso muerto en binarios Android e iOS. | Retirar `icon.png`, `icons.png` y `splash_screen.jpeg` de la sección `flutter.assets:` de `pubspec.yaml`. | Bajo | **P0** | Detectado |
| **INC-002** | Asset | **Alta** | Imagen duplicada idéntica de 6.7 MB en disco. | `md5 assets/icon.png assets/icons.png` = `9b5e0cab9f3aaa583230a4f37bd05723`. | 6.7 MB de redundancia en disco y empaquetado. | Eliminar `assets/icon.png` y conservar únicamente la referencia a `icons.png`. | Bajo | **P0** | Detectado |
| **INC-003** | Configuración | **Crítica** | Drawables nativos de splash e iconos sobredimensionados en Android e iOS. | `android/res/drawable-*/` (>40 MB) y `ios/Runner/Assets.xcassets/` (>12.5 MB). | Más de 50 MB en binarios sin comprimir. | Comprimir imágenes fuente a WebP/PNG optimizado (< 300 KB) y regenerar iconos y splash nativo. | Medio | **P0** | Detectado |
| **INC-004** | Configuración | **Alta** | R8 Minification y Resource Shrinking inactivos en Android Release. | `android/app/build.gradle.kts:56-61` carece de `isMinifyEnabled = true` y `isShrinkResources = true`. | ~3 a 6 MB adicionales de código Java/Kotlin y recursos muertos. | Habilitar `isMinifyEnabled = true`, `isShrinkResources = true` y crear `proguard-rules.pro`. | Medio | **P1** | Detectado |
| **INC-005** | Dependencia / Código | **Alta** | Uso de `video_player` y video MP4 de 6.2 MB exclusivamente para splash. | `lib/presentation/screens/splash/splash_screen.dart`; `assets/estilo_neutral.mp4` (6.2 MB). | ~10 a 14 MB (video + ExoPlayer / AVKit nativos). | Reemplazar video splash por animación ligera (Lottie / Flutter Canvas) o splash nativo estático. | Medio | **P1** | Detectado |
| **INC-006** | Dependencia | **Media** | Dependencia HTTP redundante y sin uso funcional real (`dio`). | `pubspec.yaml:19`; `lib/core/network/dio_client.dart` sin consumidores en repositorios/servicios. | ~500 KB en binario y deuda técnica/duplicidad. | Eliminar `dio` de `pubspec.yaml` y su wrapper de red no utilizado. | Bajo | **P1** | Detectado |
| **INC-007** | Configuración | **Alta** | Compilación en APK FAT universal en lugar de App Bundle o Split ABIs. | `build/app/outputs/flutter-apk/app-prod-release.apk` contiene `armeabi-v7a`, `arm64-v8a` y `x86_64`. | ~35 MB de librerías nativas redundantes por dispositivo. | Utilizar `flutter build appbundle` para Play Store o `--split-per-abi` para distribución directa. | Bajo | **P0** | Detectado |
| **INC-008** | Repositorio | **Baja** | Presencia de documentación HTML generada (`doc/api/`) en el workspace. | `doc/api/` (18 MB en disco, 174 carpetas). | 18 MB de peso inútil en repositorio Git y clonación. | Eliminar carpeta `doc/api/` y agregar a `.gitignore`. | Nulo | **P2** | Detectado |
| **INC-009** | Repositorio | **Baja** | Archivo huérfano de video de 4.2 MB en carpeta `assets/`. | `assets/estilo_neutral_video_audio.mp4` (4.2 MB sin referencia en pubspec ni código). | 4.2 MB en workspace y repo. | Eliminar archivo huérfano. | Nulo | **P2** | Detectado |
| **INC-010** | Repositorio | **Baja** | Carpeta de backups manuales y volcados de base de datos en el proyecto. | `Backups/2026/` (252 KB con archivos xlsx, json, csv). | Contaminación del repositorio con datos estáticos. | Mover fuera del repositorio y configurar en `.gitignore`. | Nulo | **P2** | Detectado |
| **INC-011** | Dependencia | **Baja** | Paquete de desarrollo de un solo uso en `dev_dependencies`. | `change_app_package_name: ^1.5.0` en `pubspec.yaml:30`. | Dependencia innecesaria en pubspec. | Remover de `dev_dependencies`. | Nulo | **P2** | Detectado |

---

## 9. Impacto Estimado en el Tamaño de la Aplicación

| Acción Propuesta | Impacto en APK FAT | Impacto en AAB / APK Split | Impacto en iOS IPA | Impacto en Repositorio |
| :--- | :--- | :--- | :--- | :--- |
| **1. Retirar assets no utilizados de `pubspec.yaml`** (`icon.png`, `icons.png`, `splash_screen.jpeg`) | **-16.0 MB** | **-16.0 MB** | **-16.0 MB** | 0 MB (se conservan en disco para build tools) |
| **2. Optimizar / regenerar drawables nativos** (compresión de imágenes base para splash e iconos) | **-35.0 MB** | **-35.0 MB** | **-10.0 MB** | **-40 MB** en código fuente nativo |
| **3. Compilación por arquitectura (AAB o `--split-per-abi`)** | N/A (solo para distribución individual) | **-35.0 MB** | N/A | 0 MB |
| **4. Habilitar R8 (Minify) + Resource Shrinking en Android** | **-4.0 MB** | **-4.0 MB** | N/A | 0 MB |
| **5. Sustituir `video_player` y video MP4 por splash vectorial** | **-10.0 MB** | **-10.0 MB** | **-8.0 MB** | **-6.2 MB** |
| **6. Eliminar dependencia redundante `dio`** | **-0.5 MB** | **-0.5 MB** | **-0.5 MB** | 0 MB |
| **7. Limpieza de `doc/api/`, video huérfano y duplicados** | 0 MB | 0 MB | 0 MB | **-28.9 MB** |
| **REDUCCIÓN TOTAL ESTIMADA** | **De 111 MB a ~45 MB** | **De 111 MB a ~12 - 18 MB** | **Reducción de > 30 MB** | **-75.1 MB** |

---

## 10. Riesgos Detectados y Estrategias de Mitigación

1. **Riesgo en R8 / Obfuscation (`isMinifyEnabled`):**
   - *Riesgo:* R8 podría ofuscar o remover clases serializables necesarias para `googleapis`, `google_sign_in` o `flutter_secure_storage`.
   - *Mitigación:* Crear un archivo `android/app/proguard-rules.pro` con las reglas de exclusión estándar para Flutter, plugins de Google APIs y autenticación segura antes de activar `isMinifyEnabled`. Validar con build release y ejecución de login de prueba.
2. **Riesgo al remover `video_player`:**
   - *Riesgo:* Modificar el flujo de inicio si la experiencia de usuario corporativa exige ver el video completo.
   - *Mitigación:* Coordinar con el equipo de producto. La recomendación técnica es presentar un splash nativo instantáneo y una transición limpia a la pantalla de login, eliminando 14 MB de sobrecosto técnico.
3. **Riesgo al regenerar iconos y splash nativo:**
   - *Riesgo:* Pérdida de resolución o corte en pantallas de alta densidad si la compresión es agresiva.
   - *Mitigación:* Comprimir la imagen maestra con algoritmos sin pérdida (optipng / pngquant) manteniendo las dimensiones necesarias, o utilizar vectores vectoriales (`VectorDrawable` en Android y PDF/SVG en iOS).

---

## 11. Plan de Acción Priorizado

### Fase 1: Acciones Inmediatas (P0 - Máximo Impacto, Riesgo Mínimo)
1. **Editar `pubspec.yaml`:**
   - Remover las líneas de `assets/icon.png`, `assets/icons.png` y `assets/splash_screen.jpeg`.
   - Mantener únicamente `assets/estilo_neutral.mp4` (si aún se usa) o los assets reales de widgets.
   - Ejecutar `flutter pub get`.
2. **Limpieza de disco de assets duplicados y huérfanos:**
   - Eliminar `assets/icon.png` (redundante con `assets/icons.png`).
   - Eliminar `assets/estilo_neutral_video_audio.mp4` (huérfano).
3. **Optimización de imágenes base y regeneración de recursos nativos:**
   - Comprimir `assets/icons.png` y `assets/splash_screen.jpeg`.
   - Ejecutar `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.
4. **Validación de empaquetado:**
   - Ejecutar `flutter build apk --release --flavor prod --split-per-abi`.
   - Comprobar la reducción inmediata a menos de 30 MB por APK individual.

### Fase 2: Optimización de Código y Dependencias (P1 - Alto Impacto, Riesgo Medio)
1. **Configurar R8 y Shrinking en Android:**
   - Crear `android/app/proguard-rules.pro`.
   - Configurar `isMinifyEnabled = true` y `isShrinkResources = true` en `android/app/build.gradle.kts`.
   - Validar con `flutter test` y build release.
2. **Depuración de dependencias no usadas:**
   - Remover `dio: ^5.11.1` y eliminar `lib/core/network/dio_client.dart` y su test.
   - Remover `change_app_package_name: ^1.5.0` de `dev_dependencies`.
3. **Evaluación de eliminación de `video_player`:**
   - Sustituir `SplashScreen` de video por animación fluida de widgets Flutter o transición directa de splash nativo.

### Fase 3: Higiene del Repositorio y Mantenimiento (P2 - Bajo Impacto Binario)
1. Eliminar `doc/api/` y agregar su entrada a `.gitignore`.
2. Remover archivos `.DS_Store` del repositorio.
3. Trasladar la carpeta `Backups/` fuera del árbol de trabajo.

---

## 12. Comandos Ejecutados y Resultados de Auditoría

### 12.1. Diagnóstico de Herramientas
- `flutter --version`:
  - Flutter 3.47.1 (channel stable).
  - Dart 3.13.1 • DevTools 2.60.0.
- `flutter analyze`:
  - **Resultado:** `No issues found! (ran in 3.9s)`. Cero errores de sintaxis o advertencias de linter.
- `flutter test`:
  - **Resultado:** `133 tests passed!`. Toda la suite de pruebas unitarias y de integración de widgets se encuentra en estado verde.
- `flutter pub deps --style=compact`:
  - Se mapeó la jerarquía de 14 dependencias directas y 67 dependencias transitivas.
- `flutter pub outdated`:
  - Paquetes directos con actualización disponible: `equatable` (3.0.0), `flutter_secure_storage` (11.2.0), `go_router` (18.0.1), `google_fonts` (8.2.1), `google_sign_in` (7.2.0), `googleapis` (17.0.0). Se detectaron descontinuados en dependencias transitivas de plataformas no objetivo (`flutter_secure_storage_macos`, `js`).

### 12.2. Inspección de Binario (`app-prod-release.apk`)
```bash
unzip -l build/app/outputs/flutter-apk/app-prod-release.apk | sort -n -k1 | tail -n 25
```
**Extracto de pesos críticos encontrados en el APK:**
- `assets/flutter_assets/assets/icon.png`: 7,017,772 bytes
- `assets/flutter_assets/assets/icons.png`: 7,017,772 bytes
- `assets/flutter_assets/assets/estilo_neutral.mp4`: 6,522,939 bytes
- `assets/flutter_assets/assets/splash_screen.jpeg`: 2,766,263 bytes
- `res/3o.png` / `res/5l.png` / `res/rW.png` / `res/y_.png`: ~5.8 MB cada una
- `lib/armeabi-v7a`: 15.8 MB
- `lib/arm64-v8a`: 18.2 MB
- `lib/x86_64`: 19.7 MB

---

## 13. Conclusión
El proyecto presenta una excelente salud en cuanto a calidad de código y cobertura de pruebas (`flutter analyze` limpio y 133 pruebas pasando al 100%). No obstante, el tamaño final del binario (111 MB) está severamente penalizado por:
1. **Configuración errónea de assets en `pubspec.yaml`** (incluyendo recursos de build time en el paquete de runtime).
2. **Recursos gráficos nativos generados sin compresión previa**.
3. **Ausencia de R8 / Resource Shrinking en Android**.
4. **Distribución en APK FAT multi-arquitectura**.

La ejecución de las recomendaciones del presente informe permitirá reducir el peso final de distribución a menos de **18 MB** sin afectar ninguna funcionalidad de la aplicación.
