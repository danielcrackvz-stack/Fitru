/// Montos en centavos de boliviano. Bs 2,30 se guarda como 230.
class Dinero {
  const Dinero(this.centavos);

  final int centavos;

  static const cero = Dinero(0);

  bool get esNegativo => centavos < 0;

  Dinero operator +(Dinero otro) => Dinero(centavos + otro.centavos);

  Dinero operator -(Dinero otro) => Dinero(centavos - otro.centavos);

  Dinero operator *(int veces) => Dinero(centavos * veces);

  /// Formato boliviano: `Bs 1.234,50`.
  String get texto {
    final negativo = centavos < 0;
    final absoluto = centavos.abs();
    final entero = absoluto ~/ 100;
    final fraccion = (absoluto % 100).toString().padLeft(2, '0');
    final signo = negativo ? '-' : '';
    return '$signo${'Bs'} ${_miles(entero)},$fraccion';
  }

  static String _miles(int valor) {
    final texto = valor.toString();
    final salida = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) {
        salida.write('.');
      }
      salida.write(texto[i]);
    }
    return salida.toString();
  }

  @override
  bool operator ==(Object other) => other is Dinero && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;

  @override
  String toString() => texto;
}

/// Número de operación visible en el comprobante: `KF-261121-0007`.
String numeroDeOperacion(DateTime fecha, int secuencia) {
  final anio = (fecha.year % 100).toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  final serie = secuencia.toString().padLeft(4, '0');
  return 'KF-$anio$mes$dia-$serie';
}
