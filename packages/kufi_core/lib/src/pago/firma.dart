import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Clave de desarrollo. En producción se reemplaza con `--dart-define`
/// o con el secreto del servidor. No es un secreto real.
const secretoDesarrollo = 'kufi-dev-santa-cruz';

String firmar(String secreto, String canonico) {
  final mac = Hmac(sha256, utf8.encode(secreto));
  final digest = mac.convert(utf8.encode(canonico));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}

bool firmasCoinciden(String esperada, String recibida) {
  if (esperada.length != recibida.length) return false;
  var diferencia = 0;
  for (var i = 0; i < esperada.length; i++) {
    diferencia |= esperada.codeUnitAt(i) ^ recibida.codeUnitAt(i);
  }
  return diferencia == 0;
}
