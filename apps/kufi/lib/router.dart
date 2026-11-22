import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'estado/estado_kufi.dart';
import 'estado/modelos_app.dart';
import 'ui/acceso/pantallas_acceso.dart';
import 'ui/chofer/pantallas_chofer.dart';
import 'ui/legal/pantalla_legal.dart';
import 'ui/mapa/pantalla_detalle.dart';
import 'ui/mapa/pantalla_explorar.dart';
import 'ui/mapa/pantalla_mapa.dart';
import 'ui/mapa/pantalla_viaje.dart';
import 'ui/pago/pantallas_pago.dart';
import 'ui/pasajero/pantallas_pasajero.dart';
import 'ui/widgets.dart';

GoRouter crearRouter(EstadoKufi estado) {
  return GoRouter(
    initialLocation: rutaInicial(estado),
    refreshListenable: estado,
    redirect: (context, state) {
      final loc = state.uri.path;
      if (loc.startsWith('/captura')) return null;
      if (!estado.onboardingListo && loc != '/bienvenida') return '/bienvenida';
      if (estado.onboardingListo &&
          !estado.permisosVistos &&
          loc != '/permisos' &&
          loc != '/bienvenida') {
        return '/permisos';
      }
      const publicas = {
        '/bienvenida',
        '/permisos',
        '/ingresar',
        '/registro',
        '/recuperar',
        '/nuevo-pin',
        '/verificacion',
        '/legal/terminos',
        '/legal/privacidad',
      };
      if (estado.sesion == null && !publicas.contains(loc)) return '/ingresar';
      if (estado.sesion != null &&
          (loc == '/ingresar' || loc == '/bienvenida' || loc == '/permisos')) {
        return estado.sesion!.rol == Rol.chofer
            ? '/chofer/cobro'
            : '/pasajero/inicio';
      }
      if (estado.sesion?.rol == Rol.pasajero && loc.startsWith('/chofer'))
        return '/pasajero/inicio';
      if (estado.sesion?.rol == Rol.chofer &&
          loc.startsWith('/pasajero') &&
          loc != '/pasajero/perfil') {
        return '/chofer/cobro';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/bienvenida',
        builder: (context, state) => const PantallaBienvenida(),
      ),
      GoRoute(
        path: '/permisos',
        builder: (context, state) => const PantallaPermisos(),
      ),
      GoRoute(
        path: '/ingresar',
        builder: (context, state) => const PantallaIngreso(),
      ),
      GoRoute(
        path: '/registro',
        builder: (context, state) => const PantallaRegistro(),
      ),
      GoRoute(
        path: '/legal/terminos',
        builder: (context, state) =>
            const PantallaLegal(titulo: 'Términos', cuerpo: textoTerminos),
      ),
      GoRoute(
        path: '/legal/privacidad',
        builder: (context, state) =>
            const PantallaLegal(titulo: 'Privacidad', cuerpo: textoPrivacidad),
      ),
      GoRoute(
        path: '/verificacion',
        builder: (context, state) => const PantallaVerificacion(),
      ),
      GoRoute(
        path: '/recuperar',
        builder: (context, state) => const PantallaRecuperarPin(),
      ),
      GoRoute(
        path: '/nuevo-pin',
        builder: (context, state) => const PantallaNuevoPin(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            CascaronPasajero(ruta: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/pasajero/inicio',
            builder: (context, state) => const PantallaInicio(),
          ),
          GoRoute(
            path: '/pasajero/mapa',
            builder: (context, state) => const PantallaMapa(),
          ),
          GoRoute(
            path: '/pasajero/recarga',
            builder: (context, state) => const PantallaRecarga(),
          ),
          GoRoute(
            path: '/pasajero/perfil',
            builder: (context, state) => const PantallaPerfil(),
          ),
        ],
      ),
      GoRoute(
        path: '/pasajero/buscar',
        builder: (context, state) => const PantallaBuscar(),
      ),
      GoRoute(
        path: '/pasajero/rutas',
        builder: (context, state) => const PantallaExplorar(),
      ),
      GoRoute(
        path: '/pasajero/viaje',
        builder: (context, state) => const PantallaViaje(),
      ),
      GoRoute(
        path: '/pasajero/historial',
        builder: (context, state) => const PantallaHistorial(),
      ),
      GoRoute(
        path: '/ruta/:id',
        builder: (context, state) =>
            PantallaDetalleRuta(routeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pago/nfc',
        builder: (context, state) => const PantallaNfc(),
      ),
      GoRoute(
        path: '/pago/ble',
        builder: (context, state) => const PantallaBle(),
      ),
      GoRoute(
        path: '/pago/qr',
        builder: (context, state) => const PantallaQrPasajero(),
      ),
      GoRoute(
        path: '/pago/confirmar',
        builder: (context, state) => const PantallaConfirmarPago(),
      ),
      GoRoute(
        path: '/pago/manual',
        builder: (context, state) => const PantallaManual(),
      ),
      GoRoute(
        path: '/pago/resultado',
        builder: (context, state) => const PantallaResultado(),
      ),
      GoRoute(
        path: '/recibo/:id',
        builder: (context, state) =>
            PantallaRecibo(pagoId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chofer/turno',
        builder: (context, state) => const PantallaTurno(),
      ),
      GoRoute(
        path: '/chofer/cobro',
        builder: (context, state) => const PantallaCobro(),
      ),
      GoRoute(
        path: '/chofer/cierre',
        builder: (context, state) => const PantallaCierre(),
      ),
      GoRoute(
        path: '/chofer/detalle',
        builder: (context, state) => const PantallaDetalleChofer(),
      ),
      GoRoute(
        path: '/chofer/qr',
        builder: (context, state) => const PantallaQrChofer(),
      ),
      GoRoute(
        path: '/captura/:pantalla',
        builder: (context, state) =>
            PantallaCaptura(pantalla: state.pathParameters['pantalla']!),
      ),
    ],
  );
}

String rutaInicial(EstadoKufi estado) {
  final captura = estado.captura;
  if (captura != null) return '/captura/$captura';
  if (!estado.onboardingListo) return '/bienvenida';
  if (!estado.permisosVistos) return '/permisos';
  if (estado.sesion == null) return '/ingresar';
  return estado.sesion!.rol == Rol.chofer
      ? '/chofer/cobro'
      : '/pasajero/inicio';
}

class PantallaCaptura extends StatelessWidget {
  const PantallaCaptura({required this.pantalla, super.key});

  final String pantalla;

  @override
  Widget build(BuildContext context) {
    final pagina = switch (pantalla) {
      'bienvenida' => const PantallaBienvenida(),
      'permisos' => const PantallaPermisos(),
      'ingreso' => const PantallaIngreso(),
      'registro' => const PantallaRegistro(),
      'verificacion' => const PantallaVerificacion(),
      'inicio' => const PantallaInicio(),
      'mapa' => const PantallaMapa(),
      'recarga' => const PantallaRecarga(),
      'perfil' => const PantallaPerfil(),
      'buscar' => const PantallaBuscar(),
      'detalle' => const PantallaDetalleRuta(routeId: 'R069'),
      'nfc' => const PantallaNfc(),
      'ble' => const PantallaBle(),
      'qr' => const PantallaQrPasajero(),
      'confirmar' => const PantallaConfirmarPago(),
      'manual' => const PantallaManual(),
      'saldo' || 'rechazo' || 'sin-conexion' => const PantallaResultado(),
      'recibo' => const PantallaRecibo(pagoId: 'ultima'),
      'historial' => const PantallaHistorial(),
      'cobro' => const PantallaCobro(),
      'cierre' => const PantallaCierre(),
      'qr-chofer' => const PantallaQrChofer(),
      'turno' => const PantallaTurno(),
      _ => const PantallaInicio(),
    };
    if (pantalla == 'inicio' ||
        pantalla == 'mapa' ||
        pantalla == 'recarga' ||
        pantalla == 'perfil') {
      return CascaronPasajero(ruta: '/pasajero/$pantalla', child: pagina);
    }
    return pagina;
  }
}
