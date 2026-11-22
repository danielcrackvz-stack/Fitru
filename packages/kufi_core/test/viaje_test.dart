import 'dart:io';

import 'package:kufi_core/kufi_core.dart';
import 'package:test/test.dart';

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
}
