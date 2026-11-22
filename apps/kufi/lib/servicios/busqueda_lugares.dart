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

  /// Dirección corta para un pin. Si Nominatim no responde, usa la zona más cercana.
  Future<String> direccionDe(Coord punto) async {
    final espera = DateTime.now().difference(_ultimo);
    if (espera < const Duration(milliseconds: 900)) {
      await Future<void>.delayed(const Duration(milliseconds: 900) - espera);
    }
    _ultimo = DateTime.now();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': punto.lat.toStringAsFixed(5),
        'lon': punto.lon.toStringAsFixed(5),
        'format': 'jsonv2',
        'zoom': '16',
      });
      final respuesta = await _cliente
          .get(uri, headers: {'User-Agent': agenteBusqueda, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        if (datos is Map) {
          final nombre = datos['name'];
          final direccion = datos['display_name'];
          if (nombre is String && nombre.trim().isNotEmpty) return nombre.trim();
          if (direccion is String && direccion.trim().isNotEmpty) {
            final partes = direccion.split(',');
            return partes.take(2).join(',').trim();
          }
        }
      }
    } catch (_) {}
    return respaldoDePin(punto);
  }
}

String respaldoDePin(Coord punto) {
  Lugar? mejor;
  var distancia = double.infinity;
  for (final lugar in lugaresSantaCruz) {
    final metros = haversineMetros(punto, lugar.punto);
    if (metros < distancia) {
      distancia = metros;
      mejor = lugar;
    }
  }
  if (mejor != null && distancia < 1800) {
    return 'Cerca de ${mejor.nombre}';
  }
  return '${punto.lat.toStringAsFixed(4)}, ${punto.lon.toStringAsFixed(4)}';
}
