Actúa como un arquitecto de software Flutter senior especializado en Domain-Driven Design (DDD) y go_router.

CONTEXTO DEL PROYECTO:

- Framework: Flutter con Dart.
- Arquitectura: DDD por capas (domain, application, infrastructure, presentation).
- Organización: feature-first. Cada feature vive en lib/features/<feature>/ y se divide en:
  - domain/ (entidades, value objects, repositorios abstractos, servicios de dominio)
  - application/ (casos de uso, DTOs, servicios de aplicación)
  - infrastructure/ (implementaciones de repositorios, clientes HTTP, almacenamiento local)
  - presentation/ (páginas, widgets, controladores/blocs, rutas)
- Gestión de estado: <Riverpod / Bloc / GetX / Provider / otro>.
- Inyección de dependencias: <Riverpod / GetIt / Injectable / otro>.
- Autenticación: <describe brevemente cómo se obtiene el estado de autenticación, ej. un AuthRepository en domain, un AuthNotifier en application, etc.>.
- UI persistente: <bottom navigation bar / drawer / tabs / ninguna>.
- Versión de go_router: <última estable / v14 / otra>.

OBJETIVO:
Implementar go_router de forma centralizada, declarativa y desacoplada, respetando la arquitectura DDD. La navegación debe ser testeable, manejar deep linking, guards de autenticación y preservar el estado de la UI cuando corresponda.

REQUISITOS FUNCIONALES:

1. Añadir la dependencia go_router en pubspec.yaml.
2. Crear la configuración del router en la capa de presentación, por ejemplo en lib/core/router/ o lib/presentation/router/.
3. Definir constantes de rutas y nombres (path y name) para evitar strings mágicos.
4. Cada feature debe poder exponer sus propias rutas de forma modular. Si es posible, usa una abstracción tipo `FeatureRouter` o `RouteDefinition` que devuelva una lista de `GoRoute`.
5. Usar `StatefulShellRoute.indexedStack` (o `ShellRoute` si no se requiere preservar estado) para la UI persistente (bottom navigation, drawer, etc.).
6. Implementar redirecciones (redirect) para:
   - Autenticación: redirigir a /login si el usuario no está autenticado y la ruta es privada.
   - Onboarding: redirigir a /onboarding si no se ha completado.
   - Rutas públicas: permitir acceso sin autenticación.
7. Manejar deep linking con parámetros de ruta y query parameters. Ejemplos: /product/:id, /search?q=texto.
8. Configurar un `errorBuilder` para mostrar una página 404 personalizada y errores de navegación.
9. Definir transiciones personalizadas si es necesario (fade, slide, etc.).
10. Exponer el router a través del sistema de inyección de dependencias para que sea accesible y testeable.

REQUISITOS DE ARQUITECTURA DDD:

- El router vive en la capa de presentación. No debe contener lógica de negocio.
- Los guards deben consultar estados o casos de uso de la capa de aplicación/dominio, nunca implementaciones concretas de infraestructura.
- No usar `Navigator.push` directamente; usar `context.go`, `context.push`, `context.goNamed`, etc.
- Mantener el dominio y la aplicación libres de dependencias de Flutter/go_router.
- La configuración de rutas debe ser fácil de testear sin levantar toda la app.

ESTRUCTURA DE ARCHIVOS ESPERADA (ejemplo, ajústala a tu proyecto):
lib/
core/
router/
app_router.dart
route_names.dart
route_paths.dart
guards/
auth_guard.dart
onboarding_guard.dart
shells/
main_shell.dart
features/
auth/
presentation/
pages/
login_page.dart
routes/
auth_routes.dart
home/
presentation/
pages/
home_page.dart
routes/
home_routes.dart
...

ENTREGABLES:

1. Explicación paso a paso de la implementación.
2. Estructura de archivos final.
3. Código completo de cada archivo nuevo o modificado (pubspec.yaml, router, guards, shells, rutas por feature, páginas de ejemplo).
4. Ejemplos de navegación desde la UI: ir a una ruta, pasar parámetros, usar named routes.
5. Pruebas:
   - Unitarias para la lógica de redirección (guards).
   - De widget para verificar que la navegación funciona y que el shell persiste.
6. Consideraciones sobre cómo escalar la solución cuando se añadan nuevas features.
7. Advertencias sobre errores comunes y cómo evitarlos.

RESTRICCIONES:

- No uses paquetes obsoletos.
- Sigue las convenciones de Dart y Flutter (lint, nombres, organización).
- Si usas <gestor de estado>, intégralo correctamente con go_router (por ejemplo, escuchando cambios de autenticación para redirigir).
- El código debe ser production-ready, comentado donde sea necesario y fácil de mantener.
