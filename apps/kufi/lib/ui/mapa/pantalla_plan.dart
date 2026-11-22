import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';
import 'package:latlong2/latlong.dart';

import '../../alcance.dart';
import '../../estado/estado_kufi.dart';
import '../../formato.dart';
import '../../servicios/busqueda_lugares.dart';
import '../../servicios/teselas.dart';
import '../../servicios/ubicacion.dart';
import '../../tema.dart';
import '../widgets.dart';

/// Pares del dataset real, los mismos que cubren los tests del planificador.
const _directoA = Coord(-17.79242, -63.18148);
const _directoB = Coord(-17.77468, -63.17862);
const _cambioA = Coord(-17.81137, -63.15961);
const _cambioB = Coord(-17.81689, -63.11577);

class PantallaPlan extends StatefulWidget {
  const PantallaPlan({super.key});

  @override
  State<PantallaPlan> createState() => _PantallaPlanState();
}

class _PantallaPlanState extends State<PantallaPlan> {
  final _origen = TextEditingController(text: 'Mi ubicación');
  final _destino = TextEditingController();
  final _buscador = BuscadorLugares();
  final _teselas = ConfigTeselas.desdeEntorno();
  final _mapa = MapController();
  Coord? _puntoOrigen;
  Coord? _puntoDestino;
  var _origenExplicito = false;
  var _editandoOrigen = false;
  var _radio = 800.0;
  List<Lugar> _sugerencias = const [];
  List<ItinerarioSugerido> _ideas = const [];
  var _elegido = 0;
  Coord? _menu;
  var _eligiendo = false;
  var _eligiendoOrigen = false;
  Coord _centro = centroSantaCruz;
  var _direccionPin = '';
  Timer? _debounce;
  Timer? _geo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final estado = KufiScope.of(context);
      estado.refrescarUbicacion();
      final captura = estado.captura;
      if (captura == 'menu-mapa') {
        setState(() => _menu = centroSantaCruz);
      } else if (captura == 'opciones') {
        _aplicar(_directoA, '1er anillo sur', origen: true);
        _aplicar(_directoB, '1er anillo norte', origen: false);
        _calcular(encuadrar: true);
      } else if (captura == 'transbordo') {
        _aplicar(_cambioA, 'Ramada', origen: true);
        _aplicar(_cambioB, 'Barrio 15 de Mayo', origen: false);
        _calcular(encuadrar: true, preferirTransbordo: true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _geo?.cancel();
    _origen.dispose();
    _destino.dispose();
    _mapa.dispose();
    super.dispose();
  }

  Coord _origenEfectivo(EstadoKufi estado) => _puntoOrigen ?? estado.ubicacion;

  void _aplicar(Coord punto, String nombre, {required bool origen}) {
    setState(() {
      if (origen) {
        _puntoOrigen = punto;
        _origenExplicito = true;
        _origen.text = nombre;
      } else {
        _puntoDestino = punto;
        _destino.text = nombre;
      }
      _sugerencias = const [];
      _menu = null;
    });
  }

  void _calcular({bool encuadrar = false, bool preferirTransbordo = false}) {
    final estado = KufiScope.of(context);
    final destino = _puntoDestino;
    if (destino == null) {
      setState(() => _ideas = const []);
      return;
    }
    final ideas = estado.planificador.proponer(
      origen: _origenEfectivo(estado),
      destino: destino,
      tarifaCentavos: estado.tarifas.montoDe(TipoPasaje.adulto),
      radioAndar: _radio,
    );
    var indice = 0;
    if (preferirTransbordo) {
      final cambio = ideas.indexWhere((idea) => idea.transbordos > 0);
      if (cambio >= 0) indice = cambio;
    }
    setState(() {
      _ideas = ideas;
      _elegido = indice;
    });
    if (ideas.isNotEmpty) {
      estado.elegirItinerario(ideas[indice]);
      if (encuadrar) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _encuadrar(ideas[indice]);
        });
      }
    }
  }

  void _encuadrar(ItinerarioSugerido idea) {
    final puntos = [for (final tramo in idea.tramos) ...tramo.puntos];
    if (puntos.length < 2) return;
    _mapa.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final punto in puntos) LatLng(punto.lat, punto.lon)],
        padding: const EdgeInsets.fromLTRB(36, 210, 36, 280),
        maxZoom: 15,
      ),
    );
  }

  void _buscar(String texto, {required bool origen}) {
    _editandoOrigen = origen;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final lugares = await _buscador.buscar(texto);
      if (!mounted) return;
      setState(() => _sugerencias = lugares);
    });
  }

  void _usarLugar(Lugar lugar) {
    final estado = KufiScope.of(context);
    _aplicar(lugar.punto, lugar.nombre, origen: _editandoOrigen);
    estado.recordarLugar(lugar.nombre, lugar.punto);
    estado.recordarBusqueda(lugar.nombre);
    _calcular(encuadrar: true);
  }

  void _intercambiar(EstadoKufi estado) {
    final destino = _puntoDestino;
    if (destino == null) return;
    final origen = _origenEfectivo(estado);
    final textoOrigen = _origen.text;
    setState(() {
      _puntoOrigen = destino;
      _puntoDestino = origen;
      _origenExplicito = true;
      _origen.text = _destino.text.isEmpty ? 'Destino' : _destino.text;
      _destino.text = textoOrigen.isEmpty ? 'Mi ubicación' : textoOrigen;
    });
    _calcular(encuadrar: true);
  }

  void _mover(Coord actual, Offset delta, void Function(Coord) aplicar) {
    try {
      final pantalla = _mapa.camera.latLngToScreenOffset(LatLng(actual.lat, actual.lon));
      final nuevo = _mapa.camera.screenOffsetToLatLng(pantalla + delta);
      aplicar(Coord(nuevo.latitude, nuevo.longitude));
    } catch (_) {}
  }

  Future<void> _resolverCentro() async {
    final punto = _centro;
    final texto = respaldoDePin(punto);
    if (mounted) setState(() => _direccionPin = texto);
    final calle = await _buscador.direccionDe(punto);
    if (!mounted) return;
    final movido = (_centro.lat - punto.lat).abs() > 0.0002 || (_centro.lon - punto.lon).abs() > 0.0002;
    if (movido) return;
    setState(() => _direccionPin = calle);
  }

  void _programarDireccion() {
    _geo?.cancel();
    _geo = Timer(const Duration(milliseconds: 700), _resolverCentro);
  }

  ItinerarioSugerido? get _idea {
    if (_ideas.isEmpty) return null;
    return _ideas[_elegido.clamp(0, _ideas.length - 1)];
  }

  bool get _hayTrufi => _ideas.any((idea) => idea.tramos.any((tramo) => !tramo.aPie));

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final origen = _origenEfectivo(estado);
    final idea = _idea;
    final saldo = estado.sesion == null ? 0 : estado.saldoDe(estado.sesion!.id);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: LatLng(estado.ubicacion.lat, estado.ubicacion.lon),
              initialZoom: 13,
              minZoom: 11,
              maxZoom: 18,
              backgroundColor: const Color(0xFFE7E2D6),
              onTap: (tap, punto) => setState(() {
                _menu = null;
                _sugerencias = const [];
              }),
              onLongPress: (tap, punto) {
                setState(() => _menu = Coord(punto.latitude, punto.longitude));
              },
              onPositionChanged: (camera, tieneGesto) {
                _centro = Coord(camera.center.latitude, camera.center.longitude);
                if (_eligiendo && tieneGesto) _programarDireccion();
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
              MarkerLayer(markers: _pines(estado, origen)),
              if (idea != null) MarkerLayer(markers: _flechas(idea)),
            ],
          ),
          if (_eligiendo)
            const IgnorePointer(
              child: Center(
                child: Icon(Icons.location_on, size: 46, color: ColoresKufi.verde700),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: SafeArea(child: _tarjeta(estado, saldo)),
          ),
          if (_menu != null)
            Positioned(
              left: 24,
              right: 24,
              top: 230,
              child: _menuEn(_menu!),
            ),
          if (_eligiendo)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _barraPin(),
            )
          else if (_puntoDestino != null)
            DraggableScrollableSheet(
              initialChildSize: _hayTrufi ? 0.42 : 0.28,
              minChildSize: 0.16,
              maxChildSize: 0.78,
              builder: (context, scroll) => _hoja(estado, scroll),
            ),
        ],
      ),
    );
  }

  Widget _tarjeta(EstadoKufi estado, int saldo) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('¿A dónde vas?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const Spacer(),
                InkWell(
                  onTap: () => context.go('/pasajero/recarga'),
                  child: Text(Dinero(saldo).texto, style: const TextStyle(fontWeight: FontWeight.w800, color: ColoresKufi.verde700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _campo(
                        controlador: _origen,
                        icono: Icons.trip_origin,
                        color: ColoresKufi.verde,
                        pista: 'Origen',
                        origen: true,
                      ),
                      _campo(
                        controlador: _destino,
                        icono: Icons.place,
                        color: ColoresKufi.peligro,
                        pista: 'Destino',
                        origen: false,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Intercambiar',
                  onPressed: () => _intercambiar(estado),
                  icon: const Icon(Icons.swap_vert, color: ColoresKufi.verde),
                ),
              ],
            ),
            if (estado.ubicacionEsEjemplo && !_origenExplicito)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Sin GPS: el origen es el centro de Santa Cruz.', style: TextStyle(color: ColoresKufi.textoSuave, fontSize: 12)),
              ),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final etiqueta in const ['Casa', 'Trabajo', 'U'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(etiqueta),
                        avatar: Icon(
                          estado.lugarFijo(etiqueta) == null ? Icons.add_location_alt_outlined : Icons.star,
                          size: 16,
                          color: ColoresKufi.verde,
                        ),
                        onPressed: () => _chipFijo(estado, etiqueta),
                      ),
                    ),
                  for (final reciente in estado.lugaresRecientes.take(4))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(reciente.nombre),
                        onPressed: () {
                          _editandoOrigen = _destino.text.isEmpty;
                          _usarLugar(Lugar(nombre: reciente.nombre, detalle: 'Reciente', punto: reciente.punto));
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_sugerencias.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final lugar in _sugerencias)
                      ListTile(
                        dense: true,
                        title: Text(lugar.nombre),
                        subtitle: Text(lugar.detalle),
                        onTap: () => _usarLugar(lugar),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controlador,
    required IconData icono,
    required Color color,
    required String pista,
    required bool origen,
  }) {
    return Row(
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: controlador,
            decoration: InputDecoration(
              isDense: true,
              hintText: pista,
              border: InputBorder.none,
            ),
            onTap: () => _editandoOrigen = origen,
            onChanged: (texto) {
              if (origen) _origenExplicito = true;
              _buscar(texto, origen: origen);
            },
          ),
        ),
        IconButton(
          tooltip: 'Elegir en el mapa',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            setState(() {
              _eligiendo = true;
              _eligiendoOrigen = origen;
              _sugerencias = const [];
              _menu = null;
              _direccionPin = respaldoDePin(_centro);
            });
            _resolverCentro();
          },
          icon: const Icon(Icons.map_outlined, size: 18),
        ),
      ],
    );
  }

  void _chipFijo(EstadoKufi estado, String etiqueta) {
    final guardado = estado.lugarFijo(etiqueta);
    if (guardado == null) {
      final punto = _editandoOrigen || _puntoDestino == null ? _origenEfectivo(estado) : _puntoDestino!;
      estado.guardarLugarFijo(etiqueta, etiqueta, punto);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$etiqueta quedó guardada. Tocá de nuevo para usarla.')));
      return;
    }
    _editandoOrigen = _destino.text.isEmpty;
    _usarLugar(Lugar(nombre: guardado.nombre, detalle: etiqueta, punto: guardado.punto));
  }

  Widget _menuEn(Coord punto) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.trip_origin, color: ColoresKufi.verde),
            title: const Text('Desde aquí'),
            onTap: () {
              _aplicar(punto, respaldoDePin(punto), origen: true);
              _calcular(encuadrar: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.place, color: ColoresKufi.peligro),
            title: const Text('Hasta aquí'),
            onTap: () {
              _aplicar(punto, respaldoDePin(punto), origen: false);
              _calcular(encuadrar: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _barraPin() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _eligiendoOrigen ? 'Elegí el origen' : 'Elegí el destino',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(_direccionPin.isEmpty ? 'Mové el mapa' : _direccionPin),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Confirmar',
              onPressed: () {
                final punto = _centro;
                final nombre = _direccionPin.isEmpty ? respaldoDePin(punto) : _direccionPin;
                _aplicar(punto, nombre, origen: _eligiendoOrigen);
                setState(() => _eligiendo = false);
                _calcular(encuadrar: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _hoja(EstadoKufi estado, ScrollController scroll) {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      color: Colors.white,
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: ColoresKufi.superficie3, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          if (!_hayTrufi) ...[
            Text(
              'No hay un trufi o micro a menos de ${_radio.round()} m a pie.',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text('Probá otro punto o ampliá la caminata. El mapa no cubre el oeste y el noroeste.'),
            const SizedBox(height: 10),
            if (_radio < 1500)
              BotonKufi(
                texto: 'Ampliar a 1.500 m',
                onPressed: () {
                  _radio = 1500;
                  _calcular(encuadrar: true);
                },
              ),
          ] else
            for (var i = 0; i < _ideas.length; i++)
              if (_ideas[i].tramos.any((tramo) => !tramo.aPie) || _ideas.length == 1)
                _opcion(estado, _ideas[i], i == _elegido, () {
                  setState(() => _elegido = i);
                  estado.elegirItinerario(_ideas[i]);
                  _encuadrar(_ideas[i]);
                }),
        ],
      ),
    );
  }

  Widget _opcion(EstadoKufi estado, ItinerarioSugerido idea, bool activa, VoidCallback alTocar) {
    final rides = idea.tramos.where((tramo) => !tramo.aPie).toList();
    final subida = idea.tramos.first.aPie ? idea.tramos.first : null;
    final bajada = idea.tramos.length > 1 && idea.tramos.last.aPie ? idea.tramos.last : null;
    final idPrimera = rides.isEmpty ? null : rides.first.routeId;
    final primera = idPrimera == null ? null : estado.catalogo.porId(idPrimera);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: activa ? ColoresKufi.menta : ColoresKufi.superficie,
        borderRadius: BorderRadius.circular(16),
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
                  children: [
                    for (final tramo in rides)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colorHex(tramo.colorHex ?? '#009048'),
                        label: Text(
                          tramo.nombre ?? 'Línea',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    Text(idea.titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${idea.minutos.round()} min en total · ${Dinero(idea.centavos).texto}'),
                Text(
                  'Hasta subir ${subida?.metros.round() ?? 0} m (${subida?.minutos.round() ?? 0} min) · '
                  'desde bajar ${bajada?.metros.round() ?? 0} m (${bajada?.minutos.round() ?? 0} min)',
                  style: const TextStyle(color: ColoresKufi.textoSuave),
                ),
                if (rides.isNotEmpty)
                  Text(
                    rides.map((tramo) => tramo.sindicato?.isNotEmpty == true ? '${tramo.operador} · ${tramo.sindicato}' : (tramo.operador ?? '')).where((t) => t.isNotEmpty).join('  ·  '),
                    style: const TextStyle(color: ColoresKufi.textoSuave),
                  ),
                if (activa && primera != null) ...[
                  const SizedBox(height: 8),
                  BotonKufi(
                    texto: 'Pagar al subir',
                    onPressed: () {
                      estado.prepararPago(
                        ruta: primera,
                        sentido: rides.first.sentido ?? 'ida',
                        medio: 'nfc',
                        subtitulo: 'Línea lista al subir',
                      );
                      context.push('/pago/nfc');
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Polyline<Object>> _red(EstadoKufi estado, {required bool atenuar}) {
    final salida = <Polyline<Object>>[];
    for (final ruta in estado.catalogo.rutas) {
      void agregar(TramoRuta? tramo) {
        if (tramo == null || tramo.puntos.length < 2) return;
        salida.add(
          Polyline(
            points: [for (final punto in tramo.puntos) LatLng(punto.lat, punto.lon)],
            strokeWidth: atenuar ? 1.4 : 2.2,
            color: colorHex(ruta.colorHex, atenuar ? 0.12 : 0.45),
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
            strokeWidth: tramo.aPie ? 3 : 6,
            color: tramo.aPie ? const Color(0xFF5E665F) : colorHex(tramo.colorHex ?? '#009048'),
            pattern: tramo.aPie ? StrokePattern.dashed(segments: const [8, 8]) : const StrokePattern.solid(),
          ),
    ];
  }

  List<Marker> _pines(EstadoKufi estado, Coord origen) {
    return [
      _pin(origen, 'A', ColoresKufi.verde, (delta) {
        _mover(origen, delta, (punto) {
          setState(() {
            _puntoOrigen = punto;
            _origenExplicito = true;
            _origen.text = respaldoDePin(punto);
          });
        });
      }, () => _calcular(encuadrar: false)),
      if (_puntoDestino != null)
        _pin(_puntoDestino!, 'B', ColoresKufi.peligro, (delta) {
          final actual = _puntoDestino!;
          _mover(actual, delta, (punto) {
            setState(() {
              _puntoDestino = punto;
              _destino.text = respaldoDePin(punto);
            });
          });
        }, () => _calcular(encuadrar: false)),
    ];
  }

  Marker _pin(Coord punto, String letra, Color color, void Function(Offset delta) alMover, VoidCallback alSoltar) {
    return Marker(
      point: LatLng(punto.lat, punto.lon),
      width: 36,
      height: 36,
      child: GestureDetector(
        onPanUpdate: (detalle) => alMover(detalle.delta),
        onPanEnd: (_) => alSoltar(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(letra, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }

  List<Marker> _flechas(ItinerarioSugerido idea) {
    final marcas = <Marker>[];
    for (final tramo in idea.tramos) {
      if (tramo.aPie || tramo.puntos.length < 2) continue;
      final ultimo = tramo.puntos.length - 1;
      for (final fraccion in const [0.35, 0.7]) {
        final indice = (fraccion * ultimo).floor().clamp(0, ultimo - 1);
        final a = tramo.puntos[indice];
        final b = tramo.puntos[indice + 1];
        final rumbo = math.atan2(b.lon - a.lon, b.lat - a.lat);
        marcas.add(
          Marker(
            point: LatLng(a.lat, a.lon),
            width: 22,
            height: 22,
            child: Transform.rotate(
              angle: rumbo,
              child: const Icon(Icons.navigation, size: 18, color: Colors.white),
            ),
          ),
        );
      }
    }
    return marcas;
  }
}
