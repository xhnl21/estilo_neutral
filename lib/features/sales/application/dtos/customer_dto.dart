import '../../domain/entities/customer.dart';

class CustomerDto {
  final String id;
  final String name;
  final String phone;
  final String email;
  final double debtBalanceUsd;
  final String registeredAt;

  const CustomerDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.debtBalanceUsd,
    required this.registeredAt,
  });

  factory CustomerDto.fromDomain(Customer customer) {
    return CustomerDto(
      id: customer.id.value,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      debtBalanceUsd: customer.debtBalance.value,
      registeredAt: customer.registeredAt.toIso8601String(),
    );
  }
}
