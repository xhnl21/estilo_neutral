import '../../domain/entities/sale.dart';

class SaleDto {
  final String id;
  final String date;
  final String customerId;
  final String firstItemId;
  final int totalQuantity;
  final double bcvRate;
  final double usdRate;
  final String paymentMethod;
  final double mobilePaymentFeeBs;
  final double montoBs;
  final double montoUsd;
  final double abonoUsd;
  final double deudaUsd;
  final double totalPagarUsd;
  final String validacion;
  final String estado;

  const SaleDto({
    required this.id,
    required this.date,
    required this.customerId,
    required this.firstItemId,
    required this.totalQuantity,
    required this.bcvRate,
    required this.usdRate,
    required this.paymentMethod,
    required this.mobilePaymentFeeBs,
    required this.montoBs,
    required this.montoUsd,
    required this.abonoUsd,
    required this.deudaUsd,
    required this.totalPagarUsd,
    required this.validacion,
    required this.estado,
  });

  factory SaleDto.fromDomain(Sale sale) {
    int totalQty = 0;
    for (final it in sale.items) {
      totalQty += it.quantity;
    }
    return SaleDto(
      id: sale.id.value,
      date: sale.date.toIso8601String(),
      customerId: sale.customerId.value,
      firstItemId: sale.items.isNotEmpty ? sale.items.first.productId.value : '',
      totalQuantity: totalQty,
      bcvRate: sale.bcvRate.value,
      usdRate: sale.usdRate.value,
      paymentMethod: sale.paymentMethod.sheetValue,
      mobilePaymentFeeBs: sale.mobilePaymentFeeBs.value,
      montoBs: sale.montoBs.value,
      montoUsd: sale.totalPagarUsd.value,
      abonoUsd: sale.paidAmount.value,
      deudaUsd: sale.deudaUsd.value,
      totalPagarUsd: sale.totalPagarUsd.value,
      validacion: 'OK',
      estado: sale.status.sheetValue,
    );
  }
}
