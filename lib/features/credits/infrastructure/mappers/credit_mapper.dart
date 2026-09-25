import '../../domain/entities/client_credit.dart';
import '../models/client_credit_model.dart';

/// Mapper bidireccional para transformación de créditos entre Google Sheets y Dominio.
class CreditMapper {
  /// Convierte un mapa proveniente de la hoja Google Sheets en un [ClientCredit].
  static ClientCredit fromSheet(Map<String, dynamic> row) {
    return ClientCreditModel.fromMap(row);
  }

  /// Convierte un [ClientCredit] en un mapa para persistencia en Google Sheets.
  static Map<String, dynamic> toSheet(ClientCredit credit) {
    return ClientCreditModel.toMap(credit);
  }

  /// Convierte una lista de registros crudos a entidades [ClientCredit].
  static List<ClientCredit> fromSheetList(List<Map<String, dynamic>> rows) {
    return rows.map((r) => fromSheet(r)).toList();
  }

  /// Convierte una lista de entidades en mapas para persistencia.
  static List<Map<String, dynamic>> toSheetList(List<ClientCredit> list) {
    return list.map((c) => toSheet(c)).toList();
  }
}
