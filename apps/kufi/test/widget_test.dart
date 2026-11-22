import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kufi/estado/estado_kufi.dart';
import 'package:kufi/main.dart';
import 'package:kufi_core/kufi_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la bienvenida explica cómo encontrar el trufi', (tester) async {
    final estado = EstadoKufi.paraPruebas();
    await tester.pumpWidget(KufiApp(estado: estado));
    expect(find.text('Encuentra tu trufi'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('el PIN de demostración abre el saldo', (tester) async {
    final estado = EstadoKufi.paraPruebas(onboardingListo: true);
    await tester.pumpWidget(KufiApp(estado: estado));
    await tester.pumpAndSettle();
    for (final digito in ['1', '2', '3', '4']) {
      await tester.ensureVisible(find.text(digito));
      await tester.tap(find.text(digito));
      await tester.pump();
    }
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Bs 50,00'), findsWidgets);
    expect(find.textContaining('Bienvenido'), findsOneWidget);
  });

  test('el GeoJSON empaquetado trae las 126 rutas', () async {
    final geo = await rootBundle.loadString('assets/datos/rutas.geojson');
    final csv = await rootBundle.loadString('assets/datos/rutas_nombres.csv');
    final catalogo = AnalizadorRutas.desdeGeoJson(geo, csv: csv);
    expect(catalogo.rutas, hasLength(126));
    expect(catalogo.totalTrazos, 250);
    expect(catalogo.buscar('Los Piyós'), isNotEmpty);
    expect(catalogo.buscar('1er anillo'), isNotEmpty);
  });

  test('el aviso de saldo bajo solo sale al cruzar el umbral', () {
    expect(
      correspondeAvisoSaldoBajo(antes: 600, despues: 370, umbral: 500),
      isTrue,
    );
    expect(
      correspondeAvisoSaldoBajo(antes: 400, despues: 170, umbral: 500),
      isFalse,
    );
  });
}
