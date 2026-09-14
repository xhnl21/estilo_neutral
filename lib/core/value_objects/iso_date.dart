import '../types/value_object.dart';
import '../error/failures.dart';

/// Fecha normalizada a estándar estricto ISO 8601 (YYYY-MM-DD)
class IsoDate extends ValueObject<DateTime> {
  const IsoDate._(super.value);

  factory IsoDate(DateTime date) {
    final utcOnlyDate = DateTime.utc(date.year, date.month, date.day);
    return IsoDate._(utcOnlyDate);
  }

  factory IsoDate.fromString(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return IsoDate(parsed);
    } catch (_) {
      throw ValidationFailure('Fecha inválida "$dateStr". Debe cumplir ISO 8601 (YYYY-MM-DD).');
    }
  }

  factory IsoDate.now() => IsoDate(DateTime.now());

  bool isBefore(IsoDate other) => value.isBefore(other.value);
  bool isAfter(IsoDate other) => value.isAfter(other.value);
  bool isAtSameMomentAs(IsoDate other) => value.isAtSameMomentAs(other.value);

  String toIso8601String() {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  String toString() => toIso8601String();
}
