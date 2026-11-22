import 'dart:io';

import 'package:kufi_core/kufi_core.dart';
import 'package:test/test.dart';

const secretoPrueba = 'prueba-unitaria-kufi';

void main() {
  group('Dinero', () {
    test('formatea bolivianos con coma decimal', () {
      expect(const Dinero(230).texto, 'Bs 2,30');
      expect(const Dinero(5000).texto, 'Bs 50,00');
      expect(const Dinero(7700).texto, 'Bs 77,00');
      expect(const Dinero(123450).texto, 'Bs 1.234,50');
      expect(const Dinero(-120).texto, '-Bs 1,20');
    });

    test('arma el número de operación', () {
      expect(
        numeroDeOperacion(DateTime.utc(2026, 11, 21), 7),
        'KF-261121-0007',
      );
    });
  });

  group('Búsqueda', () {
    test('ignora tildes y mayúsculas', () {
      expect(plegar('Piyós'), 'piyos');
      expect(plegar('1er Anillo'), plegar('1ER ANILLO'));
      expect(
        coincideConsulta('los piyos', ['Trufi Los Piyós', 'La Guardia']),
        isTrue,
      );
      expect(
          coincideConsulta('anillo norte', ['1er Anillo', 'centro']), isFalse);
    });
  });

  group('Trazados', () {
    const linea = [
      Coord(-17.78, -63.20),
      Coord(-17.78, -63.18),
    ];

    test('interpola a la mitad del segmento', () {
      final medio = posicionEnTrazado(linea, 0.5);
      expect(medio.lat, closeTo(-17.78, 0.00001));
      expect(medio.lon, closeTo(-63.19, 0.0002));
    });

    test('mide la distancia a la línea y no solo a los vértices', () {
      final punto = Coord(-17.78, -63.19);
      expect(distanciaATrazadoMetros(punto, linea), lessThan(30));
      final lejos = Coord(-17.70, -63.19);
      expect(distanciaATrazadoMetros(lejos, linea), greaterThan(5000));
    });
  });

  group('Catálogo', () {
    const geo = '''
{"type":"FeatureCollection","features":[
 {"type":"Feature","properties":{"shape_id":"R069_ida","route_id":"R069","nombre_comun":"Trufi Los Piyos Blanco","sentido":"ida","km":15.86,"min":47,"operador":"Los Piyos","federacion":"16 de Noviembre","jurisdiccion":"Intermunicipal","color_panter":"Blanco","banderin":"","color_hex":"#8A8F98","color_hex_2":"","zona_origen":"La Guardia","zona_destino":"Centro","geom_invertida_corregida":false,"zonas":"La Guardia ↔ Centro"},"geometry":{"type":"LineString","coordinates":[[-63.20,-17.82],[-63.18,-17.80],[-63.16,-17.78]]}},
 {"type":"Feature","properties":{"shape_id":"R069_vuelta","route_id":"R069","nombre_comun":"Trufi Los Piyos Blanco","sentido":"vuelta","km":16.4,"min":40,"operador":"Los Piyos","federacion":"16 de Noviembre","jurisdiccion":"Intermunicipal","color_panter":"Blanco","color_hex":"#8A8F98","zona_origen":"Centro","zona_destino":"La Guardia","geom_invertida_corregida":true,"zonas":"La Guardia ↔ Centro"},"geometry":{"type":"LineString","coordinates":[[-63.16,-17.78],[-63.19,-17.81]]}},
 {"type":"Feature","properties":{"shape_id":"R054_ida","route_id":"R054","nombre_comun":"1er Anillo Blanco (ATL)","sentido":"ida","km":6.58,"min":22,"operador":"ATL","federacion":"Fedetracruz","jurisdiccion":"Urbano","color_panter":"Blanco","color_hex":"#8A8F98","zona_origen":"Centro","zona_destino":"Centro","zonas":"1er Anillo"},"geometry":{"type":"LineString","coordinates":[[-63.190,-17.785],[-63.180,-17.785],[-63.180,-17.775],[-63.190,-17.775],[-63.190,-17.785]]}}
]}
''';

    const csv = '''
route_id,nombre_crudo,nombre_comun,nombre_revisar,motivo_revisar,zonas,operador,tipo_entidad,federacion,jurisdiccion,color_panter,banderin,color_hex,color_hex_2
R069,"ASOC. LOS PIYOS","Trufi Los Piyos Blanco",False,,La Guardia ↔ Centro,Los Piyos,Asociación,16 de Noviembre,Intermunicipal,Blanco,,#8A8F98,
R054,"ASOC. ATL","1er Anillo Blanco (ATL)",True,nombre dudoso,1er Anillo,ATL,Asociación,Fedetracruz,Urbano,Blanco,,#8A8F98,
''';

    late CatalogoRutas catalogo;

    setUp(() {
      catalogo = AnalizadorRutas.desdeGeoJson(geo, csv: csv);
    });

    test('agrupa ida y vuelta y marca la geometría corregida', () {
      expect(catalogo.rutas, hasLength(2));
      expect(catalogo.totalTrazos, 3);
      final piyos = catalogo.porId('R069')!;
      expect(piyos.ida!.km, 15.86);
      expect(piyos.vuelta!.minutos, 40);
      expect(piyos.vuelta!.geomInvertidaCorregida, isTrue);
      expect(piyos.tipoEntidad, 'Asociación');
      expect(catalogo.porId('R054')!.nombreRevisar, isTrue);
      expect(catalogo.porId('R054')!.motivoRevisar, 'nombre dudoso');
    });

    test('busca por zona sin tildes y filtra jurisdicción', () {
      expect(catalogo.buscar('piyós').map((r) => r.routeId), ['R069']);
      expect(catalogo.buscar('anillo', jurisdiccion: 'urbano'), hasLength(1));
      expect(
          catalogo.buscar('anillo', jurisdiccion: 'intermunicipal'), isEmpty);
      expect(catalogo.urbanas, 1);
      expect(catalogo.intermunicipales, 1);
    });

    test('ordena las rutas cerca de un punto', () {
      final cercanas = catalogo.cercaDe(const Coord(-17.78, -63.185));
      expect(cercanas.first.ruta.routeId, 'R054');
      expect(cercanas.first.metros, lessThan(cercanas.last.metros));
    });
  });

  group('GeoJSON real', () {
    test('carga las 126 rutas y 250 sentidos', () {
      final archivo = File('../../datos/rutas.geojson');
      final csv = File('../../datos/rutas_nombres.csv');
      expect(archivo.existsSync(), isTrue, reason: archivo.path);
      final catalogo = AnalizadorRutas.desdeGeoJson(
        archivo.readAsStringSync(),
        csv: csv.readAsStringSync(),
      );
      expect(catalogo.rutas, hasLength(126));
      expect(catalogo.totalTrazos, 250);
      expect(catalogo.urbanas + catalogo.intermunicipales, 126);
      final piyos = catalogo.buscar('Los Piyós');
      expect(piyos.any((r) => r.nombreComun.contains('Los Piyos')), isTrue);
      final anillos = catalogo.buscar('1er anillo');
      expect(anillos, isNotEmpty);
      final corregidos = catalogo.rutas
          .expand((r) => r.tramos)
          .where((t) => t.geomInvertidaCorregida)
          .length;
      expect(corregidos, greaterThan(0));
    });
  });

  group('Libro y pagos', () {
    final firmador = FirmadorTokens(secretoPrueba);
    final servicio =
        ServicioPagos(firmador: firmador, tarifas: TablaTarifas.porDefecto);
    final ahora = DateTime.utc(2026, 11, 21, 16, 24);

    LibroMayor conSaldo(int centavos) {
      final recarga = servicio.recargar(
        libro: LibroMayor(),
        cuentaId: 'pasajero-demo',
        centavos: centavos,
        claveIdempotencia: 'recarga-inicial',
        ahora: ahora,
        enLinea: true,
        medio: 'demo',
        numeroOperacion: 'KF-261121-0001',
      );
      return recarga.libro;
    }

    TokenPago token({
      DateTime? vence,
      bool usoUnico = true,
      String id = 'tok-1',
    }) {
      return firmador.sellar(
        TokenPago(
          id: id,
          vehiculoId: 'BUS-69',
          cuentaChoferId: 'chofer-demo',
          rutaId: 'R069',
          sentido: 'ida',
          nombreRuta: 'Trufi Los Piyos Blanco',
          emitidoEn: ahora,
          venceEn: vence ?? ahora.add(const Duration(seconds: 45)),
          nonce: 'n-$id',
          firma: '',
          usoUnico: usoUnico,
        ),
      );
    }

    SolicitudCobro solicitud(TokenPago qr,
        {String clave = 'cobro-1',
        bool enLinea = true,
        int pasajeros = 1,
        TipoPasaje tipo = TipoPasaje.adulto,
        DateTime? momento}) {
      return SolicitudCobro(
        claveIdempotencia: clave,
        cuentaPasajeroId: 'pasajero-demo',
        cuentaChoferId: qr.cuentaChoferId,
        tipoPasaje: tipo,
        pasajeros: pasajeros,
        medio: 'qr',
        ahora: momento ?? ahora,
        enLinea: enLinea,
        numeroOperacion: 'KF-261121-0007',
        rutaId: qr.rutaId,
        nombreRuta: qr.nombreRuta,
        operador: 'Los Piyos',
        sentido: qr.sentido,
        vehiculoId: qr.vehiculoId,
        token: qr,
      );
    }

    test('cobra una vez y rechaza el segundo intento con la misma clave', () {
      final qr = token();
      final primero = servicio.cobrar(
        libro: conSaldo(5000),
        tokensUsados: {},
        solicitud: solicitud(qr),
      );
      expect(primero.aceptado, isTrue);
      expect(primero.montoCentavos, 230);
      expect(primero.saldoPasajero, 4770);
      expect(primero.libro.saldoDe('chofer-demo'), 230);
      expect(primero.tokensUsados, contains('tok-1'));

      final segundo = servicio.cobrar(
        libro: primero.libro,
        tokensUsados: primero.tokensUsados,
        solicitud: solicitud(qr, clave: 'cobro-2'),
      );
      expect(segundo.aceptado, isFalse);
      expect(segundo.motivo, MotivoRechazo.yaCobrado);
      expect(segundo.libro.saldoDe('pasajero-demo'), 4770);
    });

    test('no descuenta si el saldo no alcanza', () {
      final qr = token();
      final resultado = servicio.cobrar(
        libro: conSaldo(120),
        tokensUsados: {},
        solicitud: solicitud(qr),
      );
      expect(resultado.motivo, MotivoRechazo.saldoInsuficiente);
      expect(resultado.saldoPasajero, 120);
      expect(resultado.faltaCentavos, 110);
      expect(resultado.libro.movimientos, hasLength(1));
    });

    test('rechaza firma rota o token vencido sin tocar el saldo', () {
      final qr = token();
      final roto =
          TokenPago.fromJson({...qr.toJson(), 'firma': 'no-es-valida'});
      final firma = servicio.cobrar(
        libro: conSaldo(5000),
        tokensUsados: {},
        solicitud: solicitud(roto),
      );
      expect(firma.motivo, MotivoRechazo.firmaInvalida);

      final viejo = token(
          vence: ahora.subtract(const Duration(seconds: 1)), id: 'tok-viejo');
      final vencido = servicio.cobrar(
        libro: conSaldo(5000),
        tokensUsados: {},
        solicitud: solicitud(viejo, clave: 'cobro-viejo'),
      );
      expect(vencido.motivo, MotivoRechazo.tokenVencido);
    });

    test('en modo sin conexión guarda el pasaje y la sync no lo duplica', () {
      final qr = token(id: 'tok-off');
      final cobro = servicio.cobrar(
        libro: conSaldo(5000),
        tokensUsados: {},
        solicitud: solicitud(qr, clave: 'off-1', enLinea: false),
      );
      expect(cobro.aceptado, isTrue);
      expect(cobro.pendienteDeSync, isTrue);
      expect(cobro.libro.pendientes, 2);

      final sincronizado = cobro.libro.sincronizar();
      expect(sincronizado.pendientes, 0);
      expect(sincronizado.saldoDe('pasajero-demo'), cobro.saldoPasajero);

      final replay = servicio.cobrar(
        libro: sincronizado,
        tokensUsados: cobro.tokensUsados,
        solicitud: solicitud(qr, clave: 'off-1', enLinea: true),
      );
      expect(replay.duplicado, isTrue);
      expect(sincronizado.saldoDe('pasajero-demo'), 4770);
    });

    test('bloquea un segundo cobro del mismo vehículo dentro de la ventana',
        () {
      final primeroQr = token(id: 'tok-a', usoUnico: true);
      final libro = servicio
          .cobrar(
            libro: conSaldo(5000),
            tokensUsados: {},
            solicitud: solicitud(primeroQr, clave: 'a'),
          )
          .libro;
      final otro = token(id: 'tok-b');
      final seguido = servicio.cobrar(
        libro: libro,
        tokensUsados: {'tok-a'},
        solicitud: solicitud(
          otro,
          clave: 'b',
          momento: ahora.add(const Duration(seconds: 30)),
        ),
      );
      expect(seguido.motivo, MotivoRechazo.cobroReciente);
      expect(libro.saldoDe('pasajero-demo'), 4770);
    });

    test('el QR firmado se puede leer y las tarifas salen del diseño', () {
      final qr = token();
      final leido = CodigoQrPago.leer(CodigoQrPago.emitir(qr));
      expect(firmador.verificar(leido), isTrue);
      expect(leido.rutaId, 'R069');
      expect(TablaTarifas.porDefecto.montoDe(TipoPasaje.estudiante), 100);
      expect(TablaTarifas.porDefecto.montoDe(TipoPasaje.nino), 100);
      expect(TablaTarifas.porDefecto.montoDe(TipoPasaje.adultoMayor), 150);
    });

    test('deshacer agrega un reverso y no borra el apunte original', () {
      final qr = token(id: 'tok-des');
      final cobro = servicio.cobrar(
        libro: conSaldo(5000),
        tokensUsados: {},
        solicitud: solicitud(qr, clave: 'des'),
      );
      final revertido = servicio.revertir(
        libro: cobro.libro,
        pagoId: cobro.pagoId!,
        ahora: ahora.add(const Duration(minutes: 1)),
        enLinea: true,
      );
      expect(revertido.aceptado, isTrue);
      expect(revertido.saldoPasajero, 5000);
      expect(revertido.libro.movimientos.length,
          greaterThan(cobro.libro.movimientos.length));
      final otraVez = servicio.revertir(
        libro: revertido.libro,
        pagoId: cobro.pagoId!,
        ahora: ahora,
        enLinea: true,
      );
      expect(otraVez.duplicado, isTrue);
    });

    test('el cierre suma por tipo de pasaje y separa lo pendiente', () {
      var libro = conSaldo(20000);
      var usados = <String>{};
      final casos = [
        (TipoPasaje.adulto, true, 'ad-1'),
        (TipoPasaje.adulto, false, 'ad-2'),
        (TipoPasaje.estudiante, true, 'es-1'),
        (TipoPasaje.adultoMayor, true, 'am-1'),
      ];
      for (final caso in casos) {
        final qr = token(
          id: caso.$3,
          usoUnico: true,
          vence: ahora.add(const Duration(hours: 3)),
        );
        final resultado = servicio.cobrar(
          libro: libro,
          tokensUsados: usados,
          solicitud: SolicitudCobro(
            claveIdempotencia: caso.$3,
            cuentaPasajeroId: 'pasajero-demo',
            cuentaChoferId: 'chofer-demo',
            tipoPasaje: caso.$1,
            pasajeros: 1,
            medio: 'manual',
            ahora: ahora.add(Duration(minutes: casos.indexOf(caso) + 10)),
            enLinea: caso.$2,
            numeroOperacion: caso.$3,
            rutaId: 'R069',
            nombreRuta: 'Trufi Los Piyos Blanco',
            vehiculoId: 'otro-bus-${caso.$3}',
            token: qr,
          ),
        );
        expect(resultado.aceptado, isTrue, reason: caso.$3);
        libro = resultado.libro;
        usados = resultado.tokensUsados;
      }
      final resumen =
          ResumenTurno.desde(libro: libro, cuentaChoferId: 'chofer-demo');
      expect(resumen.viajes, 4);
      expect(resumen.pasajeros, 4);
      expect(resumen.totalCentavos, 230 + 230 + 100 + 150);
      expect(resumen.pagosPendientes, 1);
      expect(resumen.centavosPendientes, 230);
      expect(resumen.porTipo.first.tipo, TipoPasaje.adulto);
      expect(resumen.porTipo.first.viajes, 2);
    });
  });

  group('Bluetooth y NFC', () {
    test('se queda con la señal fuerte y descarta el RSSI bajo o la firma mala',
        () {
      final firmador = FirmadorAnuncios(secretoPrueba);
      final ahora = DateTime.utc(2026, 11, 21, 12);
      AnuncioVehiculo anuncio(String id, int rssi) {
        return firmador.sellar(
          AnuncioVehiculo(
            vehiculoId: id,
            cuentaChoferId: 'chofer-demo',
            rutaId: 'R069',
            nombreRuta: 'Trufi Los Piyos',
            sentido: 'ida',
            operador: 'Los Piyos',
            jurisdiccion: 'Intermunicipal',
            panter: 'Blanco',
            rssi: rssi,
            nonce: 'turno-1',
            venceEn: ahora.add(const Duration(minutes: 5)),
            firma: '',
          ),
        );
      }

      final debil = anuncio('lejos', -95);
      final lejosPeroVisible = anuncio('medio', -84);
      final cerca = anuncio('cerca', -55);
      final falso = AnuncioVehiculo(
        vehiculoId: 'falso',
        cuentaChoferId: 'otro',
        rutaId: 'R001',
        nombreRuta: 'Falso',
        sentido: 'ida',
        operador: 'Nadie',
        jurisdiccion: 'Urbano',
        panter: 'Rojo',
        rssi: -40,
        nonce: 'x',
        venceEn: ahora.add(const Duration(minutes: 5)),
        firma: 'firma-rota',
      );
      final lista = FiltroAnuncios.detectados(
        [debil, lejosPeroVisible, cerca, falso],
        ahora: ahora,
        firmador: firmador,
      );
      expect(lista.map((a) => a.vehiculoId), ['cerca', 'medio']);
      expect(lista.first.etiquetaSenal, contains('fuerte'));
    });

    test('en iOS el NFC queda como no disponible y el QR siempre sirve', () {
      expect(TransportesDePago.qr.funcionaSinHardware, isTrue);
      expect(TransportesDePago.nfc(PlataformaNfc.ios).descripcion,
          contains('HCE'));
      expect(TransportesDePago.nfc(PlataformaNfc.android).descripcion,
          contains('opcional'));
    });
  });
}
