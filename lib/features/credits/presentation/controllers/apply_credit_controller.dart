import '../cubit/apply_credit_cubit.dart';

export '../cubit/apply_credit_cubit.dart';
export '../cubit/apply_credit_state.dart';

/// Controlador / Cubit para el flujo de compensación de créditos de clientes.
class ApplyCreditController extends ApplyCreditCubit {
  ApplyCreditController({
    required super.repository,
    required super.dataService,
  });
}
