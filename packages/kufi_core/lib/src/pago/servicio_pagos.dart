import '../libro/libro_mayor.dart';
import '../libro/movimiento.dart';
import '../tarifas.dart';
import 'token_pago.dart';

class SolicitudCobro {
  const SolicitudCobro({
    required this.claveIdempotencia,
    required this.cuentaPasajeroId,
    required this.cuentaChoferId,
    required this.tipoPasaje,
    required this.pasajeros,
    required this.medio,
    required this.ahora,
    required this.enLinea,
    required this.numeroOperacion,
    this.rutaId,
    this.nombreRuta,
    this.operador,
    this.sentido,
    this.vehiculoId,
    this.token,
    this.forzarRechazoDeLector = false,
  });

  final String claveIdempotencia;
  final String cuentaPasajeroId;
  final String cuentaChoferId;
  final TipoPasaje tipoPasaje;
  final int pasajeros;
  final String medio;
  final DateTime ahora;
  final bool enLinea;
  final String numeroOperacion;
  final String? rutaId;
  final String? nombreRuta;
  final String? operador;
  final String? sentido;
  final String? vehiculoId;
  final TokenPago? token;
  final bool forzarRechazoDeLector;
}

class ResultadoCobro {
  const ResultadoCobro({
    required this.aceptado,
    required this.duplicado,
    required this.pendienteDeSync,
    required this.libro,
    required this.tokensUsados,
    required this.montoCentavos,
    required this.saldoPasajero,
    this.motivo,
    this.pagoId,
  });

  final bool aceptado;
  final bool duplicado;
  final bool pendienteDeSync;
  final LibroMayor libro;
  final Set<String> tokensUsados;
  final int montoCentavos;
  final int saldoPasajero;
  final MotivoRechazo? motivo;
  final String? pagoId;

  int get faltaCentavos {
    if (motivo != MotivoRechazo.saldoInsuficiente) return 0;
    final falta = montoCentavos - saldoPasajero;
    return falta < 0 ? 0 : falta;
  }
}

class ServicioPagos {
  ServicioPagos({
    required this.firmador,
    required this.tarifas,
    this.ventanaAntidoble = const Duration(minutes: 2),
  });

  final FirmadorTokens firmador;
  final TablaTarifas tarifas;
  final Duration ventanaAntidoble;

  ResultadoCobro cobrar({
    required LibroMayor libro,
    required Set<String> tokensUsados,
    required SolicitudCobro solicitud,
  }) {
    if (solicitud.pasajeros < 1 || solicitud.pasajeros > 8) {
      return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.pasajerosInvalidos, 0);
    }
    final int montoUnitario;
    try {
      montoUnitario = tarifas.montoDe(solicitud.tipoPasaje);
    } on StateError {
      return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.tarifaInvalida, 0);
    }
    final monto = montoUnitario * solicitud.pasajeros;

    if (solicitud.forzarRechazoDeLector) {
      return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.lectorNoResponde, monto);
    }

    final token = solicitud.token;
    if (token != null) {
      if (!firmador.verificar(token)) {
        return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.firmaInvalida, monto);
      }
      if (!token.vigenteEn(solicitud.ahora)) {
        return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.tokenVencido, monto);
      }
      if (token.cuentaChoferId != solicitud.cuentaChoferId ||
          (solicitud.rutaId != null && token.rutaId != solicitud.rutaId)) {
        return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.datosNoCoinciden, monto);
      }
      if (token.usoUnico && tokensUsados.contains(token.id)) {
        return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.yaCobrado, monto);
      }
    }

    final previo = libro.porClave('${solicitud.claveIdempotencia}:debito');
    if (previo != null) {
      return ResultadoCobro(
        aceptado: false,
        duplicado: true,
        pendienteDeSync: previo.sync == EstadoSync.pendiente,
        libro: libro,
        tokensUsados: tokensUsados,
        montoCentavos: monto,
        saldoPasajero: libro.saldoDe(solicitud.cuentaPasajeroId),
        motivo: MotivoRechazo.yaCobrado,
        pagoId: previo.pagoId,
      );
    }

    if (solicitud.medio != 'manual' &&
        solicitud.vehiculoId != null &&
        _hayCobroReciente(libro, solicitud)) {
      return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.cobroReciente, monto);
    }

    final saldo = libro.saldoDe(solicitud.cuentaPasajeroId);
    if (saldo < monto) {
      return _rechazo(libro, tokensUsados, solicitud, MotivoRechazo.saldoInsuficiente, monto);
    }

    final pagoId = 'pago-${solicitud.claveIdempotencia}';
    final sync = solicitud.enLinea ? EstadoSync.sincronizado : EstadoSync.pendiente;
    final debito = _movimiento(
      solicitud: solicitud,
      pagoId: pagoId,
      sufijo: 'debito',
      cuentaId: solicitud.cuentaPasajeroId,
      centavos: -monto,
      sync: sync,
    );
    final credito = _movimiento(
      solicitud: solicitud,
      pagoId: pagoId,
      sufijo: 'credito',
      cuentaId: solicitud.cuentaChoferId,
      centavos: monto,
      sync: sync,
    );
    final aplicado = libro.aplicarTodos([debito, credito]);
    if (!aplicado.aplicado) {
      return _rechazo(
        libro,
        tokensUsados,
        solicitud,
        aplicado.motivo ?? MotivoRechazo.saldoInsuficiente,
        monto,
      );
    }
    final usados = {...tokensUsados};
    if (token != null && token.usoUnico) usados.add(token.id);
    return ResultadoCobro(
      aceptado: true,
      duplicado: false,
      pendienteDeSync: !solicitud.enLinea,
      libro: aplicado.libro,
      tokensUsados: usados,
      montoCentavos: monto,
      saldoPasajero: aplicado.libro.saldoDe(solicitud.cuentaPasajeroId),
      pagoId: pagoId,
    );
  }

  ResultadoCobro recargar({
    required LibroMayor libro,
    required String cuentaId,
    required int centavos,
    required String claveIdempotencia,
    required DateTime ahora,
    required bool enLinea,
    required String medio,
    required String numeroOperacion,
  }) {
    if (centavos <= 0) {
      return _rechazo(
        libro,
        const {},
        SolicitudCobro(
          claveIdempotencia: claveIdempotencia,
          cuentaPasajeroId: cuentaId,
          cuentaChoferId: cuentaId,
          tipoPasaje: TipoPasaje.adulto,
          pasajeros: 1,
          medio: medio,
          ahora: ahora,
          enLinea: enLinea,
          numeroOperacion: numeroOperacion,
        ),
        MotivoRechazo.tarifaInvalida,
        centavos,
      );
    }
    final movimiento = Movimiento(
      id: 'mov-$claveIdempotencia',
      claveIdempotencia: claveIdempotencia,
      cuentaId: cuentaId,
      tipo: TipoMovimiento.recarga,
      centavos: centavos,
      creadoEn: ahora,
      pagoId: 'recarga-$claveIdempotencia',
      medio: medio,
      sync: enLinea ? EstadoSync.sincronizado : EstadoSync.pendiente,
      numeroOperacion: numeroOperacion,
      nota: 'Recarga',
    );
    final aplicado = libro.aplicar(movimiento);
    if (aplicado.duplicado) {
      return ResultadoCobro(
        aceptado: false,
        duplicado: true,
        pendienteDeSync: false,
        libro: libro,
        tokensUsados: const {},
        montoCentavos: centavos,
        saldoPasajero: libro.saldoDe(cuentaId),
        motivo: MotivoRechazo.yaCobrado,
        pagoId: aplicado.movimiento?.pagoId,
      );
    }
    return ResultadoCobro(
      aceptado: true,
      duplicado: false,
      pendienteDeSync: !enLinea,
      libro: aplicado.libro,
      tokensUsados: const {},
      montoCentavos: centavos,
      saldoPasajero: aplicado.libro.saldoDe(cuentaId),
      pagoId: movimiento.pagoId,
    );
  }

  /// El deshacer no borra: agrega un reverso con su propia clave.
  ResultadoCobro revertir({
    required LibroMayor libro,
    required String pagoId,
    required DateTime ahora,
    required bool enLinea,
  }) {
    final originales = libro.dePago(pagoId).where((m) => m.tipo == TipoMovimiento.pasaje).toList();
    if (originales.isEmpty) {
      return ResultadoCobro(
        aceptado: false,
        duplicado: false,
        pendienteDeSync: false,
        libro: libro,
        tokensUsados: const {},
        montoCentavos: 0,
        saldoPasajero: 0,
        motivo: MotivoRechazo.pagoNoEncontrado,
      );
    }
    final clave = 'reverso:$pagoId';
    if (libro.porClave('$clave:0') != null) {
      return ResultadoCobro(
        aceptado: false,
        duplicado: true,
        pendienteDeSync: false,
        libro: libro,
        tokensUsados: const {},
        montoCentavos: 0,
        saldoPasajero: 0,
        motivo: MotivoRechazo.yaCobrado,
        pagoId: 'reverso-$pagoId',
      );
    }
    final reversos = <Movimiento>[];
    for (var i = 0; i < originales.length; i++) {
      final original = originales[i];
      reversos.add(
        Movimiento(
          id: 'mov-$clave-$i',
          claveIdempotencia: '$clave:$i',
          cuentaId: original.cuentaId,
          tipo: TipoMovimiento.reverso,
          centavos: -original.centavos,
          creadoEn: ahora,
          pagoId: 'reverso-$pagoId',
          rutaId: original.rutaId,
          nombreRuta: original.nombreRuta,
          operador: original.operador,
          tipoPasaje: original.tipoPasaje,
          pasajeros: original.pasajeros,
          medio: original.medio,
          sentido: original.sentido,
          vehiculoId: original.vehiculoId,
          sync: enLinea ? EstadoSync.sincronizado : EstadoSync.pendiente,
          numeroOperacion: original.numeroOperacion,
          nota: 'Reverso de $pagoId',
        ),
      );
    }
    final aplicado = libro.aplicarTodos(reversos);
    final cuentaPasajero = originales.firstWhere((m) => m.centavos < 0).cuentaId;
    if (!aplicado.aplicado) {
      return ResultadoCobro(
        aceptado: false,
        duplicado: aplicado.duplicado,
        pendienteDeSync: false,
        libro: libro,
        tokensUsados: const {},
        montoCentavos: 0,
        saldoPasajero: libro.saldoDe(cuentaPasajero),
        motivo: aplicado.motivo,
      );
    }
    return ResultadoCobro(
      aceptado: true,
      duplicado: false,
      pendienteDeSync: !enLinea,
      libro: aplicado.libro,
      tokensUsados: const {},
      montoCentavos: originales.firstWhere((m) => m.centavos < 0).centavos.abs(),
      saldoPasajero: aplicado.libro.saldoDe(cuentaPasajero),
      pagoId: 'reverso-$pagoId',
    );
  }

  bool _hayCobroReciente(LibroMayor libro, SolicitudCobro solicitud) {
    for (final movimiento in libro.movimientos) {
      if (movimiento.cuentaId != solicitud.cuentaPasajeroId) continue;
      if (movimiento.tipo != TipoMovimiento.pasaje || movimiento.centavos >= 0) continue;
      if (movimiento.vehiculoId != solicitud.vehiculoId) continue;
      final diferencia = solicitud.ahora.difference(movimiento.creadoEn);
      if (!diferencia.isNegative && diferencia < ventanaAntidoble) return true;
    }
    return false;
  }

  Movimiento _movimiento({
    required SolicitudCobro solicitud,
    required String pagoId,
    required String sufijo,
    required String cuentaId,
    required int centavos,
    required EstadoSync sync,
  }) {
    final clave = '${solicitud.claveIdempotencia}:$sufijo';
    return Movimiento(
      id: 'mov-$clave',
      claveIdempotencia: clave,
      cuentaId: cuentaId,
      tipo: TipoMovimiento.pasaje,
      centavos: centavos,
      creadoEn: solicitud.ahora,
      pagoId: pagoId,
      rutaId: solicitud.rutaId,
      nombreRuta: solicitud.nombreRuta,
      operador: solicitud.operador,
      tipoPasaje: solicitud.tipoPasaje.id,
      pasajeros: solicitud.pasajeros,
      medio: solicitud.medio,
      sentido: solicitud.sentido,
      vehiculoId: solicitud.vehiculoId,
      sync: sync,
      numeroOperacion: solicitud.numeroOperacion,
    );
  }

  ResultadoCobro _rechazo(
    LibroMayor libro,
    Set<String> tokens,
    SolicitudCobro solicitud,
    MotivoRechazo motivo,
    int monto,
  ) {
    return ResultadoCobro(
      aceptado: false,
      duplicado: motivo == MotivoRechazo.yaCobrado,
      pendienteDeSync: false,
      libro: libro,
      tokensUsados: tokens,
      montoCentavos: monto,
      saldoPasajero: libro.saldoDe(solicitud.cuentaPasajeroId),
      motivo: motivo,
    );
  }
}

class LineaCierre {
  const LineaCierre({required this.tipo, required this.viajes, required this.pasajeros, required this.centavos});

  final TipoPasaje tipo;
  final int viajes;
  final int pasajeros;
  final int centavos;
}

class ResumenTurno {
  const ResumenTurno({
    required this.pasajeros,
    required this.viajes,
    required this.totalCentavos,
    required this.porTipo,
    required this.pagosPendientes,
    required this.centavosPendientes,
  });

  final int pasajeros;
  final int viajes;
  final int totalCentavos;
  final List<LineaCierre> porTipo;
  final int pagosPendientes;
  final int centavosPendientes;

  static ResumenTurno desde({
    required LibroMayor libro,
    required String cuentaChoferId,
    DateTime? desde,
    DateTime? hasta,
  }) {
    final creditos = libro.movimientos.where((m) {
      if (m.cuentaId != cuentaChoferId || m.tipo != TipoMovimiento.pasaje || m.centavos <= 0) {
        return false;
      }
      if (desde != null && m.creadoEn.isBefore(desde)) return false;
      if (hasta != null && m.creadoEn.isAfter(hasta)) return false;
      return true;
    }).toList();

    final porTipo = <TipoPasaje, LineaCierre>{};
    var pasajeros = 0;
    var total = 0;
    var pendientes = 0;
    var centavosPendientes = 0;
    for (final movimiento in creditos) {
      final tipo = TipoPasajeTexto.desdeId(movimiento.tipoPasaje ?? 'adulto');
      final previo = porTipo[tipo];
      porTipo[tipo] = LineaCierre(
        tipo: tipo,
        viajes: (previo?.viajes ?? 0) + 1,
        pasajeros: (previo?.pasajeros ?? 0) + movimiento.pasajeros,
        centavos: (previo?.centavos ?? 0) + movimiento.centavos,
      );
      pasajeros += movimiento.pasajeros;
      total += movimiento.centavos;
      if (movimiento.sync == EstadoSync.pendiente) {
        pendientes += 1;
        centavosPendientes += movimiento.centavos;
      }
    }
    const orden = TipoPasaje.values;
    final lineas = [
      for (final tipo in orden)
        if (porTipo.containsKey(tipo)) porTipo[tipo]!,
    ];
    return ResumenTurno(
      pasajeros: pasajeros,
      viajes: creditos.length,
      totalCentavos: total,
      porTipo: lineas,
      pagosPendientes: pendientes,
      centavosPendientes: centavosPendientes,
    );
  }
}
