# Reglas del Proyecto: Gestión de Estado Estricta BLoC/Cubit

## Directriz Arquitectónica Paranoica e Inquebrantable

**BLoC / Cubit (`flutter_bloc`) es el ÚNICO patrón de gestión de estado reactivo autorizado en la capa de presentación. NO HAY EXCEPCIONES PARA ESTADO DE NEGOCIO O DATOS.**

Cualquier uso de los siguientes patrones en la capa de presentación constituye una **VIOLACIÓN CRÍTICA Y RECHAZO INMEDIATO**:
- ❌ **PROHIBIDO**: `ListenableBuilder` escuchando `SheetsDataService`, notifiers o servicios de datos.
- ❌ **PROHIBIDO**: `AnimatedBuilder` usado como mecanismo de reactividad sobre `ChangeNotifier` de negocio.
- ❌ **PROHIBIDO**: `ChangeNotifierProvider` o paquetes `provider` para estado de negocio en vistas.
- ❌ **PROHIBIDO**: Consumo directo de `ChangeNotifier` en `build()` sin envoltorio de Cubit.
- ❌ **PROHIBIDO**: `setState()` para gestionar datos de Sheets, colecciones, filtros de negocio o sincronización remota.

---

## Arquitectura Canónica: Cubit por Módulo

Cada pantalla/módulo de la aplicación DEBE tener su propio par `Cubit` + `State`:

1. **Estado Inmutable (`<modulo>_state.dart`)**:
   - Hereda de `Equatable`.
   - Incluye un enum de estado: `enum <Modulo>Status { initial, loading, success, failure }`.
   - Propiedades inmutables (`final List<...>`, filtros, mensajes de éxito/error).
   - Método `copyWith(...)` inmutable.

2. **Cubit Envoltorio (`<modulo>_cubit.dart`)**:
   - Hereda de `Cubit<<Modulo>State>`.
   - Recibe `SheetsDataService dataService` (o el servicio correspondiente).
   - En `_init()`, registra `dataService.addListener(_onDataServiceChanged)`.
   - En `close()`, ejecuta rigurosamente `dataService.removeListener(_onDataServiceChanged)`.
   - Expone métodos de acción (`refresh()`, `search()`, mutaciones CRUD) delegando en `dataService` y emitiendo estados tipados.

3. **Página / Widget de Entrada (`<modulo>_page.dart`)**:
   - Es un `StatelessWidget` que monta un `BlocProvider`:
     ```dart
     return BlocProvider(
       create: (_) => <Modulo>Cubit(dataService: dataService),
       child: const _<Modulo>View(),
     );
     ```
   - La vista interna (`_<Modulo>View`) reacciona mediante `BlocBuilder<<Modulo>Cubit, <Modulo>State>` o `BlocConsumer<<Modulo>Cubit, <Modulo>State>`.

---

## Única Excepción Admitida (Estado Efímero Local de Widget)

Se permite `StatefulWidget` o `ValueNotifier<T>` **únicamente** para:
- `TextEditingController` o `FocusNode`.
- Control de aperturas colapsables/acordeón locales (`ExpansionTile`).
- Animaciones puramente cosméticas locales (`AnimationController`).

Si el dato:
1. Proviene de Google Sheets / backend / red,
2. Debe compartirse o conservarse entre widgets, o
3. Representa un filtro, colección o entidad del dominio,
**ES ESTADO DE NEGOCIO Y OBLIGATORIAMENTE PERTENECE A UN CUBIT.**
