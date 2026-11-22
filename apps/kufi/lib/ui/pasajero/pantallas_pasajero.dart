import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kufi_core/kufi_core.dart';

import '../../alcance.dart';
import '../../estado/modelos_app.dart';
import '../../formato.dart';
import '../../tema.dart';
import '../formatos_entrada.dart';
import '../legal/pantalla_legal.dart';
import '../widgets.dart';

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final usuario = estado.sesion;
    final saldo = usuario == null ? 0 : estado.saldoDe(usuario.id);
    final nombre = usuario?.nombre.split(' ').first ?? 'pasajero';
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: const BoxDecoration(
              gradient: gradienteVerde,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Kufi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push('/pasajero/historial'),
                        icon: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '¡Bienvenido, $nombre!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF4F4F4), Color(0xFFC8C8C8)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.contactless,
                              color: ColoresKufi.verde700,
                            ),
                            Spacer(),
                            Text(
                              'KUFI',
                              style: TextStyle(
                                color: ColoresKufi.verde700,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          Dinero(saldo).texto,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'SANTA CRUZ',
                          style: TextStyle(
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: ColoresKufi.verde800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (usuario != null && !usuario.kycListo)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Material(
                color: const Color(0xFFFFF6E8),
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  leading: const Icon(Icons.schedule, color: ColoresKufi.aviso),
                  title: const Text('Carnet en revisión'),
                  subtitle: const Text('Puedes mirar el mapa mientras tanto.'),
                  onTap: () => context.push('/verificacion'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _Accion(
                    icono: Icons.volunteer_activism_outlined,
                    texto: 'Recarga',
                    onTap: () => context.go('/pasajero/recarga'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Accion(
                    icono: Icons.confirmation_number_outlined,
                    texto: 'Pago manual',
                    onTap: () => context.push('/pago/manual'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: BotonKufi(
                    texto: 'Pagar con NFC',
                    onPressed: () => context.push('/pago/nfc'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BotonKufi(
                    texto: 'Bluetooth',
                    contorno: true,
                    onPressed: () => context.push('/pago/ble'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Últimos viajes',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/pasajero/historial'),
                  child: const Text('Ver más'),
                ),
              ],
            ),
          ),
          if (usuario != null)
            for (final movimiento
                in estado
                    .movimientosDe(usuario.id)
                    .where(
                      (m) => m.tipo == TipoMovimiento.pasaje && m.centavos < 0,
                    )
                    .take(3))
              _MovimientoTile(
                movimiento: movimiento,
                onTap: () => context.push('/recibo/${movimiento.pagoId}'),
              ),
        ],
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColoresKufi.superficie2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 32),
              const SizedBox(height: 8),
              Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.movimiento, required this.onTap});

  final Movimiento movimiento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verde = movimiento.centavos < 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: verde ? ColoresKufi.verde : ColoresKufi.verde700,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movimiento.nombreRuta ?? 'Movimiento',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        fechaConHora(movimiento.creadoEn),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Dinero(movimiento.centavos.abs()).texto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key});

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  DateTime? _dia;

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final usuario = estado.sesion;
    final todos = usuario == null
        ? <Movimiento>[]
        : estado.movimientosDe(usuario.id);
    final lista = todos.where((m) {
      if (m.tipo == TipoMovimiento.reverso) return true;
      if (m.centavos > 0 && m.tipo == TipoMovimiento.pasaje) return false;
      if (_dia == null) return true;
      final local = m.creadoEn.toLocal();
      return local.year == _dia!.year &&
          local.month == _dia!.month &&
          local.day == _dia!.day;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Transacciones'),
        actions: [
          IconButton(
            onPressed: () async {
              final elegido = await showDatePicker(
                context: context,
                initialDate: _dia ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                helpText: 'Filtrar por fecha',
              );
              if (elegido != null) setState(() => _dia = elegido);
            },
            icon: const Icon(Icons.calendar_month, color: ColoresKufi.verde),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_dia != null)
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(fechaLarga(_dia!)),
                onDeleted: () => setState(() => _dia = null),
              ),
            ),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Todavía no hay movimientos en esa fecha.'),
              ),
            ),
          for (final movimiento in lista)
            _MovimientoTile(
              movimiento: movimiento,
              onTap: () => context.push('/recibo/${movimiento.pagoId}'),
            ),
        ],
      ),
    );
  }
}

class PantallaRecarga extends StatelessWidget {
  const PantallaRecarga({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final saldo = estado.sesion == null ? 0 : estado.saldoDe(estado.sesion!.id);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SafeArea(
            bottom: false,
            child: Text(
              'Hola, ${estado.sesion?.nombre.split(' ').first ?? 'pasajero'}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF14315C), Color(0xFF1A1F71)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo', style: TextStyle(color: Colors.white70)),
                Text(
                  Dinero(saldo).texto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Billetera Kufi · Santa Cruz',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Recargar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            avisoBorrador,
            style: TextStyle(color: ColoresKufi.textoSuave),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final monto in [1000, 2000, 5000, 10000])
                ActionChip(
                  label: Text(Dinero(monto).texto),
                  onPressed: () => _abrirMetodos(context, monto),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _RecargaLibre(
            alElegir: (centavos) => _abrirMetodos(context, centavos),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirMetodos(BuildContext context, int monto) async {
    final medio = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ColoresKufi.fondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recargar ${Dinero(monto).texto}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Selecciona el método. Nada sale de tu banco: es una simulación.',
            ),
            const SizedBox(height: 12),
            BotonKufi(
              texto: 'Tarjeta',
              onPressed: () => Navigator.pop(context, 'tarjeta'),
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Tigo Money',
              onPressed: () => Navigator.pop(context, 'tigo'),
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'QR de recarga',
              contorno: true,
              onPressed: () => Navigator.pop(context, 'qr'),
            ),
          ],
        ),
      ),
    );
    if (medio == null || !context.mounted) return;
    final mensaje = KufiScope.of(context).recargar(monto, medio);
    if (!context.mounted) return;
    if (mensaje != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
      return;
    }
    context.push('/recibo/ultima');
  }
}

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final usuario = estado.sesion;
    if (usuario == null) return const SizedBox.shrink();
    final chofer = usuario.rol.name == 'chofer';
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const SafeArea(bottom: false, child: SizedBox(height: 8)),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: ColoresKufi.menta,
                child: Text(
                  usuario.nombre.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 24,
                    color: ColoresKufi.verde,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      usuario.telefono,
                      style: const TextStyle(color: ColoresKufi.textoSuave),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notificaciones'),
            subtitle: const Text('Pago, recarga y saldo bajo'),
            value: usuario.notificaciones,
            activeThumbColor: Colors.white,
            activeTrackColor: ColoresKufi.verde,
            onChanged: estado.alternarNotificaciones,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pagar con huella'),
            value: usuario.huella,
            activeThumbColor: Colors.white,
            activeTrackColor: ColoresKufi.verde,
            onChanged: estado.alternarHuella,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simular sin conexión'),
            subtitle: const Text('El pago se guarda y se envía después'),
            value: !estado.enLinea,
            activeThumbColor: Colors.white,
            activeTrackColor: ColoresKufi.aviso,
            onChanged: (valor) => estado.fijarEnLinea(!valor),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simular lector que no responde'),
            value: estado.simularRechazo,
            onChanged: estado.fijarSimularRechazo,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tarifas'),
            subtitle: Text(estado.tarifas.nota),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editarTarifas(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(chofer ? 'Entrar como pasajero' : 'Entrar como chofer'),
            subtitle: Text(
              chofer ? 'Juanito Perez Gonzales' : 'Carlos Mamani · PIN 1234',
            ),
            trailing: const Icon(Icons.swap_horiz),
            onTap: () {
              estado.cambiarA(chofer ? Rol.pasajero : Rol.chofer);
              context.go(chofer ? '/pasajero/inicio' : '/chofer/cobro');
            },
          ),
          if (!usuario.kycListo)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Marcar carnet como verificado'),
              subtitle: const Text('Solo para la demo del equipo'),
              onTap: () => estado.marcarKycListo(true),
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Términos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/terminos'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Política de privacidad'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/privacidad'),
          ),
          BotonKufi(
            texto: 'Borrar cuenta',
            peligro: true,
            onPressed: () async {
              final confirma = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Borrar cuenta'),
                  content: const Text(
                    'Se eliminan de este teléfono tu nombre, carnet, PIN y movimientos. Esta demo no envía el pedido a un servidor.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              );
              if (confirma != true || !context.mounted) return;
              await estado.borrarCuentaActual();
              if (!context.mounted) return;
              context.go('/ingresar');
            },
          ),
          const SizedBox(height: 8),
          BotonKufi(
            texto: 'Cerrar sesión',
            contorno: true,
            onPressed: () {
              estado.cerrarSesion();
              context.go('/ingresar');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editarTarifas(BuildContext context) async {
    final estado = KufiScope.of(context);
    final controles = {
      for (final tarifa in estado.tarifas.tarifas)
        tarifa.tipo: TextEditingController(
          text: (tarifa.centavos / 100).toStringAsFixed(2).replaceAll('.', ','),
        ),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarifas por confirmar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entrada in controles.entries)
              TextField(
                controller: entrada.value,
                decoration: InputDecoration(labelText: entrada.key.etiqueta),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [formatoMonto, largoMaximo(8)],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              for (final entrada in controles.entries) {
                final monto = validarMonto(
                  entrada.value.text,
                  minimoCentavos: 50,
                  maximoCentavos: 5000,
                  etiqueta: entrada.key.etiqueta,
                );
                if (!monto.esValido || monto.centavos == null) continue;
                estado.fijarTarifa(entrada.key, monto.centavos!);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    for (final control in controles.values) {
      control.dispose();
    }
  }
}

class _RecargaLibre extends StatefulWidget {
  const _RecargaLibre({required this.alElegir});

  final void Function(int centavos) alElegir;

  @override
  State<_RecargaLibre> createState() => _RecargaLibreState();
}

class _RecargaLibreState extends State<_RecargaLibre> {
  final _monto = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _monto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [formatoMonto, largoMaximo(8)],
          decoration: const InputDecoration(
            labelText: 'Otro monto',
            hintText: '20,00',
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: ColoresKufi.peligro)),
        const SizedBox(height: 8),
        BotonKufi(
          texto: 'Recargar este monto',
          contorno: true,
          onPressed: () {
            final monto = validarMonto(
              _monto.text,
              minimoCentavos: minimoRecargaCentavos,
              maximoCentavos: maximoRecargaCentavos,
              etiqueta: 'La recarga',
            );
            if (!monto.esValido || monto.centavos == null) {
              setState(() => _error = monto.mensaje);
              return;
            }
            widget.alElegir(monto.centavos!);
          },
        ),
      ],
    );
  }
}
