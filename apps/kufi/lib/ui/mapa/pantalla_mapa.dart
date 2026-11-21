import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';
import 'package:latlong2/latlong.dart';

import '../../alcance.dart';
import '../../estado/estado_kufi.dart';
import '../../formato.dart';
import '../../servicios/teselas.dart';
import '../../tema.dart';
import '../widgets.dart';

class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final _mapa = MapController();
  final _busqueda = TextEditingController();
  final _teselas = ConfigTeselas.desdeEntorno();
  String _filtro = 'todas';
  String? _seleccion;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      KufiScope.of(context).refrescarUbicacion();
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _busqueda.dispose();
    _mapa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final consulta = _busqueda.text.trim();
    final resultados = consulta.isEmpty
        ? const <RutaTrufi>[]
        : estado.catalogo.buscar(consulta, jurisdiccion: _filtro == 'todas' ? null : _filtro);
    final cercanas = estado.catalogo.cercaDe(
      estado.ubicacion,
      jurisdiccion: _filtro == 'todas' ? null : _filtro,
      limite: 8,
    );
    final polilineas = _polilineas(estado);
    return Scaffold(
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
              onTap: (tap, punto) {
                final cercana = estado.catalogo.masCercanaAlToque(
                  Coord(punto.latitude, punto.longitude),
                  jurisdiccion: _filtro == 'todas' ? null : _filtro,
                );
                setState(() => _seleccion = cercana?.ruta.routeId);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _teselas.urlPlantilla,
                userAgentPackageName: _teselas.agente,
                maxZoom: 19,
              ),
              PolylineLayer(polylines: polilineas),
              MarkerLayer(markers: _marcadores(estado)),
            ],
          ),
          Positioned(
            left: 8,
            bottom: 210,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(_teselas.atribucion, style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    child: TextField(
                      controller: _busqueda,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: estado.recordarBusqueda,
                      decoration: InputDecoration(
                        hintText: 'Busca tu zona: Los Piyos, 1er Anillo...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _busqueda.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _busqueda.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ChipFiltro(
                        texto: 'Todas (${estado.catalogo.rutas.length})',
                        activo: _filtro == 'todas',
                        onTap: () => setState(() => _filtro = 'todas'),
                      ),
                      _ChipFiltro(
                        texto: 'Urbanas (${estado.catalogo.urbanas})',
                        activo: _filtro == 'urbano',
                        onTap: () => setState(() => _filtro = 'urbano'),
                      ),
                      _ChipFiltro(
                        texto: 'Intermunicipales (${estado.catalogo.intermunicipales})',
                        activo: _filtro == 'intermunicipal',
                        onTap: () => setState(() => _filtro = 'intermunicipal'),
                      ),
                    ],
                  ),
                  if (_teselas.esOsmPublico)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Teselas de OpenStreetMap solo para desarrollo',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 250,
            child: FloatingActionButton.small(
              heroTag: 'ubicacion',
              backgroundColor: Colors.white,
              foregroundColor: ColoresKufi.verde,
              onPressed: () async {
                await estado.refrescarUbicacion();
                _mapa.move(LatLng(estado.ubicacion.lat, estado.ubicacion.lon), 14);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: 0.18,
            maxChildSize: 0.72,
            builder: (context, scroll) {
              final mostrandoBusqueda = consulta.isNotEmpty;
              return Container(
                decoration: const BoxDecoration(
                  color: ColoresKufi.fondo,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12)],
                ),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: ColoresKufi.superficie3, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          mostrandoBusqueda ? 'Resultados' : 'Rutas que pasan cerca',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/pasajero/buscar'),
                          child: const Text('Ver todas'),
                        ),
                      ],
                    ),
                    if (estado.ubicacionEsEjemplo && !mostrandoBusqueda)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Ubicación de ejemplo: centro de Santa Cruz. Activa el permiso para usar la tuya.',
                          style: TextStyle(fontSize: 12, color: ColoresKufi.textoSuave),
                        ),
                      ),
                    if (mostrandoBusqueda && resultados.isEmpty)
                      const Text('Ninguna ruta coincide. Prueba con la zona, sin tildes también sirve.'),
                    if (mostrandoBusqueda)
                      for (final ruta in resultados.take(12))
                        _FilaRuta(
                          titulo: ruta.nombreComun,
                          detalle: '${ruta.etiquetaJurisdiccion} · ${ruta.zonas}',
                          color: ruta.colorHex,
                          onTap: () => _abrir(ruta),
                        )
                    else
                      for (final cercana in cercanas)
                        _FilaRuta(
                          titulo: cercana.ruta.nombreComun,
                          detalle: '${cercana.ruta.etiquetaJurisdiccion} · ${cercana.distanciaCorta} · ${cercana.ruta.operador}',
                          color: cercana.ruta.colorHex,
                          onTap: () => _abrir(cercana.ruta),
                        ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _abrir(RutaTrufi ruta) {
    setState(() => _seleccion = ruta.routeId);
    final tramo = ruta.principal;
    if (tramo != null && tramo.puntos.isNotEmpty) {
      _mapa.fitCamera(
        CameraFit.coordinates(
          coordinates: [for (final punto in tramo.puntos) LatLng(punto.lat, punto.lon)],
          padding: const EdgeInsets.fromLTRB(32, 120, 32, 280),
          maxZoom: 15,
        ),
      );
    }
    context.push('/ruta/${ruta.routeId}');
  }

  List<Polyline<String>> _polilineas(EstadoKufi estado) {
    final salida = <Polyline<String>>[];
    for (final ruta in estado.catalogo.rutas) {
      if (_filtro == 'urbano' && !ruta.esUrbana) continue;
      if (_filtro == 'intermunicipal' && !ruta.esIntermunicipal) continue;
      final elegida = _seleccion == ruta.routeId;
      final apagada = _seleccion != null && !elegida;
      void agregar(TramoRuta? tramo, {required bool vuelta}) {
        if (tramo == null || tramo.puntos.length < 2) return;
        final colorBase = vuelta
            ? (ruta.colorHex2.isNotEmpty ? ruta.colorHex2 : '#F07C00')
            : ruta.colorHex;
        salida.add(
          Polyline(
            points: [for (final punto in tramo.puntos) LatLng(punto.lat, punto.lon)],
            strokeWidth: elegida ? (vuelta ? 4 : 5) : 2.2,
            color: colorHex(colorBase, apagada ? 0.12 : (elegida ? 0.95 : 0.72)),
            pattern: vuelta ? StrokePattern.dashed(segments: const [10, 8]) : const StrokePattern.solid(),
            hitValue: ruta.routeId,
          ),
        );
      }

      agregar(ruta.ida, vuelta: false);
      agregar(ruta.vuelta, vuelta: true);
    }
    return salida;
  }

  List<Marker> _marcadores(EstadoKufi estado) {
    final ahora = DateTime.now();
    final marcadores = <Marker>[
      Marker(
        point: LatLng(estado.ubicacion.lat, estado.ubicacion.lon),
        width: 22,
        height: 22,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2F6BFF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    ];
    final ids = <String>{
      ?_seleccion,
      for (final cercana in estado.catalogo.cercaDe(estado.ubicacion, limite: 4)) cercana.ruta.routeId,
    };
    var fase = 0.05;
    for (final id in ids) {
      final ruta = estado.catalogo.porId(id);
      final tramo = ruta?.ida ?? ruta?.vuelta;
      if (tramo == null || tramo.puntos.length < 2) continue;
      final posicion = posicionSimulada(linea: tramo.puntos, ahora: ahora, fase: fase, vueltasPorHora: 1.2);
      fase += 0.17;
      marcadores.add(
        Marker(
          point: LatLng(posicion.lat, posicion.lon),
          width: 34,
          height: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ColoresKufi.verde,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.directions_bus, color: Colors.white, size: 18),
          ),
        ),
      );
    }
    return marcadores;
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({required this.texto, required this.activo, required this.onTap});

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: activo ? ColoresKufi.verde : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              texto,
              style: TextStyle(
                color: activo ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaRuta extends StatelessWidget {
  const _FilaRuta({required this.titulo, required this.detalle, required this.color, required this.onTap});

  final String titulo;
  final String detalle;
  final String color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colorHex(color, 0.18),
        child: Icon(Icons.directions_bus, color: colorHex(color)),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detalle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class PantallaBuscar extends StatefulWidget {
  const PantallaBuscar({super.key});

  @override
  State<PantallaBuscar> createState() => _PantallaBuscarState();
}

class _PantallaBuscarState extends State<PantallaBuscar> {
  final _control = TextEditingController(text: 'Trufi');

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final resultados = estado.catalogo.buscar(_control.text);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  const BotonAtras(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _control,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Zona o nombre',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ColoresKufi.verde)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ColoresKufi.verde)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Los trufis se buscan por el nombre de su zona, no por número.',
                  style: TextStyle(color: ColoresKufi.textoSuave),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Text('Resultados', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  for (final ruta in resultados.take(30))
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorHex(ruta.colorHex, 0.18),
                        child: Icon(Icons.directions_bus, color: colorHex(ruta.colorHex)),
                      ),
                      title: Text(ruta.nombreComun, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${ruta.etiquetaJurisdiccion} · ${ruta.zonas}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        estado.recordarBusqueda(_control.text);
                        context.push('/ruta/${ruta.routeId}');
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Text('Búsquedas recientes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final reciente in estado.busquedas.isEmpty ? const ['1er Anillo', '2do Anillo', '4to Anillo'] : estado.busquedas)
                          ActionChip(
                            label: Text(reciente),
                            backgroundColor: ColoresKufi.menta,
                            onPressed: () {
                              _control.text = reciente;
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
