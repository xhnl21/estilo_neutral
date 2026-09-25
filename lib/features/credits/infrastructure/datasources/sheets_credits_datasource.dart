import '../../../../models/models.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../domain/entities/client_credit.dart';

/// Fuente de datos de infraestructura para sincronización de créditos con Google Sheets.
class SheetsCreditsDataSource {
  final SheetsDataService dataService;

  SheetsCreditsDataSource({required this.dataService});

  /// Lista en memoria de créditos cargados localmente
  final List<ClientCredit> _creditsCache = [];

  List<ClientCredit> get credits {
    final remote = dataService.creditosClientes;
    if (remote.isEmpty) {
      return List.unmodifiable(_creditsCache);
    }
    final map = <String, ClientCredit>{};
    for (final c in remote) {
      map[c.id.value] = c;
    }
    for (final c in _creditsCache) {
      map[c.id.value] = c;
    }
    return List.unmodifiable(map.values.toList());
  }

  void setCredits(List<ClientCredit> list) {
    _creditsCache.clear();
    _creditsCache.addAll(list);
  }

  void addCreditLocal(ClientCredit credit) {
    _creditsCache.removeWhere((c) => c.id == credit.id);
    _creditsCache.insert(0, credit);
    dataService.addCreditoClienteLocal(credit);
  }

  void updateCreditLocal(ClientCredit credit) {
    final idx = _creditsCache.indexWhere((c) => c.id == credit.id);
    if (idx != -1) {
      _creditsCache[idx] = credit;
    } else {
      _creditsCache.add(credit);
    }
    dataService.updateCreditoClienteLocal(credit);
  }

  String get nextCreditId {
    var maxN = 0;
    for (final c in credits) {
      final numStr = c.id.value.replaceAll(RegExp(r'\D'), '');
      final n = int.tryParse(numStr) ?? 0;
      if (n > maxN) maxN = n;
    }
    final nextNum = (maxN + 1).toString().padLeft(8, '0');
    return 'cr$nextNum';
  }

  Future<BatchTransactionResult> executeBatch(BatchTransaction transaction) {
    return dataService.executeBatchTransaction(transaction);
  }
}
