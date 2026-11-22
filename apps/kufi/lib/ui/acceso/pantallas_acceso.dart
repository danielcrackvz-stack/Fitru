import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../alcance.dart';
import '../../estado/modelos_app.dart';
import 'package:kufi_core/kufi_core.dart';

import '../../tema.dart';
import '../formatos_entrada.dart';
import '../widgets.dart';

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  final _pagina = PageController();
  var _indice = 0;

  static const _pasos = [
    (
      Icons.map_outlined,
      'Encuentra tu trufi',
      'Busca por zona —1er Anillo, Los Piyos, Monte Carmelo— y mira su recorrido en el mapa.',
    ),
    (
      Icons.contactless,
      'Paga sin efectivo',
      'Acerca tu celular al lector o confirma por Bluetooth. Sin monedas y sin esperar cambio.',
    ),
    (
      Icons.verified_user_outlined,
      'Tu dinero, seguro',
      'Cada pago se confirma con tu PIN o tu huella y queda guardado en tu historial.',
    ),
  ];

  @override
  void dispose() {
    _pagina.dispose();
    super.dispose();
  }

  void _seguir() {
    if (_indice < 2) {
      _pagina.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }
    KufiScope.of(context).terminarOnboarding();
    context.go('/permisos');
  }

  @override
  Widget build(BuildContext context) {
    final paso = _pasos[_indice];
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: gradienteVerde,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(36),
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    const Positioned(
                      left: 8,
                      bottom: 8,
                      child: Palmera(alto: 130),
                    ),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: Palmera(alto: 130, reflejo: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subí',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              KufiScope.of(context).terminarOnboarding();
                              context.go('/permisos');
                            },
                            child: const Text(
                              'Saltar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            paso.$1,
                            color: ColoresKufi.verde,
                            size: 52,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _indice ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _indice
                                ? ColoresKufi.verde
                                : ColoresKufi.superficie3,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: PageView(
                      controller: _pagina,
                      onPageChanged: (valor) => setState(() => _indice = valor),
                      children: [
                        for (final item in _pasos)
                          Column(
                            children: [
                              Text(
                                item.$2,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.$3,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: ColoresKufi.textoSuave),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  BotonKufi(
                    texto: _indice == 2 ? 'Empezar' : 'Siguiente',
                    onPressed: _seguir,
                  ),
                  if (_indice == 2)
                    TextButton(
                      onPressed: () {
                        final estado = KufiScope.of(context);
                        estado.terminarOnboarding();
                        estado.guardarPermisos(
                          nfc: true,
                          ble: true,
                          ubicacion: true,
                          camara: true,
                        );
                        context.go('/ingresar');
                      },
                      child: const Text('¿Ya tienes cuenta? Ingresar'),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PantallaPermisos extends StatefulWidget {
  const PantallaPermisos({super.key});

  @override
  State<PantallaPermisos> createState() => _PantallaPermisosState();
}

class _PantallaPermisosState extends State<PantallaPermisos> {
  var nfc = true;
  var ble = true;
  var ubicacion = true;
  var camara = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activa los permisos',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 8),
              const Text(
                'Subí los usa solo para cobrar tu pasaje y mostrarte las rutas. La ubicación y el Bluetooth son opcionales (Ley 164 y protección de datos). Puedes cambiarlos en Ajustes.',
                style: TextStyle(color: ColoresKufi.textoSuave),
              ),
              const SizedBox(height: 18),
              _Permiso(
                icono: Icons.contactless,
                titulo: 'NFC',
                detalle: 'Para pagar acercando tu celular al lector',
                valor: nfc,
                onChanged: (v) => setState(() => nfc = v),
              ),
              _Permiso(
                icono: Icons.bluetooth,
                titulo: 'Bluetooth',
                detalle: 'Para detectar el trufi en el que vas',
                valor: ble,
                onChanged: (v) => setState(() => ble = v),
              ),
              _Permiso(
                icono: Icons.location_on_outlined,
                titulo: 'Ubicación',
                detalle: 'Para mostrarte las rutas cerca de ti',
                valor: ubicacion,
                onChanged: (v) => setState(() => ubicacion = v),
              ),
              _Permiso(
                icono: Icons.photo_camera_outlined,
                titulo: 'Cámara',
                detalle: 'Para escanear QR y fotografiar tu carnet',
                valor: camara,
                onChanged: (v) => setState(() => camara = v),
              ),
              const Spacer(),
              BotonKufi(
                texto: 'Permitir y continuar',
                onPressed: () {
                  KufiScope.of(context).guardarPermisos(
                    nfc: nfc,
                    ble: ble,
                    ubicacion: ubicacion,
                    camara: camara,
                  );
                  context.go('/ingresar');
                },
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    KufiScope.of(context).guardarPermisos(
                      nfc: false,
                      ble: false,
                      ubicacion: false,
                      camara: false,
                    );
                    context.go('/ingresar');
                  },
                  child: const Text('Ahora no'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Permiso extends StatelessWidget {
  const _Permiso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.onChanged,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresKufi.superficie2),
      ),
      child: Row(
        children: [
          IconoEnCirculo(icono: icono, tamano: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ColoresKufi.textoSuave,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: valor,
            activeThumbColor: Colors.white,
            activeTrackColor: ColoresKufi.verde,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class PantallaIngreso extends StatefulWidget {
  const PantallaIngreso({super.key});

  @override
  State<PantallaIngreso> createState() => _PantallaIngresoState();
}

class _PantallaIngresoState extends State<PantallaIngreso> {
  var _pin = '';
  String? _error;

  Future<void> _entrar() async {
    final estado = KufiScope.of(context);
    final mensaje = await estado.entrar(_pin);
    if (mensaje != null) {
      setState(() => _error = mensaje);
      return;
    }
    if (!mounted) return;
    final rol = estado.sesion?.rol;
    context.go(rol == Rol.chofer ? '/chofer/cobro' : '/pasajero/inicio');
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final chofer = estado.rolEnPuerta == Rol.chofer;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: gradienteVerde,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(48),
                ),
              ),
              child: const SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_bus_filled,
                      color: Colors.white,
                      size: 92,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'SUBÍ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Subí y pagá con un toque',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Column(
                children: [
                  SegmentedButton<Rol>(
                    segments: const [
                      ButtonSegment(
                        value: Rol.pasajero,
                        label: Text('Pasajero'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment(
                        value: Rol.chofer,
                        label: Text('Chofer'),
                        icon: Icon(Icons.directions_bus),
                      ),
                    ],
                    selected: {estado.rolEnPuerta},
                    onSelectionChanged: (valor) =>
                        estado.elegirRolEnPuerta(valor.first),
                  ),
                  const SizedBox(height: 16),
                  CajasCodigo(valor: _pin, largo: 4, ocultar: true),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: ColoresKufi.peligro),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TecladoNumerico(
                    onDigito: (digito) {
                      if (_pin.length >= 4) return;
                      setState(() => _pin += digito);
                    },
                    onBorrar: () {
                      if (_pin.isEmpty) return;
                      setState(() => _pin = _pin.substring(0, _pin.length - 1));
                    },
                  ),
                  const SizedBox(height: 8),
                  BotonKufi(
                    texto: 'Ingresar',
                    onPressed: _pin.length == 4 ? _entrar : null,
                  ),
                  TextButton(
                    onPressed: () => context.push('/recuperar'),
                    child: const Text('¿Olvidaste tu PIN?'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _pin = '1234';
                        _error = null;
                      });
                    },
                    child: Text(
                      chofer
                          ? 'Demo chofer: PIN 1234'
                          : 'Demo pasajero: PIN 1234',
                    ),
                  ),
                  if (!chofer)
                    TextButton(
                      onPressed: () => context.push('/registro'),
                      child: const Text('¿No tienes cuenta? Crear'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _carnet = TextEditingController();
  var _pin = '';
  var _anverso = false;
  var _reverso = false;
  var _aceptoTerminos = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _telefono.dispose();
    _carnet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              children: [
                const SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BotonAtras(),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.pets, color: ColoresKufi.palmera, size: 36),
                Text(
                  'Crear cuenta',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nombre,
                  inputFormatters: [formatoNombre, largoMaximo(maximoNombre)],
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre y apellidos',
                  ),
                ),
                TextField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [largoMaximo(maximoCorreo)],
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                TextField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [formatoTelefono, largoMaximo(14)],
                  decoration: const InputDecoration(
                    labelText: 'Celular',
                    hintText: '7XXXXXXX o +591',
                  ),
                ),
                TextField(
                  controller: _carnet,
                  inputFormatters: [formatoCarnet, largoMaximo(16)],
                  decoration: const InputDecoration(
                    labelText: 'Carnet de identidad',
                    hintText: '1234567-1K SC',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PIN de 4 números',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                CajasCodigo(valor: _pin, largo: 4, ocultar: true),
                TecladoNumerico(
                  onDigito: (d) {
                    if (_pin.length >= 4) return;
                    setState(() => _pin += d);
                  },
                  onBorrar: () {
                    if (_pin.isEmpty) return;
                    setState(() => _pin = _pin.substring(0, _pin.length - 1));
                  },
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Carnet de identidad',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Foto(
                        texto: 'Foto anterior',
                        activo: _anverso,
                        onTap: () => setState(() => _anverso = !_anverso),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Foto(
                        texto: 'Foto posterior',
                        activo: _reverso,
                        onTap: () => setState(() => _reverso = !_reverso),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _aceptoTerminos,
                  onChanged: (valor) =>
                      setState(() => _aceptoTerminos = valor ?? false),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Acepto los '),
                      GestureDetector(
                        onTap: () => context.push('/legal/terminos'),
                        child: const Text(
                          'Términos',
                          style: TextStyle(
                            color: ColoresKufi.verde,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Text(' y la '),
                      GestureDetector(
                        onTap: () => context.push('/legal/privacidad'),
                        child: const Text(
                          'Política de privacidad',
                          style: TextStyle(
                            color: ColoresKufi.verde,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Text(' (borrador).'),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: ColoresKufi.peligro),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: const BoxDecoration(
              gradient: gradienteVerde,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Stack(
              children: [
                const Positioned(left: 0, bottom: 0, child: Palmera(alto: 90)),
                BotonKufi(
                  texto: 'Crear',
                  onPressed: () async {
                    final mensaje = await KufiScope.of(context).registrar(
                      nombre: _nombre.text,
                      correo: _correo.text,
                      telefono: _telefono.text,
                      carnet: _carnet.text,
                      pin: _pin,
                      anverso: _anverso,
                      reverso: _reverso,
                      aceptoTerminos: _aceptoTerminos,
                    );
                    if (!context.mounted) return;
                    if (mensaje != null) {
                      setState(() => _error = mensaje);
                      return;
                    }
                    context.go('/verificacion');
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

class _Foto extends StatelessWidget {
  const _Foto({required this.texto, required this.activo, required this.onTap});

  final String texto;
  final bool activo;
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
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activo ? ColoresKufi.verde : ColoresKufi.borde,
            ),
          ),
          child: Text(
            activo ? '$texto\nlista' : texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: activo ? ColoresKufi.verde : ColoresKufi.textoSuave,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaVerificacion extends StatelessWidget {
  const PantallaVerificacion({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Verificación'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            const IconoEnCirculo(
              icono: Icons.schedule,
              fondo: Color(0xFFFFF3D8),
              color: ColoresKufi.aviso,
              tamano: 84,
            ),
            const SizedBox(height: 16),
            Text(
              'Estamos revisando tu carnet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Suele tardar menos de 24 horas. Te avisaremos cuando tu cuenta esté lista para pagar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresKufi.textoSuave),
            ),
            const SizedBox(height: 16),
            const Tarjeta(
              child: Column(
                children: [
                  _Check(texto: 'Datos personales', listo: true),
                  _Check(
                    texto: 'Foto del carnet (anverso y reverso)',
                    listo: true,
                  ),
                  _Check(
                    texto: 'Revisión del equipo Subí',
                    listo: false,
                    enCurso: true,
                  ),
                  _Check(texto: 'Cuenta habilitada para pagos', listo: false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColoresKufi.menta,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: ColoresKufi.verde),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mientras tanto ya puedes ver las rutas en el mapa.',
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            BotonKufi(
              texto: 'Ir al mapa',
              onPressed: () => context.go('/pasajero/mapa'),
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Contactar soporte',
              contorno: true,
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Soporte Subí'),
                    content: const Text(
                      'Escríbenos a hola@kufi.bo. En esta demo el mensaje no se envía.',
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

class _Check extends StatelessWidget {
  const _Check({
    required this.texto,
    required this.listo,
    this.enCurso = false,
  });

  final String texto;
  final bool listo;
  final bool enCurso;

  @override
  Widget build(BuildContext context) {
    final icono = listo
        ? Icons.check_circle
        : (enCurso ? Icons.schedule : Icons.circle_outlined);
    final color = listo
        ? ColoresKufi.verde
        : (enCurso ? ColoresKufi.aviso : ColoresKufi.superficie3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class PantallaRecuperarPin extends StatefulWidget {
  const PantallaRecuperarPin({super.key});

  @override
  State<PantallaRecuperarPin> createState() => _PantallaRecuperarPinState();
}

class _PantallaRecuperarPinState extends State<PantallaRecuperarPin> {
  var _codigo = '';
  String? _error;

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final usuario = estado.rolEnPuerta == Rol.chofer
        ? estado.cuentaChofer
        : estado.cuentaPasajero;
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Recuperar PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paso 2 de 3',
              style: TextStyle(
                color: ColoresKufi.verde,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el código',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 8),
            Text(
              'Te enviamos un código de 6 dígitos por SMS al ${usuario?.telefonoEnmascarado ?? '+591'}. En esta demo el código es ${estado.codigoSmsDemo}.',
            ),
            const SizedBox(height: 18),
            CajasCodigo(valor: _codigo, largo: 6),
            const SizedBox(height: 8),
            const Text(
              'Reenviar código en 0:42',
              style: TextStyle(color: ColoresKufi.textoSuave),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: ColoresKufi.peligro)),
            const Spacer(),
            TecladoNumerico(
              onDigito: (d) {
                if (_codigo.length >= 6) return;
                setState(() => _codigo += d);
              },
              onBorrar: () {
                if (_codigo.isEmpty) return;
                setState(
                  () => _codigo = _codigo.substring(0, _codigo.length - 1),
                );
              },
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Verificar',
              onPressed: _codigo.length == 6
                  ? () {
                      if (!estado.codigoSmsEsValido(_codigo)) {
                        setState(() => _error = 'Ese código no coincide.');
                        return;
                      }
                      context.go('/nuevo-pin');
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '¿Cambiaste de número? Recupera con tu carnet',
                style: TextStyle(color: ColoresKufi.textoSuave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaNuevoPin extends StatefulWidget {
  const PantallaNuevoPin({super.key});

  @override
  State<PantallaNuevoPin> createState() => _PantallaNuevoPinState();
}

class _PantallaNuevoPinState extends State<PantallaNuevoPin> {
  var _pin = '';
  var _huella = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BotonAtras(),
        title: const Text('Nuevo PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paso 3 de 3',
              style: TextStyle(
                color: ColoresKufi.verde,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu nuevo PIN',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 8),
            const Text('Usa 4 números que no sean tu fecha de nacimiento.'),
            const SizedBox(height: 16),
            Center(child: CajasCodigo(valor: _pin, largo: 4, ocultar: true)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ColoresKufi.superficie2),
              ),
              child: Row(
                children: [
                  const IconoEnCirculo(icono: Icons.fingerprint, tamano: 44),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pagar con huella',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Confirma tus pagos sin escribir el PIN',
                          style: TextStyle(
                            color: ColoresKufi.textoSuave,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _huella,
                    activeThumbColor: Colors.white,
                    activeTrackColor: ColoresKufi.verde,
                    onChanged: (v) => setState(() => _huella = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: ColoresKufi.textoSuave,
                ),
                SizedBox(width: 6),
                Text(
                  'Tu huella nunca sale de tu celular',
                  style: TextStyle(color: ColoresKufi.textoSuave),
                ),
              ],
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: ColoresKufi.peligro)),
            const Spacer(),
            TecladoNumerico(
              onDigito: (d) {
                if (_pin.length >= 4) return;
                setState(() => _pin += d);
              },
              onBorrar: () {
                if (_pin.isEmpty) return;
                setState(() => _pin = _pin.substring(0, _pin.length - 1));
              },
            ),
            const SizedBox(height: 8),
            BotonKufi(
              texto: 'Guardar PIN',
              onPressed: () async {
                final ruta = GoRouter.of(context);
                final mensaje = await KufiScope.of(context).guardarPinNuevo(_pin, huella: _huella);
                if (!mounted) return;
                if (mensaje != null) {
                  setState(() => _error = mensaje);
                  return;
                }
                ruta.go('/ingresar');
              },
            ),
          ],
        ),
      ),
    );
  }
}
