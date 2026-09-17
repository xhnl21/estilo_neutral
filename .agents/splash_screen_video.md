# Módulo de Splash Screen con Video (Estilo Neutral)

Implementación del módulo de splash screen en `lib/presentation/screens/splash/` para la aplicación **Estilo Neutral**, enfocado exclusivamente en la inicialización y reproducción fluida del video corporativo de introducción (`assets/estilo_neutral.mp4`), sin comprobación de sesión ni validaciones de autenticación.

### 1. Requerimientos Funcionales y Alcance

- **Objetivo Principal:** Cargar e iniciar la reproducción del video corporativo `assets/estilo_neutral.mp4` a pantalla completa adaptativa apenas arranca la app.
- **Sin Validación de Sesión:** Omitir cualquier llamada a endpoints, tokens en almacenamiento seguro o validación de estado de autenticación durante la reproducción del splash.
- **Transición Post-Video:** Al completarse la duración del video (o mediante el callback `onVideoFinished` o botón de omitir), liberar recursos y ejecutar la navegación hacia la ruta de inicio de sesión (`RoutePaths.login` o `/login`).
- **Resiliencia (Fallback):** Si ocurre un error al cargar o decodificar el archivo de video, la app no se congela; atrapa el error con `Logger.error`, remueve el splash nativo y navega inmediatamente a `RoutePaths.login`.

### 2. Configuración de Video y Plataforma Nativa

- **Dependencia en `pubspec.yaml`:**
  ```yaml
  dependencies:
    video_player: ^2.9.2
  ```
- **Declaración del Recurso en `pubspec.yaml`:**
  ```yaml
  flutter:
    assets:
      - assets/estilo_neutral.mp4
  ```
- **Configuración de Plataforma:**
  - **Android (`android/app/build.gradle.kts`):** `minSdk = 21` requerido para decodificación de hardware.
  - **iOS (`ios/Runner/Info.plist`):** Reproducción fluida mediante AVFoundation (integrado en el runner).

### 3. Arquitectura y Estructura de Archivos

Estructura implementada en el proyecto:

1. `lib/presentation/screens/splash/splash_screen.dart`:
   - Widget de entrada/pantalla que contiene el ciclo de vida del controlador (`VideoPlayerController`), maneja `initState`, inicialización asíncrona, listener de progreso/finalización, botón de "Omitir" accesible con `Semantics`, y liberación de memoria en `dispose()`.
2. `lib/presentation/screens/splash/views/splash_animation_view.dart`:
   - Componente visual desacoplado (`StatelessWidget`) que recibe el controlador y se encarga del renderizado a pantalla completa adaptativa usando `FittedBox(fit: BoxFit.cover, ...)` dentro de un `SizedBox.expand`, evitando bordes negros o distorsiones.
3. `lib/presentation/screens/splash/splash.dart`:
   - Archivo barril para exportar la pantalla y sus vistas.
4. `lib/features/auth/presentation/pages/login_page.dart` (y export en `lib/presentation/screens/login/login_screen.dart`):
   - Vista de inicio de sesión de destino tras la finalización del video.

### 4. Directrices Técnicas de Implementación

- **Controlador:**
  - Instanciar `VideoPlayerController.asset('assets/estilo_neutral.mp4')`.
  - Ejecutar `await controller.initialize()`.
  - Configurar volumen (`await controller.setVolume(1.0)`) y llamar a `controller.play()`.
- **Detección de Finalización:**
  - Listener reactivo que compara `position >= duration` para detonar la navegación exactamente una sola vez (controlado por la bandera `_hasNavigated`).
- **Ciclo de Vida y Prevención de Fugas de Memoria:**
  - Remover listeners y ejecutar `controller.dispose()` obligatoriamente en el método `dispose()`.
  - Verificar siempre `mounted` antes de cualquier llamada a `setState` o `context.go(RoutePaths.login)`.
- **Experiencia Visual y Marca:**
  - Fondo con el color institucional `AppPalette.blue900` mientras el video se inicializa para evitar destellos blancos.
  - Llamada a `FlutterNativeSplash.remove()` una vez inicializado y renderizado el primer frame.
