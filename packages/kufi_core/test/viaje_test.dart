import 'dart:io';

import 'package:kufi_core/kufi_core.dart';
import 'package:test/test.dart';

CatalogoRutas? _catalogoReal;

CatalogoRutas catalogoReal() {
  return _catalogoReal ??= AnalizadorRutas.desdeGeoJson(
    File('../../datos/rutas.geojson').readAsStringSync(),
    csv: File('../../datos/rutas_nombres.csv').readAsStringSync(),
  );
}

void main() {
  const geo = '''
{"type":"FeatureCollection","features":[
 {"type":"Feature","properties":{"shape_id":"A_ida","route_id":"A","nombre_comun":"Linea A","sentido":"ida","km":4,"min":20,"operador":"A","federacion":"F","jurisdiccion":"Urbano","color_hex":"#009048","zonas":"Centro"},"geometry":{"type":"LineString","coordinates":[[-63.210,-17.780],[-63.190,-17.780],[-63.170,-17.780]]}},
 {"type":"Feature","properties":{"shape_id":"B_ida","route_id":"B","nombre_comun":"Linea B","sentido":"ida","km":4,"min":20,"operador":"B","federacion":"F","jurisdiccion":"Urbano","color_hex":"#D7263D","zonas":"Norte"},"geometry":{"type":"LineString","coordinates":[[-63.190,-17.800],[-63.190,-17.780],[-63.190,-17.760]]}}
]}
''';

  late CatalogoRutas catalogo;
  late IndiceCercania indice;

  setUp(() {
    catalogo = AnalizadorRutas.desdeGeoJson(geo);
    indice = IndiceCercania.desde(catalogo);
  });

  test('el índice deja fuera lo que está a más del radio', () {
    const sobreLaLinea = Coord(-17.7804, -63.200);
    final cerca = indice.dentroDe(sobreLaLinea, 100, catalogo);
    final lejos = indice.dentroDe(const Coord(-17.790, -63.200), 100, catalogo);
    final medio = indice.dentroDe(const Coord(-17.783, -63.200), 500, catalogo);
    expect(cerca.map((r) => r.ruta.routeId), contains('A'));
    expect(lejos.map((r) => r.ruta.routeId), isNot(contains('A')));
    expect(medio.map((r) => r.ruta.routeId), contains('A'));
    expect(indice.segmentos, greaterThan(0));
  });

  test('un viaje sobre la misma línea sale directo y respeta el sentido', () {
    final plan = PlanificadorViajes(catalogo, indice: indice);
    final ideas = plan.proponer(
      origen: const Coord(-17.7802, -63.205),
      destino: const Coord(-17.7802, -63.175),
      tarifaCentavos: 230,
    );
    final directo = ideas.where((i) => i.titulo == 'Directo' && i.tramos.any((t) => t.routeId == 'A'));
    expect(directo, isNotEmpty);
    final trufi = directo.first.tramos.firstWhere((t) => !t.aPie);
    expect(trufi.sentido, 'ida');
    expect(trufi.puntos.first.lon, lessThan(trufi.puntos.last.lon));
    expect(directo.first.centavos, 230);
  });

  test('si hay que cambiar de línea aparece un transbordo', () {
    final plan = PlanificadorViajes(catalogo, indice: indice);
    final ideas = plan.proponer(
      origen: const Coord(-17.7802, -63.208),
      destino: const Coord(-17.765, -63.1902),
      tarifaCentavos: 230,
    );
    expect(ideas.any((i) => i.transbordos == 1), isTrue);
    final cambio = ideas.firstWhere((i) => i.transbordos == 1);
    expect(cambio.centavos, 460);
    expect(cambio.tramos.where((t) => !t.aPie).map((t) => t.routeId).toSet(), {'A', 'B'});
    expect(cambio.metrosCaminando, greaterThan(0));
  });

  test('los lugares locales ignoran tildes', () {
    expect(buscarLugaresLocales('viru').map((l) => l.nombre), contains('Aeropuerto Viru Viru'));
    expect(buscarLugaresLocales('anillo').length, greaterThan(1));
  });

  test('el catálogo real responde cerca del centro', () {
    final archivo = AnalizadorRutas.desdeGeoJson(
      File('../../datos/rutas.geojson').readAsStringSync(),
    );
    final red = IndiceCercania.desde(archivo);
    final cerca = red.dentroDe(const Coord(-17.7834, -63.1821), 800, archivo);
    expect(cerca, isNotEmpty);
    expect(cerca.every((r) => r.metros <= 800), isTrue);
    expect(red.dentroDe(const Coord(-17.7834, -63.1821), 100, archivo), isEmpty);
  });

  test('pares reales de Santa Cruz tienen directo y transbordo', () {
    final plan = PlanificadorViajes(catalogoReal());
    final directoAnillo = plan.proponer(
      origen: const Coord(-17.79242, -63.18148),
      destino: const Coord(-17.77468, -63.17862),
      tarifaCentavos: 230,
    );
    final directoSegundo = plan.proponer(
      origen: const Coord(-17.79959, -63.19109),
      destino: const Coord(-17.77423, -63.16607),
      tarifaCentavos: 230,
    );
    final cambio = plan.proponer(
      origen: const Coord(-17.81137, -63.15961),
      destino: const Coord(-17.81689, -63.11577),
      tarifaCentavos: 230,
    );
    expect(
      directoAnillo.any((i) => i.transbordos == 0 && i.tramos.any((t) => t.routeId == 'R054' && t.sentido == 'ida')),
      isTrue,
      reason: '1er Anillo Blanco debería salir directo',
    );
    expect(
      directoSegundo.any((i) => i.transbordos == 0 && i.tramos.any((t) => t.routeId == 'R049' && t.sentido == 'ida')),
      isTrue,
      reason: '2do Anillo debería salir directo',
    );
    final transbordos = cambio.where((i) => i.transbordos == 1).toList();
    expect(transbordos, isNotEmpty);
    expect(transbordos.first.tramos.where((t) => !t.aPie).length, 2);
    expect(transbordos.first.centavos, 460);
    expect(cambio.indexWhere((i) => i.transbordos == 0), lessThan(cambio.indexWhere((i) => i.transbordos == 1)));
  });

  test('del centro hacia el este hay opciones aunque la caminata pase de 800 m', () {
    final plan = PlanificadorViajes(catalogoReal());
    final ideas = plan.proponer(
      origen: const Coord(-17.7833, -63.1821),
      destino: const Coord(-17.8094, -63.1254),
      tarifaCentavos: 230,
      radioAndar: 2200,
    );
    expect(ideas.where((i) => i.tramos.any((t) => !t.aPie)), isNotEmpty);
    expect(haversineMetros(const Coord(-17.7833, -63.1821), const Coord(-17.8094, -63.1254)) / 1000, greaterThan(5));
  });

  test('proponer varios pares reales tarda menos de un segundo', () {
    final inicio = DateTime.now();
    final plan = PlanificadorViajes(catalogoReal());
    const pares = [
      (Coord(-17.79242, -63.18148), Coord(-17.77468, -63.17862)),
      (Coord(-17.79959, -63.19109), Coord(-17.77423, -63.16607)),
      (Coord(-17.81137, -63.15961), Coord(-17.81689, -63.11577)),
      (Coord(-17.78525, -63.15254), Coord(-17.76872, -63.20111)),
      (Coord(-17.81405, -63.18281), Coord(-17.76794, -63.20281)),
    ];
    for (final par in pares) {
      final ideas = plan.proponer(origen: par.$1, destino: par.$2, tarifaCentavos: 230);
      expect(ideas, isNotEmpty);
    }
    final ms = DateTime.now().difference(inicio).inMilliseconds;
    expect(ms, lessThan(1000), reason: 'armado + 5 consultas tardaron $ms ms');
  });
}
