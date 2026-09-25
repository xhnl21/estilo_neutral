# Reglas del proyecto

## Gestión de estado: BLoC/Cubit es OBLIGATORIO, sin excepciones

**Esta regla es innegociable.** Toda la gestión de estado reactivo de la capa de presentación de este proyecto se hace con **BLoC/Cubit** (paquete `flutter_bloc`). No hay una segunda opción "válida en ciertos casos" — si una pantalla necesita reaccionar a datos que cambian, la respuesta es siempre un `Cubit`, nunca otra cosa.

### Por qué existe esta regla

El 2026-09-25 se detectó que el proyecto tenía un uso **mixto** e inconsistente de gestión de estado: la mayoría de las pantallas escuchaban directamente un `ChangeNotifier` (`SheetsDataService`, `AuthNotifier`) vía `ListenableBuilder`, mientras que solo dos módulos (`ClientesPage`/`ClientesCubit`, la búsqueda de inventario/`SearchCubit`) seguían BLoC/Cubit. Esto se consideró una **falta grave** de consistencia arquitectónica y se corrigió migrando **todo** el proyecto a Cubit. Que no se repita: cualquier código nuevo que reintroduzca `ListenableBuilder`, `AnimatedBuilder` sobre un `ChangeNotifier` propio, `Provider`/`ChangeNotifierProvider`, o `setState()` para modelar estado de negocio (no confundir con estado puramente visual/efímero de un widget, ver excepción abajo) **es una violación de esta regla** y debe rechazarse en revisión, sin importar que "funcione".

### Qué NO cambia: `SheetsDataService` sigue siendo un `ChangeNotifier`

`SheetsDataService` (capa de datos/repositorio sobre Google Sheets) se queda como `ChangeNotifier` — **no** se convierte en un Cubit gigante. Meter las 14 hojas y sus ~100 métodos CRUD en un solo `Cubit<State>` violaría el propio principio de BLoC de estado acotado por feature. En vez de eso, cada pantalla tiene su propio `Cubit` de alcance reducido que **envuelve** a `SheetsDataService` (se suscribe con `addListener`/`removeListener` y reemite un `State` propio, inmutable y tipado). El patrón de referencia, que se debe copiar literalmente para cualquier pantalla nueva o migración pendiente, es:

- [`lib/presentation/cubits/clientes/clientes_state.dart`](lib/presentation/cubits/clientes/clientes_state.dart) — estado inmutable con `Equatable`, un enum `XxxStatus {initial, loading, success, failure}`, `copyWith`.
- [`lib/presentation/cubits/clientes/clientes_cubit.dart`](lib/presentation/cubits/clientes/clientes_cubit.dart) — `Cubit` que recibe `SheetsDataService dataService`, hace `dataService.addListener(_onDataServiceChanged)` en `_init()`, resincroniza estado en `_syncFromService()`, expone un método por cada mutación (delegando siempre a `dataService.xxx(...)`, nunca reimplementando lógica de negocio) y hace `dataService.removeListener(...)` en `close()`.
- [`lib/presentation/pages/clientes_page.dart`](lib/presentation/pages/clientes_page.dart) — el widget externo es un `StatelessWidget` que solo monta un `BlocProvider(create: (_) => XxxCubit(dataService: dataService))`; la vista interna consume con `BlocBuilder`/`BlocConsumer<XxxCubit, XxxState>`.

### Excepción explícita (la única)

Estado puramente visual y efímero de un widget individual — el valor de un `TextEditingController`, si un `ExpansionTile` está abierto, la posición de scroll, una animación local — puede seguir usando `StatefulWidget`/`setState()`. La diferencia es: si el dato le importa a más de un widget, si viene de `SheetsDataService`/red, o si sobrevive a un rebuild por razones de negocio (no solo de UI), **es estado de negocio y va en un Cubit**, punto.

### Antes de tocar cualquier pantalla

1. Verificá si ya existe un `Cubit`/`State` para esa pantalla en `lib/presentation/cubits/<feature>/` o `lib/features/<feature>/presentation/cubit/`.
2. Si no existe, creálo siguiendo el patrón de referencia de arriba — no inventes una variante nueva.
3. Nunca agregues un `ListenableBuilder(listenable: dataService, ...)` ni un `ListenableBuilder(listenable: authCubit...)` nuevo. Si lo ves en una pantalla que estás tocando y todavía no fue migrada, migrala vos como parte del cambio.
