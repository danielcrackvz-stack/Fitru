import 'package:flutter/material.dart';

import '../widgets.dart';

const avisoBorrador =
    'BORRADOR para revisión de un abogado. No es asesoría legal. Subí todavía no está autorizado por la ASFI ni mueve dinero real: la recarga y los pasajes de esta versión son una simulación.';

const textoTerminos =
    '''
$avisoBorrador

1. Subí es una billetera de demostración para pagar trufis y minibuses en Santa Cruz de la Sierra. Los montos que ves no salen de un banco ni de una entidad de intermediación financiera.

2. Si en el futuro Subí custodiara dinero de otras personas, tendría que cumplir la Ley 393 de servicios financieros y obtener autorización de la ASFI antes de operar. Hasta ese día, no debe usarse como medio de pago real.

3. El pasaje se confirma en tu teléfono. Un cobro repetido con la misma clave no se descuenta dos veces. Las tarifas mostradas (adulto, estudiante, niño y adulto mayor) están por confirmar con cada asociación.

4. Puedes borrar la cuenta desde el perfil. En este teléfono se eliminan tu nombre, teléfono, carnet, PIN y los movimientos locales. El libro del servidor, cuando exista, no se borra: se anonimiza, porque el registro contable es inmutable.

5. Ley 164 de telecomunicaciones y TIC: el servicio se presta por una aplicación móvil. El uso de NFC, Bluetooth y ubicación es opcional y se puede revocar en los permisos.
''';

const textoPrivacidad =
    '''
$avisoBorrador

Responsable: el equipo estudiantil de Subí, en Santa Cruz de la Sierra.

Datos que pedimos: nombre, correo, celular, carnet de identidad, fotos del carnet, PIN (solo como hash con sal en el almacenamiento seguro del teléfono) y, si aceptas, ubicación, Bluetooth y NFC.

Para qué: crear la cuenta, mostrar rutas cerca de ti, cobrar el pasaje y avisarte del saldo. No vendemos estos datos.

Base: tu consentimiento al registrarte y al activar cada permiso. Puedes negarte a la ubicación o al Bluetooth y seguir mirando el mapa con una ubicación de ejemplo.

Conservación: en esta demo los datos viven en el teléfono. Al borrar la cuenta se eliminan de este aparato.

Derechos: puedes pedir el acceso, la corrección o la eliminación desde el perfil o escribiendo a hola@subi.app. Este correo es de contacto de la demo; el mensaje no se envía solo.

La protección de datos personales en Bolivia se interpreta junto con la Constitución y la Ley 164. Un abogado debe cerrar este texto antes de publicar la app.
''';

class PantallaLegal extends StatelessWidget {
  const PantallaLegal({required this.titulo, required this.cuerpo, super.key});

  final String titulo;
  final String cuerpo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BotonAtras(), title: Text(titulo)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(avisoBorrador),
          ),
          Text(cuerpo.replaceFirst('$avisoBorrador\n\n', '')),
        ],
      ),
    );
  }
}
