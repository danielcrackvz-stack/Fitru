import 'movimiento.dart';

enum MotivoRechazo {
  firmaInvalida,
  tokenVencido,
  yaCobrado,
  saldoInsuficiente,
  datosNoCoinciden,
  tarifaInvalida,
  pasajerosInvalidos,
  cobroReciente,
  lectorNoResponde,
  pagoNoEncontrado,
}

extension MotivoRechazoTexto on MotivoRechazo {
  String get codigo {
    switch (this) {
      case MotivoRechazo.firmaInvalida:
        return 'K-401';
      case MotivoRechazo.tokenVencido:
        return 'K-403';
      case MotivoRechazo.yaCobrado:
        return 'K-409';
      case MotivoRechazo.saldoInsuficiente:
        return 'K-412';
      case MotivoRechazo.datosNoCoinciden:
        return 'K-406';
      case MotivoRechazo.tarifaInvalida:
        return 'K-422';
      case MotivoRechazo.pasajerosInvalidos:
        return 'K-422';
      case MotivoRechazo.cobroReciente:
        return 'K-409';
      case MotivoRechazo.lectorNoResponde:
        return 'K-402';
      case MotivoRechazo.pagoNoEncontrado:
        return 'K-404';
    }
  }

  String get descripcion {
    switch (this) {
      case MotivoRechazo.firmaInvalida:
        return 'firma inválida';
      case MotivoRechazo.tokenVencido:
        return 'el código venció';
      case MotivoRechazo.yaCobrado:
        return 'este cobro ya fue registrado';
      case MotivoRechazo.saldoInsuficiente:
        return 'saldo insuficiente';
      case MotivoRechazo.datosNoCoinciden:
        return 'los datos del trufi no coinciden';
      case MotivoRechazo.tarifaInvalida:
        return 'tarifa no configurada';
      case MotivoRechazo.pasajerosInvalidos:
        return 'cantidad de pasajeros no válida';
      case MotivoRechazo.cobroReciente:
        return 'ya pagaste este trufi hace un momento';
      case MotivoRechazo.lectorNoResponde:
        return 'lector no responde';
      case MotivoRechazo.pagoNoEncontrado:
        return 'no hay un pago para deshacer';
    }
  }
}

class ResultadoLibro {
  const ResultadoLibro._({
    required this.aplicado,
    required this.duplicado,
    required this.libro,
    this.motivo,
    this.movimiento,
  });

  final bool aplicado;
  final bool duplicado;
  final LibroMayor libro;
  final MotivoRechazo? motivo;
  final Movimiento? movimiento;

  factory ResultadoLibro.ok(LibroMayor libro, Movimiento movimiento) {
    return ResultadoLibro._(aplicado: true, duplicado: false, libro: libro, movimiento: movimiento);
  }

  factory ResultadoLibro.duplicado(LibroMayor libro, Movimiento movimiento) {
    return ResultadoLibro._(
      aplicado: false,
      duplicado: true,
      libro: libro,
      movimiento: movimiento,
      motivo: MotivoRechazo.yaCobrado,
    );
  }

  factory ResultadoLibro.rechazo(LibroMayor libro, MotivoRechazo motivo) {
    return ResultadoLibro._(aplicado: false, duplicado: false, libro: libro, motivo: motivo);
  }
}

/// Libro inmutable: cada cambio devuelve otra instancia y nada se borra.
class LibroMayor {
  LibroMayor([Iterable<Movimiento> movimientos = const []])
      : _movimientos = List<Movimiento>.unmodifiable(movimientos);

  final List<Movimiento> _movimientos;

  List<Movimiento> get movimientos => _movimientos;

  int saldoDe(String cuentaId) {
    var total = 0;
    for (final movimiento in _movimientos) {
      if (movimiento.cuentaId == cuentaId) total += movimiento.centavos;
    }
    return total;
  }

  Movimiento? porClave(String clave) {
    for (final movimiento in _movimientos) {
      if (movimiento.claveIdempotencia == clave) return movimiento;
    }
    return null;
  }

  List<Movimiento> dePago(String pagoId) {
    return _movimientos.where((m) => m.pagoId == pagoId).toList();
  }

  List<Movimiento> deCuenta(String cuentaId) {
    final lista = _movimientos.where((m) => m.cuentaId == cuentaId).toList();
    lista.sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
    return lista;
  }

  int get pendientes => _movimientos.where((m) => m.sync == EstadoSync.pendiente).length;

  ResultadoLibro aplicar(Movimiento movimiento) {
    final previo = porClave(movimiento.claveIdempotencia);
    if (previo != null) return ResultadoLibro.duplicado(this, previo);
    if (movimiento.centavos < 0 && saldoDe(movimiento.cuentaId) + movimiento.centavos < 0) {
      return ResultadoLibro.rechazo(this, MotivoRechazo.saldoInsuficiente);
    }
    return ResultadoLibro.ok(LibroMayor([..._movimientos, movimiento]), movimiento);
  }

  /// Aplica varios apuntes como una sola operación.
  /// Si uno falla, el libro queda igual que al empezar.
  ResultadoLibro aplicarTodos(List<Movimiento> lote) {
    var actual = this;
    Movimiento? ultimo;
    for (final movimiento in lote) {
      final resultado = actual.aplicar(movimiento);
      if (!resultado.aplicado) {
        return ResultadoLibro._(
          aplicado: false,
          duplicado: resultado.duplicado,
          libro: this,
          motivo: resultado.motivo,
          movimiento: resultado.movimiento,
        );
      }
      actual = resultado.libro;
      ultimo = resultado.movimiento;
    }
    return ResultadoLibro.ok(actual, ultimo!);
  }

  /// Marca como sincronizados los apuntes pendientes. No crea apuntes nuevos.
  LibroMayor sincronizar() {
    var cambio = false;
    final siguientes = <Movimiento>[];
    for (final movimiento in _movimientos) {
      if (movimiento.sync == EstadoSync.pendiente) {
        siguientes.add(movimiento.copiarCon(sync: EstadoSync.sincronizado));
        cambio = true;
      } else {
        siguientes.add(movimiento);
      }
    }
    return cambio ? LibroMayor(siguientes) : this;
  }

  Map<String, dynamic> toJson() => {
        'movimientos': _movimientos.map((m) => m.toJson()).toList(),
      };

  factory LibroMayor.fromJson(Map<String, dynamic> json) {
    final lista = (json['movimientos'] as List<dynamic>? ?? const [])
        .map((e) => Movimiento.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return LibroMayor(lista);
  }
}
