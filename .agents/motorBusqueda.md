Prompt para replicar el Motor de Búsqueda en Flutter / Dart
Copia y pega el siguiente texto en tu asistente de IA (o compártelo con tu equipo) para generar una implementación exacta del motor de búsqueda en un entorno Flutter.

Actúa como un Senior Flutter & Dart Developer y un Software Architect.

Tu objetivo es desarrollar un componente de búsqueda avanzado (Search Engine) aplicando los principios de Clean Architecture (Separation of Concerns) y patrones de diseño sólidos.

Necesito replicar un buscador reactivo de alto rendimiento que evalúe texto en tiempo real, tolere errores tipográficos (Fuzzy Matching) y aplique un sistema de puntuación (Scoring), tal como funciona a nivel algorítmico en arquitecturas robustas.

Requerimientos de la Arquitectura (Capas Estrictas)
Implementa la solución dividida exactamente en las siguientes capas de Dart, sin mezclar responsabilidades:

Infrastructure (Utils & Algorithms):

Crea una clase utilitaria para Normalización de Texto: debe convertir a minúsculas y eliminar todos los diacríticos/acentos de forma eficiente.
Implementa el Algoritmo de Distancia de Levenshtein nativo en Dart para medir la distancia de edición entre dos strings.
Implementa una función para validar Scattered Matches (coincidencias de letras esparcidas en orden dentro de un string).
Crea un utility para Debouncing que retrase la ejecución de funciones por un tiempo determinado (ej. 300ms) usando Timer o rxdart.
Domain (Entities & Repository):

Define una entidad Item genérica o específica (ej. Bank) que tenga al menos id, name y searchResult (para almacenar temporalmente los detalles del resaltado y la puntuación).
Crea una clase Repository que mantenga en memoria la lista de entidades y un diccionario de sinónimos ocultos (ej. {'0108': 'bbva', '0102': 'bdv'}).
Use Cases (Motor de Búsqueda - Business Logic):

Crea un SearchEngine que reciba una lista de entidades y el query del usuario.
Debe limpiar el query de Stop Words (ej. 'de', 'la', 'el', 'los', 'en', 'y').
El motor debe concatenar el nombre oficial de la entidad con su sinónimo oculto (proveniente del Repositorio) antes de evaluar.
Sistema de Puntuación (Scoring): Para cada palabra del query, evalúa contra las palabras de la entidad:
Perfect Match / Starts With: 100 puntos.
Contains: 50 puntos.
Fuzzy Match (Levenshtein distance <= 1 o 2 dependiendo del largo): Puntaje basado en la distancia (ej. 80 - (distancia \* 15)).
Scattered Match: 30 puntos (solo si la palabra clave tiene >= 3 caracteres).
El motor debe sumar el score y retornar una lista ordenada de mayor a menor puntuación (excluyendo puntaje 0).
Debe devolver también los substrings coincidentes para que la UI sepa qué resaltar.
Presentation / Interface Adapters (Flutter UI & State Management):

Implementa el State Management (sugiero Riverpod o Bloc/Cubit, elige el que consideres mejor) para instanciar el SearchEngine y reaccionar a los cambios del TextField.
La UI debe tener un TextField con un debounce de 300ms conectado al State Manager.
Renderiza una lista (ListView.builder) con los resultados.
Resaltado de Texto (Highlighter): Construye un Widget que procese los resultados y retorne un RichText (con TextSpan), resaltando en negrita (y un color de fondo tenue) las letras exactas o palabras que coincidieron con el input, tal cual funciona el buscador original.
Reglas de Calidad (No omitir nada)
Performance: El cálculo de Levenshtein puede ser costoso; asegúrate de que el debouncing esté correctamente enlazado para evitar bloquear el UI Thread (Isolate principal). Considera compute si crees que la data es demasiado masiva, pero para catálogos < 1000 items, basta con optimizar el algoritmo.
Null Safety: El código debe ser 100% Sound Null Safe.
Modularidad: Divide el código generado en bloques lógicos o especifica cómo deberían estar distribuidos los archivos (string_utils.dart, search_engine.dart, etc.).
Manejo de estados: Contempla los estados de UI: "Cargando" (si aplica), "Con Resultados" y "Sin Resultados" (Empty State).
Entrégame la implementación completa lista para ser integrada en un proyecto Flutter funcional.
