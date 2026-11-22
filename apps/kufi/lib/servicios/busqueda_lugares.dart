import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kufi_core/kufi_core.dart';

/// User-Agent identificable. Nominatim pide no martillar el servicio.
const agenteBusqueda = 'Subi/0.1 (educativo; Santa Cruz de la Sierra)';

class BuscadorLugares {
  BuscadorLugares({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  DateTime _ultimo = DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<Lugar>> buscar(String consulta) async {
    final locales = buscarLugaresLocales(consulta);
    final texto = consulta.trim();
    if (texto.length < 3) return locales;
    final espera = DateTime.now().difference(_ultimo);
    if (espera < const Duration(milliseconds: 900)) {
      await Future<void>.delayed(const Duration(milliseconds: 900) - espera);
    }
    _ultimo = DateTime.now();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$texto, Santa Cruz, Bolivia',
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'bo',
      });
      final respuesta = await _cliente
          .get(uri, headers: {'User-Agent': agenteBusqueda, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (respuesta.statusCode != 200) return locales;
      final datos = jsonDecode(respuesta.body);
      if (datos is! List) return locales;
      final remotos = <Lugar>[];
      for (final item in datos) {
        if (item is! Map) continue;
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat == null || lon == null) continue;
        remotos.add(
          Lugar(
            nombre: '${item['name'] ?? texto}',
            detalle: '${item['display_name'] ?? 'Resultado en línea'}',
            punto: Coord(lat, lon),
            enLinea: true,
          ),
        );
      }
      return [...remotos, ...locales];
    } catch (_) {
      return locales;
    }
  }
}
