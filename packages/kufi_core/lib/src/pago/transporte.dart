enum PlataformaNfc { android, ios, otra }

class TransportePago {
  const TransportePago({
    required this.id,
    required this.nombre,
    required this.funcionaSinHardware,
    required this.descripcion,
  });

  final String id;
  final String nombre;
  final bool funcionaSinHardware;
  final String descripcion;
}

class TransportesDePago {
  const TransportesDePago._();

  static const qr = TransportePago(
    id: 'qr',
    nombre: 'QR dinámico',
    funcionaSinHardware: true,
    descripcion:
        'El chofer muestra un QR firmado que rota. Sirve en cualquier teléfono, con o sin NFC.',
  );

  static const ble = TransportePago(
    id: 'ble',
    nombre: 'Bluetooth',
    funcionaSinHardware: false,
    descripcion:
        'El chofer anuncia el vehículo y la ruta. El pasajero se queda con el de mejor señal.',
  );

  static TransportePago nfc(PlataformaNfc plataforma) {
    if (plataforma == PlataformaNfc.ios) {
      return const TransportePago(
        id: 'nfc',
        nombre: 'NFC',
        funcionaSinHardware: false,
        descripcion:
            'iOS no permite emular una tarjeta (HCE). En iPhone el pasaje se paga con QR o Bluetooth.',
      );
    }
    if (plataforma == PlataformaNfc.android) {
      return const TransportePago(
        id: 'nfc',
        nombre: 'NFC',
        funcionaSinHardware: false,
        descripcion:
            'En Android, HCE es opcional: acerca el celular al lector si el trufi lo tiene. Si no, usa QR.',
      );
    }
    return const TransportePago(
      id: 'nfc',
      nombre: 'NFC',
      funcionaSinHardware: false,
      descripcion: 'Este dispositivo no tiene lector NFC. Usa QR o Bluetooth.',
    );
  }
}
