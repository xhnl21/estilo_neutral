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
  /// Si no, se utilizan los elementos estáticos provistos en [fallbackItems]
  /// (vacío por defecto: nunca se muestra un catálogo inventado).
  CloudInventarioSearchRepository({
    SheetsDataService? dataService,
    List<InventarioItem>? fallbackItems,
    Map<String, String>? customSynonyms,
  })  : _dataService = dataService,
        _staticItems = fallbackItems ?? const [],
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
