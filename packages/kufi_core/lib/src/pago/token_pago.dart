import 'firma.dart';

class TokenPago {
  const TokenPago({
    required this.id,
    required this.vehiculoId,
    required this.cuentaChoferId,
    required this.rutaId,
    required this.sentido,
    required this.nombreRuta,
    required this.emitidoEn,
    required this.venceEn,
    required this.nonce,
    required this.firma,
    this.usoUnico = true,
  });

  final String id;
  final String vehiculoId;
  final String cuentaChoferId;
  final String rutaId;
  final String sentido;
  final String nombreRuta;
  final DateTime emitidoEn;
  final DateTime venceEn;
  final String nonce;
  final String firma;
  final bool usoUnico;

  String get canonico => [
        id,
        vehiculoId,
        cuentaChoferId,
        rutaId,
        sentido,
        emitidoEn.toUtc().toIso8601String(),
        venceEn.toUtc().toIso8601String(),
        nonce,
        usoUnico ? '1' : '0',
      ].join('|');

  bool vigenteEn(DateTime ahora) => ahora.isBefore(venceEn);

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehiculoId': vehiculoId,
        'cuentaChoferId': cuentaChoferId,
        'rutaId': rutaId,
        'sentido': sentido,
        'nombreRuta': nombreRuta,
        'emitidoEn': emitidoEn.toUtc().toIso8601String(),
        'venceEn': venceEn.toUtc().toIso8601String(),
        'nonce': nonce,
        'firma': firma,
        'usoUnico': usoUnico,
      };

  factory TokenPago.fromJson(Map<String, dynamic> json) {
    return TokenPago(
      id: json['id'] as String,
      vehiculoId: json['vehiculoId'] as String,
      cuentaChoferId: json['cuentaChoferId'] as String,
      rutaId: json['rutaId'] as String,
      sentido: json['sentido'] as String,
      nombreRuta: json['nombreRuta'] as String? ?? '',
      emitidoEn: DateTime.parse(json['emitidoEn'] as String),
      venceEn: DateTime.parse(json['venceEn'] as String),
      nonce: json['nonce'] as String,
      firma: json['firma'] as String? ?? '',
      usoUnico: json['usoUnico'] as bool? ?? true,
    );
  }
}

class FirmadorTokens {
  const FirmadorTokens(this.secreto);

  final String secreto;

  TokenPago sellar(TokenPago borrador) {
    final firmado = TokenPago(
      id: borrador.id,
      vehiculoId: borrador.vehiculoId,
      cuentaChoferId: borrador.cuentaChoferId,
      rutaId: borrador.rutaId,
      sentido: borrador.sentido,
      nombreRuta: borrador.nombreRuta,
      emitidoEn: borrador.emitidoEn,
      venceEn: borrador.venceEn,
      nonce: borrador.nonce,
      firma: '',
      usoUnico: borrador.usoUnico,
    );
    return TokenPago(
      id: firmado.id,
      vehiculoId: firmado.vehiculoId,
      cuentaChoferId: firmado.cuentaChoferId,
      rutaId: firmado.rutaId,
      sentido: firmado.sentido,
      nombreRuta: firmado.nombreRuta,
      emitidoEn: firmado.emitidoEn,
      venceEn: firmado.venceEn,
      nonce: firmado.nonce,
      firma: firmar(secreto, firmado.canonico),
      usoUnico: firmado.usoUnico,
    );
  }

  bool verificar(TokenPago token) {
    final limpio = TokenPago(
      id: token.id,
      vehiculoId: token.vehiculoId,
      cuentaChoferId: token.cuentaChoferId,
      rutaId: token.rutaId,
      sentido: token.sentido,
      nombreRuta: token.nombreRuta,
      emitidoEn: token.emitidoEn,
      venceEn: token.venceEn,
      nonce: token.nonce,
      firma: '',
      usoUnico: token.usoUnico,
    );
    return firmasCoinciden(firmar(secreto, limpio.canonico), token.firma);
  }
}
