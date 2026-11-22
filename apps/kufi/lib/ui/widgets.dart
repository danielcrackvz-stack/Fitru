import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';

import '../alcance.dart';
import '../formato.dart';
import '../tema.dart';

class BotonKufi extends StatelessWidget {
  const BotonKufi({
    required this.texto,
    required this.onPressed,
    this.contorno = false,
    this.peligro = false,
    super.key,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool contorno;
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 16,
    );
    final child = SizedBox(
      width: double.infinity,
      height: 52,
      child: contorno
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresKufi.verde,
                side: const BorderSide(color: ColoresKufi.verde, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: estilo,
              ),
              child: Text(texto),
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: peligro
                    ? ColoresKufi.peligroSuave
                    : ColoresKufi.verde,
                foregroundColor: peligro
                    ? const Color(0xFF5C3030)
                    : Colors.white,
                disabledBackgroundColor: ColoresKufi.superficie3,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: estilo,
              ),
              child: Text(texto),
            ),
    );
    return child;
  }
}

class BotonAtras extends StatelessWidget {
  const BotonAtras({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresKufi.superficie2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back, size: 20),
        ),
      ),
    );
  }
}

class Palmera extends StatelessWidget {
  const Palmera({this.alto = 120, this.reflejo = false, super.key});

  final double alto;
  final bool reflejo;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: reflejo,
      child: CustomPaint(
        size: Size(alto * 0.7, alto),
        painter: _PalmeraPainter(),
      ),
    );
  }
}

class _PalmeraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = ColoresKufi.palmera.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final tronco = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.72),
        width: size.width * 0.08,
        height: size.height * 0.5,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(tronco, pincel);
    final origen = Offset(size.width * 0.5, size.height * 0.48);
    for (var i = -3; i <= 3; i++) {
      canvas.save();
      canvas.translate(origen.dx, origen.dy);
      canvas.rotate(i * 0.38);
      final hoja = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
          size.width * 0.22,
          -size.height * 0.05,
          size.width * 0.02,
          -size.height * 0.42,
        )
        ..quadraticBezierTo(-size.width * 0.08, -size.height * 0.12, 0, 2)
        ..close();
      canvas.drawPath(hoja, pincel);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CajasCodigo extends StatelessWidget {
  const CajasCodigo({
    required this.valor,
    required this.largo,
    this.ocultar = false,
    super.key,
  });

  final String valor;
  final int largo;
  final bool ocultar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < largo; i++)
          Container(
            width: largo > 4 ? 44 : 56,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColoresKufi.superficie3.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: i == valor.length
                    ? ColoresKufi.verde
                    : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Text(
              i < valor.length ? (ocultar ? '•' : valor[i]) : '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class TecladoNumerico extends StatelessWidget {
  const TecladoNumerico({
    required this.onDigito,
    required this.onBorrar,
    super.key,
  });

  final ValueChanged<String> onDigito;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    const filas = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'borrar'],
    ];
    return Column(
      children: [
        for (final fila in filas)
          Row(
            children: [
              for (final tecla in fila)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: tecla.isEmpty
                        ? const SizedBox(height: 56)
                        : Material(
                            color: ColoresKufi.superficie,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                if (tecla == 'borrar') {
                                  onBorrar();
                                } else {
                                  onDigito(tecla);
                                }
                              },
                              child: SizedBox(
                                height: 56,
                                child: Center(
                                  child: tecla == 'borrar'
                                      ? const Icon(Icons.backspace_outlined)
                                      : Text(
                                          tecla,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class FilaDato extends StatelessWidget {
  const FilaDato({
    required this.etiqueta,
    required this.valor,
    this.valorColor,
    super.key,
  });

  final String etiqueta;
  final String valor;
  final Color? valorColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(color: ColoresKufi.textoSuave),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: valorColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Tarjeta extends StatelessWidget {
  const Tarjeta({required this.child, this.color, this.margen, super.key});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? margen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margen,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresKufi.superficie2),
      ),
      child: child,
    );
  }
}

class BannerKufi extends StatelessWidget {
  const BannerKufi({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final aviso = estado.banner;
    if (aviso == null) return const SizedBox.shrink();
    final esError = aviso.tipo.contains('rechaz') || aviso.tipo == 'saldo_bajo';
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: esError ? const Color(0xFFFFF1F0) : ColoresKufi.menta,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: estado.cerrarBanner,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      esError ? Icons.error_outline : Icons.check_circle,
                      color: esError ? ColoresKufi.peligro : ColoresKufi.verde,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            aviso.titulo,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            aviso.cuerpo,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CascaronPasajero extends StatelessWidget {
  const CascaronPasajero({required this.child, required this.ruta, super.key});

  final Widget child;
  final String ruta;

  int get _indice {
    if (ruta.contains('/mapa')) return 1;
    if (ruta.contains('/recarga')) return 2;
    if (ruta.contains('/perfil')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: ColoresKufi.menta,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (indice) {
          const destinos = [
            '/pasajero/inicio',
            '/pasajero/mapa',
            '/pasajero/recarga',
            '/pasajero/perfil',
          ];
          context.go(destinos[indice]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Viaje',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Recarga',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

Future<String?> pedirPin(BuildContext context, {required bool huella}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColoresKufi.fondo,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _HojaPin(huella: huella),
  );
}

class _HojaPin extends StatefulWidget {
  const _HojaPin({required this.huella});

  final bool huella;

  @override
  State<_HojaPin> createState() => _HojaPinState();
}

class _HojaPinState extends State<_HojaPin> {
  var _pin = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColoresKufi.superficie3,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.huella ? 'Confirma el pago' : 'Escribe tu PIN',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.huella
                ? 'Puedes usar la huella de este teléfono o el PIN.'
                : 'Así nadie paga con tu celular.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (widget.huella) ...[
            BotonKufi(
              texto: 'Usar huella',
              onPressed: () => Navigator.pop(context, 'huella'),
            ),
            const SizedBox(height: 8),
          ],
          CajasCodigo(valor: _pin, largo: 4, ocultar: true),
          const SizedBox(height: 8),
          TecladoNumerico(
            onDigito: (d) {
              if (_pin.length >= 4) return;
              setState(() => _pin += d);
              if (_pin.length == 4) Navigator.pop(context, _pin);
            },
            onBorrar: () {
              if (_pin.isEmpty) return;
              setState(() => _pin = _pin.substring(0, _pin.length - 1));
            },
          ),
        ],
      ),
    );
  }
}

class IconoEnCirculo extends StatelessWidget {
  const IconoEnCirculo({
    required this.icono,
    this.fondo,
    this.color,
    this.tamano = 72,
    super.key,
  });

  final IconData icono;
  final Color? fondo;
  final Color? color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo ?? ColoresKufi.menta,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icono,
        color: color ?? ColoresKufi.verde,
        size: tamano * 0.42,
      ),
    );
  }
}

String textoComprobante(UltimoCobroVista vista) {
  return [
    'Subí · comprobante',
    vista.titulo,
    Dinero(vista.monto).texto,
    if (vista.fecha != null) fechaConHora(vista.fecha!),
    if (vista.ruta != null) 'Ruta: ${vista.ruta}',
    if (vista.operador != null) 'Operador: ${vista.operador}',
    if (vista.pasaje != null) 'Pasaje: ${vista.pasaje}',
    if (vista.medio != null) 'Método: ${vista.medio}',
    if (vista.numero != null) 'N.º ${vista.numero}',
  ].join('\n');
}

class UltimoCobroVista {
  const UltimoCobroVista({
    required this.titulo,
    required this.monto,
    this.fecha,
    this.ruta,
    this.operador,
    this.pasaje,
    this.medio,
    this.numero,
  });

  final String titulo;
  final int monto;
  final DateTime? fecha;
  final String? ruta;
  final String? operador;
  final String? pasaje;
  final String? medio;
  final String? numero;
}

Future<void> copiarTexto(BuildContext context, String texto) async {
  await Clipboard.setData(ClipboardData(text: texto));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Comprobante copiado.')));
}
