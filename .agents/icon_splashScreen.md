Actúa como un ingeniero DevOps/Flutter senior especializado en configuración de proyectos multiplataforma (Android + iOS).

CONTEXTO:

- Proyecto Flutter con Dart.
- Nombre de paquete actual: <indica el actual o "por defecto, ej. com.example.mi_app">.
- Nuevo nombre de paquete objetivo: com.estiloneutral.es.
- Imagen de marca (logo/ícono) disponible en: assets/Gemini_Generated_Image_siwabesiwabesiwa.png
- El proyecto debe quedar listo para producción (release) tanto en Android como en iOS.

OBJETIVO:
Ejecutar de forma ordenada y verificable las siguientes tres tareas sobre el proyecto:

1. CAMBIAR EL NOMBRE DEL PAQUETE (applicationId / bundle identifier)
2. CONFIGURAR EL SPLASH SCREEN NATIVO
3. CONFIGURAR LOS LAUNCHER ICONS (íconos de la app)

TAREAS DETALLADAS:

────────────────────────────────────────
TAREA 1 — Cambiar el nombre del paquete
────────────────────────────────────────

- Añadir la dependencia de desarrollo `change_app_package_name` en el `pubspec.yaml`.
- Ejecutar:
  dart run change_app_package_name:main com.estiloneutral.es
- Verificar que el cambio se aplicó correctamente en:
  - android/app/build.gradle (o build.gradle.kts) → applicationId y namespace.
  - android/app/src/main/AndroidManifest.xml → package.
  - android/app/src/main/kotlin/... → estructura de carpetas y package.
  - ios/Runner.xcodeproj/project.pbxproj → PRODUCT_BUNDLE_IDENTIFIER.
  - ios/Runner/Info.plist si aplica.
- Advertir sobre posibles errores (ej. carpetas antiguas de Kotlin que queden huérfanas) y cómo solucionarlos.

────────────────────────────────────────
TAREA 2 — Splash Screen nativo
────────────────────────────────────────

- Añadir la dependencia de desarrollo `flutter_native_splash` en el `pubspec.yaml`.
- Crear en la raíz del proyecto el archivo `flutter_native_splash.yaml` con la siguiente configuración base (ajústala según buenas prácticas):
  - Imagen: assets/Gemini_Generated_Image_siwabesiwabesiwa.png
  - Color de fondo: <indica el color hex, ej. "#ffffff" o "#0A0A0A">.
  - Modo oscuro opcional (color alternativo).
  - Configuración para Android 12+ (android_12) con su propia imagen y color.
  - Fullscreen: true.
- Ejecutar:
  dart run flutter_native_splash:create
- Verificar que se generaron los archivos:
  - android/app/src/main/res/drawable/launch_background.xml
  - android/app/src/main/res/values/styles.xml
  - android/app/src/main/res/drawable-v21/ y drawable-night/ si aplica
  - ios/Runner/Base.lproj/LaunchScreen.storyboard
  - ios/Runner/Assets.xcassets/LaunchImage.imageset/
- Añadir nota sobre cómo regenerar el splash cuando cambie la imagen o el color.

────────────────────────────────────────
TAREA 3 — Launcher Icons
────────────────────────────────────────

- Añadir la dependencia de desarrollo `flutter_launcher_icons` en el `pubspec.yaml`.
- Crear en la raíz del proyecto el archivo `flutter_launcher_icons.yaml` con la siguiente configuración:
  - android: true
  - ios: true
  - image_path: "assets/Gemini_Generated_Image_siwabesiwabesiwa.png"
  - adaptive_icon_background: <color hex o ruta de imagen>
  - adaptive_icon_foreground: "assets/Gemini_Generated_Image_siwabesiwabesiwa.png"
  - remove_alpha_ios: true
  - min_sdk_android: 21
- Ejecutar en orden:
  dart run flutter_launcher_icons:generate
  dart run flutter_launcher_icons
- Verificar que se generaron los íconos en:
  - android/app/src/main/res/mipmap-\*/ic_launcher.png
  - android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml (adaptive)
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/

────────────────────────────────────────
ORDEN DE EJECUCIÓN RECOMENDADO
────────────────────────────────────────

1. Cambiar el nombre del paquete.
2. Configurar el splash screen.
3. Configurar los launcher icons.
4. Ejecutar `flutter clean` y `flutter pub get` al final.
5. Probar en Android (`flutter run`) y en iOS (`flutter run` en simulador/dispositivo) para validar splash e íconos.

ENTREGABLES:

1. Explicación paso a paso de cada tarea.
2. Contenido completo de los archivos:
   - pubspec.yaml (sección dev_dependencies)
   - flutter_native_splash.yaml
   - flutter_launcher_icons.yaml
3. Comandos exactos a ejecutar en orden, en bloques de shell/bash.
4. Lista de archivos que se generan o modifican automáticamente por cada herramienta.
5. Checklist de verificación final (Android + iOS).
6. Advertencias sobre:
   - Rutas de imagen incorrectas.
   - Falta de `flutter pub get` antes de ejecutar los comandos.
   - Problemas comunes en iOS (assets no registrados, caché de Xcode).
   - Cómo revertir cada cambio si algo falla.

RESTRICCIONES:

- No modificar archivos nativos manualmente si la herramienta lo hace automáticamente.
- Usar siempre la imagen `assets/Gemini_Generated_Image_siwabesiwabesiwa.png` como fuente.
- Mantener las versiones más recientes y estables de cada paquete.
- El resultado debe estar listo para producción (release build) en Android e iOS.
- Configura el nombre de paquete actual desde las variables de entorno, nada debe estar hardcodeado, solo usando el valor de la variable de entorno APP_PACKAGE_NAME.
