import '../entities/product.dart';

/// Domain Service: StockValidator (puro, sin estado)
class StockValidator {
  const StockValidator();

  bool canSell(Product product, int quantityToSell) {
    if (quantityToSell <= 0) return false;
    return product.stock.value >= quantityToSell;
  }
}
