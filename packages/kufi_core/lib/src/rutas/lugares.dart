import '../geo.dart';
import '../texto.dart';

/// Lugar que se puede usar como origen o destino.
class Lugar {
  const Lugar({required this.nombre, required this.detalle, required this.punto, this.enLinea = false});

  final String nombre;
  final String detalle;
  final Coord punto;
  final bool enLinea;
}

/// Puntos públicos de Santa Cruz. No salen de otra app: son referencias conocidas.
const lugaresSantaCruz = <Lugar>[
  Lugar(nombre: 'Plaza 24 de Septiembre', detalle: 'Centro', punto: Coord(-17.7834, -63.1821)),
  Lugar(nombre: 'Catedral Metropolitana', detalle: 'Centro', punto: Coord(-17.7840, -63.1816)),
  Lugar(nombre: 'Mercado Los Pozos', detalle: 'Centro', punto: Coord(-17.7915, -63.1808)),
  Lugar(nombre: 'Mercado La Ramada', detalle: 'Centro norte', punto: Coord(-17.7758, -63.1856)),
  Lugar(nombre: 'Mercado Abasto', detalle: 'Sur', punto: Coord(-17.8148, -63.1675)),
  Lugar(nombre: 'Mercado Mutualista', detalle: '2do anillo', punto: Coord(-17.7922, -63.1910)),
  Lugar(nombre: 'Terminal Bimodal', detalle: '2do anillo', punto: Coord(-17.7848, -63.1974)),
  Lugar(nombre: 'UAGRM', detalle: 'Universidad', punto: Coord(-17.7746, -63.1968)),
  Lugar(nombre: 'UPSA', detalle: 'Universidad', punto: Coord(-17.7468, -63.1855)),
  Lugar(nombre: 'Univalle', detalle: 'Universidad', punto: Coord(-17.7225, -63.1688)),
  Lugar(nombre: 'Cristo Redentor', detalle: '2do anillo', punto: Coord(-17.7586, -63.1818)),
  Lugar(nombre: 'Parque Urbano', detalle: '2do anillo', punto: Coord(-17.7896, -63.1704)),
  Lugar(nombre: 'Ventura Mall', detalle: 'Equipetrol', punto: Coord(-17.7552, -63.1849)),
  Lugar(nombre: '1er Anillo', detalle: 'Anillo', punto: Coord(-17.7834, -63.1821)),
  Lugar(nombre: '2do Anillo', detalle: 'Anillo', punto: Coord(-17.7750, -63.1900)),
  Lugar(nombre: '3er Anillo', detalle: 'Anillo', punto: Coord(-17.7600, -63.1850)),
  Lugar(nombre: '4to Anillo', detalle: 'Anillo', punto: Coord(-17.7400, -63.1750)),
  Lugar(nombre: 'Plan 3000', detalle: 'Este', punto: Coord(-17.8350, -63.1350)),
  Lugar(nombre: 'Aeropuerto Viru Viru', detalle: 'Norte', punto: Coord(-17.6448, -63.1354)),
  Lugar(nombre: 'La Guardia', detalle: 'Sur', punto: Coord(-17.8890, -63.2460)),
  Lugar(nombre: 'Cotoca', detalle: 'Este', punto: Coord(-17.7530, -62.9960)),
];

List<Lugar> buscarLugaresLocales(String consulta, {int limite = 8}) {
  final textos = lugaresSantaCruz.where(
    (lugar) => coincideConsulta(consulta, [lugar.nombre, lugar.detalle]),
  );
  final lista = textos.toList();
  if (lista.length <= limite) return lista;
  return lista.sublist(0, limite);
}
