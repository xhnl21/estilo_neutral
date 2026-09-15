# Reestructuración y Estandarización de Archivos Barril (DDD & Clean Architecture)

Este documento contiene el **Informe de Auditoría Inicial** y el **Plan de Trabajo Detallado** para cumplir con el requerimiento de estandarización de barriles y reglas de dependencia en el proyecto Flutter/Dart.

> [!NOTE]
>
> ## Decisiones Arquitectónicas (DDD - Enfoque Pragmático)
>
> Tras evaluar los principios de Domain-Driven Design (DDD), Clean Architecture estricto y el estado actual del sistema, se ha determinado lo siguiente:
>
> 1. **Mantener Estructura Layer-First:** Para mitigar el riesgo operativo sobre los más de 350 archivos existentes, se mantendrá la estructura orientada a capas en la raíz (`lib/domain`, `lib/infrastructure`, `lib/presentation`). La separación por contextos seguirá existiendo como subdirectorios dentro de cada capa.
> 2. **Capa Application:** Se extraerán los Casos de Uso (actualmente en `lib/domain/usecases`) hacia una nueva capa raíz independiente (`lib/application`), aislando el dominio puro tal como dicta Clean Architecture.

---

## 🔍 Informe de Auditoría Inicial

### 1. Estado de los Archivos de Barril

Se han encontrado barriles existentes (ej. `lib/presentation/screens/screens.dart`, `lib/infrastructure/infrastructure.dart`, `lib/domain/domain.dart`), pero presentan los siguientes problemas:

- Agrupan exportaciones de forma masiva (exportan todos los archivos indiscriminadamente).
- No encapsulan implementaciones. Por ejemplo, `infrastructure.dart` exporta `datasources` y `repositories`, haciéndolos públicos para todo el proyecto.
- No hay barriles por Bounded Context.

### 2. Violaciones Graves a la Regla de Dependencia

Se detectaron múltiples lugares en la capa de Presentación (`lib/presentation/...`) importando directamente clases concretas de la capa de Infraestructura (`lib/infrastructure/...`). Esto rompe el principio de Inversión de Dependencias (Dependency Inversion) de Clean Architecture.

**Ejemplos detectados (entre más de 40 ocurrencias):**

- **`onboarding_screen.dart`** importa directamente `onboarding_datasource.dart` y `onboarding_repository_impl.dart`.
- **`users_screen.dart`** importa `users_repository_impl.dart`, `users_datasource.dart`, y `users_local_datasource.dart`.
- **`dashboard_screen.dart`** importa `terms_remote_data_source.dart` y `terms_conditions_repository_impl.dart`.
- Múltiples **Cubits** en `lib/presentation/cubits/...` importan implementaciones de base de datos o conectividad (ej. `app_database_helper.dart`).

_Nota: La UI o los Blocs/Cubits solo deben depender de abstracciones (interfaces del Dominio) o Casos de Uso (Aplicación), y la inyección de la implementación concreta debe resolverse a través de un Service Locator o Dependency Injection (como get_it o provider) inicializado en `lib/app` o `main.dart`._

---

## 🛠️ Plan de Trabajo Detallado (Propuesta de Ejecución)

El plan de acción se ejecutará en las siguientes fases:

### Fase 1: Reorganización y Extracción de Capa Application

- **Mantener estructura base:** Preservar `lib/domain`, `lib/infrastructure` y `lib/presentation`.
- **Crear `lib/application`:** Extraer los casos de uso desde `lib/domain/usecases` hacia `lib/application/usecases`, agrupados por Bounded Context (ej. `lib/application/usecases/auth`).

### Fase 2: Creación/Actualización de Archivos Barril Contextuales

- **Eliminar barriles globales indiscriminados** (`lib/infrastructure/infrastructure.dart`, etc.).
- **Crear barriles de contexto por capa**: En lugar de un solo barril genérico por capa, crear barriles específicos para cada contexto.
  - Ejemplo Dominio: `lib/domain/auth.dart` exportará solo entidades y contratos de Auth.
  - Ejemplo Aplicación: `lib/application/auth.dart` exportará los casos de uso de Auth.
  - Infraestructura: Solo exportará lo necesario para el Service Locator en `lib/app`, asegurando que repositorios concretos y datasources no sean públicos para la UI.
  - Presentación: Se crearán barriles por módulo (ej. `lib/presentation/auth_screens.dart`) exportando pantallas principales y ocultando widgets privados.

### Fase 3: Refactorización de Imports y Corrección de Violaciones

- Reemplazar los imports profundos o absolutos por los nuevos barriles correspondientes.
- **Corregir violaciones de dependencia:** Modificaremos la inicialización en las pantallas y Cubits para que reciban la abstracción (interface o caso de uso) requerida a través de inyección de dependencias (DI) o del Service Locator (`lib/app/service_locator.dart`), eliminando todas las importaciones hacia `package:zas/infrastructure/...` desde presentación.

### Fase 4: Validación Automática y Documentación

- Configurar el archivo `analysis_options.yaml` (o script en CI) para lanzar errores si `lib/domain` o `lib/presentation` intentan importar paquetes de `lib/infrastructure`.
- Redactar un anexo `ARCHITECTURE.md` para dejar constancia formal de la política de barriles e inyección de dependencias para los desarrolladores.

---

## ✅ Verification Plan

### Automated Tests / Static Analysis

- Ejecutar `dart analyze` y validar 0 violaciones de código tras refactorizar.
- Implementar y ejecutar el script/linter para confirmar que no existen imports de `infrastructure` en las capas externas.

### Manual Verification

- Validar que el proyecto compila exitosamente.
- Revisar manualmente un Pull Request modelo de un bounded context (ej. Auth) asegurando que el barril sea limpio y cumpla DDD.
