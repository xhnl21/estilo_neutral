import 'package:flutter/foundation.dart';
import '../../../../core/core.dart';
import '../../application/application.dart';
import '../../domain/domain.dart';

/// Estados sellados de la interfaz de ventas (Sealed Classes)
sealed class SalesState {
  const SalesState();
}

class SalesInitial extends SalesState {
  const SalesInitial();
}

class SalesLoading extends SalesState {
  const SalesLoading();
}

class SalesSuccess extends SalesState {
  final List<SaleDto> sales;
  const SalesSuccess(this.sales);
}

class SalesError extends SalesState {
  final String userFriendlyMessage;
  const SalesError(this.userFriendlyMessage);
}

/// Controlador de ventas: consume exclusivamente Use Cases (CERO polling)
/// Justificación de arquitectura:
/// Se utiliza ChangeNotifier / ValueNotifier para mantener el controlador puro,
/// testeable, libre de dependencias pesadas y reactivo bajo demanda del usuario.
class SalesController extends ChangeNotifier {
  final CreateSaleUseCase createSaleUseCase;
  final RegisterPaymentUseCase registerPaymentUseCase;
  final RefreshSalesDataUseCase refreshSalesDataUseCase;
  final SaleRepository saleRepository;

  SalesState _state = const SalesInitial();
  SalesState get state => _state;

  SalesController({
    required this.createSaleUseCase,
    required this.registerPaymentUseCase,
    required this.refreshSalesDataUseCase,
    required this.saleRepository,
  });

  /// Carga inicial o refresco manual bajo demanda (PULL MANUAL, CERO POLLING)
  Future<void> loadSales({bool forceRefresh = false}) async {
    _state = const SalesLoading();
    notifyListeners();

    try {
      if (forceRefresh) {
        await refreshSalesDataUseCase(const NoParams());
      }
      final result = await saleRepository.findAll(forceRefresh: forceRefresh);
      result.fold(
        (failure) {
          _state = SalesError(failure.message);
        },
        (sales) {
          final dtos = sales.map((s) => SaleDto.fromDomain(s)).toList();
          _state = SalesSuccess(dtos);
        },
      );
    } catch (e) {
      _state = SalesError('Error inesperado al cargar las ventas: $e');
    }
    notifyListeners();
  }

  /// Acción de botón "Actualizar" en la UI
  Future<void> onRefreshButtonPressed() async {
    // No polling. Actualización bajo demanda del usuario.
    await loadSales(forceRefresh: true);
  }

  /// Registrar una nueva venta
  Future<bool> createSale(CreateSaleParams params) async {
    _state = const SalesLoading();
    notifyListeners();

    final result = await createSaleUseCase(params);
    return result.fold(
      (failure) {
        _state = SalesError(failure.message);
        notifyListeners();
        return false;
      },
      (createdDto) {
        // Relectura puntual bajo demanda tras escritura
        loadSales(forceRefresh: true);
        return true;
      },
    );
  }
}
