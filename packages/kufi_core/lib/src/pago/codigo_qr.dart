import 'dart:convert';

import 'token_pago.dart';

class FormatoQrInvalido implements Exception {
  FormatoQrInvalido(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class CodigoQrPago {
  static const esquema = 'kufi://pago/v1/';

  static String emitir(TokenPago token) {
    final cuerpo = base64Url
        .encode(utf8.encode(jsonEncode(token.toJson())))
        .replaceAll('=', '');
    return '$esquema$cuerpo';
  }

  static TokenPago leer(String codigo) {
    final limpio = codigo.trim();
    if (!limpio.startsWith(esquema)) {
      throw FormatoQrInvalido('El código no es un QR de Subí.');
    }
    final cuerpo = limpio.substring(esquema.length);
    final relleno = '=' * ((4 - cuerpo.length % 4) % 4);
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(cuerpo + relleno)));
      if (json is! Map) {
        throw FormatoQrInvalido('El QR no trae un token.');
      }
      return TokenPago.fromJson(json.cast<String, dynamic>());
    } on FormatException {
      throw FormatoQrInvalido('No se pudo leer el QR.');
    }
  }
}
