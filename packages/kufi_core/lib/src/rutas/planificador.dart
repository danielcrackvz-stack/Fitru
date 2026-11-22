import '../geo.dart';
import 'analizador_rutas.dart';
import 'indice_cercania.dart';
import 'modelos_ruta.dart';

/// Un tramo a pie o arriba de un trufi, en el sentido del trazado.
class TramoSugerido {
  const TramoSugerido({
    required this.aPie,
    required this.puntos,
    required this.metros,
    required this.minutos,
    this.routeId,
    this.sentido,
    this.nombre,
    this.colorHex,
  });

  final bool aPie;
  final List<Coord> puntos;
  final double metros;
  final double minutos;
  final String? routeId;
  final String? sentido;
  final String? nombre;
  final String? colorHex;
}

class ItinerarioSugerido {
  const ItinerarioSugerido({
    required this.tramos,
    required this.minutos,
    required this.metrosCaminando,
    required this.centavos,
    required this.transbordos,
  });

  final List<TramoSugerido> tramos;
  final double minutos;
  final double metrosCaminando;
  final int centavos;
  final int transbordos;

  String get titulo {
    if (transbordos == 0 && tramos.every((t) => t.aPie)) return 'A pie';
    if (transbordos == 0) return 'Directo';
    return 'Un transbordo';
  }
}

class _Muestra {
  const _Muestra({
    required this.routeId,
    required this.sentido,
    required this.orden,
    required this.punto,
    required this.metros,
    required this.minutos,
    required this.metrosTotales,
    required this.minutosTotales,
  });

  final String routeId;
  final String sentido;
  final int orden;
  final Coord punto;
  final double metros;
  final double minutos;
  final double metrosTotales;
  final double minutosTotales;
}

/// Propone viajes offline. Camina a 4,5 km/h y no inventa recorridos.
class PlanificadorViajes {
  PlanificadorViajes(this.catalogo, {IndiceCercania? indice})
      : indice = indice ?? IndiceCercania.desde(catalogo) {
    for (final ruta in catalogo.rutas) {
      for (final tramo in ruta.tramos) {
        _muestras.addAll(_muestrear(tramo));
      }
    }
  }

  final CatalogoRutas catalogo;
  final IndiceCercania indice;
  final List<_Muestra> _muestras = [];

  static const double _metrosPorMinutoAPie = 75;
  static const double _maximoAndar = 800;
  static const double _maximoTransbordo = 450;

  List<ItinerarioSugerido> proponer({
    required Coord origen,
    required Coord destino,
    required int tarifaCentavos,
    int limite = 5,
  }) {
    final ideas = <ItinerarioSugerido>[];
    final aPie = haversineMetros(origen, destino);
    if (aPie <= 1800) {
      ideas.add(_soloAPie(origen, destino, aPie));
    }
    ideas.addAll(_directos(origen, destino, tarifaCentavos));
    ideas.addAll(_conTransbordo(origen, destino, tarifaCentavos));
    ideas.sort((a, b) {
      final porTiempo = a.minutos.compareTo(b.minutos);
      if (porTiempo != 0) return porTiempo;
      return a.metrosCaminando.compareTo(b.metrosCaminando);
    });
    final vistos = <String>{};
    final unicos = <ItinerarioSugerido>[];
    for (final idea in ideas) {
      final clave = idea.tramos.map((t) => '${t.routeId ?? 'pie'}:${t.metros.round()}').join('|');
      if (vistos.add(clave)) unicos.add(idea);
      if (unicos.length >= limite) break;
    }
    return unicos;
  }

  ItinerarioSugerido _soloAPie(Coord origen, Coord destino, double metros) {
    final minutos = metros / _metrosPorMinutoAPie;
    return ItinerarioSugerido(
      tramos: [
        TramoSugerido(aPie: true, puntos: [origen, destino], metros: metros, minutos: minutos),
      ],
      minutos: minutos,
      metrosCaminando: metros,
      centavos: 0,
      transbordos: 0,
    );
  }

  List<ItinerarioSugerido> _directos(Coord origen, Coord destino, int tarifa) {
    final porSentido = <String, List<_Muestra>>{};
    for (final muestra in _muestras) {
      porSentido.putIfAbsent('${muestra.routeId}|${muestra.sentido}', () => []).add(muestra);
    }
    final salida = <ItinerarioSugerido>[];
    for (final grupo in porSentido.values) {
      _Muestra? subida;
      _Muestra? bajada;
      var mejor = double.infinity;
      for (final candidataSubida in grupo) {
        final andar = haversineMetros(origen, candidataSubida.punto);
        if (andar > _maximoAndar) continue;
        for (final candidataBajada in grupo) {
          if (candidataBajada.orden <= candidataSubida.orden) continue;
          final llegar = haversineMetros(candidataBajada.punto, destino);
          if (llegar > _maximoAndar) continue;
          final costo = andar + llegar;
          if (costo < mejor) {
            mejor = costo;
            subida = candidataSubida;
            bajada = candidataBajada;
          }
        }
      }
      if (subida == null || bajada == null) continue;
      salida.add(_armarDirecto(origen, destino, subida, bajada, tarifa));
    }
    return salida;
  }

  ItinerarioSugerido _armarDirecto(
    Coord origen,
    Coord destino,
    _Muestra subida,
    _Muestra bajada,
    int tarifa,
  ) {
    final ruta = catalogo.porId(subida.routeId);
    final andarIda = haversineMetros(origen, subida.punto);
    final andarVuelta = haversineMetros(bajada.punto, destino);
    final aBordo = (bajada.minutos - subida.minutos).clamp(1, 400).toDouble();
    final tramos = [
      if (andarIda > 20)
        TramoSugerido(aPie: true, puntos: [origen, subida.punto], metros: andarIda, minutos: andarIda / _metrosPorMinutoAPie),
      TramoSugerido(
        aPie: false,
        puntos: _recorte(ruta?.tramo(subida.sentido)?.puntos ?? [subida.punto, bajada.punto], subida.orden, bajada.orden),
        metros: bajada.metros - subida.metros,
        minutos: aBordo,
        routeId: subida.routeId,
        sentido: subida.sentido,
        nombre: ruta?.nombreComun,
        colorHex: ruta?.colorHex,
      ),
      if (andarVuelta > 20)
        TramoSugerido(aPie: true, puntos: [bajada.punto, destino], metros: andarVuelta, minutos: andarVuelta / _metrosPorMinutoAPie),
    ];
    return ItinerarioSugerido(
      tramos: tramos,
      minutos: tramos.fold(0, (suma, tramo) => suma + tramo.minutos),
      metrosCaminando: andarIda + andarVuelta,
      centavos: tarifa,
      transbordos: 0,
    );
  }

  List<ItinerarioSugerido> _conTransbordo(Coord origen, Coord destino, int tarifa) {
    final salidas = _mejoresCercanas(origen, true);
    final llegadas = _mejoresCercanas(destino, false);
    final salida = <ItinerarioSugerido>[];
    for (final subida in salidas) {
      for (final bajada in llegadas) {
        if (subida.routeId == bajada.routeId) continue;
        final puente = _puente(subida, bajada);
        if (puente == null) continue;
        salida.add(_armarTransbordo(origen, destino, subida, puente.$1, puente.$2, bajada, tarifa));
        if (salida.length > 12) return salida;
      }
    }
    return salida;
  }

  List<_Muestra> _mejoresCercanas(Coord punto, bool esOrigen) {
    final mejor = <String, _Muestra>{};
    final distancia = <String, double>{};
    for (final muestra in _muestras) {
      final metros = haversineMetros(punto, muestra.punto);
      if (metros > _maximoAndar) continue;
      if (esOrigen && muestra.metros > muestra.metrosTotales * 0.92) continue;
      if (!esOrigen && muestra.metros < muestra.metrosTotales * 0.08) continue;
      final clave = '${muestra.routeId}|${muestra.sentido}';
      final previa = distancia[clave];
      if (previa == null || metros < previa) {
        distancia[clave] = metros;
        mejor[clave] = muestra;
      }
    }
    final lista = mejor.values.toList()
      ..sort((a, b) => distancia['${a.routeId}|${a.sentido}']!.compareTo(distancia['${b.routeId}|${b.sentido}']!));
    if (lista.length <= 8) return lista;
    return lista.sublist(0, 8);
  }

  (_Muestra, _Muestra)? _puente(_Muestra subida, _Muestra bajada) {
    (_Muestra, _Muestra)? mejor;
    var caminata = double.infinity;
    final delPrimero = _muestras.where(
      (m) => m.routeId == subida.routeId && m.sentido == subida.sentido && m.orden > subida.orden,
    );
    final delSegundo = _muestras.where(
      (m) => m.routeId == bajada.routeId && m.sentido == bajada.sentido && m.orden < bajada.orden,
    );
    final segundos = delSegundo.toList();
    var paso = 0;
    for (final bajaAqui in delPrimero) {
      if (paso++ % 2 == 1) continue;
      for (final subeAlli in segundos) {
        final metros = haversineMetros(bajaAqui.punto, subeAlli.punto);
        if (metros > _maximoTransbordo || metros >= caminata) continue;
        caminata = metros;
        mejor = (bajaAqui, subeAlli);
      }
    }
    return mejor;
  }

  ItinerarioSugerido _armarTransbordo(
    Coord origen,
    Coord destino,
    _Muestra subida,
    _Muestra bajaPrimero,
    _Muestra subeSegundo,
    _Muestra bajada,
    int tarifa,
  ) {
    ItinerarioSugerido directo(Coord a, Coord b, _Muestra s, _Muestra t, int precio) {
      return _armarDirecto(a, b, s, t, precio);
    }

    final primero = directo(origen, bajaPrimero.punto, subida, bajaPrimero, tarifa);
    final caminar = haversineMetros(bajaPrimero.punto, subeSegundo.punto);
    final segundo = directo(subeSegundo.punto, destino, subeSegundo, bajada, tarifa);
    final tramos = [
      ...primero.tramos.where((t) => !(t.aPie && t.puntos.last == bajaPrimero.punto && t.puntos.first != origen)),
      TramoSugerido(
        aPie: true,
        puntos: [bajaPrimero.punto, subeSegundo.punto],
        metros: caminar,
        minutos: caminar / _metrosPorMinutoAPie,
      ),
      ...segundo.tramos.where((t) => !t.aPie || t.puntos.first != subeSegundo.punto),
    ];
    final limpios = tramos.where((t) => t.puntos.length >= 2 && t.minutos >= 0).toList();
    return ItinerarioSugerido(
      tramos: limpios,
      minutos: limpios.fold(0, (s, t) => s + t.minutos),
      metrosCaminando: limpios.where((t) => t.aPie).fold(0, (s, t) => s + t.metros),
      centavos: tarifa * 2,
      transbordos: 1,
    );
  }

  List<_Muestra> _muestrear(TramoRuta tramo) {
    final linea = tramo.puntos;
    if (linea.length < 2) return const [];
    final acumulado = List<double>.filled(linea.length, 0);
    for (var i = 1; i < linea.length; i++) {
      acumulado[i] = acumulado[i - 1] + haversineMetros(linea[i - 1], linea[i]);
    }
    final total = acumulado.last;
    if (total == 0) return const [];
    final salida = <_Muestra>[];
    var proximo = 0.0;
    for (var i = 0; i < linea.length; i++) {
      final esExtremo = i == 0 || i == linea.length - 1;
      if (!esExtremo && acumulado[i] + 1 < proximo) continue;
      final minutos = tramo.minutos * (acumulado[i] / total);
      salida.add(
        _Muestra(
          routeId: tramo.rutaId,
          sentido: tramo.sentido,
          orden: i,
          punto: linea[i],
          metros: acumulado[i],
          minutos: minutos,
          metrosTotales: total,
          minutosTotales: tramo.minutos,
        ),
      );
      proximo = acumulado[i] + 250;
    }
    return salida;
  }

  List<Coord> _recorte(List<Coord> linea, int desde, int hasta) {
    if (linea.length < 2) return linea;
    final a = desde.clamp(0, linea.length - 1);
    final b = hasta.clamp(a, linea.length - 1);
    if (b <= a) return [linea[a], linea[mathMin(a + 1, linea.length - 1)]];
    return linea.sublist(a, b + 1);
  }
}

int mathMin(int a, int b) => a < b ? a : b;
