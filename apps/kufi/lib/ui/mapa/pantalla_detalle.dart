import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';
import 'package:latlong2/latlong.dart';

import '../../alcance.dart';
import '../../formato.dart';
import '../../servicios/teselas.dart';
import '../../tema.dart';
import '../widgets.dart';

class PantallaDetalleRuta extends StatefulWidget {
  const PantallaDetalleRuta({required this.routeId, super.key});

  final String routeId;

  @override
  State<PantallaDetalleRuta> createState() => _PantallaDetalleRutaState();
}

class _PantallaDetalleRutaState extends State<PantallaDetalleRuta> {
  final _mapa = MapController();
  var _sentido = 'ida';
  Timer? _reloj;
  final _teselas = ConfigTeselas.desdeEntorno();

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _mapa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final ruta = estado.catalogo.porId(widget.routeId);
    if (ruta == null) {
      return const Scaffold(body: Center(child: Text('No encontramos esa ruta.')));
    }
    final tramo = ruta.tramo(_sentido) ?? ruta.principal;
    final otro = _sentido == 'ida' ? ruta.vuelta : ruta.ida;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  BotonAtras(onPressed: () => context.pop()),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ruta.nombreComun, style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 230,
            child: FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: tramo == null || tramo.puntos.isEmpty
                    ? const LatLng(-17.78, -63.18)
                    : LatLng(tramo.puntos[tramo.puntos.length ~/ 2].lat, tramo.puntos[tramo.puntos.length ~/ 2].lon),
                initialZoom: 12.5,
                backgroundColor: const Color(0xFFE7E2D6),
              ),
              children: [
                TileLayer(urlTemplate: _teselas.urlPlantilla, userAgentPackageName: _teselas.agente),
                PolylineLayer(
                  polylines: [
                    if (ruta.ida != null)
                      Polyline(
                        points: [for (final p in ruta.ida!.puntos) LatLng(p.lat, p.lon)],
                        strokeWidth: 5,
                        color: colorHex(ruta.colorHex),
                      ),
                    if (ruta.vuelta != null)
                      Polyline(
                        points: [for (final p in ruta.vuelta!.puntos) LatLng(p.lat, p.lon)],
                        strokeWidth: 4,
                        color: colorHex(ruta.colorHex2.isEmpty ? '#F07C00' : ruta.colorHex2),
                        pattern: StrokePattern.dashed(segments: const [10, 8]),
                      ),
                  ],
                ),
                if (tramo != null && tramo.puntos.length > 1)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _bus(tramo),
                        width: 34,
                        height: 34,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(color: ColoresKufi.verde, shape: BoxShape.circle),
                          child: Icon(Icons.directions_bus, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Row(
                  children: [
                    _leyenda(colorHex(ruta.colorHex), 'Ida'),
                    const SizedBox(width: 12),
                    _leyenda(colorHex(ruta.colorHex2.isEmpty ? '#F07C00' : ruta.colorHex2), 'Vuelta'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _sentidoChip(ruta, 'ida', 'Ida · ${ruta.ida?.zonaOrigen ?? ''} → ${ruta.ida?.zonaDestino ?? ''}')),
                    const SizedBox(width: 8),
                    Expanded(child: _sentidoChip(ruta, 'vuelta', 'Vuelta')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _dato(tramo == null ? '—' : kmTexto(tramo.km), 'Distancia'),
                    _dato(tramo == null ? '—' : minTexto(tramo.minutos), 'Tiempo aprox.'),
                    _dato(Dinero(estado.tarifas.montoDe(TipoPasaje.adulto)).texto, 'Pasaje adulto'),
                  ],
                ),
                const Divider(height: 28),
                FilaDato(etiqueta: 'Operador', valor: 'Asoc. ${ruta.operador}'),
                if (otro != null)
                  FilaDato(
                    etiqueta: _sentido == 'ida' ? 'Vuelta' : 'Ida',
                    valor: '${kmTexto(otro.km)} · ${minTexto(otro.minutos)}',
                  ),
                FilaDato(etiqueta: 'Panter', valor: '${ruta.panterVisible} · ${ruta.federacion}'),
                if (ruta.nombreRevisar)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Nombre por confirmar${ruta.motivoRevisar.isEmpty ? '' : ': ${ruta.motivoRevisar}'}.',
                      style: const TextStyle(color: ColoresKufi.aviso),
                    ),
                  ),
                const SizedBox(height: 16),
                BotonKufi(
                  texto: 'Pagar en este trufi',
                  onPressed: () {
                    estado.prepararPago(ruta: ruta, sentido: _sentido, medio: 'nfc');
                    context.push('/pago/nfc');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LatLng _bus(TramoRuta tramo) {
    final punto = posicionSimulada(linea: tramo.puntos, ahora: DateTime.now(), fase: 0.2, vueltasPorHora: 1);
    return LatLng(punto.lat, punto.lon);
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      children: [
        Container(width: 18, height: 4, color: color),
        const SizedBox(width: 6),
        Text(texto),
      ],
    );
  }

  Widget _sentidoChip(RutaTrufi ruta, String sentido, String texto) {
    final activo = _sentido == sentido;
    final existe = ruta.tramo(sentido) != null;
    return InkWell(
      onTap: existe ? () => setState(() => _sentido = sentido) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? ColoresKufi.menta : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo ? ColoresKufi.verde : ColoresKufi.superficie2),
        ),
        child: Text(texto, maxLines: 2, style: TextStyle(fontWeight: activo ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
      ),
    );
  }

  Widget _dato(String valor, String etiqueta) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(etiqueta, style: const TextStyle(color: ColoresKufi.textoSuave, fontSize: 12)),
        ],
      ),
    );
  }
}
