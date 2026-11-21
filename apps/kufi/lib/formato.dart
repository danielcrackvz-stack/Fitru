import 'package:flutter/material.dart';

const diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String fechaLarga(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = diasSemana[local.weekday - 1];
  final titulo = '${dia[0].toUpperCase()}${dia.substring(1)}';
  return '$titulo ${local.day} ${mesesCortos[local.month - 1]} ${local.year}';
}

String fechaConHora(DateTime fecha) {
  return '${fechaLarga(fecha)} · ${horaCorta(fecha)}';
}

String horaCorta(DateTime fecha) {
  final local = fecha.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String haceCuanto(DateTime fecha, DateTime ahora) {
  final delta = ahora.difference(fecha);
  if (delta.inSeconds < 45) return 'hace un momento';
  if (delta.inMinutes < 60) return 'hace ${delta.inMinutes} min';
  if (delta.inHours < 24) return 'hace ${delta.inHours} h';
  return fechaLarga(fecha);
}

Color colorHex(String hex, [double alpha = 1]) {
  var limpio = hex.trim().replaceAll('#', '');
  if (limpio.isEmpty) limpio = '009048';
  if (limpio.length == 6) limpio = 'FF$limpio';
  final valor = int.tryParse(limpio, radix: 16) ?? 0xFF009048;
  if (alpha >= 1) return Color(valor);
  return Color(valor).withValues(alpha: alpha);
}

String kmTexto(double km) {
  final texto = km.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto km';
}

String minTexto(double minutos) => '${minutos.round()} min';
