import '../models/currency_purchase_model.dart';

abstract class TreasurySheetsDataSource {
  Future<List<CurrencyPurchaseModel>> getPurchases();
  Future<void> savePurchase(CurrencyPurchaseModel purchase);
}

class InMemoryTreasurySheetsDataSource implements TreasurySheetsDataSource {
  final List<CurrencyPurchaseModel> _purchases = [];

  InMemoryTreasurySheetsDataSource({List<CurrencyPurchaseModel>? initialPurchases}) {
    if (initialPurchases != null) _purchases.addAll(initialPurchases);
  }

  @override
  Future<List<CurrencyPurchaseModel>> getPurchases() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_purchases);
  }

  @override
  Future<void> savePurchase(CurrencyPurchaseModel purchase) async {
    _purchases.removeWhere((p) => p.id == purchase.id);
    _purchases.add(purchase);
  }
}
