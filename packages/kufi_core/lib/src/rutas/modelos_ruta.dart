import '../geo.dart';

class TramoRuta {
  const TramoRuta({
    required this.shapeId,
    required this.rutaId,
    required this.sentido,
    required this.puntos,
    required this.km,
    required this.minutos,
    required this.zonaOrigen,
    required this.zonaDestino,
    required this.geomInvertidaCorregida,
  });

  final String shapeId;
  final String rutaId;

  /// `ida` o `vuelta`.
  final String sentido;
  final List<Coord> puntos;
  final double km;
  final double minutos;
  final String zonaOrigen;
  final String zonaDestino;
  final bool geomInvertidaCorregida;

  bool get esIda => sentido == 'ida';

  Limites get limites => Limites.de(puntos);
}

class RutaTrufi {
  const RutaTrufi({
    required this.routeId,
    required this.nombreComun,
    required this.nombreCrudo,
    required this.nombreRevisar,
    required this.motivoRevisar,
    required this.zonas,
    required this.operador,
    required this.tipoEntidad,
    required this.federacion,
    required this.jurisdiccion,
    required this.colorPanter,
    required this.banderin,
    required this.colorHex,
    required this.colorHex2,
    required this.ida,
    required this.vuelta,
  });

  /// Identificador interno R001–R126. No es un número de línea público.
  final String routeId;
  final String nombreComun;
  final String nombreCrudo;
  final bool nombreRevisar;
  final String motivoRevisar;
  final String zonas;
  final String operador;
  final String tipoEntidad;
  final String federacion;
  final String jurisdiccion;
  final String colorPanter;
  final String banderin;
  final String colorHex;
  final String colorHex2;
  final TramoRuta? ida;
  final TramoRuta? vuelta;

  bool get esUrbana => jurisdiccion.toLowerCase() == 'urbano';

  bool get esIntermunicipal => jurisdiccion.toLowerCase() == 'intermunicipal';

  TramoRuta? get principal => ida ?? vuelta;

  List<TramoRuta> get tramos => [?ida, ?vuelta];

  TramoRuta? tramo(String sentido) =>
      sentido == 'vuelta' ? (vuelta ?? ida) : (ida ?? vuelta);

  String get panterVisible {
    final partes = <String>[
      if (colorPanter.isNotEmpty) colorPanter,
      if (banderin.isNotEmpty) 'banderín $banderin',
    ];
    return partes.isEmpty ? 'sin color de panter' : partes.join(' · ');
  }

  String get etiquetaJurisdiccion => esUrbana ? 'Urbana' : 'Intermunicipal';
}

class RutaCercana {
  const RutaCercana({
    required this.ruta,
    required this.metros,
    required this.sentido,
  });

  final RutaTrufi ruta;
  final double metros;
  final String sentido;

  String get distanciaCorta {
    if (metros < 1000) return '${metros.round()} m';
    final km = metros / 1000;
    final texto = km.toStringAsFixed(1).replaceAll('.', ',');
    return '$texto km';
  }
}
