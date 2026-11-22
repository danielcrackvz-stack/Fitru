import 'package:flutter_test/flutter_test.dart';
import 'package:kufi/estado/estado_kufi.dart';
import 'package:kufi/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el origen ofrece GPS y marcar en el mapa', (tester) async {
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
    await tester.tap(find.text('¿A dónde vas?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Elegí el origen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Usar mi ubicación actual'), findsOneWidget);
    expect(find.text('Marcar en el mapa'), findsOneWidget);
    expect(find.text('Buscá un lugar'), findsOneWidget);

    await tester.tap(find.text('Marcar en el mapa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tocá el mapa para marcar tu ORIGEN'), findsOneWidget);
    expect(find.text('Confirmar origen'), findsOneWidget);
  });

  testWidgets('sin GPS el origen pasa a marcarse en el mapa', (tester) async {
    final estado = EstadoKufi.paraPruebas(onboardingListo: true);
    estado.permisoUbicacion = false;
    estado.ubicacionEsEjemplo = true;
    await tester.pumpWidget(KufiApp(estado: estado));
    await tester.pumpAndSettle();
    for (final digito in ['1', '2', '3', '4']) {
      await tester.ensureVisible(find.text(digito));
      await tester.tap(find.text(digito));
      await tester.pump();
    }
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿A dónde vas?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Elegir origen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Usar mi ubicación actual'));
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tocá el mapa para marcar tu ORIGEN'), findsOneWidget);
    expect(find.textContaining('No hay GPS'), findsOneWidget);
  });
}
