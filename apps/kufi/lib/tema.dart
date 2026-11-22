import 'package:flutter/material.dart';

class ColoresKufi {
  static const verde = Color(0xFF009048);
  static const verde600 = Color(0xFF006636);
  static const verde700 = Color(0xFF004E2A);
  static const verde800 = Color(0xFF06421E);
  static const verde900 = Color(0xFF00240C);
  static const verdeClaro = Color(0xFF009A4F);
  static const fondo = Color(0xFFFCFCFC);
  static const superficie = Color(0xFFF6F6F6);
  static const superficie2 = Color(0xFFEAEAEA);
  static const superficie3 = Color(0xFFDEDEDE);
  static const borde = Color(0xFFCCCCCC);
  static const palmera = Color(0xFF787E78);
  static const peligroSuave = Color(0xFFE7C8C8);
  static const peligro = Color(0xFFC2413B);
  static const aviso = Color(0xFFB86E00);
  static const avisoFondo = Color(0xFFFFF6E8);
  static const menta = Color(0xFFE7F6EE);
  static const textoSuave = Color(0xFF5E665F);
}

ThemeData temaKufi() {
  const esquema = ColorScheme.light(
    primary: ColoresKufi.verde,
    onPrimary: Colors.white,
    secondary: ColoresKufi.verde600,
    surface: ColoresKufi.fondo,
    onSurface: Colors.black,
    error: ColoresKufi.peligro,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresKufi.fondo,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: Colors.black,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: Colors.black,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: Colors.black,
      ),
      bodyMedium: TextStyle(fontSize: 15, height: 1.35, color: Colors.black),
      bodySmall: TextStyle(fontSize: 13, color: ColoresKufi.textoSuave),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresKufi.fondo,
      foregroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: Colors.black,
      ),
    ),
  );
}

const gradienteVerde = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF009A4F), Color(0xFF01582C)],
);
