enum TipoMovimiento { recarga, pasaje, reverso }

enum EstadoSync { sincronizado, pendiente }

extension TipoMovimientoTexto on TipoMovimiento {
  String get id => name;

  static TipoMovimiento desdeId(String id) {
    return TipoMovimiento.values.firstWhere(
      (tipo) => tipo.name == id,
      orElse: () => TipoMovimiento.pasaje,
    );
  }
}

extension EstadoSyncTexto on EstadoSync {
  String get id => name;

  static EstadoSync desdeId(String id) {
    return id == 'pendiente' ? EstadoSync.pendiente : EstadoSync.sincronizado;
  }
}

/// Apunte del libro. El signo de [centavos] indica el sentido:
/// negativo descuenta de la cuenta y positivo acredita.
class Movimiento {
  const Movimiento({
    required this.id,
    required this.claveIdempotencia,
    required this.cuentaId,
    required this.tipo,
    required this.centavos,
    required this.creadoEn,
    required this.pagoId,
    this.rutaId,
    this.nombreRuta,
    this.operador,
    this.tipoPasaje,
    this.pasajeros = 1,
    this.medio,
    this.sentido,
    this.vehiculoId,
    this.sync = EstadoSync.sincronizado,
    this.numeroOperacion,
    this.nota,
  });

  final String id;
  final String claveIdempotencia;
  final String cuentaId;
  final TipoMovimiento tipo;
  final int centavos;
  final DateTime creadoEn;
  final String pagoId;
  final String? rutaId;
  final String? nombreRuta;
  final String? operador;
  final String? tipoPasaje;
  final int pasajeros;
  final String? medio;
  final String? sentido;
  final String? vehiculoId;
  final EstadoSync sync;
  final String? numeroOperacion;
  final String? nota;

  bool get esDebito => centavos < 0;

  Movimiento copiarCon({EstadoSync? sync}) {
    return Movimiento(
      id: id,
      claveIdempotencia: claveIdempotencia,
      cuentaId: cuentaId,
      tipo: tipo,
      centavos: centavos,
      creadoEn: creadoEn,
      pagoId: pagoId,
      rutaId: rutaId,
      nombreRuta: nombreRuta,
      operador: operador,
      tipoPasaje: tipoPasaje,
      pasajeros: pasajeros,
      medio: medio,
      sentido: sentido,
      vehiculoId: vehiculoId,
      sync: sync ?? this.sync,
      numeroOperacion: numeroOperacion,
      nota: nota,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'claveIdempotencia': claveIdempotencia,
        'cuentaId': cuentaId,
        'tipo': tipo.id,
        'centavos': centavos,
        'creadoEn': creadoEn.toUtc().toIso8601String(),
        'pagoId': pagoId,
        'rutaId': rutaId,
        'nombreRuta': nombreRuta,
        'operador': operador,
        'tipoPasaje': tipoPasaje,
        'pasajeros': pasajeros,
        'medio': medio,
        'sentido': sentido,
        'vehiculoId': vehiculoId,
        'sync': sync.id,
        'numeroOperacion': numeroOperacion,
        'nota': nota,
      };

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    return Movimiento(
      id: json['id'] as String,
      claveIdempotencia: json['claveIdempotencia'] as String,
      cuentaId: json['cuentaId'] as String,
      tipo: TipoMovimientoTexto.desdeId(json['tipo'] as String),
      centavos: (json['centavos'] as num).toInt(),
      creadoEn: DateTime.parse(json['creadoEn'] as String),
      pagoId: json['pagoId'] as String? ?? '',
      rutaId: json['rutaId'] as String?,
      nombreRuta: json['nombreRuta'] as String?,
      operador: json['operador'] as String?,
      tipoPasaje: json['tipoPasaje'] as String?,
      pasajeros: (json['pasajeros'] as num?)?.toInt() ?? 1,
      medio: json['medio'] as String?,
      sentido: json['sentido'] as String?,
      vehiculoId: json['vehiculoId'] as String?,
      sync: EstadoSyncTexto.desdeId(json['sync'] as String? ?? 'sincronizado'),
      numeroOperacion: json['numeroOperacion'] as String?,
      nota: json['nota'] as String?,
    );
  }
}
