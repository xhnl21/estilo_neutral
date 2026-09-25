# Regla Arquitectónica: BLoC/Cubit Obligatorio e Innegociable

## Principio Fundamental

Toda reactividad de interfaz en `lib/presentation/` y `lib/features/**/presentation/` debe gobernarse exclusivamente mediante `flutter_bloc` (`BlocProvider`, `BlocBuilder`, `BlocConsumer`, `BlocListener`).

## Prohibiciones Terminantes
1. **No `ListenableBuilder`** sobre servicios de datos o estado de negocio.
2. **No consumo directo de `ChangeNotifier`** en widgets de pantalla.
3. **No `setState`** para listas, filtros, estado de carga, errores o datos de negocio.
4. **No mezclas híbridas**: El repositorio de datos (`SheetsDataService`) es envuelto por Cubits de alcance acotado.

## Estructura Estándar Obligatoria
- **State**: Inmutable, `Equatable`, enum `<Feature>Status { initial, loading, success, failure }`, `copyWith`.
- **Cubit**: Suscripción al repositorio en constructor (`addListener`), desuscripción en `close()` (`removeListener`), sincronización de estado, métodos de acción explícitos.
- **Page**: `StatelessWidget` que suministra el `BlocProvider` a la vista interna `_<Feature>View`.
