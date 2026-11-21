import 'dart:convert';

import '../geo.dart';
import '../texto.dart';
import 'modelos_ruta.dart';

class AnalizadorRutas {
  const AnalizadorRutas._();

  static CatalogoRutas desdeGeoJson(String geojson, {String? csv}) {
    final data = jsonDecode(geojson) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? const [];
    final tramosPorRuta = <String, List<TramoRuta>>{};
    final propsPorRuta = <String, Map<String, dynamic>>{};

    for (final crudo in features) {
      final feature = (crudo as Map).cast<String, dynamic>();
      final props = (feature['properties'] as Map).cast<String, dynamic>();
      final geometria = (feature['geometry'] as Map).cast<String, dynamic>();
      if (geometria['type'] != 'LineString') continue;
      final coordenadas = (geometria['coordinates'] as List<dynamic>).map((par) {
        final lista = par as List<dynamic>;
        return Coord((lista[1] as num).toDouble(), (lista[0] as num).toDouble());
      }).toList();
      final rutaId = props['route_id'] as String;
      final tramo = TramoRuta(
        shapeId: (props['shape_id'] as String?) ?? '${rutaId}_${props['sentido']}',
        rutaId: rutaId,
        sentido: (props['sentido'] as String?) ?? 'ida',
        puntos: coordenadas,
        km: (props['km'] as num?)?.toDouble() ?? 0,
        minutos: (props['min'] as num?)?.toDouble() ?? 0,
        zonaOrigen: (props['zona_origen'] as String?) ?? '',
        zonaDestino: (props['zona_destino'] as String?) ?? '',
        geomInvertidaCorregida: props['geom_invertida_corregida'] == true,
      );
      tramosPorRuta.putIfAbsent(rutaId, () => []).add(tramo);
      propsPorRuta[rutaId] = props;
    }

    final extra = csv == null ? const <String, Map<String, String>>{} : _leerCsv(csv);
    final rutas = <RutaTrufi>[];
    for (final entrada in tramosPorRuta.entries) {
      final props = propsPorRuta[entrada.key] ?? const {};
      final fila = extra[entrada.key];
      TramoRuta? ida;
      TramoRuta? vuelta;
      for (final tramo in entrada.value) {
        if (tramo.sentido == 'vuelta') {
          vuelta = _preferir(vuelta, tramo);
        } else {
          ida = _preferir(ida, tramo);
        }
      }
      rutas.add(
        RutaTrufi(
          routeId: entrada.key,
          nombreComun: _texto(fila?['nombre_comun'], props['nombre_comun']) ?? entrada.key,
          nombreCrudo: _texto(fila?['nombre_crudo'], props['nombre_crudo']) ?? '',
          nombreRevisar: _booleano(fila?['nombre_revisar'], props['nombre_revisar']),
          motivoRevisar: fila?['motivo_revisar'] ?? '',
          zonas: _texto(fila?['zonas'], props['zonas']) ?? '',
          operador: _texto(fila?['operador'], props['operador']) ?? '',
          tipoEntidad: fila?['tipo_entidad'] ?? '',
          federacion: _texto(fila?['federacion'], props['federacion']) ?? '',
          jurisdiccion: _texto(fila?['jurisdiccion'], props['jurisdiccion']) ?? '',
          colorPanter: _texto(fila?['color_panter'], props['color_panter']) ?? '',
          banderin: _texto(fila?['banderin'], props['banderin']) ?? '',
          colorHex: _color(_texto(fila?['color_hex'], props['color_hex'])),
          colorHex2: _colorOpcional(_texto(fila?['color_hex_2'], props['color_hex_2'])),
          ida: ida,
          vuelta: vuelta,
        ),
      );
    }
    rutas.sort((a, b) => a.routeId.compareTo(b.routeId));
    return CatalogoRutas(rutas);
  }

  static TramoRuta _preferir(TramoRuta? actual, TramoRuta candidato) {
    if (actual == null) return candidato;
    return candidato.puntos.length > actual.puntos.length ? candidato : actual;
  }

  static String? _texto(String? csv, Object? geo) {
    if (csv != null && csv.isNotEmpty) return csv;
    if (geo is String && geo.isNotEmpty) return geo;
    return null;
  }

  static bool _booleano(String? csv, Object? geo) {
    if (csv != null && csv.isNotEmpty) return csv.toLowerCase() == 'true';
    return geo == true;
  }

  static String _color(String? valor) {
    if (valor == null || valor.isEmpty) return '#009048';
    return valor.startsWith('#') ? valor : '#$valor';
  }

  static String _colorOpcional(String? valor) {
    if (valor == null || valor.isEmpty) return '';
    return valor.startsWith('#') ? valor : '#$valor';
  }

  static Map<String, Map<String, String>> _leerCsv(String csv) {
    final filas = parsearCsv(csv);
    if (filas.isEmpty) return const {};
    final encabezado = filas.first;
    final indice = <String, int>{
      for (var i = 0; i < encabezado.length; i++) encabezado[i]: i,
    };
    final salida = <String, Map<String, String>>{};
    for (final fila in filas.skip(1)) {
      String celda(String nombre) {
        final i = indice[nombre];
        if (i == null || i >= fila.length) return '';
        return fila[i];
      }

      final id = celda('route_id');
      if (id.isEmpty) continue;
      salida[id] = {for (final nombre in indice.keys) nombre: celda(nombre)};
    }
    return salida;
  }
}

class CatalogoRutas {
  const CatalogoRutas(this.rutas);

  final List<RutaTrufi> rutas;

  int get totalTrazos => rutas.fold(0, (suma, ruta) => suma + ruta.tramos.length);

  int get urbanas => rutas.where((r) => r.esUrbana).length;

  int get intermunicipales => rutas.where((r) => r.esIntermunicipal).length;

  RutaTrufi? porId(String routeId) {
    for (final ruta in rutas) {
      if (ruta.routeId == routeId) return ruta;
    }
    return null;
  }

  /// [jurisdiccion] admite `urbano`, `intermunicipal` o null para todas.
  List<RutaTrufi> buscar(String consulta, {String? jurisdiccion}) {
    final filtradas = rutas.where((ruta) {
      if (!_pasaJurisdiccion(ruta, jurisdiccion)) return false;
      return coincideConsulta(consulta, [
        ruta.nombreComun,
        ruta.nombreCrudo,
        ruta.zonas,
        ruta.operador,
        ruta.federacion,
        ruta.colorPanter,
        ruta.banderin,
        ruta.routeId,
      ]);
    }).toList();
    final consultaPlegada = plegar(consulta).trim();
    filtradas.sort((a, b) {
      final porNombre = _puntaje(a, consultaPlegada).compareTo(_puntaje(b, consultaPlegada));
      if (porNombre != 0) return porNombre;
      return plegar(a.nombreComun).compareTo(plegar(b.nombreComun));
    });
    return filtradas;
  }

  List<RutaCercana> cercaDe(
    Coord punto, {
    String? jurisdiccion,
    int limite = 8,
    double? maximoMetros,
  }) {
    final cercanas = <RutaCercana>[];
    for (final ruta in rutas) {
      if (!_pasaJurisdiccion(ruta, jurisdiccion)) continue;
      double? mejor;
      String sentido = 'ida';
      for (final tramo in ruta.tramos) {
        final distancia = distanciaATrazadoMetros(punto, tramo.puntos);
        if (mejor == null || distancia < mejor) {
          mejor = distancia;
          sentido = tramo.sentido;
        }
      }
      if (mejor == null) continue;
      if (maximoMetros != null && mejor > maximoMetros) continue;
      cercanas.add(RutaCercana(ruta: ruta, metros: mejor, sentido: sentido));
    }
    cercanas.sort((a, b) => a.metros.compareTo(b.metros));
    if (cercanas.length <= limite) return cercanas;
    return cercanas.sublist(0, limite);
  }

  /// La ruta cuyo trazado pasa más cerca del toque, si está a menos de [maximoMetros].
  RutaCercana? masCercanaAlToque(Coord punto, {double maximoMetros = 180, String? jurisdiccion}) {
    final lista = cercaDe(punto, jurisdiccion: jurisdiccion, limite: 1, maximoMetros: maximoMetros);
    return lista.isEmpty ? null : lista.first;
  }

  static bool _pasaJurisdiccion(RutaTrufi ruta, String? jurisdiccion) {
    if (jurisdiccion == null || jurisdiccion.isEmpty || jurisdiccion == 'todas') {
      return true;
    }
    return plegar(ruta.jurisdiccion) == plegar(jurisdiccion);
  }

  static int _puntaje(RutaTrufi ruta, String consulta) {
    if (consulta.isEmpty) return 1;
    final nombre = plegar(ruta.nombreComun);
    if (nombre == consulta) return 0;
    if (nombre.startsWith(consulta)) return 1;
    if (nombre.contains(consulta)) return 2;
    return 3;
  }
}
