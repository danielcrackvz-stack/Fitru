import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../alcance.dart';
import '../../estado/estado_kufi.dart';
import '../../formato.dart';
import '../../tema.dart';
import '../formatos_entrada.dart';
import '../pago/pantallas_pago.dart';
import '../widgets.dart';

class PantallaTurno extends StatefulWidget {
  const PantallaTurno({super.key});

  @override
  State<PantallaTurno> createState() => _PantallaTurnoState();
}

class _PantallaTurnoState extends State<PantallaTurno> {
  final _busqueda = TextEditingController();
  final _placa = TextEditingController();
  var _sentido = 'ida';
  String? _rutaId;
  String? _error;

  @override
  void dispose() {
    _busqueda.dispose();
    _placa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final rutas = estado.catalogo.buscar(_busqueda.text);
    final elegida = _rutaId == null ? null : estado.catalogo.porId(_rutaId!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar turno'),
        actions: [
          TextButton(
            onPressed: () => context.go('/pasajero/perfil'),
            child: const Text('Perfil'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Ruta de hoy: Los Piyos, 1er Anillo...',
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final ruta in rutas.take(40))
                  ListTile(
                    selected: ruta.routeId == _rutaId,
                    leading: Icon(
                      Icons.directions_bus,
                      color: colorHex(ruta.colorHex),
                    ),
                    title: Text(ruta.nombreComun),
                    subtitle: Text(
                      '${ruta.etiquetaJurisdiccion} · ${ruta.operador}',
                    ),
                    onTap: () => setState(() => _rutaId = ruta.routeId),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Sentido(
                        texto: 'Ida',
                        activo: _sentido == 'ida',
                        onTap: () => setState(() => _sentido = 'ida'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Sentido(
                        texto: 'Vuelta',
                        activo: _sentido == 'vuelta',
                        onTap: () => setState(() => _sentido = 'vuelta'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _placa,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [formatoPlaca, largoMaximo(10)],
                  decoration: const InputDecoration(
                    labelText: 'Placa del trufi',
                    hintText: '4821KUF',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: ColoresKufi.peligro),
                  ),
                const SizedBox(height: 8),
                BotonKufi(
                  texto: elegida == null
                      ? 'Elige la ruta'
                      : 'Empezar cobro · ${elegida.nombreComun}',
                  onPressed: elegida == null
                      ? null
                      : () {
                          final mensaje = estado.iniciarTurno(
                            elegida,
                            _sentido,
                            _placa.text,
                          );
                          if (mensaje != null) {
                            setState(() => _error = mensaje);
                            return;
                          }
                          context.go('/chofer/cobro');
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sentido extends StatelessWidget {
  const _Sentido({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? ColoresKufi.menta : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activo ? ColoresKufi.verde : ColoresKufi.superficie2,
            ),
          ),
          child: Text(
            texto,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class PantallaCobro extends StatelessWidget {
  const PantallaCobro({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final turno = estado.turno;
    if (turno == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_bus,
                size: 64,
                color: ColoresKufi.verde,
              ),
              const SizedBox(height: 12),
              const Text(
                'Todavía no abriste el turno',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Elige la ruta y el sentido. El celular anuncia el vehículo por Bluetooth y muestra un QR que rota.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              BotonKufi(
                texto: 'Elegir ruta',
                onPressed: () => context.go('/chofer/turno'),
              ),
              const SizedBox(height: 8),
              BotonKufi(
                texto: 'Ver un día de ejemplo',
                contorno: true,
                onPressed: () {
                  estado.cargarJornadaDeEjemplo();
                  context.go('/chofer/cobro');
                },
              ),
            ],
          ),
        ),
      );
    }
    final ruta = estado.catalogo.porId(turno.rutaId);
    final resumen = estado.resumenDelTurno();
    final ultimo = estado.ultimoCobroDelChofer();
    final nombre = ruta?.nombreComun ?? 'Trufi';
    final sentido = turno.sentido == 'vuelta' ? 'Vuelta' : 'Ida';
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              gradient: gradienteVerde,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Kufi Chofer',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/chofer/qr'),
                        icon: const Icon(
                          Icons.directions_bus,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$nombre · $sentido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          turno.pausado ? 'Cobro en pausa' : 'Cobro activo',
                          style: const TextStyle(
                            color: ColoresKufi.verde,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NFC · Bluetooth · QR',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: ColoresKufi.menta,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Text('Pasajeros hoy'),
                      Text(
                        '${resumen.pasajeros}',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        ultimo == null
                            ? 'Aún no entra un pasaje en este turno'
                            : '+${ultimo.pasajeros} en el último cobro',
                        style: const TextStyle(color: ColoresKufi.textoSuave),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Caja(
                        titulo: Dinero(resumen.totalCentavos).texto,
                        detalle: 'Recaudado hoy',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Caja(
                        titulo: '${resumen.pagosPendientes}',
                        detalle: 'Pagos sin conexión',
                        acento: resumen.pagosPendientes > 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Último cobro',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (ultimo == null)
                  const Text('Cuando un pasajero pague, aparece aquí.')
                else
                  Tarjeta(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.check_circle,
                        color: ColoresKufi.verde,
                      ),
                      title: Text(
                        '${TipoPasajeTexto.desdeId(ultimo.tipoPasaje ?? 'adulto').etiqueta} · ${Dinero(ultimo.centavos).texto}',
                      ),
                      subtitle: Text(
                        '${ultimo.medio ?? 'QR'} · ${haceCuanto(ultimo.creadoEn, DateTime.now())}',
                      ),
                      trailing: Text(
                        ultimo.sync == EstadoSync.pendiente
                            ? 'Pendiente'
                            : 'Aprobado',
                        style: const TextStyle(
                          color: ColoresKufi.verde,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                BotonKufi(
                  texto: turno.pausado ? 'Reanudar cobro' : 'Pausar cobro',
                  contorno: true,
                  onPressed: () => estado.pausarTurno(!turno.pausado),
                ),
                const SizedBox(height: 8),
                BotonKufi(
                  texto: 'Cerrar el día',
                  onPressed: () => context.push('/chofer/cierre'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({
    required this.titulo,
    required this.detalle,
    this.acento = false,
  });

  final String titulo;
  final String detalle;
  final bool acento;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresKufi.superficie2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: acento ? ColoresKufi.aviso : Colors.black,
            ),
          ),
          Text(detalle, style: const TextStyle(color: ColoresKufi.textoSuave)),
        ],
      ),
    );
  }
}

class PantallaCierre extends StatelessWidget {
  const PantallaCierre({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final resumen = estado.resumenDelTurno();
    final turnoActual = estado.turno;
    final ruta = turnoActual == null
        ? null
        : estado.catalogo.porId(turnoActual.rutaId);
    final ahora = DateTime.now();
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              gradient: gradienteVerde,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kufi Chofer',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Text(
                    'Cierre del día',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${fechaLarga(ahora)} · ${ruta?.nombreComun ?? 'Sin ruta'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _mini('${resumen.pasajeros}', 'Pasajeros'),
                    _mini('${resumen.viajes}', 'Viajes'),
                    _mini(Dinero(resumen.totalCentavos).texto, 'Total'),
                  ],
                ),
                const SizedBox(height: 12),
                Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          'Detalle por pasaje',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (resumen.porTipo.isEmpty)
                        const Text('Hoy todavía no hay pasajes.'),
                      for (final linea in resumen.porTipo)
                        FilaDato(
                          etiqueta:
                              '${linea.tipo.etiqueta} · ${linea.pasajeros} × ${Dinero(estado.tarifas.montoDe(linea.tipo)).texto}',
                          valor: Dinero(linea.centavos).texto,
                        ),
                      const Divider(),
                      FilaDato(
                        etiqueta: 'Total recaudado',
                        valor: Dinero(resumen.totalCentavos).texto,
                      ),
                    ],
                  ),
                ),
                if (resumen.pagosPendientes > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ColoresKufi.avisoFondo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${resumen.pagosPendientes} pagos (${Dinero(resumen.centavosPendientes).texto}) se enviarán al recuperar conexión',
                      style: const TextStyle(
                        color: ColoresKufi.aviso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'La liquidación se deposita a la Asoc. ${ruta?.operador ?? 'del trufi'} al cerrar el día.',
                  style: const TextStyle(color: ColoresKufi.textoSuave),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                BotonKufi(
                  texto: 'Cerrar día y enviar',
                  onPressed: () {
                    estado.cerrarDia();
                    context.go('/chofer/turno');
                  },
                ),
                const SizedBox(height: 8),
                BotonKufi(
                  texto: 'Ver detalle por viaje',
                  contorno: true,
                  onPressed: () => context.push('/chofer/detalle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String valor, String etiqueta) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(
            etiqueta,
            style: const TextStyle(color: ColoresKufi.textoSuave, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PantallaDetalleChofer extends StatelessWidget {
  const PantallaDetalleChofer({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final desde = estado.turno?.inicio;
    final viajes = estado.libro.movimientos.where((m) {
      if (m.cuentaId != idChoferDemo ||
          m.centavos <= 0 ||
          m.tipo != TipoMovimiento.pasaje)
        return false;
      if (desde != null && m.creadoEn.isBefore(desde)) return false;
      return true;
    }).toList()..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Detalle por viaje'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final viaje in viajes)
            ListTile(
              title: Text(
                '${viaje.nombreRuta ?? 'Trufi'} · ${viaje.pasajeros} pasajero${viaje.pasajeros == 1 ? '' : 's'}',
              ),
              subtitle: Text(
                '${fechaConHora(viaje.creadoEn)} · ${viaje.sync == EstadoSync.pendiente ? 'pendiente' : 'sincronizado'}',
              ),
              trailing: Text(
                Dinero(viaje.centavos).texto,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class PantallaQrChofer extends StatelessWidget {
  const PantallaQrChofer({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('QR del trufi'),
      ),
      body: RelojQr(
        builder: (context, segundos) {
          final token = estado.tokenQrDelTurno();
          if (token == null) {
            return const Center(
              child: Text('Activa el cobro para mostrar el QR.'),
            );
          }
          final codigo = CodigoQrPago.emitir(token);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                token.nombreRuta,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este código está firmado y sirve una sola vez. Cambia solo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: codigo,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cambia en $segundos s',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColoresKufi.textoSuave),
              ),
              const SizedBox(height: 12),
              BotonKufi(
                texto: 'Copiar código',
                contorno: true,
                onPressed: () => copiarTexto(context, codigo),
              ),
            ],
          );
        },
      ),
    );
  }
}
