import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash anterior, sin sal. Solo sirve para migrar cuentas ya guardadas.
String hashPinLegado(String pin, String usuarioId) {
  return sha256.convert(utf8.encode('$usuarioId:$pin')).toString();
}

String derivarPin(String pin, String sal) {
  var digest = sha256.convert(utf8.encode('$sal:$pin'));
  for (var i = 0; i < 8000; i++) {
    digest = sha256.convert(digest.bytes);
  }
  return digest.toString();
}

class CredencialPin {
  const CredencialPin({required this.sal, required this.hash});

  final String sal;
  final String hash;

  String serializar() => '$sal.$hash';

  static CredencialPin? parse(String? crudo) {
    if (crudo == null || !crudo.contains('.')) return null;
    final corte = crudo.indexOf('.');
    final sal = crudo.substring(0, corte);
    final hash = crudo.substring(corte + 1);
    if (sal.length < 8 || hash.length < 32) return null;
    return CredencialPin(sal: sal, hash: hash);
  }
}

bool hashesCoinciden(String esperado, String recibido) {
  if (esperado.length != recibido.length) return false;
  var diferencia = 0;
  for (var i = 0; i < esperado.length; i++) {
    diferencia |= esperado.codeUnitAt(i) ^ recibido.codeUnitAt(i);
  }
  return diferencia == 0;
}

bool verificarPin(String pin, CredencialPin credencial) {
  return hashesCoinciden(derivarPin(pin, credencial.sal), credencial.hash);
}
