import 'notificador_memoria.dart'
    if (dart.library.io) 'notificador_io.dart'
    as impl;

abstract class Notificador {
  Future<void> iniciar();
  Future<void> mostrar(String titulo, String cuerpo);
}

Notificador crearNotificador() => impl.crearNotificador();

/// Puerta lista para Firebase Cloud Messaging.
/// Sin `FCM_PROJECT_ID` no envía nada: el aviso queda en el teléfono.
class PuertaFcm {
  const PuertaFcm();

  static const proyecto = String.fromEnvironment('FCM_PROJECT_ID');

  bool get configurado => proyecto.isNotEmpty;

  Future<void> encolar({
    required String tipo,
    required String titulo,
    required String cuerpo,
  }) async {
    if (!configurado) return;
    // El backend (cuando exista) publica con Firebase Admin usando este id de proyecto.
    // El cliente no guarda llaves de servidor.
  }
}
