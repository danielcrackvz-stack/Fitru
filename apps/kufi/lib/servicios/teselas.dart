/// Teselas del mapa. OpenStreetMap público solo para desarrollo.
class ConfigTeselas {
  const ConfigTeselas({
    required this.urlPlantilla,
    required this.atribucion,
    required this.agente,
    required this.esOsmPublico,
  });

  final String urlPlantilla;
  final String atribucion;
  final String agente;
  final bool esOsmPublico;

  static const osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  factory ConfigTeselas.desdeEntorno() {
    const url = String.fromEnvironment('TILE_URL_TEMPLATE', defaultValue: osm);
    const atribucion = String.fromEnvironment(
      'TILE_ATTRIBUTION',
      defaultValue: '© colaboradores de OpenStreetMap',
    );
    return ConfigTeselas(
      urlPlantilla: url,
      atribucion: atribucion,
      agente: 'bo.subi.app',
      esOsmPublico: url.contains('openstreetmap.org'),
    );
  }
}
