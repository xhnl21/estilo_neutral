📸 Librerías para Compresión de Imágenes
Existen opciones que utilizan código nativo para mayor rendimiento y otras implementadas puramente en Dart.

Paquete Descripción Plataformas Características Clave
flutter_image_compress Es el paquete más popular y establecido para comprimir imágenes. Utiliza plugins nativos (Obj-C/Kotlin) para un alto rendimiento. Android, iOS, macOS, Web, OpenHarmony. - Compresión de archivos y assets.

- Control de calidad, rotación y dimensiones.
- Soporte para formatos JPEG, PNG, WebP, HEIC.
  image_compress_plus Un fork comunitario y activamente mantenido de flutter_image_compress. Busca mejorar el rendimiento y la compatibilidad con las versiones más recientes de Flutter. Android, iOS, Linux, Windows, macOS, Web, OpenHarmony. - Mismas funcionalidades que el original.
- Enfoque en mantenimiento y corrección de errores de compatibilidad.
  smart_image_compress Librería diseñada para comprimir imágenes de forma automática e inteligente a límites de tamaño o resolución configurables, preservando la calidad. Multiplataforma - Compresión automática basada en objetivos.
- Procesamiento por lotes (batch) usando isolates para no bloquear la UI.
  nice_image_compress Un plugin que utiliza algoritmos inteligentes para balancear el tamaño final y la calidad de la imagen. Es una implementación pura en Dart, por lo que funciona en todas las plataformas de Flutter. Todas las plataformas de Flutter (implementación en Dart). - Ajuste adaptativo de calidad para alcanzar un tamaño objetivo.
- Soporte para JPEG, PNG, y WebP.
- Control de dimensiones y preservación de metadatos EXIF.
  flutter_luban Una implementación en Dart inspirada en Luban, un conocido algoritmo de compresión para Android. No tiene dependencias de plataforma nativa. Todas las plataformas de Flutter (implementación en Dart). - Algoritmo de compresión estilo Luban.
- Sin restricciones de plataforma, lo que simplifica su integración.
  🎥 Librerías para Compresión de Video
  La compresión de video es computacionalmente intensiva, por lo que la mayoría de las librerías dependen de APIs nativas del sistema operativo.

Paquete Descripción Plataformas Características Clave
video_compress Es una de las librerías más ligeras y populares para la manipulación de video en Flutter. Se enfoca en la compresión y tareas relacionadas. Android, iOS, macOS - Compresión de video con control de calidad (baja, media, alta).

- Eliminación de audio.
- Generación de miniaturas (thumbnails).
  flutter_video_compressor Un plugin que ofrece compresión de video, imagen y audio utilizando los algoritmos nativos de la librería React Native Compressor para un rendimiento óptimo. Android, iOS - Compresión de video (MP4, MOV, AVI).
- Compresión de imagen (JPEG, PNG, WebP).
- Seguimiento del progreso en tiempo real.
- Generación de miniaturas y gestión de caché.
  native_video_compress Un plugin enfocado en la compresión de video nativa en iOS y Android. Ofrece un control detallado sobre los parámetros de codificación. Android, iOS - Soporte para códecs de video (h264, h265/hevc) y audio (aac, alac, mp3).
- Control de bitrate, resolución y frecuencia de muestreo.
- Callback de progreso en tiempo real (0.0 → 1.0).
  light_compressor Un plugin de compresión de video descrito como potente y fácil de usar, similar a la librería LightCompressor de Android. Android, iOS - API sencilla para comprimir videos.
- Enfocado en ser una solución ligera y directa.
  📦 Soluciones Unificadas (Imagen y Video)
  Si prefieres una única dependencia para manejar ambos tipos de medios, estas opciones son ideales.

Paquete Descripción Plataformas Características Clave
flutter_media_compress Ofrece una API unificada para comprimir imágenes, videos, audio y documentos. Es una solución "todo en uno" con presets de calidad y procesamiento por lotes. Multiplataforma - Detección automática del tipo de archivo.

- Presets de calidad (baja, media, alta, ultra).
- Estadísticas de compresión (ratio, bytes ahorrados).
- Opción de crear un respaldo antes de comprimir.
  flutter_video_compressor Aunque su nombre se centra en video, este paquete también maneja la compresión de imágenes y audio, como se mencionó anteriormente. Android, iOS - API unificada para los tres tipos de medios.
- Progreso en tiempo real y generación de miniaturas.
  💡 ¿Cómo elegir?
  Para imágenes: Si buscas el máximo rendimiento, elige flutter_image_compress o su fork image_compress_plus. Si prefieres una solución pura en Dart que funcione en cualquier plataforma sin complicaciones, nice_image_compress o flutter_luban son excelentes opciones.

Para videos: video_compress es una opción ligera y probada. Si necesitas funcionalidades más completas (como compresión de imagen y audio en un solo paquete) o seguimiento de progreso detallado, flutter_video_compressor o native_video_compress son más adecuados.

Para ambos: Si deseas simplificar tus dependencias, flutter_media_compress es una opción muy completa que unifica el manejo de múltiples tipos de archivos.

Si tu proyecto requiere comprimir los archivos antes de subirlos a Google Drive (como se sugiere en tu contexto anterior), cualquiera de estas librerías te será de gran utilidad para optimizar el almacenamiento y el ancho de banda.
