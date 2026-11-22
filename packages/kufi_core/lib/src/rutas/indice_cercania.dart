import 'dart:math' as math;

import '../geo.dart';
import 'analizador_rutas.dart';
import 'modelos_ruta.dart';

/// Celda de ~220 m en Santa Cruz. Sirve para no medir todos los segmentos.
class IndiceCercania {
  IndiceCercania._(this._segmentos, this._celdas);

  static const double _grados = 0.002;

  final List<_Segmento> _segmentos;
  final Map<String, List<int>> _celdas;

  factory IndiceCercania.desde(CatalogoRutas catalogo) {
    final segmentos = <_Segmento>[];
    final celdas = <String, List<int>>{};
    for (final ruta in catalogo.rutas) {
      for (final tramo in ruta.tramos) {
        final linea = tramo.puntos;
        for (var i = 1; i < linea.length; i++) {
          final id = segmentos.length;
          segmentos.add(
            _Segmento(
              rutaId: ruta.routeId,
              sentido: tramo.sentido,
              a: linea[i - 1],
              b: linea[i],
            ),
          );
          for (final clave in _clavesDeSegmento(linea[i - 1], linea[i])) {
            celdas.putIfAbsent(clave, () => []).add(id);
          }
        }
      }
    }
    return IndiceCercania._(segmentos, celdas);
  }

  int get segmentos => _segmentos.length;

  /// Rutas cuya línea pasa a lo sumo a [radioMetros] del punto.
  List<RutaCercana> dentroDe(
    Coord punto,
    double radioMetros,
    CatalogoRutas catalogo, {
    String? jurisdiccion,
    int limite = 30,
  }) {
    if (radioMetros <= 0) return const [];
    final vistos = <int>{};
    final mejor = <String, _Toque>{};
    for (final clave in _clavesEnRadio(punto, radioMetros)) {
      for (final id in _celdas[clave] ?? const <int>[]) {
        if (!vistos.add(id)) continue;
        final segmento = _segmentos[id];
        final distancia = distanciaPuntoSegmentoMetros(punto, segmento.a, segmento.b);
        if (distancia > radioMetros) continue;
        final actual = mejor[segmento.rutaId];
        if (actual == null || distancia < actual.metros) {
          mejor[segmento.rutaId] = _Toque(segmento.sentido, distancia);
        }
      }
    }
    final salida = <RutaCercana>[];
    for (final entrada in mejor.entries) {
      final ruta = catalogo.porId(entrada.key);
      if (ruta == null) continue;
      if (jurisdiccion != null &&
          jurisdiccion.isNotEmpty &&
          jurisdiccion != 'todas' &&
          ruta.jurisdiccion.toLowerCase() != jurisdiccion.toLowerCase()) {
        continue;
      }
      salida.add(
        RutaCercana(ruta: ruta, metros: entrada.value.metros, sentido: entrada.value.sentido),
      );
    }
    salida.sort((a, b) => a.metros.compareTo(b.metros));
    if (salida.length <= limite) return salida;
    return salida.sublist(0, limite);
  }

  static Iterable<String> _clavesDeSegmento(Coord a, Coord b) sync* {
    final pasos = math.max(1, (haversineMetros(a, b) / 180).ceil());
    for (var i = 0; i <= pasos; i++) {
      final t = i / pasos;
      yield _clave(Coord(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t));
    }
  }

  static Iterable<String> _clavesEnRadio(Coord punto, double radioMetros) sync* {
    final margen = (radioMetros / 111320) + _grados;
    final lat0 = ((punto.lat - margen) / _grados).floor();
    final lat1 = ((punto.lat + margen) / _grados).floor();
    final lon0 = ((punto.lon - margen) / _grados).floor();
    final lon1 = ((punto.lon + margen) / _grados).floor();
    for (var lat = lat0; lat <= lat1; lat++) {
      for (var lon = lon0; lon <= lon1; lon++) {
        yield '$lat:$lon';
      }
    }
  }

  static String _clave(Coord punto) {
    final lat = (punto.lat / _grados).floor();
    final lon = (punto.lon / _grados).floor();
    return '$lat:$lon';
  }
}

class _Segmento {
  const _Segmento({
    required this.rutaId,
    required this.sentido,
    required this.a,
    required this.b,
  });

  final String rutaId;
  final String sentido;
  final Coord a;
  final Coord b;
}

class _Toque {
  const _Toque(this.sentido, this.metros);
  final String sentido;
  final double metros;
}

/// Radios que ofrece la interfaz, en metros.
const radiosCercania = <int>[100, 300, 500];
