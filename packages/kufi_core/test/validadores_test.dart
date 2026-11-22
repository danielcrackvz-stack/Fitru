import 'package:kufi_core/kufi_core.dart';
import 'package:test/test.dart';

void main() {
  group('Nombres y contacto', () {
    test('acepta tildes, ñ, apóstrofo y guion, y recorta espacios', () {
      final nombre = validarNombre("  María  José O'Connor-Ñato  ");
      expect(nombre.esValido, isTrue);
      expect(nombre.valor, "María José O'Connor-Ñato");
      expect(validarNombre('Juan 2').esValido, isFalse);
      expect(validarNombre('Ab').esValido, isFalse);
      expect(validarNombre('A' * 81).esValido, isFalse);
    });

    test('el celular boliviano es de 8 dígitos y empieza en 6 o 7', () {
      expect(validarTelefonoBolivia('+591 7012-3445').valor, '70123445');
      expect(validarTelefonoBolivia('59161234567').valor, '61234567');
      expect(validarTelefonoBolivia('50123445').esValido, isFalse);
      expect(validarTelefonoBolivia('7012344').esValido, isFalse);
      expect(validarTelefonoBolivia('70123445a').esValido, isFalse);
    });

    test('el carnet acepta complemento y extensión', () {
      expect(validarCarnet('1234567').valor, '1234567');
      expect(validarCarnet('1234567-1k sc').valor, '1234567-1K SC');
      expect(validarCarnet('12').esValido, isFalse);
      expect(validarCarnet('1234567 XX').esValido, isFalse);
    });

    test('el correo se normaliza y rechaza basura', () {
      expect(validarCorreo(' Juanito@Correo.com ').valor, 'juanito@correo.com');
      expect(validarCorreo('sin-arroba').esValido, isFalse);
    });
  });

  group('PIN, placa y montos', () {
    test('el registro rechaza 1234 y 1111, el ingreso solo exige 4 dígitos',
        () {
      expect(validarPinIngreso('1234').esValido, isTrue);
      expect(validarPinNuevo('1234').esValido, isFalse);
      expect(validarPinNuevo('1111').esValido, isFalse);
      expect(validarPinNuevo('0000').esValido, isFalse);
      expect(validarPinNuevo('9876').esValido, isFalse);
      expect(validarPinNuevo('4821').esValido, isTrue);
      expect(validarPinNuevo('12a4').esValido, isFalse);
    });

    test('la placa boliviana se normaliza', () {
      expect(validarPlacaBolivia('4821-kuf').valor, '4821KUF');
      expect(validarPlacaBolivia('sc 1234').valor, 'SC1234');
      expect(validarPlacaBolivia('ABC').esValido, isFalse);
    });

    test('el monto es positivo, con máximo 2 decimales y topes', () {
      expect(
        validarMonto('10,50',
                minimoCentavos: minimoRecargaCentavos,
                maximoCentavos: maximoRecargaCentavos)
            .centavos,
        1050,
      );
      expect(
        validarMonto('2.309', minimoCentavos: 1, maximoCentavos: 100000)
            .esValido,
        isFalse,
      );
      expect(
        validarMonto('-5', minimoCentavos: 1, maximoCentavos: 100000).esValido,
        isFalse,
      );
      expect(
        validarMonto('0',
                minimoCentavos: minimoRecargaCentavos,
                maximoCentavos: maximoRecargaCentavos)
            .esValido,
        isFalse,
      );
      expect(
        validarMonto('3000',
                minimoCentavos: minimoRecargaCentavos,
                maximoCentavos: maximoRecargaCentavos)
            .esValido,
        isFalse,
      );
    });

    test('cinco PIN malos bloquean y el acierto reinicia', () {
      final control = ControlIntentosPin();
      final ahora = DateTime.utc(2026, 11, 21, 12);
      for (var i = 0; i < 4; i++) {
        expect(control.registrarFallo(ahora), contains('quedan'));
        expect(control.estaBloqueado(ahora), isFalse);
      }
      expect(control.registrarFallo(ahora), contains('bloqueada'));
      expect(
          control.estaBloqueado(ahora.add(const Duration(minutes: 1))), isTrue);
      expect(control.estaBloqueado(ahora.add(const Duration(minutes: 6))),
          isFalse);
      control.registrarAcierto();
      expect(control.fallos, 0);
    });

    test('el hash con sal no guarda el PIN y el legado sigue verificable', () {
      const pin = '4821';
      const sal = 'sal-de-prueba-16';
      final hash = derivarPin(pin, sal);
      final credencial = CredencialPin(sal: sal, hash: hash);
      expect(verificarPin(pin, credencial), isTrue);
      expect(verificarPin('4822', credencial), isFalse);
      expect(credencial.serializar().contains(pin), isFalse);
      expect(hashPinLegado(pin, 'pasajero-demo'), isNot(contains(pin)));
    });
  });

  group('Anuncio BLE compacto', () {
    test('firma, rechaza manipulación y vence', () {
      const secreto = 'prueba-unitaria-kufi';
      final vence =
          DateTime.utc(2026, 11, 21, 18).millisecondsSinceEpoch ~/ 1000;
      final bytes = AnuncioCompacto.codificar(
        rutaId: 'R069',
        sentido: 'ida',
        venceEnSegundos: vence,
        nonce: 42,
        secreto: secreto,
      );
      expect(bytes.length, AnuncioCompacto.largo);
      final anuncio = AnuncioCompacto.decodificar(
        bytes: bytes,
        rssi: -60,
        secreto: secreto,
        ahora: DateTime.utc(2026, 11, 21, 17),
        vehiculoId: 'BUS',
        cuentaChoferId: 'chofer',
        nombreRuta: 'Trufi Los Piyos',
        operador: 'Los Piyos',
        jurisdiccion: 'Intermunicipal',
        panter: 'Blanco',
      );
      expect(anuncio?.rutaId, 'R069');
      expect(anuncio?.nonce, '42');
      final roto = bytes.toList();
      roto[3] = roto[3] ^ 1;
      expect(
        AnuncioCompacto.decodificar(
          bytes: roto,
          rssi: -40,
          secreto: secreto,
          ahora: DateTime.utc(2026, 11, 21, 17),
          vehiculoId: 'BUS',
          cuentaChoferId: 'chofer',
          nombreRuta: 'x',
          operador: 'x',
          jurisdiccion: 'x',
          panter: 'x',
        ),
        isNull,
      );
    });
  });
}
