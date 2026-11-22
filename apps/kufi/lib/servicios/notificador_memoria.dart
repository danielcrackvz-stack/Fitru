import 'notificador.dart';

Notificador crearNotificador() => NotificadorMemoria();

class NotificadorMemoria implements Notificador {
  final List<String> enviados = [];

  @override
  Future<void> iniciar() async {}

  @override
  Future<void> mostrar(String titulo, String cuerpo) async {
    enviados.add('$titulo $cuerpo');
  }
}
