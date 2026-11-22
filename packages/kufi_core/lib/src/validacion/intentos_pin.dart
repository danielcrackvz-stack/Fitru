class ControlIntentosPin {
  ControlIntentosPin(
      {this.fallos = 0,
      this.bloqueadoHasta,
      this.maximos = 5,
      this.bloqueo = const Duration(minutes: 5)});

  int fallos;
  DateTime? bloqueadoHasta;
  final int maximos;
  final Duration bloqueo;

  bool estaBloqueado(DateTime ahora) {
    final hasta = bloqueadoHasta;
    return hasta != null && ahora.isBefore(hasta);
  }

  String? mensajeBloqueo(DateTime ahora) {
    if (!estaBloqueado(ahora)) return null;
    final restante = bloqueadoHasta!.difference(ahora);
    final minutos =
        restante.inMinutes + (restante.inSeconds.remainder(60) > 0 ? 1 : 0);
    return 'Demasiados intentos. Vuelve a probar en $minutos min.';
  }

  /// Devuelve el mensaje de error. Null si todavía no corresponde avisar bloqueo nuevo... siempre hay mensaje.
  String registrarFallo(DateTime ahora) {
    final bloqueoActual = mensajeBloqueo(ahora);
    if (bloqueoActual != null) return bloqueoActual;
    fallos += 1;
    if (fallos >= maximos) {
      fallos = 0;
      bloqueadoHasta = ahora.add(bloqueo);
      return 'Demasiados intentos. La cuenta queda bloqueada ${bloqueo.inMinutes} minutos.';
    }
    final quedan = maximos - fallos;
    return 'PIN incorrecto. Te quedan $quedan intento${quedan == 1 ? '' : 's'}.';
  }

  void registrarAcierto() {
    fallos = 0;
    bloqueadoHasta = null;
  }

  Map<String, dynamic> toJson() => {
        'fallos': fallos,
        'bloqueadoHasta': bloqueadoHasta?.toUtc().toIso8601String(),
      };

  factory ControlIntentosPin.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ControlIntentosPin();
    final hasta = json['bloqueadoHasta'] as String?;
    return ControlIntentosPin(
      fallos: (json['fallos'] as num?)?.toInt() ?? 0,
      bloqueadoHasta: hasta == null ? null : DateTime.parse(hasta),
    );
  }
}
