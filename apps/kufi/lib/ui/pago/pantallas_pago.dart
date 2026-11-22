import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../alcance.dart';
import '../../formato.dart';
import '../../servicios/teselas.dart';
import '../../tema.dart';
import '../widgets.dart';

class PantallaNfc extends StatefulWidget {
  const PantallaNfc({super.key});

  @override
  State<PantallaNfc> createState() => _PantallaNfcState();
}

class _PantallaNfcState extends State<PantallaNfc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final borrador = estado.borrador;
    final monto =
        estado.tarifas.montoDe(borrador?.tipo ?? TipoPasaje.adulto) *
        (borrador?.pasajeros ?? 1);
    final nfc = TransportesDePago.nfc(
      _plataformaNfc(Theme.of(context).platform),
    );
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Pagar con NFC'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(borrador?.nombreRuta ?? 'Elige una ruta'),
                  backgroundColor: ColoresKufi.menta,
                ),
                Chip(
                  label: Text(borrador?.tipo.etiqueta ?? 'Adulto'),
                  backgroundColor: ColoresKufi.menta,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              Dinero(monto).texto,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulso,
                  builder: (context, child) {
                    return Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColoresKufi.menta.withValues(
                          alpha: 0.35 + _pulso.value * 0.25,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(
                      color: ColoresKufi.verde,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contactless,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            const Text(
              'Acerca tu celular',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pon la parte de atrás de tu celular junto al lector del trufi y mantenlo quieto un segundo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresKufi.textoSuave),
            ),
            const SizedBox(height: 6),
            Text(
              nfc.descripcion,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColoresKufi.textoSuave,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text('Saldo disponible: ${Dinero(estado.saldoSesion).texto}'),
            const SizedBox(height: 16),
            BotonKufi(
              texto: 'Ya lo acerqué',
              onPressed: borrador == null
                  ? null
                  : () async {
                      await estado.nfc.empezarEmulacion(borrador.nombreRuta);
                      if (context.mounted) context.push('/pago/confirmar');
                    },
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Pagar con QR o Bluetooth',
              contorno: true,
              onPressed: () => context.push('/pago/ble'),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaBle extends StatelessWidget {
  const PantallaBle({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final anuncios = estado.anunciosVisibles.isEmpty
        ? estado.anunciosDetectados()
        : estado.anunciosVisibles;
    final principal = anuncios.isEmpty ? null : anuncios.first;
    final otros = anuncios.length < 2
        ? const <AnuncioVehiculo>[]
        : anuncios.skip(1).toList();
    final monto = estado.tarifas.montoDe(TipoPasaje.adulto);
    final teselas = ConfigTeselas.desdeEntorno();
    return Scaffold(
      body: Stack(
        children: [
          const _BuscarRadio(),
          Positioned.fill(
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(-17.7833, -63.1821),
                initialZoom: 15,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: teselas.urlPlantilla,
                  userAgentPackageName: teselas.agente,
                ),
              ],
            ),
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0x66000000))),
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: principal == null
                      ? Column(
                          children: [
                            const SizedBox(height: 12),
                            const Icon(
                              Icons.bluetooth_disabled,
                              size: 42,
                              color: ColoresKufi.textoSuave,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No hay un trufi lo bastante cerca',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'El chofer tiene que tener el cobro activo. También puedes pagar con el QR.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            BotonKufi(
                              texto: 'Pagar con QR',
                              onPressed: () => context.push('/pago/qr'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: ColoresKufi.superficie3,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const IconoEnCirculo(
                                  icono: Icons.bluetooth,
                                  tamano: 40,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Trufi detectado',
                                      style: TextStyle(
                                        color: ColoresKufi.verde,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      principal.etiquetaSenal,
                                      style: const TextStyle(
                                        color: ColoresKufi.verde,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              principal.nombreRuta,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontSize: 26),
                            ),
                            Text(
                              '${principal.operador.isEmpty ? '' : 'Asoc. ${principal.operador} · '}${principal.jurisdiccion} · Panter ${principal.panter}',
                            ),
                            const SizedBox(height: 12),
                            FilaDato(
                              etiqueta: 'Pasaje',
                              valor: 'Adulto · ${Dinero(monto).texto}',
                            ),
                            FilaDato(
                              etiqueta: 'Saldo después del pago',
                              valor: Dinero(estado.saldoSesion - monto).texto,
                            ),
                            const SizedBox(height: 8),
                            BotonKufi(
                              texto: 'Confirmar pago ${Dinero(monto).texto}',
                              onPressed: () {
                                final ruta = estado.catalogo.porId(
                                  principal.rutaId,
                                );
                                if (ruta == null) return;
                                estado.prepararPago(
                                  ruta: ruta,
                                  sentido: principal.sentido,
                                  medio: 'ble',
                                  vehiculoId: principal.vehiculoId,
                                  cuentaChoferId: principal.cuentaChoferId,
                                  clave:
                                      'ble-${estado.sesion?.id}-${principal.vehiculoId}-${principal.nonce}',
                                  subtitulo:
                                      'Pago por Bluetooth · Asoc. ${ruta.operador}',
                                );
                                context.push('/pago/confirmar');
                              },
                            ),
                            const SizedBox(height: 8),
                            BotonKufi(
                              texto: 'No es mi trufi',
                              contorno: true,
                              onPressed: otros.isEmpty
                                  ? () => context.push('/pago/qr')
                                  : () {
                                      final siguiente = otros.first;
                                      final ruta = estado.catalogo.porId(
                                        siguiente.rutaId,
                                      );
                                      if (ruta == null) return;
                                      estado.prepararPago(
                                        ruta: ruta,
                                        sentido: siguiente.sentido,
                                        medio: 'ble',
                                        vehiculoId: siguiente.vehiculoId,
                                        cuentaChoferId:
                                            siguiente.cuentaChoferId,
                                        subtitulo:
                                            'Pago por Bluetooth · Asoc. ${ruta.operador}',
                                      );
                                      context.push('/pago/confirmar');
                                    },
                            ),
                            if (otros.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: Text(
                                    'También cerca: ${otros.first.nombreRuta} (${otros.first.etiquetaSenal.toLowerCase()})',
                                    style: const TextStyle(
                                      color: ColoresKufi.textoSuave,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuscarRadio extends StatefulWidget {
  const _BuscarRadio();

  @override
  State<_BuscarRadio> createState() => _BuscarRadioState();
}

class _BuscarRadioState extends State<_BuscarRadio> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) KufiScope.of(context).refrescarRadios();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

PlataformaNfc _plataformaNfc(TargetPlatform plataforma) {
  switch (plataforma) {
    case TargetPlatform.iOS:
      return PlataformaNfc.ios;
    case TargetPlatform.android:
      return PlataformaNfc.android;
    default:
      return PlataformaNfc.otra;
  }
}

class PantallaQrPasajero extends StatefulWidget {
  const PantallaQrPasajero({super.key});

  @override
  State<PantallaQrPasajero> createState() => _PantallaQrPasajeroState();
}

class _PantallaQrPasajeroState extends State<PantallaQrPasajero> {
  final _codigo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _leer(String codigo) {
    final estado = KufiScope.of(context);
    try {
      final token = CodigoQrPago.leer(codigo);
      if (!estado.firmador.verificar(token)) {
        setState(() => _error = 'La firma del QR no es válida.');
        return;
      }
      final ruta = estado.catalogo.porId(token.rutaId);
      if (ruta == null) {
        setState(() => _error = 'Ese QR no corresponde a una ruta cargada.');
        return;
      }
      estado.prepararPago(
        ruta: ruta,
        sentido: token.sentido,
        medio: 'qr',
        vehiculoId: token.vehiculoId,
        cuentaChoferId: token.cuentaChoferId,
        token: token,
        clave: 'qr-${token.id}',
        subtitulo: 'Pago por QR · ${ruta.operador}',
      );
      context.push('/pago/confirmar');
    } on FormatoQrInvalido catch (error) {
      setState(() => _error = error.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final tokenTurno = estado.tokenQrDelTurno();
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Pagar con QR'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pega el código que muestra el chofer o usa el QR del turno abierto en este teléfono.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'kufi://pago/v1/...',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: ColoresKufi.peligro)),
          ],
          const SizedBox(height: 12),
          BotonKufi(texto: 'Leer código', onPressed: () => _leer(_codigo.text)),
          if (tokenTurno != null) ...[
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Usar el QR del chofer en este teléfono',
              contorno: true,
              onPressed: () => _leer(CodigoQrPago.emitir(tokenTurno)),
            ),
          ],
          const SizedBox(height: 16),
          if (estado.borrador != null)
            QrImageView(
              data: 'kufi://billetera/${estado.sesion?.id ?? 'pasajero'}',
              size: 180,
              backgroundColor: Colors.white,
            ),
          const SizedBox(height: 8),
          const Text(
            'También puedes mostrar este QR de tu billetera. El cobro firmado, el que evita el doble cargo, es el que rota en el teléfono del chofer.',
            style: TextStyle(color: ColoresKufi.textoSuave),
          ),
        ],
      ),
    );
  }
}

class PantallaConfirmarPago extends StatefulWidget {
  const PantallaConfirmarPago({super.key});

  @override
  State<PantallaConfirmarPago> createState() => _PantallaConfirmarPagoState();
}

class _PantallaConfirmarPagoState extends State<PantallaConfirmarPago> {
  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final borrador = estado.borrador;
    if (borrador == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar pago')),
        body: const Center(
          child: Text('Elige un trufi en el mapa para pagar.'),
        ),
      );
    }
    final unitario = estado.tarifas.montoDe(borrador.tipo);
    final total = unitario * borrador.pasajeros;
    final despues = estado.saldoSesion - total;
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Confirmar pago'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Tarjeta(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconoEnCirculo(
                icono: Icons.directions_bus,
                tamano: 44,
              ),
              title: Text(
                borrador.nombreRuta,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(borrador.subtitulo),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tipo de pasaje',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final tipo in TipoPasaje.values)
            _OpcionTarifa(
              etiqueta: tipo.etiqueta,
              monto: Dinero(estado.tarifas.montoDe(tipo)).texto,
              activo: borrador.tipo == tipo,
              onTap: () => setState(() => borrador.tipo = tipo),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Pasajeros',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: borrador.pasajeros > 1
                    ? () => setState(() => borrador.pasajeros -= 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                '${borrador.pasajeros}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              IconButton(
                onPressed: borrador.pasajeros < 8
                    ? () => setState(() => borrador.pasajeros += 1)
                    : null,
                icon: const Icon(Icons.add),
                color: ColoresKufi.verde,
              ),
            ],
          ),
          FilaDato(etiqueta: 'Total', valor: Dinero(total).texto),
          FilaDato(
            etiqueta: 'Saldo después del pago',
            valor: Dinero(despues < 0 ? estado.saldoSesion : despues).texto,
            valorColor: despues < 0 ? ColoresKufi.peligro : null,
          ),
          const SizedBox(height: 12),
          BotonKufi(
            texto: 'Pagar ${Dinero(total).texto}',
            onPressed: () async {
              final pin = await pedirPin(
                context,
                huella: estado.sesion?.huella ?? false,
              );
              if (pin == null || !context.mounted) return;
              final mensaje = await estado.confirmarBorrador(
                pin: pin == 'huella' ? null : pin,
              );
              if (!context.mounted) return;
              if (mensaje != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(mensaje)));
                return;
              }
              context.go('/pago/resultado');
            },
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Se confirmará con tu huella o tu PIN',
              style: TextStyle(color: ColoresKufi.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionTarifa extends StatelessWidget {
  const _OpcionTarifa({
    required this.etiqueta,
    required this.monto,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final String monto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: activo ? ColoresKufi.menta : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activo ? ColoresKufi.verde : ColoresKufi.superficie2,
                width: activo ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  activo ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: activo ? ColoresKufi.verde : ColoresKufi.textoSuave,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  monto,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaManual extends StatelessWidget {
  const PantallaManual({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final borrador = estado.borrador?.medio == 'manual'
        ? estado.borrador
        : null;
    final monto = borrador == null
        ? estado.tarifas.montoDe(TipoPasaje.adulto)
        : estado.tarifas.montoDe(borrador.tipo);
    const tonos = [
      ColoresKufi.verde,
      ColoresKufi.verde600,
      ColoresKufi.verde700,
      ColoresKufi.verde800,
    ];
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const BotonAtras(),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Pago manual',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Palmera(alto: 64),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Dinero(monto).texto,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < TipoPasaje.values.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tonos[i],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        estado.prepararManual(TipoPasaje.values[i]),
                    child: Row(
                      children: [
                        Expanded(child: Text(TipoPasaje.values[i].etiqueta)),
                        Text(
                          Dinero(
                            estado.tarifas.montoDe(TipoPasaje.values[i]),
                          ).texto,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            BotonKufi(
              texto: 'Deshacer',
              peligro: true,
              onPressed: () {
                final mensaje = estado.deshacerUltimoManual();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      mensaje ?? 'Listo, devolvimos el último pago manual.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Pagar ${Dinero(monto).texto}',
              onPressed: borrador == null
                  ? null
                  : () async {
                      final pin = await pedirPin(
                        context,
                        huella: estado.sesion?.huella ?? false,
                      );
                      if (pin == null || !context.mounted) return;
                      final mensaje = await estado.confirmarBorrador(
                        pin: pin == 'huella' ? null : pin,
                      );
                      if (!context.mounted) return;
                      if (mensaje != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(mensaje)));
                        return;
                      }
                      context.go('/pago/resultado');
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaResultado extends StatelessWidget {
  const PantallaResultado({super.key});

  @override
  Widget build(BuildContext context) {
    final cobro = KufiScope.of(context).ultimoCobro;
    if (cobro == null) {
      return const Scaffold(
        body: Center(child: Text('No hay un resultado para mostrar.')),
      );
    }
    if (cobro.aceptado && cobro.pendiente) return const _SinConexion();
    if (cobro.aceptado) return const PantallaRecibo(pagoId: 'ultima');
    if (cobro.motivo == MotivoRechazo.saldoInsuficiente)
      return const _SaldoInsuficiente();
    return const _Rechazado();
  }
}

class _SaldoInsuficiente extends StatelessWidget {
  const _SaldoInsuficiente();

  @override
  Widget build(BuildContext context) {
    final cobro = KufiScope.of(context).ultimoCobro!;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            const IconoEnCirculo(
              icono: Icons.account_balance_wallet_outlined,
              fondo: Color(0xFFF8E4E4),
              color: ColoresKufi.peligro,
              tamano: 84,
            ),
            const SizedBox(height: 16),
            const Text(
              'Saldo insuficiente',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu saldo es ${Dinero(cobro.saldoCentavos).texto} y el pasaje cuesta ${Dinero(cobro.montoCentavos).texto}. Recarga para seguir viajando.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresKufi.textoSuave),
            ),
            const SizedBox(height: 16),
            Tarjeta(
              child: Column(
                children: [
                  FilaDato(
                    etiqueta: 'Pasaje',
                    valor: Dinero(cobro.montoCentavos).texto,
                  ),
                  FilaDato(
                    etiqueta: 'Tu saldo',
                    valor: Dinero(cobro.saldoCentavos).texto,
                  ),
                  FilaDato(
                    etiqueta: 'Te falta',
                    valor: Dinero(cobro.faltaCentavos).texto,
                    valorColor: ColoresKufi.peligro,
                  ),
                ],
              ),
            ),
            const Spacer(),
            BotonKufi(
              texto: 'Recargar saldo',
              onPressed: () => context.go('/pasajero/recarga'),
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Volver',
              contorno: true,
              onPressed: () => context.go('/pasajero/inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rechazado extends StatelessWidget {
  const _Rechazado();

  @override
  Widget build(BuildContext context) {
    final cobro = KufiScope.of(context).ultimoCobro!;
    final codigo =
        '${cobro.motivo?.codigo ?? 'K-400'} · ${cobro.motivo?.descripcion ?? 'no se pudo cobrar'}';
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            const IconoEnCirculo(
              icono: Icons.close,
              fondo: Color(0xFFF8E4E4),
              color: ColoresKufi.peligro,
              tamano: 84,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pago rechazado',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'El lector del trufi no confirmó el cobro. No se descontó nada de tu saldo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresKufi.textoSuave),
            ),
            const SizedBox(height: 16),
            Tarjeta(
              child: Column(
                children: [
                  FilaDato(
                    etiqueta: 'Ruta',
                    valor: cobro.nombreRuta ?? 'Trufi',
                  ),
                  FilaDato(etiqueta: 'Hora', valor: horaCorta(cobro.fecha)),
                  FilaDato(etiqueta: 'Código', valor: codigo),
                ],
              ),
            ),
            const Spacer(),
            BotonKufi(
              texto: 'Reintentar',
              onPressed: () => context.push('/pago/confirmar'),
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Pagar con QR',
              contorno: true,
              onPressed: () => context.push('/pago/qr'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinConexion extends StatelessWidget {
  const _SinConexion();

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final cobro = estado.ultimoCobro!;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            const IconoEnCirculo(
              icono: Icons.wifi_off,
              fondo: Color(0xFFFFF3D8),
              color: ColoresKufi.aviso,
              tamano: 84,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin conexión',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu pago se guardó en el celular de forma segura y se enviará cuando vuelvas a tener internet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresKufi.textoSuave),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ColoresKufi.avisoFondo,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${estado.pagosPendientes} pago pendiente de enviar · ${Dinero(cobro.montoCentavos).texto}',
                style: const TextStyle(
                  color: ColoresKufi.aviso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            BotonKufi(
              texto: 'Entendido',
              onPressed: () => context.go('/pasajero/inicio'),
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Ver pagos pendientes',
              contorno: true,
              onPressed: () => context.push('/pasajero/historial'),
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaRecibo extends StatelessWidget {
  const PantallaRecibo({required this.pagoId, super.key});

  final String pagoId;

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final usuario = estado.sesion;
    Movimiento? movimiento;
    if (pagoId != 'ultima' && usuario != null) {
      for (final candidato in estado.movimientosDe(usuario.id)) {
        if (candidato.pagoId == pagoId && candidato.centavos < 0) {
          movimiento = candidato;
          break;
        }
      }
    }
    final cobro = estado.ultimoCobro;
    final monto = movimiento?.centavos.abs() ?? cobro?.montoCentavos ?? 0;
    final fecha = movimiento?.creadoEn ?? cobro?.fecha ?? DateTime.now();
    final ruta = movimiento?.nombreRuta ?? cobro?.nombreRuta ?? 'Recarga';
    final operador = movimiento?.operador ?? cobro?.operador;
    final pasajeros = movimiento?.pasajeros ?? cobro?.pasajeros ?? 1;
    final pasaje = movimiento?.tipo == TipoMovimiento.recarga
        ? 'Recarga'
        : '${movimiento?.tipoPasaje ?? cobro?.tipoPasaje ?? 'Adulto'} × $pasajeros';
    final medio = movimiento?.medio ?? cobro?.medio ?? 'Billetera Subí';
    final numero = movimiento?.numeroOperacion ?? cobro?.numeroOperacion ?? '';
    final saldo = usuario == null ? 0 : estado.saldoDe(usuario.id);
    final vista = UltimoCobroVista(
      titulo: '¡Pago exitoso!',
      monto: monto,
      fecha: fecha,
      ruta: ruta,
      operador: operador == null ? null : 'Asoc. $operador',
      pasaje: pasaje,
      medio: '$medio · Billetera Subí',
      numero: numero,
    );
    return Scaffold(
      appBar: AppBar(
        leading: BotonAtras(onPressed: () => context.go('/pasajero/inicio')),
        title: const Text('Detalle del pago'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            const IconoEnCirculo(icono: Icons.check, tamano: 72),
            const SizedBox(height: 8),
            const Text(
              '¡Pago exitoso!',
              style: TextStyle(
                color: ColoresKufi.verde,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            Text(
              Dinero(monto).texto,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            Text(
              fechaConHora(fecha),
              style: const TextStyle(color: ColoresKufi.textoSuave),
            ),
            const SizedBox(height: 12),
            Tarjeta(
              child: Column(
                children: [
                  FilaDato(etiqueta: 'Ruta', valor: ruta),
                  if (operador != null)
                    FilaDato(etiqueta: 'Operador', valor: 'Asoc. $operador'),
                  FilaDato(etiqueta: 'Pasaje', valor: pasaje),
                  FilaDato(
                    etiqueta: 'Método',
                    valor: '$medio · Billetera Subí',
                  ),
                  FilaDato(
                    etiqueta: 'Saldo después',
                    valor: Dinero(cobro?.saldoCentavos ?? saldo).texto,
                  ),
                  FilaDato(etiqueta: 'N.º de operación', valor: numero),
                ],
              ),
            ),
            const Spacer(),
            BotonKufi(
              texto: 'Compartir comprobante',
              onPressed: () => copiarTexto(context, textoComprobante(vista)),
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Reportar un problema',
              contorno: true,
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reportar un problema'),
                    content: Text(
                      'Cuéntanos qué pasó con la operación $numero. En esta demo el reporte queda en el teléfono.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RelojQr extends StatefulWidget {
  const RelojQr({required this.builder, super.key});

  final Widget Function(BuildContext context, int segundos) builder;

  @override
  State<RelojQr> createState() => _RelojQrState();
}

class _RelojQrState extends State<RelojQr> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, KufiScope.of(context).segundosParaRotarQr());
}
