import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/value_objects/sale_id.dart';
import '../../domain/value_objects/customer_id.dart';
import '../../domain/value_objects/product_id.dart';
import '../../domain/value_objects/payment_method.dart';
import '../../domain/value_objects/sale_status.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/money_bs.dart';
import '../../../../core/value_objects/exchange_rate.dart';
import '../../../../core/value_objects/iso_date.dart';

/// Modelo de Infraestructura: Mapeo 1:1 con la hoja "ventas" (16 columnas A..P)
class SaleModel {
  final String id;
  final String fecha;
  final String clienteId;
  final String itemId;
  final int cantidad;
  final double tasaBcv;
  final double tasaUsd;
  final String tipoPago;
  final double comisionPagoMovilBs;
  final double montoBs;
  final double montoUsd;
  final double abonoUsd;
  final double deudaUsd;
  final double totalPagarUsd;
  final String validacion;
  final String estado;

  const SaleModel({
    required this.id,
    required this.fecha,
    required this.clienteId,
    required this.itemId,
    required this.cantidad,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.tipoPago,
    required this.comisionPagoMovilBs,
    required this.montoBs,
    required this.montoUsd,
    required this.abonoUsd,
    required this.deudaUsd,
    required this.totalPagarUsd,
    required this.validacion,
    required this.estado,
  });

  factory SaleModel.fromRow(List<dynamic> row) {
    return SaleModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      fecha: row.length > 1 ? row[1].toString() : '',
      clienteId: row.length > 2 ? row[2].toString() : '',
      itemId: row.length > 3 ? row[3].toString() : '',
      cantidad: row.length > 4 ? int.tryParse(row[4].toString()) ?? 1 : 1,
      tasaBcv: row.length > 5 ? double.tryParse(row[5].toString()) ?? 0.0 : 0.0,
      tasaUsd: row.length > 6 ? double.tryParse(row[6].toString()) ?? 0.0 : 0.0,
      tipoPago: row.length > 7 ? row[7].toString() : 'Efectivo',
      comisionPagoMovilBs: row.length > 8 ? double.tryParse(row[8].toString()) ?? 0.0 : 0.0,
      montoBs: row.length > 9 ? double.tryParse(row[9].toString()) ?? 0.0 : 0.0,
      montoUsd: row.length > 10 ? double.tryParse(row[10].toString()) ?? 0.0 : 0.0,
      abonoUsd: row.length > 11 ? double.tryParse(row[11].toString()) ?? 0.0 : 0.0,
      deudaUsd: row.length > 12 ? double.tryParse(row[12].toString()) ?? 0.0 : 0.0,
      totalPagarUsd: row.length > 13 ? double.tryParse(row[13].toString()) ?? 0.0 : 0.0,
      validacion: row.length > 14 ? row[14].toString() : 'OK',
      estado: row.length > 15 ? row[15].toString() : 'Pendiente',
    );
  }

  List<dynamic> toRow({int rowNumber = 2}) {
    return [
      id,
      fecha,
      clienteId,
      itemId,
      cantidad,
      tasaBcv.toStringAsFixed(2),
      tasaUsd.toStringAsFixed(2),
      tipoPago,
      comisionPagoMovilBs.toStringAsFixed(2),
      '=IFERROR(E$rowNumber*INDEX(inventario!G:G, MATCH(D$rowNumber, inventario!A:A, 0))*F$rowNumber, "ERROR")',
      '=IFERROR(E$rowNumber*INDEX(inventario!G:G, MATCH(D$rowNumber, inventario!A:A, 0)), "ERROR")',
      abonoUsd.toStringAsFixed(2),
      '=N$rowNumber-L$rowNumber',
      '=K$rowNumber',
      '=IF(AND(ABS(J$rowNumber-E$rowNumber*INDEX(inventario!G:G,MATCH(D$rowNumber,inventario!A:A,0))*F$rowNumber)<0.01, ABS(K$rowNumber-E$rowNumber*INDEX(inventario!G:G,MATCH(D$rowNumber,inventario!A:A,0)))<0.01, ABS(M$rowNumber-(N$rowNumber-L$rowNumber))<0.01),"OK","ERROR")',
      estado,
    ];
  }

  Sale toEntity({MoneyUsd? unitPrice}) {
    final effectivePrice = unitPrice ?? (cantidad > 0 ? MoneyUsd(montoUsd / cantidad) : MoneyUsd.zero);
    final item = SaleItem(
      id: 'item_${id}_$itemId',
      productId: ProductId(itemId),
      quantity: cantidad,
      unitPriceUsd: effectivePrice,
    );

    return Sale(
      id: SaleId(id),
      date: IsoDate.fromString(fecha),
      customerId: CustomerId(clienteId),
      items: [item],
      bcvRate: ExchangeRate(tasaBcv > 0 ? tasaBcv : 474.0),
      usdRate: ExchangeRate(tasaUsd > 0 ? tasaUsd : 800.0),
      paymentMethod: PaymentMethod.fromSheetValue(tipoPago),
      mobilePaymentFeeBs: MoneyBs(comisionPagoMovilBs),
      paidAmount: MoneyUsd(abonoUsd),
      status: SaleStatus.fromSheetValue(estado),
    );
  }

  factory SaleModel.fromEntity(Sale entity) {
    final firstItem = entity.items.isNotEmpty ? entity.items.first : null;
    int totalQty = 0;
    for (final it in entity.items) {
      totalQty += it.quantity;
    }
    return SaleModel(
      id: entity.id.value,
      fecha: entity.date.toIso8601String(),
      clienteId: entity.customerId.value,
      itemId: firstItem?.productId.value ?? '',
      cantidad: totalQty,
      tasaBcv: entity.bcvRate.value,
      tasaUsd: entity.usdRate.value,
      tipoPago: entity.paymentMethod.sheetValue,
      comisionPagoMovilBs: entity.mobilePaymentFeeBs.value,
      montoBs: entity.montoBs.value,
      montoUsd: entity.totalPagarUsd.value,
      abonoUsd: entity.paidAmount.value,
      deudaUsd: entity.deudaUsd.value,
      totalPagarUsd: entity.totalPagarUsd.value,
      validacion: 'OK',
      estado: entity.status.sheetValue,
    );
  }
}
