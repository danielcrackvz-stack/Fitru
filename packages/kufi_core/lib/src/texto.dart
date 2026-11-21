const _sinTilde = <int, String>{
  0x00E1: 'a',
  0x00C1: 'a',
  0x00E0: 'a',
  0x00C0: 'a',
  0x00E4: 'a',
  0x00C4: 'a',
  0x00E2: 'a',
  0x00C2: 'a',
  0x00E3: 'a',
  0x00E9: 'e',
  0x00C9: 'e',
  0x00E8: 'e',
  0x00C8: 'e',
  0x00EB: 'e',
  0x00CB: 'e',
  0x00EA: 'e',
  0x00CA: 'e',
  0x00ED: 'i',
  0x00CD: 'i',
  0x00EC: 'i',
  0x00CC: 'i',
  0x00EF: 'i',
  0x00CF: 'i',
  0x00EE: 'i',
  0x00CE: 'i',
  0x00F3: 'o',
  0x00D3: 'o',
  0x00F2: 'o',
  0x00D2: 'o',
  0x00F6: 'o',
  0x00D6: 'o',
  0x00F4: 'o',
  0x00D4: 'o',
  0x00F5: 'o',
  0x00FA: 'u',
  0x00DA: 'u',
  0x00F9: 'u',
  0x00D9: 'u',
  0x00FC: 'u',
  0x00DC: 'u',
  0x00FB: 'u',
  0x00DB: 'u',
  0x00F1: 'n',
  0x00D1: 'n',
  0x00E7: 'c',
  0x00C7: 'c',
  0x00BA: 'o',
  0x00AA: 'a',
};

/// Minúsculas y sin tildes. «Piyós» y «piyos» coinciden.
String plegar(String texto) {
  final salida = StringBuffer();
  for (final unidad in texto.runes) {
    final reemplazo = _sinTilde[unidad];
    if (reemplazo != null) {
      salida.write(reemplazo);
    } else {
      salida.write(String.fromCharCode(unidad).toLowerCase());
    }
  }
  return salida.toString();
}

/// Todas las palabras de [consulta] deben aparecer en [campos].
bool coincideConsulta(String consulta, List<String> campos) {
  final palabras = plegar(consulta).trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (palabras.isEmpty) return true;
  final blanco = plegar(campos.join(' '));
  for (final palabra in palabras) {
    if (!blanco.contains(palabra)) return false;
  }
  return true;
}

List<List<String>> parsearCsv(String texto) {
  final filas = <List<String>>[];
  final fila = <String>[];
  final actual = StringBuffer();
  var entreComillas = false;

  void cerrarFila() {
    fila.add(actual.toString());
    actual.clear();
    if (fila.any((celda) => celda.isNotEmpty)) {
      filas.add(List<String>.of(fila));
    }
    fila.clear();
  }

  for (var i = 0; i < texto.length; i++) {
    final caracter = texto[i];
    if (entreComillas) {
      if (caracter == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          actual.write('"');
          i++;
        } else {
          entreComillas = false;
        }
      } else {
        actual.write(caracter);
      }
      continue;
    }
    if (caracter == '"') {
      entreComillas = true;
    } else if (caracter == ',') {
      fila.add(actual.toString());
      actual.clear();
    } else if (caracter == '\n') {
      cerrarFila();
    } else if (caracter != '\r') {
      actual.write(caracter);
    }
  }
  if (actual.isNotEmpty || fila.isNotEmpty) {
    cerrarFila();
  }
  return filas;
}
