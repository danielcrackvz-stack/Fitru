class ResultadoValidacion {
  const ResultadoValidacion.ok(this.valor) : mensaje = null;

  const ResultadoValidacion.error(this.mensaje) : valor = null;

  final String? valor;
  final String? mensaje;

  bool get esValido => mensaje == null;
}

class ResultadoMonto {
  const ResultadoMonto.ok(this.centavos) : mensaje = null;

  const ResultadoMonto.error(this.mensaje) : centavos = null;

  final int? centavos;
  final String? mensaje;

  bool get esValido => mensaje == null;
}

const int largoPin = 4;
const int minimoNombre = 3;
const int maximoNombre = 80;
const int maximoCorreo = 120;
const int minimoRecargaCentavos = 100;
const int maximoRecargaCentavos = 200000;
const int maximoPasajeCentavos = 2000000;

final _letrasNombre = RegExp(
  r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:[ '\-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$",
);
final _correo = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
final _extensiones = {'LP', 'CB', 'SC', 'OR', 'PT', 'TJ', 'CH', 'BE', 'PD'};

ResultadoValidacion validarNombre(String texto, {String campo = 'El nombre'}) {
  final limpio = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty)
    return ResultadoValidacion.error('$campo es obligatorio.');
  if (limpio.length < minimoNombre) {
    return ResultadoValidacion.error(
        '$campo necesita al menos $minimoNombre letras.');
  }
  if (limpio.length > maximoNombre) {
    return ResultadoValidacion.error(
        '$campo no puede pasar de $maximoNombre caracteres.');
  }
  if (!_letrasNombre.hasMatch(limpio)) {
    return const ResultadoValidacion.error(
      'Usa solo letras, tildes, ñ, espacios, apóstrofo o guion. Sin números ni símbolos.',
    );
  }
  return ResultadoValidacion.ok(limpio);
}

ResultadoValidacion validarTelefonoBolivia(String texto) {
  var limpio = texto.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (limpio.startsWith('+591')) limpio = limpio.substring(4);
  if (limpio.startsWith('591') && limpio.length > 8)
    limpio = limpio.substring(3);
  if (!RegExp(r'^\d+$').hasMatch(limpio)) {
    return const ResultadoValidacion.error('El teléfono solo lleva dígitos.');
  }
  if (limpio.length != 8 ||
      !(limpio.startsWith('6') || limpio.startsWith('7'))) {
    return const ResultadoValidacion.error(
      'El celular boliviano tiene 8 dígitos y empieza en 6 o 7. El +591 es opcional.',
    );
  }
  return ResultadoValidacion.ok(limpio);
}

ResultadoValidacion validarCarnet(String texto) {
  var limpio = texto.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty)
    return const ResultadoValidacion.error('El carnet es obligatorio.');
  final coincidencia =
      RegExp(r'^(\d{5,8})(?:-([0-9A-Z]{1,2}))?(?: ([A-Z]{2}))?$')
          .firstMatch(limpio);
  if (coincidencia == null) {
    return const ResultadoValidacion.error(
      'El carnet es de 5 a 8 dígitos, con complemento opcional (1234567-1K) y extensión (SC, LP, CB…).',
    );
  }
  final extension = coincidencia.group(3);
  if (extension != null && !_extensiones.contains(extension)) {
    return const ResultadoValidacion.error(
        'La extensión departamental no es válida (LP, CB, SC, OR, PT, TJ, CH, BE, PD).');
  }
  final numero = coincidencia.group(1)!;
  final complemento = coincidencia.group(2);
  final normal = StringBuffer(numero);
  if (complemento != null) normal.write('-$complemento');
  if (extension != null) normal.write(' $extension');
  return ResultadoValidacion.ok(normal.toString());
}

ResultadoValidacion validarPinIngreso(String pin) {
  if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
    return const ResultadoValidacion.error('El PIN tiene 4 dígitos.');
  }
  return ResultadoValidacion.ok(pin);
}

ResultadoValidacion validarPinNuevo(String pin) {
  final formato = validarPinIngreso(pin);
  if (!formato.esValido) return formato;
  if (_pinTrivial(pin)) {
    return const ResultadoValidacion.error(
      'Ese PIN es muy fácil (1234, 1111 o una secuencia). Elige otro.',
    );
  }
  return ResultadoValidacion.ok(pin);
}

bool _pinTrivial(String pin) {
  if (RegExp(r'^(\d)\1{3}$').hasMatch(pin)) return true;
  const secuencias = {
    '0123',
    '1234',
    '2345',
    '3456',
    '4567',
    '5678',
    '6789',
    '9876',
    '8765',
    '7654',
    '6543',
    '5432',
    '4321',
    '3210',
  };
  return secuencias.contains(pin);
}

ResultadoValidacion validarCorreo(String texto) {
  final limpio = texto.trim().toLowerCase();
  if (limpio.isEmpty)
    return const ResultadoValidacion.error('El correo es obligatorio.');
  if (limpio.length > maximoCorreo || !_correo.hasMatch(limpio)) {
    return const ResultadoValidacion.error('El correo no parece válido.');
  }
  return ResultadoValidacion.ok(limpio);
}

ResultadoValidacion validarPlacaBolivia(String texto) {
  final limpio = texto.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
  if (limpio.isEmpty)
    return const ResultadoValidacion.error('La placa es obligatoria.');
  final actual = RegExp(r'^\d{4}[A-Z]{3}$');
  final anterior = RegExp(r'^[A-Z]{2,3}\d{3,4}$');
  if (!actual.hasMatch(limpio) && !anterior.hasMatch(limpio)) {
    return const ResultadoValidacion.error(
      'La placa boliviana es 4 números y 3 letras (4821KUF) o el formato anterior (SC1234).',
    );
  }
  return ResultadoValidacion.ok(limpio);
}

ResultadoValidacion validarCodigoSms(String codigo) {
  if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
    return const ResultadoValidacion.error('El código SMS tiene 6 dígitos.');
  }
  return ResultadoValidacion.ok(codigo);
}

ResultadoMonto validarMonto(
  String texto, {
  required int minimoCentavos,
  required int maximoCentavos,
  String etiqueta = 'El monto',
}) {
  final limpio = texto.trim().replaceAll(' ', '');
  if (limpio.isEmpty) return ResultadoMonto.error('$etiqueta es obligatorio.');
  if (limpio.startsWith('-'))
    return ResultadoMonto.error('$etiqueta tiene que ser positivo.');
  final separadores = RegExp(r'[.,]').allMatches(limpio).length;
  if (separadores > 1)
    return ResultadoMonto.error('$etiqueta tiene un solo separador decimal.');
  if (RegExp(r'[.,]\d{3,}').hasMatch(limpio)) {
    return ResultadoMonto.error('$etiqueta acepta como máximo 2 decimales.');
  }
  if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(limpio)) {
    return ResultadoMonto.error('$etiqueta solo lleva números.');
  }
  final normal = limpio.replaceAll(',', '.');
  final valor = double.tryParse(normal);
  if (valor == null) return ResultadoMonto.error('$etiqueta no se pudo leer.');
  final centavos = (valor * 100).round();
  if (centavos < minimoCentavos) {
    return ResultadoMonto.error('$etiqueta es menor al mínimo permitido.');
  }
  if (centavos > maximoCentavos) {
    return ResultadoMonto.error('$etiqueta supera el máximo permitido.');
  }
  return ResultadoMonto.ok(centavos);
}
