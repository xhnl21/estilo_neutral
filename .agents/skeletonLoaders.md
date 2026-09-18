Prompt para profesional senior Flutter/Dart experto en UI/UX (Proyecto Estilo Neutral):

Implementar el estado de carga progresiva (Skeleton Loaders) en todas las vistas de la aplicación "Estilo Neutral" que requieran carga de datos asíncrona. Actualmente, mientras se obtienen los datos se muestra un indicador de carga genérico (CircularProgressIndicator) o un espacio en blanco, lo que afecta la percepción de rendimiento y la experiencia de usuario. El objetivo es reemplazar dichos estados por esqueletos visuales (skeleton loaders) que simulen la estructura final de la interfaz, con animación de shimmer o pulso, para mejorar la percepción de velocidad y mantener la coherencia visual.

El proyecto utiliza Flutter 3.x con Dart 3.11.1, manejo de estado con flutter_bloc 9.1.1 (y hydrated_bloc), navegación con go_router, y un ecosistema de dependencias que incluye cached_network_image, flutter_svg, carousel_slider, card_swiper, fl_chart, google_maps_widget, flutter_osm_plugin, video_player, audioplayers, calendar_date_picker2, dropdown_button2, entre otras. Las fuentes personalizadas son Outfit y Plus Jakarta Sans.

Objetivos específicos:

Identificar todas las vistas/pantallas que obtienen datos de fuentes asíncronas (API con Dio, bases de datos locales con Drift/SQLite, Firebase, etc.) y que actualmente muestran un loader tradicional o ningún placeholder.

Diseñar e implementar componentes reutilizables de skeleton loaders (por ejemplo: SkeletonBox, SkeletonCircle, SkeletonLine, SkeletonCard, SkeletonListTile, SkeletonChart, SkeletonMap, SkeletonCarousel, etc.) que imiten las dimensiones y formas de los elementos reales presentes en la aplicación, considerando los widgets utilizados (tarjetas con Card o Container, listas con ListView, gráficos con fl_chart, mapas con google_maps_widget, carruseles con carousel_slider/card_swiper, etc.).

Aplicar animación sutil de shimmer (degradado en movimiento) o pulso (opacidad) para indicar actividad, cuidando el rendimiento y evitando parpadeos.

Integrar los skeleton loaders en el ciclo de vida de cada vista, modificando los estados de los Blocs para que durante el estado de carga (LoadingState o similar) se muestren los skeletons correspondientes, y al finalizar (SuccessState o ErrorState) se reemplacen suavemente con una transición (fade) o un AnimatedSwitcher.

Asegurar que los skeleton loaders sean responsive y se adapten a diferentes tamaños de pantalla y orientaciones, utilizando MediaQuery y/o LayoutBuilder.

Mantener consistencia con el design system de la aplicación: colores, radios, espaciados, tipografía simulada (usar bloques grises con bordes redondeados en lugar de texto real), respetando las fuentes personalizadas para estimar alturas de línea.

Considerar componentes específicos que necesitan skeleton: imágenes con CachedNetworkImage (placeholder), listas de tarjetas, detalles con múltiples campos, gráficos financieros con fl_chart, mapas de ubicación con google_maps_widget, reproductores de video/audio, carruseles de banners, etc.

Tareas a realizar:

Auditar las vistas actuales y listar aquellas que necesitan skeleton loaders, priorizando las de uso más frecuente.

Crear una carpeta widgets/skeletons/ con componentes modulares y personalizables (tamaño, forma, color base, color de resaltado, etc.), preferiblemente con const constructors y parámetros opcionales.

Implementar una animación de shimmer reutilizable (por ejemplo, usando AnimationController y ShaderMask o Gradient animado) que pueda ser aplicada a cualquier skeleton, evitando dependencias externas salvo justificación.

Modificar los Blocs existentes para que en su estado de carga emitan un estado que permita identificar que se debe mostrar skeleton (puede ser un estado Loading con un tipo de skeleton o un flag). En los BlocBuilder correspondientes, reemplazar los CircularProgressIndicator o contenedores vacíos por los skeletons diseñados.

En caso de que algunas vistas ya tengan un manejo de errores específico, asegurarse de que el skeleton desaparezca y se muestre el mensaje de error correspondiente sin conflictos visuales.

Realizar pruebas en diferentes tamaños de pantalla y con datos de distinta longitud para validar que los skeletons no causen overflow y se vean proporcionados.

Documentar los nuevos componentes y su uso, incluyendo ejemplos de implementación en los Blocs.

Requerimientos técnicos:

Utilizar Flutter 3.x y Dart 3.11.1 (o la versión estable del proyecto).

Los skeletons deben ser ligeros y no bloquear el hilo principal; se recomienda usar RepaintBoundary para aislar la animación y evitar repintados innecesarios.

Preferir AnimatedSwitcher o AnimatedOpacity para la transición entre skeleton y contenido real.

Respetar el const constructor en widgets estáticos siempre que sea posible.

No introducir dependencias externas innecesarias; si se sugiere alguna (por ejemplo, shimmer), justificar su uso y verificar compatibilidad con las versiones actuales.

Mantener la arquitectura BLoC existente, sin introducir nuevos patrones de manejo de estado.

Asegurar que los skeletons para imágenes utilicen colores neutros y no interfieran con CachedNetworkImage (cuyo placeholder actual puede ser reemplazado por el skeleton correspondiente).

Criterios de aceptación:

Ninguna vista con carga asíncrona debe mostrar únicamente un spinner genérico; todas deben tener su skeleton correspondiente.

La animación shimmer debe ser fluida (60 fps en dispositivos de gama media) y no causar jank.

Al completarse la carga, el contenido real debe aparecer con una transición suave (fade, por ejemplo) de no más de 300 ms.

Los skeletons deben reflejar aproximadamente la estructura final (número de tarjetas, líneas, imágenes, etc.) para minimizar saltos de layout.

La implementación debe ser reutilizable: un mismo skeleton puede ser usado en varias vistas con parámetros.

El código debe seguir las buenas prácticas del proyecto (nombrado, arquitectura, separación de responsabilidades).

Se debe entregar una breve documentación con capturas de pantalla de antes/después y una lista de vistas modificadas.

Entregables:

Rama feature/skeleton-loaders con todos los cambios.

Listado de archivos nuevos y modificados.

Informe de revisión que incluya: vistas cubiertas, decisiones de diseño, posibles mejoras futuras.
