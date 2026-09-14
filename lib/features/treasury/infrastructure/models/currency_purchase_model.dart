import '../../domain/entities/currency_purchase.dart';
import '../../domain/value_objects/purchase_id.dart';
import '../../../../core/value_objects/money_usd.dart';
import '../../../../core/value_objects/exchange_rate.dart';
import '../../../../core/value_objects/iso_date.dart';

/// Modelo de Infraestructura: Mapeo 1:1 con la hoja "compras_divisas"
class CurrencyPurchaseModel {
  final String id;
  final String fechaCompra;
  final String fechaEntrega;
  final double capitalUsd;
  final double comisionBinanceUsd;
  final String numeroOrden;
  final String plataforma;
  final String vendedor;
  final double tasaBcv;
  final double tasaUsd;
  final String validacion;

  const CurrencyPurchaseModel({
    required this.id,
    required this.fechaCompra,
    required this.fechaEntrega,
    required this.capitalUsd,
    required this.comisionBinanceUsd,
    required this.numeroOrden,
    required this.plataforma,
    required this.vendedor,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.validacion,
  });

  factory CurrencyPurchaseModel.fromRow(List<dynamic> row) {
    return CurrencyPurchaseModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      fechaCompra: row.length > 1 ? row[1].toString() : '',
      fechaEntrega: row.length > 2 ? row[2].toString() : '',
      capitalUsd: row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0,
      comisionBinanceUsd: row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0,
      numeroOrden: row.length > 5 ? row[5].toString() : '',
      plataforma: row.length > 6 ? row[6].toString() : '',
      vendedor: row.length > 7 ? row[7].toString() : '',
      tasaBcv: row.length > 8 ? double.tryParse(row[8].toString()) ?? 0.0 : 0.0,
      tasaUsd: row.length > 9 ? double.tryParse(row[9].toString()) ?? 0.0 : 0.0,
      validacion: row.length > 10 ? row[10].toString() : 'OK',
    );
  }

  List<dynamic> toRow({int rowNumber = 2}) {
    return [
      id,
      fechaCompra,
      fechaEntrega,
      capitalUsd.toStringAsFixed(2),
      comisionBinanceUsd.toStringAsFixed(2),
      numeroOrden,
      plataforma,
      vendedor,
      tasaBcv.toStringAsFixed(2),
      tasaUsd.toStringAsFixed(2),
      '=IF(B$rowNumber="","",IF(AND(C$rowNumber>=B$rowNumber, E$rowNumber>=0, D$rowNumber>0), "OK", "ERROR"))',
    ];
  }

  CurrencyPurchase toEntity() {
    return CurrencyPurchase(
      id: PurchaseId(id),
      purchaseDate: IsoDate.fromString(fechaCompra),
      deliveryDate: IsoDate.fromString(fechaEntrega),
      capitalUsd: MoneyUsd(capitalUsd),
      platformFeeUsd: MoneyUsd(comisionBinanceUsd),
      orderNumber: numeroOrden,
      platform: plataforma,
      seller: vendedor,
      bcvRate: ExchangeRate(tasaBcv > 0 ? tasaBcv : 474.0),
      usdRate: ExchangeRate(tasaUsd > 0 ? tasaUsd : 800.0),
    );
  }

  factory CurrencyPurchaseModel.fromEntity(CurrencyPurchase entity) {
    return CurrencyPurchaseModel(
      id: entity.id.value,
      fechaCompra: entity.purchaseDate.toIso8601String(),
      fechaEntrega: entity.deliveryDate.toIso8601String(),
      capitalUsd: entity.capitalUsd.value,
      comisionBinanceUsd: entity.platformFeeUsd.value,
      numeroOrden: entity.orderNumber,
      plataforma: entity.platform,
      vendedor: entity.seller,
      tasaBcv: entity.bcvRate.value,
      tasaUsd: entity.usdRate.value,
      validacion: 'OK',
    );
  }
}
