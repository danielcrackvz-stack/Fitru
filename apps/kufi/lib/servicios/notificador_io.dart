import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notificador.dart';

Notificador crearNotificador() => NotificadorSistema();

class NotificadorSistema implements Notificador {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  var _listo = false;

  @override
  Future<void> iniciar() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      const inicio = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: 'Abrir'),
      );
      await _plugin.initialize(inicio);
      _listo = true;
    } catch (_) {
      _listo = false;
    }
  }

  @override
  Future<void> mostrar(String titulo, String cuerpo) async {
    if (!_listo) return;
    try {
      await _plugin.show(
        cuerpo.hashCode & 0x7fffffff,
        titulo,
        cuerpo,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kufi_pagos',
            'Pagos',
            channelDescription: 'Pagos, recargas y saldo de Subí',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
