import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';
import 'package:latlong2/latlong.dart';

import '../../alcance.dart';
import '../../formato.dart';
import '../../servicios/busqueda_lugares.dart';
import '../../servicios/teselas.dart';
import '../../tema.dart';
import '../widgets.dart';

class PantallaViaje extends StatefulWidget {
  const PantallaViaje({super.key});

  @override
  State<PantallaViaje> createState() => _PantallaViajeState();
}

class _PantallaViajeState extends State<PantallaViaje> with SingleTickerProviderStateMixin {
  final _origen = TextEditingController();
  final _destino = TextEditingController();
  final _buscador = BuscadorLugares();
  final _teselas = ConfigTeselas.desdeEntorno();
  final _mapa = MapController();
  Coord? _puntoOrigen;
  Coord? _puntoDestino;
  List<Lugar> _sugerencias = lugaresSantaCruz.take(6).toList();
  var _editandoOrigen = true;
  List<ItinerarioSugerido> _ideas = [];
  var _elegido = 0;
  Timer? _debounce;
  late final AnimationController _pulso = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _debounce?.cancel();
    _origen.dispose();
    _destino.dispose();
    _mapa.dispose();
    _pulso.dispose();
    super.dispose();
  }

  void _alEscribir(String texto, bool origen) {
    _editandoOrigen = origen;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final lugares = await _buscador.buscar(texto);
      if (!mounted) return;
      setState(() => _sugerencias = lugares);
    });
  }

  void _usar(Lugar lugar) {
    setState(() {
      if (_editandoOrigen) {
        _origen.text = lugar.nombre;
        _puntoOrigen = lugar.punto;
      } else {
        _destino.text = lugar.nombre;
        _puntoDestino = lugar.punto;
      }
    });
    _calcular();
  }

  void _calcular() {
    final estado = KufiScope.of(context);
    final origen = _puntoOrigen ?? estado.ubicacion;
    final destino = _puntoDestino;
    if (destino == null) return;
    final ideas = estado.planificador.proponer(
      origen: origen,
      destino: destino,
      tarifaCentavos: estado.tarifas.montoDe(TipoPasaje.adulto),
    );
    setState(() {
      _ideas = ideas;
      _elegido = 0;
    });
    if (ideas.isNotEmpty) estado.elegirItinerario(ideas.first);
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final idea = _ideas.isEmpty ? null : _ideas[_elegido.clamp(0, _ideas.length - 1)];
    return Scaffold(
      appBar: AppBar(leading: const BotonAtras(), title: const Text('Cómo llego')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            controller: _origen,
            decoration: const InputDecoration(labelText: 'Origen', hintText: 'Mi ubicación, una plaza o un pin'),
            onTap: () => _editandoOrigen = true,
            onChanged: (v) => _alEscribir(v, true),
          ),
          TextField(
            controller: _destino,
            decoration: const InputDecoration(labelText: 'Destino'),
            onTap: () => _editandoOrigen = false,
            onChanged: (v) => _alEscribir(v, false),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Usar mi GPS'),
                onPressed: () {
                  setState(() {
                    _puntoOrigen = estado.ubicacion;
                    _origen.text = estado.ubicacionEsEjemplo ? 'Centro (ejemplo)' : 'Mi ubicación';
                    _editandoOrigen = false;
                  });
                  _calcular();
                },
              ),
              if (estado.pinMapa != null)
                ActionChip(
                  label: const Text('Usar el pin del mapa'),
                  onPressed: () {
                    setState(() {
                      if (_editandoOrigen) {
                        _puntoOrigen = estado.pinMapa;
                        _origen.text = 'Pin en el mapa';
                      } else {
                        _puntoDestino = estado.pinMapa;
                        _destino.text = 'Pin en el mapa';
                      }
                    });
                    _calcular();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final lugar in _sugerencias)
                  SizedBox(
                    width: 180,
                    child: Card(
                      child: ListTile(
                        title: Text(lugar.nombre, maxLines: 2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        subtitle: Text(lugar.enLinea ? 'En línea' : lugar.detalle),
                        onTap: () => _usar(lugar),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (idea != null) ...[
            SizedBox(height: 220, child: _mapaDe(idea)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _ideas.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_ideas[i].titulo),
                        selected: i == _elegido,
                        onSelected: (_) {
                          setState(() => _elegido = i);
                          estado.elegirItinerario(_ideas[i]);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${idea.minutos.round()} min · ${idea.metrosCaminando.round()} m a pie · ${Dinero(idea.centavos).texto}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final tramo in idea.tramos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  tramo.aPie ? Icons.directions_walk : Icons.directions_bus,
                  color: tramo.aPie ? ColoresKufi.textoSuave : colorHex(tramo.colorHex ?? '#009048'),
                ),
                title: Text(tramo.aPie ? 'Caminata' : (tramo.nombre ?? 'Trufi')),
                subtitle: Text('${tramo.minutos.round()} min · ${(tramo.metros / 1000).toStringAsFixed(1)} km'),
              ),
            BotonKufi(
              texto: 'Pagar con Subí',
              onPressed: () {
                final trufi = idea.tramos.cast<TramoSugerido?>().firstWhere((t) => t != null && !t.aPie, orElse: () => null);
                if (trufi?.routeId == null) return;
                final ruta = estado.catalogo.porId(trufi!.routeId!);
                if (ruta == null) return;
                estado.prepararPago(ruta: ruta, sentido: trufi.sentido ?? 'ida', medio: 'nfc');
                context.push('/pago/nfc');
              },
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Elige origen y destino. Si no hay internet, usamos plazas, mercados y anillos guardados en el teléfono.'),
            ),
        ],
      ),
    );
  }

  Widget _mapaDe(ItinerarioSugerido idea) {
    final lineas = <Polyline>[
      for (final tramo in idea.tramos)
        if (tramo.puntos.length >= 2)
          Polyline(
            points: [for (final p in tramo.puntos) LatLng(p.lat, p.lon)],
            color: tramo.aPie ? const Color(0xFF787E78) : colorHex(tramo.colorHex ?? '#009048'),
            strokeWidth: tramo.aPie ? 3 : 5,
            pattern: tramo.aPie ? StrokePattern.dashed(segments: const [8, 8]) : const StrokePattern.solid(),
          ),
    ];
    final todos = [for (final t in idea.tramos) ...t.puntos];
    final centro = todos.isEmpty ? const LatLng(-17.78, -63.18) : LatLng(todos.first.lat, todos.first.lon);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedBuilder(
        animation: _pulso,
        builder: (context, _) {
          final tramo = idea.tramos.cast<TramoSugerido?>().firstWhere((t) => t != null && !t.aPie, orElse: () => idea.tramos.first);
          final bus = tramo == null || tramo.puntos.length < 2
              ? centro
              : _sobre(tramo.puntos, _pulso.value);
          return FlutterMap(
            mapController: _mapa,
            options: MapOptions(initialCenter: centro, initialZoom: 13, backgroundColor: const Color(0xFFE7E2D6)),
            children: [
              TileLayer(urlTemplate: _teselas.urlPlantilla, userAgentPackageName: _teselas.agente),
              PolylineLayer(polylines: lineas),
              MarkerLayer(
                markers: [
                  if (todos.isNotEmpty)
                    Marker(point: LatLng(todos.first.lat, todos.first.lon), width: 16, height: 16, child: const _Punto(color: ColoresKufi.verde)),
                  if (todos.length > 1)
                    Marker(point: LatLng(todos.last.lat, todos.last.lon), width: 16, height: 16, child: const _Punto(color: ColoresKufi.verde700)),
                  Marker(
                    point: bus,
                    width: 28,
                    height: 28,
                    child: const Icon(Icons.navigation, color: ColoresKufi.verde),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  LatLng _sobre(List<Coord> puntos, double t) {
    final i = (t * (puntos.length - 1)).floor().clamp(0, puntos.length - 2);
    final local = (t * (puntos.length - 1)) - i;
    final a = puntos[i];
    final b = puntos[math.min(i + 1, puntos.length - 1)];
    return LatLng(a.lat + (b.lat - a.lat) * local, a.lon + (b.lon - a.lon) * local);
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
