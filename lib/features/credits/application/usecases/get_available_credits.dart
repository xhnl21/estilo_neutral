import '../../domain/entities/client_credit.dart';
import '../../domain/repositories/client_credit_repository.dart';

/// Caso de Uso: Obtener todos los créditos disponibles (con saldo a favor) de un cliente.
class GetAvailableCredits {
  final ClientCreditRepository repository;

  const GetAvailableCredits(this.repository);

  Future<List<ClientCredit>> call(String clienteId) async {
    final credits = await repository.getAvailableCredits(clienteId);
    // Ordenar FIFO por fecha de emisión más antigua
    return List<ClientCredit>.from(credits)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }
}
