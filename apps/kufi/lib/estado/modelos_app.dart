import 'package:kufi_core/kufi_core.dart';

enum Rol { pasajero, chofer }

Rol rolDesde(String valor) => valor == 'chofer' ? Rol.chofer : Rol.pasajero;

class Usuario {
  Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.rol,
    this.carnet = '',
    this.aceptoTerminos = false,
    this.kycListo = false,
    this.huella = false,
    this.notificaciones = true,
    this.fotoAnverso = false,
    this.fotoReverso = false,
    this.pinHashLegado = '',
  });

  final String id;
  String nombre;
  String correo;
  String telefono;
  String carnet;
  bool aceptoTerminos;
  final Rol rol;
  bool kycListo;
  bool huella;
  bool notificaciones;
  bool fotoAnverso;
  bool fotoReverso;

  /// Hash viejo leído de una instalación anterior. No se vuelve a guardar.
  String pinHashLegado;

  String get telefonoEnmascarado {
    final digitos = telefono.replaceAll(RegExp(r'\D'), '');
    if (digitos.length < 4) return '+591 $telefono';
    final inicio = digitos.substring(0, 1);
    final fin = digitos.substring(digitos.length - 2);
    return '+591 $inicio••• ••$fin';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'telefono': telefono,
    'carnet': carnet,
    'aceptoTerminos': aceptoTerminos,
    'rol': rol.name,
    'kycListo': kycListo,
    'huella': huella,
    'notificaciones': notificaciones,
    'fotoAnverso': fotoAnverso,
    'fotoReverso': fotoReverso,
  };

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      carnet: json['carnet'] as String? ?? '',
      aceptoTerminos: json['aceptoTerminos'] as bool? ?? false,
      pinHashLegado: json['pinHash'] as String? ?? '',
      rol: rolDesde(json['rol'] as String? ?? 'pasajero'),
      kycListo: json['kycListo'] as bool? ?? false,
      huella: json['huella'] as bool? ?? false,
      notificaciones: json['notificaciones'] as bool? ?? true,
      fotoAnverso: json['fotoAnverso'] as bool? ?? false,
      fotoReverso: json['fotoReverso'] as bool? ?? false,
    );
  }
}

class Turno {
  Turno({
    required this.id,
    required this.rutaId,
    required this.sentido,
    required this.vehiculoId,
    required this.placa,
    required this.inicio,
    this.pausado = false,
    this.ejemplo = false,
  });

  final String id;
  final String rutaId;
  final String sentido;
  final String vehiculoId;
  final String placa;
  final DateTime inicio;
  bool pausado;
  final bool ejemplo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'rutaId': rutaId,
    'sentido': sentido,
    'vehiculoId': vehiculoId,
    'placa': placa,
    'inicio': inicio.toUtc().toIso8601String(),
    'pausado': pausado,
    'ejemplo': ejemplo,
  };

  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      id: json['id'] as String,
      rutaId: json['rutaId'] as String,
      sentido: json['sentido'] as String? ?? 'ida',
      vehiculoId: json['vehiculoId'] as String? ?? 'SCZ-107',
      placa: json['placa'] as String? ?? '',
      inicio: DateTime.parse(json['inicio'] as String),
      pausado: json['pausado'] as bool? ?? false,
      ejemplo: json['ejemplo'] as bool? ?? false,
    );
  }
}

class Aviso {
  Aviso({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.fecha,
    this.leido = false,
  });

  final String id;
  final String tipo;
  final String titulo;
  final String cuerpo;
  final DateTime fecha;
  bool leido;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo,
    'titulo': titulo,
    'cuerpo': cuerpo,
    'fecha': fecha.toUtc().toIso8601String(),
    'leido': leido,
  };

  factory Aviso.fromJson(Map<String, dynamic> json) {
    return Aviso(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      titulo: json['titulo'] as String,
      cuerpo: json['cuerpo'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      leido: json['leido'] as bool? ?? false,
    );
  }
}

class BorradorPago {
  BorradorPago({
    required this.clave,
    required this.rutaId,
    required this.nombreRuta,
    required this.operador,
    required this.sentido,
    required this.medio,
    required this.cuentaChoferId,
    required this.subtitulo,
    this.vehiculoId,
    this.token,
    this.tipo = TipoPasaje.adulto,
    this.pasajeros = 1,
  });

  final String clave;
  final String rutaId;
  final String nombreRuta;
  final String operador;
  final String sentido;
  final String medio;
  final String cuentaChoferId;
  final String subtitulo;
  final String? vehiculoId;
  final TokenPago? token;
  TipoPasaje tipo;
  int pasajeros;

  String get medioVisible {
    switch (medio) {
      case 'nfc':
        return 'NFC';
      case 'ble':
        return 'Bluetooth';
      case 'qr':
        return 'QR';
      case 'manual':
        return 'Pago manual';
      default:
        return 'En ruta';
    }
  }
}

class LugarFijo {
  const LugarFijo({
    required this.etiqueta,
    required this.nombre,
    required this.punto,
  });

  final String etiqueta;
  final String nombre;
  final Coord punto;

  Map<String, dynamic> toJson() => {
    'etiqueta': etiqueta,
    'nombre': nombre,
    'lat': punto.lat,
    'lon': punto.lon,
  };

  factory LugarFijo.fromJson(Map<String, dynamic> json) {
    return LugarFijo(
      etiqueta: '${json['etiqueta'] ?? ''}',
      nombre: '${json['nombre'] ?? ''}',
      punto: Coord(
        (json['lat'] as num?)?.toDouble() ?? 0,
        (json['lon'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}

abstract class AlmacenLocal {
  Future<String?> leer(String clave);
  Future<void> guardar(String clave, String valor);
}

class AlmacenMemoria implements AlmacenLocal {
  final Map<String, String> _datos = {};

  @override
  Future<String?> leer(String clave) async => _datos[clave];

  @override
  Future<void> guardar(String clave, String valor) async {
    _datos[clave] = valor;
  }
}
