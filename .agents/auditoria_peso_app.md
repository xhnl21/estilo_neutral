# Prompt: Auditoría y optimización del tamaño de una app Flutter/Dart para Android e iOS

Actúa como ingeniero senior especializado en Flutter/Dart, optimización del tamaño de aplicaciones móviles, análisis de dependencias y limpieza de proyectos.

## Contexto

Estoy desarrollando una aplicación con Flutter y Dart. La aplicación solo debe funcionar en Android y iOS. El objetivo principal es disminuir el peso/tamaño de la aplicación final (APK/AAB/IPA) y limpiar el proyecto de elementos innecesarios.

Datos del proyecto:

- Ruta del proyecto: `{{RUTA_PROYECTO}}`
- Versión de Flutter: `{{VERSION_FLUTTER}}`
- Versión de Dart: `{{VERSION_DART}}`
- Plataformas objetivo: Android e iOS únicamente.
- Plataformas no objetivo: Web, Windows, Linux, macOS. Si existen, solo deben analizarse como posibles carpetas prescindibles, sin asumir que afectan al binario móvil.
- Archivos clave disponibles: `pubspec.yaml`, `pubspec.lock`, carpeta `lib/`, `android/`, `ios/`, `assets/`, `test/`, `integration_test/`.

## Objetivo

Realizar una auditoría completa del proyecto para detectar todo lo que pueda eliminarse, reemplazarse, optimizarse o revisarse, con el fin de reducir el tamaño de la app en Android e iOS. Además, se debe evaluar `pubspec.yaml` para determinar qué dependencias están realmente implementadas y cuáles no.

## Alcance

1. Analizar `pubspec.yaml`:
   - Dependencias directas.
   - `dev_dependencies`.
   - `dependency_overrides`.
   - Assets declarados.
   - Fuentes declaradas.
   - Plugins nativos.
   - Para cada dependencia, indicar si está usada, no usada, duplicada, obsoleta, reemplazable por el SDK, solo para desarrollo o sospechosa.
   - Aportar evidencia concreta: imports, rutas, archivos, líneas, referencias en Android/iOS o comandos ejecutados.
   - No afirmar que una dependencia no se usa sin evidencia.

2. Analizar estructura del proyecto:
   - Carpetas y archivos innecesarios.
   - Archivos temporales, duplicados o de backup.
   - Assets no referenciados.
   - Imágenes duplicadas, demasiado pesadas o en formatos no óptimos.
   - Fuentes no utilizadas o con todos los glifos cuando solo se usan algunos.
   - Carpetas de plataformas no objetivo que podrían eliminarse del repositorio.
   - Diferenciar claramente entre peso del repositorio y peso del binario final.

3. Medir y estimar impacto:
   - Ejecutar o indicar comandos como:
     - `flutter pub deps --style=compact`
     - `flutter pub outdated`
     - `flutter analyze`
     - `flutter build apk --release --analyze-size`
     - `flutter build appbundle --release --analyze-size`
     - `flutter build ios --release --analyze-size` si el entorno lo permite.
   - Revisar configuración Android: `minifyEnabled`, `shrinkResources`, R8/ProGuard, splits, `abiFilters`, recursos nativos.
   - Revisar configuración iOS: assets, Podfile, recursos nativos y tamaño de frameworks.
   - Estimar reducción de tamaño por cada acción propuesta.

4. Proponer plan de optimización:
   - Eliminar dependencias no usadas.
   - Reemplazar dependencias pesadas por alternativas más ligeras.
   - Aplicar tree shaking, ofuscación y separación de símbolos de depuración.
   - Optimizar imágenes, fuentes y assets.
   - Eliminar código muerto.
   - Configurar correctamente Android e iOS para release.
   - Priorizar acciones por impacto, esfuerzo y riesgo.

## Restricciones

- No elimines archivos ni modifiques `pubspec.yaml` sin autorización explícita.
- Primero entrega diagnóstico, evidencia y recomendaciones.
- Si se autoriza aplicar cambios, hazlo en una rama aparte, con respaldo previo, y ejecuta validaciones: `flutter pub get`, `flutter analyze`, `flutter test` y builds de prueba.
- No inventes resultados. Si no puedes ejecutar comandos, indica que el análisis es estático y explica qué comandos debería ejecutar el usuario.
- No confundas una carpeta no usada con código que realmente se empaqueta en el binario.

## Entregable final

Genera un documento en Markdown llamado `informe_optimizacion_flutter.md` con:

1. Resumen ejecutivo.
2. Alcance, supuestos y limitaciones.
3. Inventario de `pubspec.yaml` en tabla.
4. Dependencias usadas y no usadas, con evidencia.
5. Assets, fuentes e imágenes no utilizadas o mejorables.
6. Carpetas y archivos innecesarios.
7. Impacto estimado en el tamaño de la app.
8. Riesgos detectados.
9. Plan de acción priorizado.
10. Comandos ejecutados y resultados obtenidos.
11. Anexos con rutas, logs o capturas relevantes.

## Formato de incidencias

Cada incidencia debe registrarse en una tabla con estos campos:

| ID      | Categoría                                                 | Severidad                     | Descripción | Evidencia               | Impacto                              | Recomendación   | Riesgo              | Prioridad    | Estado                           |
| ------- | --------------------------------------------------------- | ----------------------------- | ----------- | ----------------------- | ------------------------------------ | --------------- | ------------------- | ------------ | -------------------------------- |
| INC-001 | Dependencia / Asset / Código / Configuración / Plataforma | Crítica / Alta / Media / Baja | ...         | archivo:línea o comando | tamaño / rendimiento / mantenimiento | acción concreta | bajo / medio / alto | P0 / P1 / P2 | detectado / propuesto / aplicado |

## Criterios de aceptación

- Cada incidencia debe incluir evidencia verificable.
- Cada recomendación debe indicar impacto y riesgo.
- Debe quedar claro qué afecta al tamaño real del APK/AAB/IPA y qué solo limpia el repositorio.
- El informe final debe ser detallado, trazable y listo para ejecutar acciones.
