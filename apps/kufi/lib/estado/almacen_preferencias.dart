import 'package:shared_preferences/shared_preferences.dart';

import 'modelos_app.dart';

class AlmacenPreferencias implements AlmacenLocal {
  @override
  Future<String?> leer(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(clave);
  }

  @override
  Future<void> guardar(String clave, String valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(clave, valor);
  }
}
