import 'package:geolocator/geolocator.dart';
import 'package:kufi_core/kufi_core.dart';

/// Centro de Santa Cruz de la Sierra, usado si el permiso no llega.
const centroSantaCruz = Coord(-17.7833, -63.1821);

class ServicioUbicacion {
  const ServicioUbicacion();

  Future<Coord?> actual() async {
    try {
      final activo = await Geolocator.isLocationServiceEnabled();
      if (!activo) return null;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return null;
      }
      final posicion = await Geolocator.getCurrentPosition();
      return Coord(posicion.latitude, posicion.longitude);
    } catch (_) {
      return null;
    }
  }
}
