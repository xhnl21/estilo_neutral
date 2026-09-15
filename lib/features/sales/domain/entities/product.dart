import '../../../../core/types/aggregate_root.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/error/failures.dart';
import '../value_objects/product_id.dart';
import '../value_objects/stock_quantity.dart';
import '../events/sales_events.dart';

/// Aggregate Root: Product (Producto)
/// Invariantes: stock >= 0, precioUsd > 0
class Product extends AggregateRoot<ProductId> {
  StockQuantity _stock;
  final String _name;
  final String _brand;
  final String _model;
  final String _size;
  MoneyUsd _priceUsd;
  final String? _photoUrl;

  Product({
    required super.id,
    required StockQuantity stock,
    required String name,
    required String brand,
    required String model,
    required String size,
    required MoneyUsd priceUsd,
    String? photoUrl,
  })  : _stock = stock,
        _name = name,
        _brand = brand,
        _model = model,
        _size = size,
        _priceUsd = priceUsd,
        _photoUrl = photoUrl {
    if (_name.trim().isEmpty) {
      throw const ValidationFailure('El nombre del producto no puede estar vacío.');
    }
    if (_priceUsd.value <= 0) {
      throw const ValidationFailure('El precio del producto debe ser mayor a 0 USD.');
    }
  }

  StockQuantity get stock => _stock;
  String get name => _name;
  String get brand => _brand;
  String get model => _model;
  String get size => _size;
  MoneyUsd get priceUsd => _priceUsd;
  String? get photoUrl => _photoUrl;

  void decrementStock(int quantity) {
    if (quantity <= 0) return;
    final previous = _stock.value;
    _stock = _stock.decrement(quantity);

    if (previous > 0 && _stock.value == 0) {
      addDomainEvent(
        StockDepleted(
          eventId: '${id.value}_${DateTime.now().millisecondsSinceEpoch}',
          occurredOn: DateTime.now().toUtc(),
          productId: id.value,
        ),
      );
    }
  }

  void replenishStock(int quantity) {
    if (quantity <= 0) return;
    _stock = _stock.increment(quantity);
    addDomainEvent(
      StockReplenished(
        eventId: '${id.value}_${DateTime.now().millisecondsSinceEpoch}',
        occurredOn: DateTime.now().toUtc(),
        productId: id.value,
        newQuantity: _stock.value,
      ),
    );
  }

  void updatePrice(MoneyUsd newPrice) {
    if (newPrice.value <= 0) {
      throw const ValidationFailure('El nuevo precio debe ser mayor a 0 USD.');
    }
    _priceUsd = newPrice;
  }
}
