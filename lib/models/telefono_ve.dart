/// Teléfono venezolano separado en código de operadora (`0412`, `0414`…) y
/// número de 7 dígitos.
///
/// En la hoja "clientes" conviven varios formatos históricos:
/// `+584124054635` (E.164, el canónico), `584124054635`, `04124054635` y
/// `4124054635` — este último porque Google Sheets convierte `0412…` en
/// número al escribirlo y se pierde el 0 inicial. [parse] los acepta todos.
class TelefonoVe {
  final String codigo;
  final String numero;

  const TelefonoVe({required this.codigo, required this.numero});

  /// Devuelve `null` si [raw] no es un teléfono venezolano de 11 dígitos
  /// (con o sin prefijo de país, con o sin el 0 inicial).
  static TelefonoVe? parse(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('58')) {
      digits = '0${digits.substring(2)}';
    } else if (digits.length == 10 && !digits.startsWith('0')) {
      digits = '0$digits';
    }
    if (digits.length != 11 || !digits.startsWith('0')) return null;
    return TelefonoVe(codigo: digits.substring(0, 4), numero: digits.substring(4));
  }

  /// Formato E.164 (`+584124054635`), el que se guarda en la hoja. Empieza
  /// con `+`, así que Apps Script lo escribe como texto y Sheets no lo
  /// convierte en número.
  String get e164 => '+58${codigo.substring(1)}$numero';

  /// Formato local legible: `0412-4054635`.
  String get legible => '$codigo-$numero';

  /// Formato local sin separadores: `04124054635`.
  String get local => '$codigo$numero';
}
