enum TipoPasaje { adulto, estudiante, nino, adultoMayor }

extension TipoPasajeTexto on TipoPasaje {
  String get id {
    switch (this) {
      case TipoPasaje.adulto:
        return 'adulto';
      case TipoPasaje.estudiante:
        return 'estudiante';
      case TipoPasaje.nino:
        return 'nino';
      case TipoPasaje.adultoMayor:
        return 'adulto_mayor';
    }
  }

  String get etiqueta {
    switch (this) {
      case TipoPasaje.adulto:
        return 'Adulto';
      case TipoPasaje.estudiante:
        return 'Estudiante';
      case TipoPasaje.nino:
        return 'Niño';
      case TipoPasaje.adultoMayor:
        return 'Adulto mayor';
    }
  }

  static TipoPasaje desdeId(String id) {
    switch (id) {
      case 'estudiante':
        return TipoPasaje.estudiante;
      case 'nino':
      case 'niño':
        return TipoPasaje.nino;
      case 'adulto_mayor':
      case 'adultoMayor':
        return TipoPasaje.adultoMayor;
      default:
        return TipoPasaje.adulto;
    }
  }
}

class Tarifa {
  const Tarifa({required this.tipo, required this.centavos});

  final TipoPasaje tipo;
  final int centavos;

  Map<String, dynamic> toJson() => {'tipo': tipo.id, 'centavos': centavos};

  factory Tarifa.fromJson(Map<String, dynamic> json) {
    return Tarifa(
      tipo: TipoPasajeTexto.desdeId(json['tipo'] as String),
      centavos: (json['centavos'] as num).toInt(),
    );
  }
}

/// Tarifas sacadas del diseño. Están por confirmar con cada asociación.
class TablaTarifas {
  const TablaTarifas({
    required this.tarifas,
    this.nota = 'Montos del diseño, por confirmar con la asociación.',
  });

  final List<Tarifa> tarifas;
  final String nota;

  static const porDefecto = TablaTarifas(
    tarifas: [
      Tarifa(tipo: TipoPasaje.adulto, centavos: 230),
      Tarifa(tipo: TipoPasaje.estudiante, centavos: 100),
      Tarifa(tipo: TipoPasaje.nino, centavos: 100),
      Tarifa(tipo: TipoPasaje.adultoMayor, centavos: 150),
    ],
  );

  int montoDe(TipoPasaje tipo) {
    for (final tarifa in tarifas) {
      if (tarifa.tipo == tipo) return tarifa.centavos;
    }
    throw StateError('No hay tarifa para ${tipo.id}');
  }

  TablaTarifas reemplazar(TipoPasaje tipo, int centavos) {
    if (centavos <= 0) {
      throw ArgumentError('La tarifa tiene que ser mayor que cero.');
    }
    return TablaTarifas(
      nota: nota,
      tarifas: [
        for (final tarifa in tarifas)
          if (tarifa.tipo == tipo) Tarifa(tipo: tipo, centavos: centavos) else tarifa,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'nota': nota,
        'tarifas': tarifas.map((t) => t.toJson()).toList(),
      };

  factory TablaTarifas.fromJson(Map<String, dynamic> json) {
    final lista = (json['tarifas'] as List)
        .map((e) => Tarifa.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return TablaTarifas(
      tarifas: lista,
      nota: json['nota'] as String? ?? TablaTarifas.porDefecto.nota,
    );
  }
}
