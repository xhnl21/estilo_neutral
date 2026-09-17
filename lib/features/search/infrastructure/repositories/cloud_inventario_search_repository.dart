import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../domain/entities/inventario_item.dart';
import '../../domain/repositories/search_repository.dart';

/// Implementación del repositorio de búsqueda que consume los datos de inventario
/// directamente desde la nube (Google Sheets a través de [SheetsDataService]).
class CloudInventarioSearchRepository implements SearchRepository<InventarioItem> {
  final SheetsDataService? _dataService;
  final List<InventarioItem> _staticItems;
  final Map<String, String> _customSynonyms;

  /// Crea un repositorio de búsqueda de inventario.
  ///
  /// Si se proporciona [_dataService], los elementos se obtienen reactivamente
  /// de los productos cargados en memoria desde Google Sheets.
  /// Si no, se utilizan los elementos estáticos provistos en [fallbackItems].
  CloudInventarioSearchRepository({
    SheetsDataService? dataService,
    List<InventarioItem>? fallbackItems,
    Map<String, String>? customSynonyms,
  })  : _dataService = dataService,
        _staticItems = fallbackItems ?? _defaultInventarioCatalog,
        _customSynonyms = customSynonyms ?? _defaultInventarioSynonyms;

  @override
  List<InventarioItem> getItems() {
    final ds = _dataService;
    if (ds != null && ds.productos.isNotEmpty) {
      return ds.productos
          .map((p) => InventarioItem.fromProducto(p))
          .toList();
    }
    return List.unmodifiable(_staticItems);
  }

  @override
  Map<String, String> getSynonyms() {
    final synonyms = <String, String>{};
    final currentItems = getItems();

    for (final item in currentItems) {
      final buffer = StringBuffer()
        ..write('${item.marca} ')
        ..write('${item.modelo} ')
        ..write('${item.talla} ')
        ..write('${item.id} ');

      final custom = _customSynonyms[item.id];
      if (custom != null && custom.isNotEmpty) {
        buffer.write('$custom ');
      }

      synonyms[item.id] = buffer.toString().trim();
    }

    return synonyms;
  }

  /// Catálogo de demostración/fallback en caso de no contar aún con conexión a la nube.
  static const List<InventarioItem> _defaultInventarioCatalog = [
    InventarioItem(
      id: 'p00000001',
      name: 'Camisa Oxford Manga Larga',
      marca: 'Tommy Hilfiger',
      modelo: 'Classic Fit',
      talla: 'M',
      cantidad: 15,
      precioUsd: 35.0,
    ),
    InventarioItem(
      id: 'p00000002',
      name: 'Pantalón Jean 501 Original',
      marca: "Levi's",
      modelo: 'Straight Leg',
      talla: '32',
      cantidad: 20,
      precioUsd: 45.0,
    ),
    InventarioItem(
      id: 'p00000003',
      name: 'Franela Dri-FIT Deportiva',
      marca: 'Nike',
      modelo: 'Training Legend',
      talla: 'L',
      cantidad: 30,
      precioUsd: 25.0,
    ),
    InventarioItem(
      id: 'p00000004',
      name: 'Chaqueta Impermeable Cortaviento',
      marca: 'Columbia',
      modelo: 'Glennaker Lake',
      talla: 'XL',
      cantidad: 8,
      precioUsd: 65.0,
    ),
    InventarioItem(
      id: 'p00000005',
      name: 'Zapatos Deportivos Running',
      marca: 'Adidas',
      modelo: 'Ultraboost Light',
      talla: '42',
      cantidad: 12,
      precioUsd: 110.0,
    ),
    InventarioItem(
      id: 'p00000006',
      name: 'Polo Piqué Algodón Premium',
      marca: 'Lacoste',
      modelo: 'L1212 Classic',
      talla: 'M',
      cantidad: 18,
      precioUsd: 55.0,
    ),
    InventarioItem(
      id: 'p00000007',
      name: 'Suéter Tejido Cuello Redondo',
      marca: 'Zara',
      modelo: 'Soft Knit',
      talla: 'S',
      cantidad: 14,
      precioUsd: 28.0,
    ),
    InventarioItem(
      id: 'p00000008',
      name: 'Bermuda Cargo Algodón',
      marca: 'Dockers',
      modelo: 'Cargo Utility',
      talla: '34',
      cantidad: 22,
      precioUsd: 32.0,
    ),
  ];

  static const Map<String, String> _defaultInventarioSynonyms = {
    'p00000001': 'camisa vestir formal botones algodon ejecutiva tommy',
    'p00000002': 'jean vaquero pantalon mezclilla levis clasico 501',
    'p00000003': 'remera polera camiseta gym fitness running dry fit nike',
    'p00000004': 'abrigo campera lluvia chubasquero impermeable columbia',
    'p00000005': 'calzado tenis zapato suela running correr adidas ultra boost',
    'p00000006': 'remera chomba casual cocodrilo lacoste l1212',
    'p00000007': 'chompa buzo lana invierno sueter zara',
    'p00000008': 'short pantalon corto bolsillos playa dockers bermudas',
  };
}
