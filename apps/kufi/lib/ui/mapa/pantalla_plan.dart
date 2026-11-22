import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:kufi_core/kufi_core.dart';
import 'package:latlong2/latlong.dart';

import '../../alcance.dart';
import '../../estado/estado_kufi.dart';
import '../../formato.dart';
import '../../servicios/busqueda_lugares.dart';
import '../../servicios/teselas.dart';
import '../../servicios/ubicacion.dart';
import '../../tema.dart';

/// Destino de las capturas del celular, al este del centro.
const _destinoDemo = Coord(-17.8094, -63.1254);

class PantallaPlan extends StatefulWidget {
  const PantallaPlan({super.key});

  @override
  State<PantallaPlan> createState() => _PantallaPlanState();
}

class _PantallaPlanState extends State<PantallaPlan> {
  final _teselas = ConfigTeselas.desdeEntorno();
  final _mapa = MapController();
  _PuntoElegido? _origen;
  _PuntoElegido? _destino;
  Coord _centro = centroSantaCruz;
  _ModoMarca _modo = _ModoMarca.ninguno;
  List<ItinerarioSugerido> _ideas = const [];
  var _elegido = 0;
  var _hoja = 0.42;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final estado = KufiScope.of(context);
      estado.refrescarUbicacion();
      final captura = estado.captura;
      if (captura == 'opciones' || captura == 'lista' || captura == 'transbordo' || captura == 'recorrido') {
        _hoja = captura == 'lista' ? 0.68 : 0.46;
        _origen = const _PuntoElegido(punto: centroSantaCruz, nombre: 'Mi ubicación');
        _destino = const _PuntoElegido(punto: _destinoDemo, nombre: 'Punto en el mapa');
        _recalcular(encuadrar: true);
      } else if (captura == 'marcar-origen') {
        setState(() => _modo = _ModoMarca.origen);
      } else if (captura == 'elegir') {
        _origen = _PuntoElegido(punto: estado.ubicacion, nombre: 'Mi ubicación');
        setState(() => _modo = _ModoMarca.destino);
      } else if (captura == 'menu-origen') {
        _abrirMenu(origen: true);
      }
    });
  }

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  bool get _marcando => _modo != _ModoMarca.ninguno;

  void _poner({required bool origen, required Coord punto, required String nombre}) {
    final elegido = _PuntoElegido(punto: punto, nombre: nombre);
    setState(() {
      if (origen) {
        _origen = elegido;
      } else {
        _destino = elegido;
      }
      _modo = _ModoMarca.ninguno;
    });
    _recalcular(encuadrar: true);
  }

  void _recalcular({bool encuadrar = false}) {
    final origen = _origen;
    final destino = _destino;
    if (origen == null || destino == null) {
      setState(() {
        _ideas = const [];
        _elegido = 0;
      });
      return;
    }
    final estado = KufiScope.of(context);
    final ideas = estado.planificador.proponer(
      origen: origen.punto,
      destino: destino.punto,
      tarifaCentavos: estado.tarifas.montoDe(TipoPasaje.adulto),
      radioAndar: 2200,
      limite: 8,
    )..sort((a, b) {
        final minutos = a.minutos.compareTo(b.minutos);
        if (minutos != 0) return minutos;
        return a.metrosCaminando.compareTo(b.metrosCaminando);
      });
    setState(() {
      _ideas = ideas;
      _elegido = 0;
    });
    if (encuadrar && ideas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _encuadrar(ideas.first);
      });
    }
  }

  void _limpiar() {
    setState(() {
      _origen = null;
      _destino = null;
      _ideas = const [];
      _elegido = 0;
      _modo = _ModoMarca.ninguno;
    });
  }

  void _intercambiar() {
    final origen = _origen;
    final destino = _destino;
    if (origen == null || destino == null) return;
    setState(() {
      _origen = destino;
      _destino = origen;
    });
    _recalcular(encuadrar: true);
  }

  Future<void> _abrirMenu({required bool origen}) async {
    final estado = KufiScope.of(context);
    final resultado = await showModalBottomSheet<_ResultadoMenu>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _MenuLugar(
        titulo: origen ? 'Origen' : 'Destino',
        gpsDisponible: !estado.ubicacionEsEjemplo,
      ),
    );
    if (!mounted || resultado == null) return;
    if (resultado.lugar != null) {
      _poner(origen: origen, punto: resultado.lugar!.punto, nombre: resultado.lugar!.nombre);
      return;
    }
    if (resultado.marcarEnMapa) {
      setState(() => _modo = origen ? _ModoMarca.origen : _ModoMarca.destino);
      return;
    }
    await estado.refrescarUbicacion();
    if (!mounted) return;
    if (estado.ubicacionEsEjemplo) {
      setState(() => _modo = origen ? _ModoMarca.origen : _ModoMarca.destino);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(origen ? 'No hay GPS. Marcá el origen en el mapa.' : 'No hay GPS. Marcá el destino en el mapa.'),
        ),
      );
      return;
    }
    _poner(origen: origen, punto: estado.ubicacion, nombre: 'Mi ubicación');
  }

  void _confirmarMarca() {
    final origen = _modo == _ModoMarca.origen;
    _poner(origen: origen, punto: _centro, nombre: 'Punto en el mapa');
  }

  void _encuadrar(ItinerarioSugerido idea) {
    final puntos = [for (final tramo in idea.tramos) ...tramo.puntos];
    if (puntos.length < 2) return;
    _mapa.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final punto in puntos) LatLng(punto.lat, punto.lon)],
        padding: const EdgeInsets.fromLTRB(28, 200, 28, 320),
        maxZoom: 15,
      ),
    );
  }

  void _irAlCentro(Coord punto) {
    _centro = punto;
    _mapa.move(LatLng(punto.lat, punto.lon), _mapa.camera.zoom);
  }

  ItinerarioSugerido? get _idea {
    if (_ideas.isEmpty) return null;
    return _ideas[_elegido.clamp(0, _ideas.length - 1)];
  }

  bool get _caminataLarga {
    for (final idea in _ideas) {
      for (final tramo in idea.tramos) {
        if (tramo.aPie && tramo.metros > 800) return true;
      }
    }
    return _ideas.isEmpty && _destino != null;
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final origen = _origen?.punto ?? estado.ubicacion;
    final idea = _idea;
    final listo = _origen != null && _destino != null && !_marcando;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: LatLng(origen.lat, origen.lon),
              initialZoom: 13,
              minZoom: 11,
              maxZoom: 18,
              backgroundColor: const Color(0xFFE7E2D6),
              onTap: (tap, punto) {
                if (!_marcando) return;
                final marcado = Coord(punto.latitude, punto.longitude);
                _centro = marcado;
                _mapa.move(punto, _mapa.camera.zoom);
              },
              onPositionChanged: (camera, gesto) {
                _centro = Coord(camera.center.latitude, camera.center.longitude);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _teselas.urlPlantilla,
                userAgentPackageName: _teselas.agente,
                maxZoom: 19,
              ),
              PolylineLayer(polylines: _red(estado, atenuar: idea != null)),
              if (idea != null) PolylineLayer(polylines: _viaje(idea)),
              MarkerLayer(markers: _marcas(estado.ubicacion, idea)),
            ],
          ),
          if (_marcando)
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Icon(
                    Icons.location_on,
                    size: 54,
                    color: _modo == _ModoMarca.origen ? ColoresKufi.verde : const Color(0xFFE23B3B),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            top: 6,
            child: SafeArea(bottom: false, child: _tarjeta(estado, origen)),
          ),
          Positioned(
            left: 8,
            bottom: _marcando || !listo ? 108 : 16,
            child: const Text(
              '© colaboradores de OpenStreetMap',
              style: TextStyle(fontSize: 11, color: Color(0xFF3C3C3C)),
            ),
          ),
          if (_marcando)
            Positioned(left: 12, right: 12, bottom: 16, child: _barraMarcar())
          else if (!listo)
            Positioned(left: 12, right: 12, bottom: 16, child: _barraGuia())
          else
            DraggableScrollableSheet(
              initialChildSize: _hoja,
              minChildSize: 0.22,
              maxChildSize: 0.74,
              builder: (context, scroll) => _hojaOpciones(estado, origen, scroll),
            ),
          if (_marcando || !listo)
            Positioned(
              right: 12,
              bottom: 108,
              child: _botonUbicacion(estado),
            ),
        ],
      ),
    );
  }

  Widget _botonUbicacion(EstadoKufi estado) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Colors.white,
      child: IconButton(
        tooltip: 'Mi ubicación',
        onPressed: () => _irAlCentro(estado.ubicacion),
        icon: const Icon(Icons.my_location, color: ColoresKufi.verde),
      ),
    );
  }

  Widget _tarjeta(EstadoKufi estado, Coord origen) {
    final destino = _destino?.punto;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(22),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: 'Volver',
              onPressed: _marcando
                  ? () => setState(() => _modo = _ModoMarca.ninguno)
                  : (_origen == null && _destino == null ? null : _limpiar),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 14, color: ColoresKufi.verde),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _abrirMenu(origen: true),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _origen == null ? 'Origen' : 'Origen · ${_coord(_origen!.punto)}',
                                style: const TextStyle(fontSize: 12, color: ColoresKufi.textoSuave),
                              ),
                              Text(
                                _origen?.nombre ?? 'Elegí el origen',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Centrar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _irAlCentro(origen),
                        icon: const Icon(Icons.gps_fixed, color: ColoresKufi.verde),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F6EE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      onTap: () => _abrirMenu(origen: false),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Color(0xFFE23B3B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destino == null ? 'Destino' : 'Destino · ${_coord(destino)}',
                                  style: const TextStyle(fontSize: 12, color: ColoresKufi.textoSuave),
                                ),
                                Text(
                                  _destino?.nombre ?? 'Elegí el destino',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Intercambiar',
                  onPressed: _origen == null || _destino == null ? null : _intercambiar,
                  icon: const Icon(Icons.swap_vert, color: ColoresKufi.verde),
                ),
                TextButton.icon(
                  onPressed: _limpiar,
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFE07A2F), size: 18),
                  label: const Text('Borrar', style: TextStyle(color: Color(0xFFE07A2F))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraGuia() {
    final faltaOrigen = _origen == null;
    return Material(
      color: const Color(0xFF0C3B22),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(Icons.route, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                faltaOrigen ? 'Primero elegí de dónde salís. Te sugerimos tu ubicación.' : 'Ahora marcá a dónde vas.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0C3B22),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _abrirMenu(origen: faltaOrigen),
              child: Text(faltaOrigen ? 'Elegir origen' : 'Elegir destino'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraMarcar() {
    final origen = _modo == _ModoMarca.origen;
    final color = origen ? ColoresKufi.verde : const Color(0xFFE23B3B);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                origen ? 'Tocá el mapa para marcar tu ORIGEN' : 'Tocá el mapa para marcar tu DESTINO',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: color,
                shape: const StadiumBorder(),
              ),
              onPressed: _confirmarMarca,
              child: Text(origen ? 'Confirmar origen' : 'Confirmar destino'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hojaOpciones(EstadoKufi estado, Coord origen, ScrollController scroll) {
    final destino = _destino?.punto ?? origen;
    final recta = haversineMetros(origen, destino);
    return Material(
      elevation: 16,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: ColoresKufi.superficie3, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_ideas.length} opciones · ${_km(recta)} en línea recta',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          if (_caminataLarga)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No hay trufis muy cerca: tocá caminar un poco más.',
                  style: TextStyle(color: Color(0xFFB86E00), fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: _ideas.length,
              itemBuilder: (context, indice) {
                final idea = _ideas[indice];
                return _tarjetaOpcion(
                  estado,
                  idea,
                  activa: indice == _elegido,
                  masRapida: indice == 0 && _ideas.length > 1,
                  alTocar: () {
                    setState(() => _elegido = indice);
                    _encuadrar(idea);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaOpcion(
    EstadoKufi estado,
    ItinerarioSugerido idea,
    {required bool activa, required bool masRapida, required VoidCallback alTocar}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: activa ? ColoresKufi.verde : ColoresKufi.superficie2, width: activa ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: ColoresKufi.verde, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'Tiempo total: ${_tiempo(idea.minutos)} · ${idea.transbordos == 0 ? 'Directo' : '${idea.transbordos} transbordo${idea.transbordos == 1 ? '' : 's'}'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    if (masRapida)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFD9F2E4), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Más rápida', style: TextStyle(color: ColoresKufi.verde700, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${_km(idea.metrosCaminando)} a pie', style: const TextStyle(color: ColoresKufi.textoSuave)),
                ),
                const SizedBox(height: 6),
                _cadena(estado, idea),
                if (activa) ...[
                  const SizedBox(height: 8),
                  for (final linea in _detalle(estado, idea))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(linea),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cadena(EstadoKufi estado, ItinerarioSugerido idea) {
    final tramos = idea.tramos;
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < tramos.length; i++) ...[
          if (i > 0) const Icon(Icons.arrow_forward, size: 16, color: ColoresKufi.verde),
          _eslabon(estado, tramos[i]),
        ],
      ],
    );
  }

  Widget _eslabon(EstadoKufi estado, TramoSugerido tramo) {
    if (tramo.aPie) {
      return SizedBox(
        width: 72,
        child: Column(
          children: [
            const Icon(Icons.directions_walk, color: ColoresKufi.verde700),
            Text(_metrosCorto(tramo.metros), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${tramo.minutos.round()} min', style: const TextStyle(fontSize: 12, color: ColoresKufi.textoSuave)),
          ],
        ),
      );
    }
    final color = colorHex(tramo.colorHex ?? '#009048');
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 220),
      child: Column(
        children: [
          CircleAvatar(radius: 14, backgroundColor: color, child: const Icon(Icons.directions_bus, size: 16, color: Colors.white)),
          Text(
            tramo.nombre ?? 'Trufi',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${_metrosCorto(tramo.metros)} · ${tramo.minutos.round()} min',
            style: const TextStyle(fontSize: 12, color: ColoresKufi.textoSuave),
          ),
        ],
      ),
    );
  }

  List<String> _detalle(EstadoKufi estado, ItinerarioSugerido idea) {
    final lineas = <String>[];
    for (var i = 0; i < idea.tramos.length; i++) {
      final tramo = idea.tramos[i];
      final antes = idea.tramos.take(i).any((otro) => !otro.aPie);
      final despues = idea.tramos.skip(i + 1).any((otro) => !otro.aPie);
      if (tramo.aPie) {
        final cuanto = '${_metrosCorto(tramo.metros)} (${tramo.minutos.round()} min)';
        if (!antes && despues) {
          lineas.add('Camina $cuanto hasta tomar el trufi');
        } else if (antes && despues) {
          lineas.add('Transbordo: camina $cuanto');
        } else if (antes) {
          lineas.add('Bájate y camina $cuanto al destino');
        } else {
          lineas.add('Camina $cuanto');
        }
        continue;
      }
      final ruta = tramo.routeId == null ? null : estado.catalogo.porId(tramo.routeId!);
      final zona = ruta?.tramo(tramo.sentido ?? 'ida')?.zonaDestino ?? '';
      final hacia = zona.isEmpty ? '' : ' hacia $zona';
      final nombre = tramo.nombre ?? 'Trufi';
      lineas.add('$nombre$hacia · ${_metrosCorto(tramo.metros)} · ${tramo.minutos.round()} min');
    }
    return lineas;
  }

  List<Polyline<Object>> _red(EstadoKufi estado, {required bool atenuar}) {
    final salida = <Polyline<Object>>[];
    for (final ruta in estado.catalogo.rutas) {
      void agregar(TramoRuta? tramo) {
        if (tramo == null || tramo.puntos.length < 2) return;
        salida.add(
          Polyline(
            points: [for (final punto in tramo.puntos) LatLng(punto.lat, punto.lon)],
            strokeWidth: atenuar ? 1.2 : 2,
            color: colorHex(ruta.colorHex, atenuar ? 0.1 : 0.4),
          ),
        );
      }

      agregar(ruta.ida);
      agregar(ruta.vuelta);
    }
    return salida;
  }

  List<Polyline<Object>> _viaje(ItinerarioSugerido idea) {
    return [
      for (final tramo in idea.tramos)
        if (tramo.puntos.length >= 2)
          Polyline(
            points: [for (final punto in tramo.puntos) LatLng(punto.lat, punto.lon)],
            strokeWidth: tramo.aPie ? 4 : 6,
            color: tramo.aPie ? const Color(0xFF5E665F) : colorHex(tramo.colorHex ?? '#009048'),
            pattern: tramo.aPie ? StrokePattern.dashed(segments: const [8, 7]) : const StrokePattern.solid(),
          ),
    ];
  }

  List<Marker> _marcas(Coord origen, ItinerarioSugerido? idea) {
    final marcas = <Marker>[
      Marker(
        point: LatLng(origen.lat, origen.lon),
        width: 18,
        height: 18,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2F6BFF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    ];
    if (_origen != null) marcas.add(_pin(_origen!.punto, ColoresKufi.verde, 'A'));
    if (_destino != null) marcas.add(_pin(_destino!.punto, const Color(0xFFE23B3B), 'B'));
    if (idea == null) return marcas;
    for (final tramo in idea.tramos) {
      if (tramo.aPie || tramo.puntos.length < 2) continue;
      final color = colorHex(tramo.colorHex ?? '#009048');
      marcas.add(
        Marker(
          point: LatLng(tramo.puntos.first.lat, tramo.puntos.first.lon),
          width: 28,
          height: 28,
          child: CircleAvatar(backgroundColor: color, child: const Icon(Icons.directions_bus, size: 16, color: Colors.white)),
        ),
      );
      final fin = tramo.puntos.last;
      marcas.add(
        Marker(
          point: LatLng(fin.lat, fin.lon),
          width: 26,
          height: 26,
          child: const Icon(Icons.flag, color: ColoresKufi.verde800),
        ),
      );
    }
    return marcas;
  }

  Marker _pin(Coord punto, Color color, String letra) {
    return Marker(
      point: LatLng(punto.lat, punto.lon),
      width: 36,
      height: 36,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: Text(letra, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _coord(Coord punto) => '${punto.lat.toStringAsFixed(4)}, ${punto.lon.toStringAsFixed(4)}';

  String _km(double metros) {
    final texto = (metros / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return '$texto km';
  }

  String _metrosCorto(double metros) {
    if (metros < 950) return '${metros.round()} m';
    return _km(metros);
  }

  String _tiempo(double minutos) {
    final total = minutos.round();
    if (total < 60) return '$total min';
    final horas = total ~/ 60;
    final resto = total % 60;
    if (resto == 0) return '$horas h';
    return '$horas h $resto min';
  }
}

enum _ModoMarca { ninguno, origen, destino }

class _PuntoElegido {
  const _PuntoElegido({required this.punto, required this.nombre});

  final Coord punto;
  final String nombre;
}

class _ResultadoMenu {
  const _ResultadoMenu.gps() : marcarEnMapa = false, lugar = null;
  const _ResultadoMenu.mapa() : marcarEnMapa = true, lugar = null;
  const _ResultadoMenu.lugar(this.lugar) : marcarEnMapa = false;

  final bool marcarEnMapa;
  final Lugar? lugar;
}

class _MenuLugar extends StatefulWidget {
  const _MenuLugar({required this.titulo, required this.gpsDisponible});

  final String titulo;
  final bool gpsDisponible;

  @override
  State<_MenuLugar> createState() => _MenuLugarState();
}

class _MenuLugarState extends State<_MenuLugar> {
  final _texto = TextEditingController();
  final _buscador = BuscadorLugares();
  List<Lugar> _lugares = lugaresSantaCruz.take(5).toList();
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  void _buscar(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () async {
      final lugares = await _buscador.buscar(texto);
      if (!mounted) return;
      setState(() => _lugares = lugares);
    });
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + teclado),
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: ColoresKufi.superficie3, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 8),
        _opcion(
          icono: Icons.my_location,
          color: ColoresKufi.verde,
          titulo: 'Usar mi ubicación actual',
          detalle: widget.gpsDisponible ? 'El GPS de este teléfono' : 'Si no hay GPS, te llevamos a marcar en el mapa',
          onTap: () => Navigator.pop(context, const _ResultadoMenu.gps()),
        ),
        const SizedBox(height: 8),
        _opcion(
          icono: Icons.map_outlined,
          color: widget.titulo == 'Origen' ? ColoresKufi.verde : const Color(0xFFE23B3B),
          titulo: 'Marcar en el mapa',
          detalle: widget.titulo == 'Origen' ? 'Tocá el punto verde de salida' : 'Tocá el punto rojo de llegada',
          onTap: () => Navigator.pop(context, const _ResultadoMenu.mapa()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _texto,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscá un lugar',
            border: OutlineInputBorder(),
          ),
          onChanged: _buscar,
        ),
        for (final lugar in _lugares.take(4))
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(lugar.nombre),
            subtitle: Text(lugar.detalle),
            onTap: () => Navigator.pop(context, _ResultadoMenu.lugar(lugar)),
          ),
      ],
    );
  }

  Widget _opcion({
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF6F6F6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color, child: Icon(icono, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(detalle, style: const TextStyle(color: ColoresKufi.textoSuave)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
