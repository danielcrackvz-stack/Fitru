import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:kufi_core/kufi_core.dart';

import 'alcance.dart';
import 'estado/almacen_preferencias.dart';
import 'estado/almacen_secreto.dart';
import 'estado/estado_kufi.dart';
import 'router.dart';
import 'tema.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final secreto = AlmacenSecretoSeguro();
  final firmador = await firmadorDeArranque(secreto);
  final estado = EstadoKufi(
    almacen: AlmacenPreferencias(),
    secreto: secreto,
    firmador: firmador,
    cargador: () async {
      final geo = await rootBundle.loadString('assets/datos/rutas.geojson');
      final csv = await rootBundle.loadString('assets/datos/rutas_nombres.csv');
      return AnalizadorRutas.desdeGeoJson(geo, csv: csv);
    },
  );
  await estado.iniciar();
  final captura = capturaDesdeUrl();
  if (captura != null) await estado.prepararCaptura(captura);
  runApp(KufiApp(estado: estado));
}

String? capturaDesdeUrl() {
  final ruta = Uri.base.path;
  const prefijo = '/captura/';
  if (!ruta.startsWith(prefijo)) return null;
  final id = ruta.substring(prefijo.length).split('/').first;
  return id.isEmpty ? null : id;
}

class KufiApp extends StatefulWidget {
  const KufiApp({required this.estado, super.key});

  final EstadoKufi estado;

  @override
  State<KufiApp> createState() => _KufiAppState();
}

class _KufiAppState extends State<KufiApp> {
  late final _router = crearRouter(widget.estado);

  @override
  Widget build(BuildContext context) {
    return KufiScope(
      estado: widget.estado,
      child: MaterialApp.router(
        title: 'Kufi',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: temaKufi(),
        routerConfig: _router,
        builder: (context, child) {
          return Stack(
            children: [child ?? const SizedBox.shrink(), const BannerKufi()],
          );
        },
      ),
    );
  }
}
