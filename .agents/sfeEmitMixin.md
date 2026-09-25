Implementa el patrón SafeEmitMixin en este proyecto Flutter (flutter_bloc) para eliminar el crash "Bad state: Cannot emit new states after calling close()".

Contexto del problema: en cualquier Cubit/Bloc, si un método async hace await sobre una llamada de red/repositorio y luego llama a emit(...), existe una ventana de carrera: si el widget que consume ese Cubit se desmonta mientras esa operación está en curso, Flutter cierra el Cubit antes de que el await resuelva, y el emit() posterior lanza una excepción no capturada. Es un bug real y frecuente.

Paso 1 — Crear el mixin base en lib/presentation/mixins/safe_emit_mixin.dart (ajusta la ruta a la convención del proyecto):

import 'package:flutter_bloc/flutter_bloc.dart';

mixin SafeEmitMixin<State> on BlocBase<State> {
void safeEmit(State state) {
if (!isClosed) {
// ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
emit(state);
}
}
}
Paso 2 — Auditar todo el proyecto: grep -rn "emit(" lib/ --include="\*.dart" | grep -v "safeEmit\|\.g\.dart". Para cada archivo, determina si es (a) un Cubit/Bloc propio sin el mixin o mezclando emit/safeEmit, (b) una clase "handler" inyectada — en ese caso revisa en el Cubit padre si le pasa emit: safeEmit (seguro) o el emit nativo (riesgo real a corregir en el padre), o (c) un mixin base tipo reset que ya tenga su propio guard isClosed.

Paso 3 — Reporta antes de tocar código: tabla archivo | tipo | veredicto (seguro/riesgo real/inconsistente) | nota. Si son muchos archivos, espera confirmación antes de aplicar cambios.

Paso 4 — Aplica el fix solo donde el veredicto sea riesgo real o inconsistente: agrega el import + with SafeEmitMixin<TuEstado>, reemplaza emit( → safeEmit( dentro de esa clase, simplifica cualquier guard manual redundante, y corrige los Cubits padres que inyectan el emit nativo a sus handlers en vez de safeEmit.

Paso 5 — Verifica: flutter analyze sin issues y suite de tests completa sin regresiones frente a la línea base anotada al inicio.

Notas: no lo agregues a clases que no son Cubit/Bloc; no cambies el contenido de ningún state.copyWith(...), es un cambio puramente de robustez; aplica el mismo mixin si el proyecto usa Bloc con Events (comparten BlocBase<State>).
