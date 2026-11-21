import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kufi_core/kufi_core.dart';

import '../servicios/notificador.dart';
import '../servicios/notificador_memoria.dart' show NotificadorMemoria;
import '../servicios/ubicacion.dart';
import 'modelos_app.dart';

const idPasajeroDemo = 'pasajero-demo';
const idChoferDemo = 'chofer-demo';

bool correspondeAvisoSaldoBajo({
  required int antes,
  required int despues,
  required int umbral,
}) {
  return antes >= umbral && despues < umbral;
}

typedef CargadorCatalogo = Future<CatalogoRutas> Function();

class UltimoCobro {
  UltimoCobro({
    required this.aceptado,
    required this.pendiente,
    required this.montoCentavos,
    required this.saldoCentavos,
    required this.fecha,
    this.motivo,
    this.pagoId,
    this.nombreRuta,
    this.operador,
    this.tipoPasaje,
    this.pasajeros = 1,
    this.medio,
    this.numeroOperacion,
  });

  final bool aceptado;
  final bool pendiente;
  final MotivoRechazo? motivo;
  final int montoCentavos;
  final int saldoCentavos;
  final DateTime fecha;
  final String? pagoId;
  final String? nombreRuta;
  final String? operador;
  final String? tipoPasaje;
  final int pasajeros;
  final String? medio;
  final String? numeroOperacion;

  int get faltaCentavos {
    final falta = montoCentavos - saldoCentavos;
    return falta < 0 ? 0 : falta;
  }
}

class EstadoKufi extends ChangeNotifier {
  EstadoKufi({
    required this.almacen,
    required this.cargador,
    Notificador? notificador,
    this.firmador = const FirmadorTokens(secretoDesarrollo),
    this.ubicacionServicio = const ServicioUbicacion(),
  }) : notificador = notificador ?? crearNotificador();

  final AlmacenLocal almacen;
  final CargadorCatalogo cargador;
  final Notificador notificador;
  final FirmadorTokens firmador;
  final ServicioUbicacion ubicacionServicio;
  final PuertaFcm fcm = const PuertaFcm();

  static const _clave = 'kufi.estado.v1';
  static const umbralSaldoBajo = 500;

  CatalogoRutas catalogo = const CatalogoRutas([]);
  LibroMayor libro = LibroMayor();
  TablaTarifas tarifas = TablaTarifas.porDefecto;
  List<Usuario> usuarios = [];
  List<Aviso> avisos = [];
  List<String> busquedas = [];
  Set<String> tokensUsados = {};
  Turno? turno;
  String? sesionId;
  String? cuentaActivaPasajero = idPasajeroDemo;
  String? cuentaActivaChofer = idChoferDemo;
  Rol rolEnPuerta = Rol.pasajero;
  BorradorPago? borrador;
  UltimoCobro? ultimoCobro;
  Aviso? banner;
  Coord ubicacion = centroSantaCruz;
  var ubicacionEsEjemplo = true;
  var onboardingListo = false;
  var permisosVistos = false;
  var permisoNfc = true;
  var permisoBle = true;
  var permisoUbicacion = true;
  var permisoCamara = true;
  var enLinea = true;
  var simularRechazo = false;
  var secuencia = 1;
  var listo = false;
  String? errorCarga;
  String? captura;
  String codigoSmsDemo = '481936';

  late ServicioPagos servicio = ServicioPagos(firmador: firmador, tarifas: tarifas);

  Usuario? get sesion {
    for (final usuario in usuarios) {
      if (usuario.id == sesionId) return usuario;
    }
    return null;
  }

  Usuario? get cuentaPasajero => _usuario(cuentaActivaPasajero);
  Usuario? get cuentaChofer => _usuario(cuentaActivaChofer);

  int saldoDe(String cuentaId) => libro.saldoDe(cuentaId);

  int get saldoSesion => sesion == null ? 0 : libro.saldoDe(sesion!.id);

  List<Movimiento> movimientosDe(String cuentaId) => libro.deCuenta(cuentaId);

  int get pagosPendientes {
    final vistos = <String>{};
    for (final movimiento in libro.movimientos) {
      if (movimiento.sync == EstadoSync.pendiente && movimiento.centavos < 0) {
        vistos.add(movimiento.pagoId);
      }
    }
    return vistos.length;
  }

  /// Para pruebas de widgets: no toca la red ni las preferencias.
  factory EstadoKufi.paraPruebas({CatalogoRutas? catalogo, bool onboardingListo = false}) {
    final estado = EstadoKufi(
      almacen: AlmacenMemoria(),
      cargador: () async => catalogo ?? const CatalogoRutas([]),
      notificador: NotificadorMemoria(),
    );
    estado._sembrar();
    estado.catalogo = catalogo ?? const CatalogoRutas([]);
    estado.onboardingListo = onboardingListo;
    estado.permisosVistos = onboardingListo;
    estado.listo = true;
    return estado;
  }

  Future<void> iniciar() async {
    await notificador.iniciar();
    final crudo = await almacen.leer(_clave);
    if (crudo == null || crudo.isEmpty) {
      _sembrar();
    } else {
      _restaurar(jsonDecode(crudo) as Map<String, dynamic>);
    }
    try {
      catalogo = await cargador();
    } catch (error) {
      errorCarga = '$error';
      catalogo = const CatalogoRutas([]);
    }
    listo = true;
    notifyListeners();
  }

  Usuario? _usuario(String? id) {
    for (final usuario in usuarios) {
      if (usuario.id == id) return usuario;
    }
    return null;
  }

  void _sembrar() {
    usuarios = [
      Usuario(
        id: idPasajeroDemo,
        nombre: 'Juanito Perez Gonzales',
        correo: 'juanito@correo.com',
        telefono: '70123445',
        pinHash: hashPin('1234', idPasajeroDemo),
        rol: Rol.pasajero,
        kycListo: true,
      ),
      Usuario(
        id: idChoferDemo,
        nombre: 'Carlos Mamani',
        correo: 'carlos@lospijos.bo',
        telefono: '71234567',
        pinHash: hashPin('1234', idChoferDemo),
        rol: Rol.chofer,
        kycListo: true,
      ),
    ];
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final anteayer = DateTime.now().subtract(const Duration(days: 2));
    libro = LibroMayor([
      Movimiento(
        id: 'mov-semilla-recarga',
        claveIdempotencia: 'semilla-recarga',
        cuentaId: idPasajeroDemo,
        tipo: TipoMovimiento.recarga,
        centavos: 5460,
        creadoEn: anteayer,
        pagoId: 'recarga-semilla',
        medio: 'tigo',
        numeroOperacion: numeroDeOperacion(anteayer, 1),
        nota: 'Recarga inicial',
      ),
      ..._pasajeSemilla(
        id: 'semilla-1',
        fecha: anteayer.add(const Duration(hours: 3)),
        nombre: '1er Anillo Blanco (ATL)',
        ruta: 'R054',
        operador: 'ATL',
        numero: 2,
      ),
      ..._pasajeSemilla(
        id: 'semilla-2',
        fecha: ayer,
        nombre: 'Trufi Los Piyos Blanco',
        ruta: 'R069',
        operador: 'Los Piyos',
        numero: 3,
      ),
    ]);
    secuencia = 4;
  }

  List<Movimiento> _pasajeSemilla({
    required String id,
    required DateTime fecha,
    required String nombre,
    required String ruta,
    required String operador,
    required int numero,
  }) {
    Movimiento mov(String sufijo, String cuenta, int centavos) {
      return Movimiento(
        id: 'mov-$id-$sufijo',
        claveIdempotencia: '$id:$sufijo',
        cuentaId: cuenta,
        tipo: TipoMovimiento.pasaje,
        centavos: centavos,
        creadoEn: fecha,
        pagoId: id,
        rutaId: ruta,
        nombreRuta: nombre,
        operador: operador,
        tipoPasaje: TipoPasaje.adulto.id,
        pasajeros: 1,
        medio: 'qr',
        sentido: 'ida',
        vehiculoId: 'semilla',
        numeroOperacion: numeroDeOperacion(fecha, numero),
      );
    }

    return [
      mov('debito', idPasajeroDemo, -230),
      mov('credito', idChoferDemo, 230),
    ];
  }

  void _restaurar(Map<String, dynamic> json) {
    onboardingListo = json['onboardingListo'] as bool? ?? false;
    permisosVistos = json['permisosVistos'] as bool? ?? false;
    permisoNfc = json['permisoNfc'] as bool? ?? true;
    permisoBle = json['permisoBle'] as bool? ?? true;
    permisoUbicacion = json['permisoUbicacion'] as bool? ?? true;
    permisoCamara = json['permisoCamara'] as bool? ?? true;
    enLinea = json['enLinea'] as bool? ?? true;
    simularRechazo = json['simularRechazo'] as bool? ?? false;
    secuencia = (json['secuencia'] as num?)?.toInt() ?? 1;
    sesionId = json['sesionId'] as String?;
    cuentaActivaPasajero = json['cuentaActivaPasajero'] as String? ?? idPasajeroDemo;
    cuentaActivaChofer = json['cuentaActivaChofer'] as String? ?? idChoferDemo;
    rolEnPuerta = rolDesde(json['rolEnPuerta'] as String? ?? 'pasajero');
    usuarios = (json['usuarios'] as List<dynamic>? ?? const [])
        .map((e) => Usuario.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    avisos = (json['avisos'] as List<dynamic>? ?? const [])
        .map((e) => Aviso.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    busquedas = (json['busquedas'] as List<dynamic>? ?? const []).map((e) => '$e').toList();
    tokensUsados = (json['tokensUsados'] as List<dynamic>? ?? const []).map((e) => '$e').toSet();
    libro = LibroMayor.fromJson((json['libro'] as Map?)?.cast<String, dynamic>() ?? const {});
    if (json['tarifas'] is Map) {
      tarifas = TablaTarifas.fromJson((json['tarifas'] as Map).cast<String, dynamic>());
      servicio = ServicioPagos(firmador: firmador, tarifas: tarifas);
    }
    final turnoJson = json['turno'];
    turno = turnoJson is Map ? Turno.fromJson(turnoJson.cast<String, dynamic>()) : null;
    if (usuarios.isEmpty) _sembrar();
  }

  Map<String, dynamic> _aJson() => {
        'onboardingListo': onboardingListo,
        'permisosVistos': permisosVistos,
        'permisoNfc': permisoNfc,
        'permisoBle': permisoBle,
        'permisoUbicacion': permisoUbicacion,
        'permisoCamara': permisoCamara,
        'enLinea': enLinea,
        'simularRechazo': simularRechazo,
        'secuencia': secuencia,
        'sesionId': sesionId,
        'cuentaActivaPasajero': cuentaActivaPasajero,
        'cuentaActivaChofer': cuentaActivaChofer,
        'rolEnPuerta': rolEnPuerta.name,
        'usuarios': usuarios.map((u) => u.toJson()).toList(),
        'avisos': avisos.map((a) => a.toJson()).toList(),
        'busquedas': busquedas,
        'tokensUsados': tokensUsados.toList(),
        'libro': libro.toJson(),
        'tarifas': tarifas.toJson(),
        'turno': turno?.toJson(),
      };

  Future<void> _guardar() => almacen.guardar(_clave, jsonEncode(_aJson()));

  void _tocar() {
    notifyListeners();
    _guardar();
  }

  void terminarOnboarding() {
    onboardingListo = true;
    _tocar();
  }

  void guardarPermisos({
    required bool nfc,
    required bool ble,
    required bool ubicacion,
    required bool camara,
  }) {
    permisoNfc = nfc;
    permisoBle = ble;
    permisoUbicacion = ubicacion;
    permisoCamara = camara;
    permisosVistos = true;
    _tocar();
  }

  void elegirRolEnPuerta(Rol rol) {
    rolEnPuerta = rol;
    notifyListeners();
  }

  String? entrar(String pin) {
    final usuario = rolEnPuerta == Rol.chofer ? cuentaChofer : cuentaPasajero;
    if (usuario == null) return 'No hay una cuenta en este teléfono.';
    if (usuario.pinHash != hashPin(pin, usuario.id)) return 'PIN incorrecto.';
    sesionId = usuario.id;
    _tocar();
    return null;
  }

  String? registrar({
    required String nombre,
    required String correo,
    required String telefono,
    required String pin,
    required bool anverso,
    required bool reverso,
  }) {
    if (nombre.trim().length < 3) return 'Escribe tu nombre completo.';
    if (!correo.contains('@')) return 'El correo no parece válido.';
    if (telefono.trim().length < 7) return 'Revisa el teléfono.';
    if (pin.length != 4) return 'El PIN tiene 4 números.';
    if (!anverso || !reverso) return 'Faltan las fotos del carnet.';
    final id = 'u-${DateTime.now().millisecondsSinceEpoch}';
    final usuario = Usuario(
      id: id,
      nombre: nombre.trim(),
      correo: correo.trim(),
      telefono: telefono.trim(),
      pinHash: hashPin(pin, id),
      rol: Rol.pasajero,
      fotoAnverso: anverso,
      fotoReverso: reverso,
    );
    usuarios.add(usuario);
    cuentaActivaPasajero = id;
    sesionId = id;
    rolEnPuerta = Rol.pasajero;
    _tocar();
    return null;
  }

  bool codigoSmsEsValido(String codigo) => codigo == codigoSmsDemo;

  String? guardarPinNuevo(String pin, {required bool huella}) {
    final usuario = rolEnPuerta == Rol.chofer ? cuentaChofer : cuentaPasajero;
    if (usuario == null) return 'No hay cuenta para actualizar.';
    if (pin.length != 4) return 'El PIN tiene 4 números.';
    usuario.pinHash = hashPin(pin, usuario.id);
    usuario.huella = huella;
    _tocar();
    return null;
  }

  void cerrarSesion() {
    sesionId = null;
    _tocar();
  }

  void cambiarA(Rol rol) {
    final usuario = rol == Rol.chofer ? cuentaChofer : cuentaPasajero;
    if (usuario == null) return;
    sesionId = usuario.id;
    rolEnPuerta = rol;
    _tocar();
  }

  void alternarHuella(bool valor) {
    sesion?.huella = valor;
    _tocar();
  }

  void alternarNotificaciones(bool valor) {
    sesion?.notificaciones = valor;
    _tocar();
  }

  void marcarKycListo(bool valor) {
    sesion?.kycListo = valor;
    _tocar();
  }

  void fijarEnLinea(bool valor) {
    enLinea = valor;
    if (valor) {
      libro = libro.sincronizar();
      _avisar(
        tipo: 'sync',
        titulo: 'Pagos enviados',
        cuerpo: 'Lo que estaba pendiente ya se sincronizó.',
        notificarSistema: false,
      );
    }
    _tocar();
  }

  void fijarSimularRechazo(bool valor) {
    simularRechazo = valor;
    _tocar();
  }

  void fijarTarifa(TipoPasaje tipo, int centavos) {
    tarifas = tarifas.reemplazar(tipo, centavos);
    servicio = ServicioPagos(firmador: firmador, tarifas: tarifas);
    _tocar();
  }

  void recordarBusqueda(String consulta) {
    final limpia = consulta.trim();
    if (limpia.isEmpty) return;
    busquedas.remove(limpia);
    busquedas.insert(0, limpia);
    if (busquedas.length > 6) busquedas = busquedas.sublist(0, 6);
    _tocar();
  }

  Future<void> refrescarUbicacion() async {
    if (!permisoUbicacion) {
      ubicacion = centroSantaCruz;
      ubicacionEsEjemplo = true;
      notifyListeners();
      return;
    }
    final obtenida = await ubicacionServicio.actual();
    if (obtenida == null) {
      ubicacion = centroSantaCruz;
      ubicacionEsEjemplo = true;
    } else {
      ubicacion = obtenida;
      ubicacionEsEjemplo = false;
    }
    notifyListeners();
  }

  void fijarUbicacionEjemplo() {
    ubicacion = centroSantaCruz;
    ubicacionEsEjemplo = true;
    notifyListeners();
  }

  RutaTrufi? rutaDe(String? id) => id == null ? null : catalogo.porId(id);

  void prepararPago({
    required RutaTrufi ruta,
    required String sentido,
    required String medio,
    String? vehiculoId,
    String? cuentaChoferId,
    TokenPago? token,
    String? clave,
    String? subtitulo,
  }) {
    final hoy = _dia(DateTime.now());
    final pasajero = sesion?.id ?? idPasajeroDemo;
    final vehiculo = vehiculoId ?? 'sim-${ruta.routeId}';
    borrador = BorradorPago(
      clave: clave ?? '$medio-$pasajero-${ruta.routeId}-$vehiculo-$hoy',
      rutaId: ruta.routeId,
      nombreRuta: ruta.nombreComun,
      operador: ruta.operador,
      sentido: sentido,
      medio: medio,
      cuentaChoferId: cuentaChoferId ?? _cuentaDeRuta(ruta),
      subtitulo: subtitulo ?? 'Pago por ${medioVisible(medio)} · Asoc. ${ruta.operador}',
      vehiculoId: vehiculo,
      token: token,
    );
    notifyListeners();
  }

  String _cuentaDeRuta(RutaTrufi ruta) {
    if (turno != null && turno!.rutaId == ruta.routeId) return idChoferDemo;
    return 'operador-${ruta.routeId}';
  }

  void prepararManual(TipoPasaje tipo) {
    final ruta = catalogo.porId('R069') ?? (catalogo.rutas.isEmpty ? null : catalogo.rutas.first);
    borrador = BorradorPago(
      clave: 'manual-${DateTime.now().microsecondsSinceEpoch}',
      rutaId: ruta?.routeId ?? 'manual',
      nombreRuta: ruta?.nombreComun ?? 'Pago manual',
      operador: ruta?.operador ?? 'Kufi',
      sentido: 'ida',
      medio: 'manual',
      cuentaChoferId: idChoferDemo,
      subtitulo: 'Pago manual',
      tipo: tipo,
      vehiculoId: 'caja-manual-${DateTime.now().microsecondsSinceEpoch}',
    );
    notifyListeners();
  }

  String? confirmarBorrador({String? pin}) {
    final usuario = sesion;
    final actual = borrador;
    if (usuario == null || actual == null) return 'No hay un pago para confirmar.';
    if (!usuario.huella) {
      if (pin == null || usuario.pinHash != hashPin(pin, usuario.id)) {
        return 'PIN incorrecto.';
      }
    }
    final antes = libro.saldoDe(usuario.id);
    final numero = numeroDeOperacion(DateTime.now(), secuencia);
    final resultado = servicio.cobrar(
      libro: libro,
      tokensUsados: tokensUsados,
      solicitud: SolicitudCobro(
        claveIdempotencia: actual.clave,
        cuentaPasajeroId: usuario.id,
        cuentaChoferId: actual.cuentaChoferId,
        tipoPasaje: actual.tipo,
        pasajeros: actual.pasajeros,
        medio: actual.medio,
        ahora: DateTime.now(),
        enLinea: enLinea,
        numeroOperacion: numero,
        rutaId: actual.rutaId,
        nombreRuta: actual.nombreRuta,
        operador: actual.operador,
        sentido: actual.sentido,
        vehiculoId: actual.vehiculoId,
        token: actual.token,
        forzarRechazoDeLector: simularRechazo && actual.medio != 'manual',
      ),
    );
    libro = resultado.libro;
    tokensUsados = resultado.tokensUsados;
    if (resultado.aceptado) secuencia += 1;
    ultimoCobro = UltimoCobro(
      aceptado: resultado.aceptado,
      pendiente: resultado.pendienteDeSync,
      motivo: resultado.motivo,
      montoCentavos: resultado.montoCentavos,
      saldoCentavos: resultado.saldoPasajero,
      fecha: DateTime.now(),
      pagoId: resultado.pagoId,
      nombreRuta: actual.nombreRuta,
      operador: actual.operador,
      tipoPasaje: actual.tipo.etiqueta,
      pasajeros: actual.pasajeros,
      medio: actual.medioVisible,
      numeroOperacion: numero,
    );
    if (resultado.aceptado && !resultado.pendienteDeSync) {
      _avisar(
        tipo: 'pago_ok',
        titulo: 'Pago exitoso',
        cuerpo: 'Pagaste ${Dinero(resultado.montoCentavos).texto} en ${actual.nombreRuta}.',
      );
      final despues = resultado.saldoPasajero;
      if (correspondeAvisoSaldoBajo(antes: antes, despues: despues, umbral: umbralSaldoBajo)) {
        _avisar(
          tipo: 'saldo_bajo',
          titulo: 'Saldo bajo',
          cuerpo: 'Te quedan ${Dinero(despues).texto}. Recarga para el próximo trufi.',
        );
      }
      _avisar(
        tipo: 'cobro',
        titulo: 'Cobro recibido',
        cuerpo: '${actual.tipo.etiqueta} · ${Dinero(resultado.montoCentavos).texto}',
      );
    } else if (resultado.aceptado && resultado.pendienteDeSync) {
      _avisar(
        tipo: 'sin_conexion',
        titulo: 'Pago guardado sin conexión',
        cuerpo: 'Se enviará cuando vuelva el internet. No se cobró dos veces.',
      );
    } else if (resultado.motivo == MotivoRechazo.saldoInsuficiente) {
      _avisar(
        tipo: 'pago_rechazado',
        titulo: 'Saldo insuficiente',
        cuerpo: 'No se descontó nada. Te falta ${Dinero(resultado.faltaCentavos).texto}.',
      );
    } else {
      _avisar(
        tipo: 'pago_rechazado',
        titulo: 'Pago rechazado',
        cuerpo: 'No se descontó nada de tu saldo.',
      );
    }
    _tocar();
    return null;
  }

  String? recargar(int centavos, String medio) {
    final usuario = sesion;
    if (usuario == null) return 'Inicia sesión para recargar.';
    final numero = numeroDeOperacion(DateTime.now(), secuencia);
    final clave = 'recarga-${usuario.id}-${DateTime.now().microsecondsSinceEpoch}';
    final resultado = servicio.recargar(
      libro: libro,
      cuentaId: usuario.id,
      centavos: centavos,
      claveIdempotencia: clave,
      ahora: DateTime.now(),
      enLinea: enLinea,
      medio: medio,
      numeroOperacion: numero,
    );
    if (!resultado.aceptado) return 'No se pudo recargar.';
    libro = resultado.libro;
    secuencia += 1;
    ultimoCobro = UltimoCobro(
      aceptado: true,
      pendiente: resultado.pendienteDeSync,
      montoCentavos: centavos,
      saldoCentavos: resultado.saldoPasajero,
      fecha: DateTime.now(),
      pagoId: resultado.pagoId,
      nombreRuta: 'Recarga',
      medio: medio,
      numeroOperacion: numero,
      tipoPasaje: 'Recarga',
    );
    _avisar(
      tipo: 'recarga',
      titulo: 'Recarga lista',
      cuerpo: 'Entraron ${Dinero(centavos).texto} a tu billetera.',
    );
    _tocar();
    return null;
  }

  String? deshacerUltimoManual() {
    final usuario = sesion;
    if (usuario == null) return 'No hay sesión.';
    Movimiento? ultimo;
    for (final movimiento in libro.movimientos) {
      if (movimiento.cuentaId == usuario.id &&
          movimiento.tipo == TipoMovimiento.pasaje &&
          movimiento.medio == 'manual' &&
          movimiento.centavos < 0) {
        ultimo = movimiento;
      }
    }
    if (ultimo == null) return 'No hay un pago manual para deshacer.';
    if (libro.porClave('reverso:${ultimo.pagoId}:0') != null) {
      return 'Ese pago ya fue deshecho.';
    }
    final resultado = servicio.revertir(
      libro: libro,
      pagoId: ultimo.pagoId,
      ahora: DateTime.now(),
      enLinea: enLinea,
    );
    if (!resultado.aceptado) return resultado.motivo?.descripcion ?? 'No se pudo deshacer.';
    libro = resultado.libro;
    _avisar(tipo: 'reverso', titulo: 'Pago deshecho', cuerpo: 'Devolvimos el monto a tu saldo.');
    _tocar();
    return null;
  }

  void iniciarTurno(RutaTrufi ruta, String sentido) {
    turno = Turno(
      id: 'turno-${DateTime.now().millisecondsSinceEpoch}',
      rutaId: ruta.routeId,
      sentido: sentido,
      vehiculoId: 'SCZ-107',
      inicio: DateTime.now(),
    );
    _tocar();
  }

  void pausarTurno(bool pausado) {
    turno?.pausado = pausado;
    _tocar();
  }

  ResumenTurno resumenDelTurno() {
    return ResumenTurno.desde(
      libro: libro,
      cuentaChoferId: idChoferDemo,
      desde: turno?.inicio,
    );
  }

  Movimiento? ultimoCobroDelChofer() {
    final desde = turno?.inicio;
    Movimiento? ultimo;
    for (final movimiento in libro.movimientos) {
      if (movimiento.cuentaId != idChoferDemo || movimiento.centavos <= 0) continue;
      if (movimiento.tipo != TipoMovimiento.pasaje) continue;
      if (desde != null && movimiento.creadoEn.isBefore(desde)) continue;
      if (ultimo == null || movimiento.creadoEn.isAfter(ultimo.creadoEn)) ultimo = movimiento;
    }
    return ultimo;
  }

  void cerrarDia() {
    if (enLinea) libro = libro.sincronizar();
    turno = null;
    _avisar(
      tipo: 'cierre',
      titulo: 'Día cerrado',
      cuerpo: enLinea
          ? 'El resumen quedó listo para la asociación.'
          : 'El día se cerró en el teléfono. Los pagos pendientes salen cuando haya internet.',
    );
    _tocar();
  }

  void cargarJornadaDeEjemplo() {
    final ruta = catalogo.porId('R069') ?? (catalogo.rutas.isEmpty ? null : catalogo.rutas.first);
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day, 6);
    turno = Turno(
      id: 'turno-ejemplo',
      rutaId: ruta?.routeId ?? 'R069',
      sentido: 'ida',
      vehiculoId: 'SCZ-107',
      inicio: inicio,
      ejemplo: true,
    );
    if (libro.movimientos.any((m) => m.nota == 'jornada-ejemplo')) {
      _tocar();
      return;
    }
    final base = DateTime(ahora.year, ahora.month, ahora.day, 7);
    final extras = <Movimiento>[];
    void agregar({
      required String id,
      required TipoPasaje tipo,
      required int pasajeros,
      required bool pendiente,
      required int minuto,
    }) {
      final monto = tarifas.montoDe(tipo) * pasajeros;
      extras.add(
        Movimiento(
          id: id,
          claveIdempotencia: '$id:credito',
          cuentaId: idChoferDemo,
          tipo: TipoMovimiento.pasaje,
          centavos: monto,
          creadoEn: base.add(Duration(minutes: minuto)),
          pagoId: id,
          rutaId: turno!.rutaId,
          nombreRuta: ruta?.nombreComun ?? 'Trufi Los Piyos',
          operador: ruta?.operador ?? 'Los Piyos',
          tipoPasaje: tipo.id,
          pasajeros: pasajeros,
          medio: 'qr',
          sentido: 'ida',
          vehiculoId: 'SCZ-107',
          sync: pendiente ? EstadoSync.pendiente : EstadoSync.sincronizado,
          numeroOperacion: id,
          nota: 'jornada-ejemplo',
        ),
      );
    }

    for (var i = 0; i < 4; i++) {
      agregar(
        id: 'ej-ad-$i',
        tipo: TipoPasaje.adulto,
        pasajeros: 7,
        pendiente: false,
        minuto: 20 * i,
      );
    }
    agregar(id: 'ej-ad-4', tipo: TipoPasaje.adulto, pasajeros: 1, pendiente: true, minuto: 90);
    agregar(id: 'ej-ad-5', tipo: TipoPasaje.adulto, pasajeros: 1, pendiente: true, minuto: 95);
    agregar(id: 'ej-es', tipo: TipoPasaje.estudiante, pasajeros: 5, pendiente: false, minuto: 110);
    agregar(id: 'ej-am', tipo: TipoPasaje.adultoMayor, pasajeros: 2, pendiente: false, minuto: 130);
    libro = LibroMayor([...libro.movimientos, ...extras]);
    _tocar();
  }

  TokenPago? tokenQrDelTurno([DateTime? momento]) {
    final actual = turno;
    if (actual == null || actual.pausado) return null;
    final ahora = momento ?? DateTime.now();
    final bloque = ahora.millisecondsSinceEpoch ~/ 45000;
    final inicio = DateTime.fromMillisecondsSinceEpoch(bloque * 45000);
    final ruta = catalogo.porId(actual.rutaId);
    return firmador.sellar(
      TokenPago(
        id: 'qr-${actual.id}-$bloque',
        vehiculoId: actual.vehiculoId,
        cuentaChoferId: idChoferDemo,
        rutaId: actual.rutaId,
        sentido: actual.sentido,
        nombreRuta: ruta?.nombreComun ?? actual.rutaId,
        emitidoEn: inicio,
        venceEn: inicio.add(const Duration(seconds: 50)),
        nonce: '$bloque',
        firma: '',
      ),
    );
  }

  int segundosParaRotarQr([DateTime? momento]) {
    final ahora = momento ?? DateTime.now();
    final resto = 45 - ((ahora.millisecondsSinceEpoch ~/ 1000) % 45);
    return resto == 0 ? 45 : resto;
  }

  List<AnuncioVehiculo> anunciosDetectados() {
    final firmadorAnuncios = FirmadorAnuncios(firmador.secreto);
    final ahora = DateTime.now();
    final anuncios = <AnuncioVehiculo>[];
    final actual = turno;
    if (actual != null && !actual.pausado) {
      final ruta = catalogo.porId(actual.rutaId);
      anuncios.add(
        firmadorAnuncios.sellar(
          AnuncioVehiculo(
            vehiculoId: actual.vehiculoId,
            cuentaChoferId: idChoferDemo,
            rutaId: actual.rutaId,
            nombreRuta: ruta?.nombreComun ?? 'Trufi',
            sentido: actual.sentido,
            operador: ruta?.operador ?? '',
            jurisdiccion: ruta?.jurisdiccion ?? '',
            panter: ruta?.panterVisible ?? '',
            rssi: -52,
            nonce: actual.id,
            venceEn: ahora.add(const Duration(hours: 12)),
            firma: '',
            turnoId: actual.id,
          ),
        ),
      );
    }
    const muestras = [
      ('R069', -61),
      ('R054', -76),
      ('R049', -84),
      ('R112', -93),
    ];
    for (final muestra in muestras) {
      final ruta = catalogo.porId(muestra.$1);
      if (ruta == null) continue;
      if (actual != null && actual.rutaId == ruta.routeId) continue;
      anuncios.add(
        firmadorAnuncios.sellar(
          AnuncioVehiculo(
            vehiculoId: 'sim-${ruta.routeId}',
            cuentaChoferId: 'operador-${ruta.routeId}',
            rutaId: ruta.routeId,
            nombreRuta: ruta.nombreComun,
            sentido: 'ida',
            operador: ruta.operador,
            jurisdiccion: ruta.jurisdiccion,
            panter: ruta.panterVisible,
            rssi: muestra.$2,
            nonce: 'sim-${ruta.routeId}-${_dia(ahora)}',
            venceEn: ahora.add(const Duration(minutes: 10)),
            firma: '',
          ),
        ),
      );
    }
    return FiltroAnuncios.detectados(anuncios, ahora: ahora, firmador: firmadorAnuncios);
  }

  void prepararCaptura(String pantalla) {
    captura = pantalla;
    onboardingListo = true;
    permisosVistos = true;
    ubicacion = centroSantaCruz;
    ubicacionEsEjemplo = true;
    if (pantalla == 'bienvenida' || pantalla == 'permisos' || pantalla == 'ingreso' || pantalla == 'registro') {
      sesionId = null;
      onboardingListo = pantalla != 'bienvenida';
      permisosVistos = pantalla == 'ingreso' || pantalla == 'registro';
      notifyListeners();
      return;
    }
    if (pantalla == 'cobro' || pantalla == 'cierre' || pantalla == 'qr-chofer') {
      sesionId = idChoferDemo;
      rolEnPuerta = Rol.chofer;
      cargarJornadaDeEjemplo();
      return;
    }
    sesionId = idPasajeroDemo;
    rolEnPuerta = Rol.pasajero;
    if (pantalla == 'sin-conexion') {
      enLinea = false;
      final ruta = catalogo.porId('R069');
      if (ruta != null && sesion != null) {
        prepararPago(ruta: ruta, sentido: 'ida', medio: 'nfc', clave: 'captura-offline');
        borrador!.tipo = TipoPasaje.adulto;
        simularRechazo = false;
        final previo = enLinea;
        enLinea = false;
        confirmarBorrador(pin: '1234');
        enLinea = previo;
        enLinea = false;
      }
    } else if (pantalla == 'recibo') {
      final ruta = catalogo.porId('R069');
      if (ruta != null) {
        prepararPago(ruta: ruta, sentido: 'ida', medio: 'nfc', clave: 'captura-recibo-${DateTime.now().millisecondsSinceEpoch}');
        confirmarBorrador(pin: '1234');
      }
    } else if (pantalla == 'saldo') {
      ultimoCobro = UltimoCobro(
        aceptado: false,
        pendiente: false,
        motivo: MotivoRechazo.saldoInsuficiente,
        montoCentavos: 230,
        saldoCentavos: 120,
        fecha: DateTime.now(),
        nombreRuta: 'Trufi Los Piyos',
        operador: 'Los Piyos',
        tipoPasaje: 'Adulto',
        medio: 'NFC',
      );
    } else if (pantalla == 'rechazo') {
      ultimoCobro = UltimoCobro(
        aceptado: false,
        pendiente: false,
        motivo: MotivoRechazo.lectorNoResponde,
        montoCentavos: 230,
        saldoCentavos: saldoDe(idPasajeroDemo),
        fecha: DateTime.now(),
        nombreRuta: 'Trufi Los Piyos',
        operador: 'Los Piyos',
        tipoPasaje: 'Adulto',
        medio: 'NFC',
      );
    } else if (pantalla == 'confirmar' || pantalla == 'nfc' || pantalla == 'ble' || pantalla == 'qr') {
      final ruta = catalogo.porId('R069') ?? (catalogo.rutas.isEmpty ? null : catalogo.rutas.first);
      if (ruta != null) {
        prepararPago(
          ruta: ruta,
          sentido: 'ida',
          medio: pantalla == 'confirmar' ? 'nfc' : pantalla,
        );
      }
    }
    banner = null;
    notifyListeners();
  }

  void cerrarBanner() {
    banner = null;
    notifyListeners();
  }

  void _avisar({
    required String tipo,
    required String titulo,
    required String cuerpo,
    bool notificarSistema = true,
  }) {
    final aviso = Aviso(
      id: 'av-${DateTime.now().microsecondsSinceEpoch}',
      tipo: tipo,
      titulo: titulo,
      cuerpo: cuerpo,
      fecha: DateTime.now(),
    );
    avisos.insert(0, aviso);
    if (avisos.length > 40) avisos = avisos.sublist(0, 40);
    banner = aviso;
    final usuario = sesion;
    if (notificarSistema && (usuario == null || usuario.notificaciones)) {
      notificador.mostrar(titulo, cuerpo);
      fcm.encolar(tipo: tipo, titulo: titulo, cuerpo: cuerpo);
    }
  }

  String _dia(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}$mes$dia';
  }
}

String medioVisible(String medio) {
  switch (medio) {
    case 'nfc':
      return 'NFC';
    case 'ble':
      return 'Bluetooth';
    case 'qr':
      return 'QR';
    case 'manual':
      return 'manual';
    default:
      return 'la ruta';
  }
}
