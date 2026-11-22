import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUID de demostración. No está registrado en el Bluetooth SIG.
const servicioBleKufi = '6b756669-0000-4000-8000-000000000001';

/// Identificador de fabricante de desarrollo, no asignado por el SIG.
const fabricanteBleKufi = 0xFFF0;

class RadioKufi {
  RadioKufi() : _periferico = FlutterBlePeripheral();

  final FlutterBlePeripheral _periferico;
  var anunciando = false;

  bool get usaHardware {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isAndroid;
  }

  Future<void> anunciar(List<int> datos) async {
    if (!usaHardware) return;
    try {
      await _periferico.start(
        advertiseData: AdvertiseDataCore(
          serviceUuid: servicioBleKufi,
          manufacturerId: fabricanteBleKufi,
          manufacturerData: Uint8List.fromList(datos),
        ),
      );
      anunciando = true;
    } catch (_) {
      anunciando = false;
    }
  }

  Future<void> detener() async {
    if (!anunciando) return;
    try {
      await _periferico.stop();
    } catch (_) {}
    anunciando = false;
  }

  Future<List<({List<int> bytes, int rssi, String id})>> escanear() async {
    if (!usaHardware) return const [];
    final hallados = <String, ({List<int> bytes, int rssi, String id})>{};
    StreamSubscription<List<ScanResult>>? suscripcion;
    try {
      suscripcion = FlutterBluePlus.scanResults.listen((resultados) {
        for (final resultado in resultados) {
          final datos =
              resultado.advertisementData.manufacturerData[fabricanteBleKufi];
          if (datos == null || datos.length < 23) continue;
          final id = resultado.device.remoteId.str;
          final previo = hallados[id];
          if (previo == null || resultado.rssi > previo.rssi) {
            hallados[id] = (bytes: datos, rssi: resultado.rssi, id: id);
          }
        }
      });
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        androidUsesFineLocation: false,
      );
      await Future<void>.delayed(const Duration(seconds: 4));
    } catch (_) {
      return const [];
    } finally {
      await suscripcion?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
    return hallados.values.toList();
  }
}

class NfcKufi {
  static const _canal = MethodChannel('dev.kufi/nfc');

  bool get usaHardware {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isAndroid;
  }

  /// En Android enciende el servicio HCE propio. En otro lado no hace nada.
  Future<bool> empezarEmulacion(String contenido) async {
    if (!usaHardware) return false;
    try {
      final ok = await _canal.invokeMethod<bool>('empezar', {'contenido': contenido});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> detener() async {
    if (!usaHardware) return;
    try {
      await _canal.invokeMethod<void>('detener');
    } catch (_) {}
  }
}
