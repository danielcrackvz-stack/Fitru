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
    this.operador,
    this.sindicato,
  });

  final bool aPie;
  final List<Coord> puntos;
  final double metros;
  final double minutos;
  final String? routeId;
  final String? sentido;
  final String? nombre;
  final String? colorHex;
  final String? operador;
  final String? sindicato;
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
        final muestras = _muestrear(tramo);
        if (muestras.isEmpty) continue;
        final clave = '${tramo.rutaId}|${tramo.sentido}';
        _porLinea[clave] = muestras;
        for (final muestra in muestras) {
          _celdas.putIfAbsent(_claveCelda(muestra.punto), () => []).add(muestra);
        }
      }
    }
  }

  final CatalogoRutas catalogo;
  final IndiceCercania indice;
  final Map<String, List<_Muestra>> _porLinea = {};
  final Map<String, List<_Muestra>> _celdas = {};

  static const double _metrosPorMinutoAPie = 75;
  static const double _maximoTransbordo = 450;
  static const double _celda = 0.004;

  List<ItinerarioSugerido> proponer({
    required Coord origen,
    required Coord destino,
    required int tarifaCentavos,
    int limite = 8,
    double radioAndar = 800,
  }) {
    final radio = radioAndar < 100 ? 100.0 : radioAndar;
    final directos = _directos(origen, destino, tarifaCentavos, radio);
    final cambios = _conTransbordo(origen, destino, tarifaCentavos, radio);
    final aPie = haversineMetros(origen, destino);
    final pie = aPie <= 1800 ? [_soloAPie(origen, destino, aPie)] : <ItinerarioSugerido>[];
    int porTiempo(ItinerarioSugerido a, ItinerarioSugerido b) {
      final minutos = a.minutos.compareTo(b.minutos);
      if (minutos != 0) return minutos;
      return a.metrosCaminando.compareTo(b.metrosCaminando);
    }

    directos.sort(porTiempo);
    cambios.sort(porTiempo);
    final vistos = <String>{};
    final unicos = <ItinerarioSugerido>[];
    void tomar(List<ItinerarioSugerido> lista, int cupo) {
      var puestos = 0;
      for (final idea in lista) {
        final clave = idea.tramos.map((t) => '${t.routeId ?? 'pie'}:${t.sentido ?? ''}:${t.metros.round()}').join('|');
        if (!vistos.add(clave)) continue;
        unicos.add(idea);
        puestos++;
        if (puestos >= cupo || unicos.length >= limite) return;
      }
    }

    tomar(directos, 5);
    tomar(cambios, 4);
    if (unicos.length < limite) tomar(pie, 1);
    return unicos;
  }

  String _claveCelda(Coord punto) {
    final x = (punto.lon / _celda).floor();
    final y = (punto.lat / _celda).floor();
    return '$x:$y';
  }

  List<_Muestra> _cerca(Coord punto, double radio) {
    final margen = (radio / 111320) + _celda;
    final x0 = ((punto.lon - margen) / _celda).floor();
    final x1 = ((punto.lon + margen) / _celda).floor();
    final y0 = ((punto.lat - margen) / _celda).floor();
    final y1 = ((punto.lat + margen) / _celda).floor();
    final vistos = <_Muestra>{};
    final salida = <_Muestra>[];
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        for (final muestra in _celdas['$x:$y'] ?? const <_Muestra>[]) {
          if (!vistos.add(muestra)) continue;
          if (haversineMetros(punto, muestra.punto) <= radio) salida.add(muestra);
        }
      }
    }
    return salida;
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

  List<ItinerarioSugerido> _directos(Coord origen, Coord destino, int tarifa, double radio) {
    final subidas = <String, List<_Muestra>>{};
    final bajadas = <String, List<_Muestra>>{};
    for (final muestra in _cerca(origen, radio)) {
      subidas.putIfAbsent('${muestra.routeId}|${muestra.sentido}', () => []).add(muestra);
    }
    for (final muestra in _cerca(destino, radio)) {
      bajadas.putIfAbsent('${muestra.routeId}|${muestra.sentido}', () => []).add(muestra);
    }
    final salida = <ItinerarioSugerido>[];
    for (final clave in subidas.keys) {
      final grupoBajada = bajadas[clave];
      if (grupoBajada == null) continue;
      _Muestra? subida;
      _Muestra? bajada;
      var mejor = double.infinity;
      for (final candidataSubida in subidas[clave]!) {
        final andar = haversineMetros(origen, candidataSubida.punto);
        for (final candidataBajada in grupoBajada) {
          if (candidataBajada.orden <= candidataSubida.orden) continue;
          final llegar = haversineMetros(candidataBajada.punto, destino);
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
        operador: ruta?.operador,
        sindicato: ruta?.federacion,
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

  List<ItinerarioSugerido> _conTransbordo(Coord origen, Coord destino, int tarifa, double radio) {
    final salidas = _hacia(origen, destino, radio, true);
    final llegadas = _hacia(destino, origen, radio, false);
    final salida = <ItinerarioSugerido>[];
    for (final subida in salidas) {
      for (final bajada in llegadas) {
        if (subida.routeId == bajada.routeId) continue;
        final puente = _puente(subida, bajada);
        if (puente == null) continue;
        salida.add(_armarTransbordo(origen, destino, subida, puente.$1, puente.$2, bajada, tarifa));
        if (salida.length >= 12) return salida;
      }
    }
    return salida;
  }

  /// Líneas que se acercan al otro punto, no solo las más pegadas al pin.
  List<_Muestra> _hacia(Coord aqui, Coord alla, double radio, bool esSubida) {
    final grupos = <String, _Muestra>{};
    final distancia = <String, double>{};
    for (final muestra in _cerca(aqui, radio)) {
      if (esSubida && muestra.metros > muestra.metrosTotales * 0.92) continue;
      if (!esSubida && muestra.metros < muestra.metrosTotales * 0.08) continue;
      final clave = '${muestra.routeId}|${muestra.sentido}';
      final metros = haversineMetros(aqui, muestra.punto);
      final previa = distancia[clave];
      if (previa == null || metros < previa) {
        distancia[clave] = metros;
        grupos[clave] = muestra;
      }
    }
    final recta = haversineMetros(aqui, alla);
    final score = <_Muestra, double>{};
    final ranked = <_Muestra>[];
    for (final entrada in grupos.entries) {
      final muestra = entrada.value;
      final linea = _porLinea[entrada.key] ?? const <_Muestra>[];
      var mejor = haversineMetros(muestra.punto, alla);
      for (final otro in linea) {
        final sirve = esSubida ? otro.orden > muestra.orden : otro.orden < muestra.orden;
        if (!sirve) continue;
        final lejos = haversineMetros(otro.punto, alla);
        if (lejos < mejor) mejor = lejos;
      }
      if (mejor > recta - 300) continue;
      score[muestra] = distancia[entrada.key]! + mejor;
      ranked.add(muestra);
    }
    ranked.sort((a, b) => score[a]!.compareTo(score[b]!));
    if (ranked.length <= 12) return ranked;
    return ranked.sublist(0, 12);
  }

  (_Muestra, _Muestra)? _puente(_Muestra subida, _Muestra bajada) {
    final primero = _porLinea['${subida.routeId}|${subida.sentido}'] ?? const <_Muestra>[];
    final segundo = _porLinea['${bajada.routeId}|${bajada.sentido}'] ?? const <_Muestra>[];
    final posteriores = <_Muestra>[];
    final rejilla = <String, List<_Muestra>>{};
    for (final muestra in segundo) {
      if (muestra.orden >= bajada.orden) continue;
      posteriores.add(muestra);
      rejilla.putIfAbsent(_claveCelda(muestra.punto), () => []).add(muestra);
    }
    if (posteriores.isEmpty) return null;
    (_Muestra, _Muestra)? mejor;
    var caminata = double.infinity;
    var paso = 0;
    final margen = (_maximoTransbordo / 111320) + _celda;
    for (final bajaAqui in primero) {
      if (bajaAqui.orden <= subida.orden) continue;
      if (paso++ % 2 == 1) continue;
      final x0 = ((bajaAqui.punto.lon - margen) / _celda).floor();
      final x1 = ((bajaAqui.punto.lon + margen) / _celda).floor();
      final y0 = ((bajaAqui.punto.lat - margen) / _celda).floor();
      final y1 = ((bajaAqui.punto.lat + margen) / _celda).floor();
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          for (final subeAlli in rejilla['$x:$y'] ?? const <_Muestra>[]) {
            final metros = haversineMetros(bajaAqui.punto, subeAlli.punto);
            if (metros > _maximoTransbordo || metros >= caminata) continue;
            caminata = metros;
            mejor = (bajaAqui, subeAlli);
          }
        }
      }
      if (caminata < 40) return mejor;
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
