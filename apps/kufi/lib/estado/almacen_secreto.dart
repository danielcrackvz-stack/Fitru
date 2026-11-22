import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kufi_core/kufi_core.dart';

abstract class AlmacenSecreto {
  Future<String?> leer(String clave);
  Future<void> guardar(String clave, String valor);
  Future<void> borrar(String clave);
}

class AlmacenSecretoMemoria implements AlmacenSecreto {
  final Map<String, String> _datos = {};

  void poner(String clave, String valor) => _datos[clave] = valor;

  @override
  Future<String?> leer(String clave) async => _datos[clave];

  @override
  Future<void> guardar(String clave, String valor) async =>
      _datos[clave] = valor;

  @override
  Future<void> borrar(String clave) async => _datos.remove(clave);
}

class AlmacenSecretoSeguro implements AlmacenSecreto {
  AlmacenSecretoSeguro()
    : _caja = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _caja;

  @override
  Future<String?> leer(String clave) async {
    try {
      return await _caja.read(key: clave);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(String clave, String valor) async {
    try {
      await _caja.write(key: clave, value: valor);
    } catch (_) {}
  }

  @override
  Future<void> borrar(String clave) async {
    try {
      await _caja.delete(key: clave);
    } catch (_) {}
  }
}

Future<FirmadorTokens> firmadorDeArranque(AlmacenSecreto secreto) async {
  const definido = String.fromEnvironment('KUFI_TOKEN_SECRET');
  if (definido.length >= 16) return FirmadorTokens(definido);
  const clave = 'kufi.hmac.dispositivo';
  final guardado = await secreto.leer(clave);
  if (guardado != null && guardado.length >= 32) {
    return FirmadorTokens(guardado);
  }
  final aleatorio = Random.secure();
  final bytes = List<int>.generate(32, (_) => aleatorio.nextInt(256));
  final nuevo = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await secreto.guardar(clave, nuevo);
  return FirmadorTokens(nuevo);
}

String salNueva() {
  final aleatorio = Random.secure();
  return List.generate(
    16,
    (_) => aleatorio.nextInt(36).toRadixString(36),
  ).join();
}
