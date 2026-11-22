import 'dart:math' as math;

class Coord {
  const Coord(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  String toString() => '($lat, $lon)';
}

const double _radioTierraMetros = 6371000;

double haversineMetros(Coord a, Coord b) {
  final lat1 = a.lat * math.pi / 180;
  final lat2 = b.lat * math.pi / 180;
  final dLat = (b.lat - a.lat) * math.pi / 180;
  final dLon = (b.lon - a.lon) * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 *
      _radioTierraMetros *
      math.asin(math.min(1, math.sqrt(h.toDouble())));
}

/// Distancia de un punto al segmento, en metros, con proyección local.
double distanciaPuntoSegmentoMetros(Coord punto, Coord a, Coord b) {
  final latRef = ((a.lat + b.lat) / 2) * math.pi / 180;
  final metrosPorLat = 111320.0;
  final metrosPorLon = 111320.0 * math.cos(latRef);
  final ax = 0.0;
  final ay = 0.0;
  final bx = (b.lon - a.lon) * metrosPorLon;
  final by = (b.lat - a.lat) * metrosPorLat;
  final px = (punto.lon - a.lon) * metrosPorLon;
  final py = (punto.lat - a.lat) * metrosPorLat;
  final largo2 = bx * bx + by * by;
  var t = largo2 == 0 ? 0.0 : (px * bx + py * by) / largo2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final dx = px - ax - t * bx;
  final dy = py - ay - t * by;
  return math.sqrt(dx * dx + dy * dy);
}

double distanciaATrazadoMetros(Coord punto, List<Coord> linea) {
  if (linea.isEmpty) return double.infinity;
  if (linea.length == 1) return haversineMetros(punto, linea.first);
  var mejor = double.infinity;
  for (var i = 1; i < linea.length; i++) {
    final distancia =
        distanciaPuntoSegmentoMetros(punto, linea[i - 1], linea[i]);
    if (distancia < mejor) mejor = distancia;
  }
  return mejor;
}

class Limites {
  const Limites(
      {required this.sur,
      required this.oeste,
      required this.norte,
      required this.este});

  final double sur;
  final double oeste;
  final double norte;
  final double este;

  factory Limites.de(List<Coord> puntos) {
    var sur = puntos.first.lat;
    var norte = puntos.first.lat;
    var oeste = puntos.first.lon;
    var este = puntos.first.lon;
    for (final punto in puntos) {
      if (punto.lat < sur) sur = punto.lat;
      if (punto.lat > norte) norte = punto.lat;
      if (punto.lon < oeste) oeste = punto.lon;
      if (punto.lon > este) este = punto.lon;
    }
    return Limites(sur: sur, oeste: oeste, norte: norte, este: este);
  }
}

/// Posición a lo largo del trazado. [fraccion] va de 0 a 1 según la distancia.
Coord posicionEnTrazado(List<Coord> linea, double fraccion) {
  if (linea.isEmpty) {
    throw ArgumentError('El trazado no tiene puntos.');
  }
  if (linea.length == 1 || fraccion <= 0) return linea.first;
  if (fraccion >= 1) return linea.last;

  final acumulado = List<double>.filled(linea.length, 0);
  for (var i = 1; i < linea.length; i++) {
    acumulado[i] = acumulado[i - 1] + haversineMetros(linea[i - 1], linea[i]);
  }
  final total = acumulado.last;
  if (total == 0) return linea.first;
  final objetivo = total * fraccion;
  for (var i = 1; i < linea.length; i++) {
    if (acumulado[i] >= objetivo) {
      final tramo = acumulado[i] - acumulado[i - 1];
      final avance = tramo == 0 ? 0.0 : (objetivo - acumulado[i - 1]) / tramo;
      return Coord(
        linea[i - 1].lat + (linea[i].lat - linea[i - 1].lat) * avance,
        linea[i - 1].lon + (linea[i].lon - linea[i - 1].lon) * avance,
      );
    }
  }
  return linea.last;
}

/// Avanza de forma cíclica. [vueltasPorHora] define la velocidad simulada.
Coord posicionSimulada({
  required List<Coord> linea,
  required DateTime ahora,
  required double fase,
  double vueltasPorHora = 2,
}) {
  final horas = ahora.millisecondsSinceEpoch / 3600000;
  final fraccion = (fase + horas * vueltasPorHora) % 1;
  final positiva = fraccion < 0 ? fraccion + 1 : fraccion;
  return posicionEnTrazado(linea, positiva);
}
