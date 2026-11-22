import 'dart:convert';
import 'dart:typed_data';

import 'anuncio_ble.dart';
import 'firma.dart';

/// Anuncio que cabe en el paquete de publicidad BLE (23 bytes).
class AnuncioCompacto {
  static const int largo = 23;

  static Uint8List codificar({
    required String rutaId,
    required String sentido,
    required int venceEnSegundos,
    required int nonce,
    required String secreto,
  }) {
    final ruta = rutaId.padRight(4).substring(0, 4).codeUnits;
    final sentidoByte = sentido == 'vuelta' ? 1 : 0;
    final cuerpo = Uint8List(15);
    cuerpo[0] = 0x4b;
    cuerpo[1] = 0x46;
    cuerpo[2] = ruta[0];
    cuerpo[3] = ruta[1];
    cuerpo[4] = ruta[2];
    cuerpo[5] = ruta[3];
    cuerpo[6] = sentidoByte;
    final expira = ByteData(4)..setUint32(0, venceEnSegundos);
    final aleatorio = ByteData(4)..setUint32(0, nonce);
    cuerpo.setRange(7, 11, expira.buffer.asUint8List());
    cuerpo.setRange(11, 15, aleatorio.buffer.asUint8List());
    final mac =
        base64Url.decode(_rellenar(firmar(secreto, base64Url.encode(cuerpo))));
    final salida = Uint8List(largo);
    salida.setRange(0, 15, cuerpo);
    salida.setRange(15, 23, mac.take(8));
    return salida;
  }

  static AnuncioVehiculo? decodificar({
    required List<int> bytes,
    required int rssi,
    required String secreto,
    required DateTime ahora,
    required String vehiculoId,
    required String cuentaChoferId,
    required String nombreRuta,
    required String operador,
    required String jurisdiccion,
    required String panter,
  }) {
    if (bytes.length < largo) return null;
    final datos = Uint8List.fromList(bytes.take(largo).toList());
    try {
      if (datos[0] != 0x4b || datos[1] != 0x46) return null;
      final cuerpo = datos.sublist(0, 15);
      final macRecibida = datos.sublist(15, 23);
      final mac =
          base64Url.decode(_rellenar(firmar(secreto, base64Url.encode(cuerpo))));
      if (!_iguales(mac.take(8).toList(), macRecibida)) return null;
      final vista = ByteData.sublistView(datos);
      final expira = vista.getUint32(7);
      final nonce = vista.getUint32(11);
      final vence =
          DateTime.fromMillisecondsSinceEpoch(expira * 1000, isUtc: true);
      if (!ahora.toUtc().isBefore(vence)) return null;
      final ruta = utf8.decode(datos.sublist(2, 6)).trim();
      final sentido = datos[6] == 1 ? 'vuelta' : 'ida';
      return AnuncioVehiculo(
        vehiculoId: vehiculoId,
        cuentaChoferId: cuentaChoferId,
        rutaId: ruta,
        nombreRuta: nombreRuta,
        sentido: sentido,
        operador: operador,
        jurisdiccion: jurisdiccion,
        panter: panter,
        rssi: rssi,
        nonce: '$nonce',
        venceEn: vence,
        firma: firmar(
            secreto,
            [
              vehiculoId,
              cuentaChoferId,
              ruta,
              sentido,
              '$nonce',
              vence.toIso8601String(),
            ].join('|')),
      );
    } catch (_) {
      return null;
    }
  }

  static bool _iguales(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diferencia = 0;
    for (var i = 0; i < a.length; i++) {
      diferencia |= a[i] ^ b[i];
    }
    return diferencia == 0;
  }

  static String _rellenar(String valor) {
    final falta = (4 - valor.length % 4) % 4;
    return valor + ('=' * falta);
  }
}
