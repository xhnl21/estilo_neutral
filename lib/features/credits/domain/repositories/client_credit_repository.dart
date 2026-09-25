import '../entities/client_credit.dart';

/// Interfaz pura del repositorio de créditos de cliente (Domain Layer).
abstract class ClientCreditRepository {
  Future<List<ClientCredit>> getAllCredits();
  Future<List<ClientCredit>> getCreditsByCliente(String clienteId);
  Future<List<ClientCredit>> getAvailableCredits(String clienteId);
  Future<ClientCredit?> findById(String id);
  Future<bool> registerCredit(ClientCredit credit);
  Future<bool> annulCredit(String creditId, String motivo);
  Future<bool> applyCreditTransaction({
    required String clienteId,
    required String targetVentaId,
    required double amountToApply,
    required String userEmail,
  });
}
