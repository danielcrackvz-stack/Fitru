import 'firma.dart';

/// Lo que el chofer anuncia por Bluetooth: vehículo, ruta y sentido.
class AnuncioVehiculo {
  const AnuncioVehiculo({
    required this.vehiculoId,
    required this.cuentaChoferId,
    required this.rutaId,
    required this.nombreRuta,
    required this.sentido,
    required this.operador,
    required this.jurisdiccion,
    required this.panter,
    required this.rssi,
    required this.nonce,
    required this.venceEn,
    required this.firma,
    this.turnoId,
  });

  final String vehiculoId;
  final String cuentaChoferId;
  final String rutaId;
  final String nombreRuta;
  final String sentido;
  final String operador;
  final String jurisdiccion;
  final String panter;
  final int rssi;
  final String nonce;
  final DateTime venceEn;
  final String firma;
  final String? turnoId;

  String get canonico => [
        vehiculoId,
        cuentaChoferId,
        rutaId,
        sentido,
        nonce,
        venceEn.toUtc().toIso8601String(),
      ].join('|');

  bool get senalFuerte => rssi >= -67;

  bool get senalMedia => rssi >= -80;

  String get etiquetaSenal {
    if (senalFuerte) return 'Muy cerca · señal fuerte';
    if (senalMedia) return 'Cerca · señal media';
    return 'Señal débil';
  }

  Map<String, dynamic> toJson() => {
        'vehiculoId': vehiculoId,
        'cuentaChoferId': cuentaChoferId,
        'rutaId': rutaId,
        'nombreRuta': nombreRuta,
        'sentido': sentido,
        'operador': operador,
        'jurisdiccion': jurisdiccion,
        'panter': panter,
        'rssi': rssi,
        'nonce': nonce,
        'venceEn': venceEn.toUtc().toIso8601String(),
        'firma': firma,
        'turnoId': turnoId,
      };
}

class FirmadorAnuncios {
  const FirmadorAnuncios(this.secreto);

  final String secreto;

  AnuncioVehiculo sellar(AnuncioVehiculo anuncio) {
    return AnuncioVehiculo(
      vehiculoId: anuncio.vehiculoId,
      cuentaChoferId: anuncio.cuentaChoferId,
      rutaId: anuncio.rutaId,
      nombreRuta: anuncio.nombreRuta,
      sentido: anuncio.sentido,
      operador: anuncio.operador,
      jurisdiccion: anuncio.jurisdiccion,
      panter: anuncio.panter,
      rssi: anuncio.rssi,
      nonce: anuncio.nonce,
      venceEn: anuncio.venceEn,
      firma: firmar(secreto, anuncio.canonico),
      turnoId: anuncio.turnoId,
    );
  }

  bool verificar(AnuncioVehiculo anuncio) {
    final esperado = firmar(
        secreto,
        [
          anuncio.vehiculoId,
          anuncio.cuentaChoferId,
          anuncio.rutaId,
          anuncio.sentido,
          anuncio.nonce,
          anuncio.venceEn.toUtc().toIso8601String(),
        ].join('|'));
    return firmasCoinciden(esperado, anuncio.firma);
  }
}

class FiltroAnuncios {
  /// Por debajo de este RSSI el teléfono no ofrece el trufi para pagar.
  static const int rssiMinimo = -90;

  static List<AnuncioVehiculo> detectados(
    List<AnuncioVehiculo> todos, {
    int rssiMinimo = FiltroAnuncios.rssiMinimo,
    DateTime? ahora,
    FirmadorAnuncios? firmador,
  }) {
    final visibles = todos.where((anuncio) {
      if (anuncio.rssi < rssiMinimo) return false;
      if (ahora != null && !ahora.isBefore(anuncio.venceEn)) return false;
      if (firmador != null && !firmador.verificar(anuncio)) return false;
      return true;
    }).toList();
    visibles.sort((a, b) => b.rssi.compareTo(a.rssi));
    return visibles;
  }
}
