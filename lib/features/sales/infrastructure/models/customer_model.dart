import '../../domain/entities/customer.dart';
import '../../domain/value_objects/customer_id.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/iso_date.dart';

/// Modelo de Infraestructura: Mapeo 1:1 con la hoja "clientes"
class CustomerModel {
  final String id;
  final String nombre;
  final String telefono;
  final String email;
  final double saldoDeudaUsd;
  final String fechaRegistro;

  const CustomerModel({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.email,
    required this.saldoDeudaUsd,
    required this.fechaRegistro,
  });

  factory CustomerModel.fromRow(List<dynamic> row) {
    return CustomerModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      nombre: row.length > 1 ? row[1].toString() : '',
      telefono: row.length > 2 ? row[2].toString() : '',
      email: row.length > 3 ? row[3].toString() : '',
      saldoDeudaUsd: row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0,
      fechaRegistro: row.length > 5 ? row[5].toString() : '',
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      nombre,
      telefono,
      email,
      saldoDeudaUsd.toStringAsFixed(2),
      fechaRegistro,
    ];
  }

  Customer toEntity() {
    return Customer(
      id: CustomerId(id),
      name: nombre,
      phone: telefono,
      email: email,
      debtBalance: MoneyUsd(saldoDeudaUsd),
      registeredAt: IsoDate.fromString(fechaRegistro),
    );
  }

  factory CustomerModel.fromEntity(Customer entity) {
    return CustomerModel(
      id: entity.id.value,
      nombre: entity.name,
      telefono: entity.phone,
      email: entity.email,
      saldoDeudaUsd: entity.debtBalance.value,
      fechaRegistro: entity.registeredAt.toIso8601String(),
    );
  }
}
