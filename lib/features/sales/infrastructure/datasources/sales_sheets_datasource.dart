// No polling. Actualización bajo demanda del usuario.
// Cumplimiento estricto: OWASP MASVS / ISO/IEC 25010

import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';

abstract class SalesSheetsDataSource {
  Future<List<CustomerModel>> getCustomers();
  Future<void> saveCustomer(CustomerModel customer);
  Future<void> updateCustomer(CustomerModel customer);

  Future<List<ProductModel>> getProducts();
  Future<void> saveProduct(ProductModel product);
  Future<void> updateProduct(ProductModel product);

  Future<List<SaleModel>> getSales();
  Future<void> saveSale(SaleModel sale);
  Future<void> updateSale(SaleModel sale);
}

/// Implementación en memoria / simulador de Google Sheets
/// Permite testeo desacoplado y ejecución lista para inyección del cliente oficial de Google Sheets.
class InMemorySalesSheetsDataSource implements SalesSheetsDataSource {
  final List<CustomerModel> _customers = [];
  final List<ProductModel> _products = [];
  final List<SaleModel> _sales = [];

  InMemorySalesSheetsDataSource({
    List<CustomerModel>? initialCustomers,
    List<ProductModel>? initialProducts,
    List<SaleModel>? initialSales,
  }) {
    if (initialCustomers != null) _customers.addAll(initialCustomers);
    if (initialProducts != null) _products.addAll(initialProducts);
    if (initialSales != null) _sales.addAll(initialSales);
  }

  @override
  Future<List<CustomerModel>> getCustomers() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_customers);
  }

  @override
  Future<void> saveCustomer(CustomerModel customer) async {
    _customers.removeWhere((c) => c.id == customer.id);
    _customers.add(customer);
  }

  @override
  Future<void> updateCustomer(CustomerModel customer) async {
    final idx = _customers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) {
      _customers[idx] = customer;
    } else {
      _customers.add(customer);
    }
  }

  @override
  Future<List<ProductModel>> getProducts() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_products);
  }

  @override
  Future<void> saveProduct(ProductModel product) async {
    _products.removeWhere((p) => p.id == product.id);
    _products.add(product);
  }

  @override
  Future<void> updateProduct(ProductModel product) async {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _products[idx] = product;
    } else {
      _products.add(product);
    }
  }

  @override
  Future<List<SaleModel>> getSales() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_sales);
  }

  @override
  Future<void> saveSale(SaleModel sale) async {
    _sales.removeWhere((s) => s.id == sale.id);
    _sales.add(sale);
  }

  @override
  Future<void> updateSale(SaleModel sale) async {
    final idx = _sales.indexWhere((s) => s.id == sale.id);
    if (idx != -1) {
      _sales[idx] = sale;
    } else {
      _sales.add(sale);
    }
  }
}
