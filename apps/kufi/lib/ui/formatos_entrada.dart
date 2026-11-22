import 'package:flutter/services.dart';

final formatoNombre = FilteringTextInputFormatter.allow(
  RegExp("[A-Za-zÁÉÍÓÚÜÑáéíóúüñ '\\-]"),
);
final formatoTelefono = FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'));
final formatoCarnet = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9A-Za-z\- ]'),
);
final formatoPlaca = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9A-Za-z\- ]'),
);
final formatoMonto = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
final formatoPin = FilteringTextInputFormatter.digitsOnly;

LengthLimitingTextInputFormatter largoMaximo(int largo) =>
    LengthLimitingTextInputFormatter(largo);
