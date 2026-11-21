# Kufi

Billetera móvil para pagar trufis y minibuses en Santa Cruz de la Sierra. Una app Flutter con dos roles, **pasajero** y **chofer**, el catálogo real de 126 rutas y un libro mayor que no se puede borrar ni cobrar dos veces.

El plan de arquitectura, el modelo PostGIS y el reparto del equipo están en [docs/PLAN.md](docs/PLAN.md).

## Qué hay en el repo

```
apps/kufi/                 App Flutter (mapa, pago, chofer)
packages/kufi_core/        Modelos, rutas, libro y protocolo. Sin Flutter
backend/migraciones/       SQL para Postgres + PostGIS (también sirve en Supabase)
backend/semilla/           Generador y carga de las 126 rutas
datos/                     GeoJSON y CSV de origen
docs/PLAN.md               Decisiones y tareas por persona
```

## Cómo correrla

Hace falta Flutter 3.35 o más nuevo (el CI usa el canal stable).

```bash
cd apps/kufi
flutter pub get
flutter run
```

En el navegador, para mirar el mapa sin un teléfono:

```bash
cd apps/kufi
flutter run -d web-server --web-port 8080
```

Teselas de producción, si las tienen:

```bash
flutter run --dart-define=TILE_URL_TEMPLATE='https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=TU_LLAVE' \
            --dart-define=TILE_ATTRIBUTION='© MapTiler © OpenStreetMap'
```

Sin ese define se usan las teselas públicas de OpenStreetMap, solo para desarrollo, con la atribución puesta en el mapa.

### Cuentas de demostración

Las dos usan el PIN `1234`.

| Rol | Persona | Qué ver |
| --- | --- | --- |
| Pasajero | Juanito Perez Gonzales | Saldo Bs 50,00, mapa, NFC, Bluetooth y QR |
| Chofer | Carlos Mamani | Turno, cobro y cierre. «Ver un día de ejemplo» arma el día de 37 pasajeros |

Para recuperar el PIN, el SMS de la demo es `481936`.

En el perfil se puede cambiar de rol, simular que no hay internet y simular un lector que no responde. Las tarifas se editan ahí mismo: están sacadas del diseño y hay que confirmarlas con cada asociación.

## Mapa

El mapa dibuja las 250 polilíneas (ida continua, vuelta punteada) con el color del panter. Se puede buscar por zona sin preocuparse por las tildes (`piyos`, `1er anillo`), filtrar urbanas e intermunicipales y tocar una línea para abrir la ficha. «Rutas que pasan cerca» usa la ubicación del teléfono o, si no hay permiso, el centro de Santa Cruz. El bus que se mueve sobre el trazado es una posición simulada: no hay GPS de la flota.

## Pago

El QR del chofer está firmado (HMAC-SHA256), vence y sirve una sola vez. Bluetooth anuncia el vehículo y la ruta; el pasajero se queda con la señal más fuerte y descarta lo que esté por debajo de −90 dBm. NFC queda como opción de Android; en iPhone la pantalla explica que no hay HCE.

Si se corta la red, el pasaje se guarda en el teléfono y se sincroniza después. La misma clave no descuenta dos veces. El detalle está en el plan.

## Base de datos

No hace falta para la demo. Cuando quieran Postgres:

```bash
psql "$DATABASE_URL" -f backend/migraciones/001_extensiones.sql
psql "$DATABASE_URL" -f backend/migraciones/002_gtfs_rutas.sql
psql "$DATABASE_URL" -f backend/migraciones/003_billetera.sql
python3 backend/semilla/generar_semilla.py
psql "$DATABASE_URL" -f backend/semilla/rutas.sql
```

Las variables están en [.env.example](.env.example). No hay secretos reales en el repo.

## Tests

```bash
cd packages/kufi_core && dart test
cd apps/kufi && flutter analyze && flutter test
```

GitHub Actions corre lo mismo en cada pull request.

## Capturas

Con la app web ya compilada, estas rutas arman el estado de demostración sin pasar por el PIN:

- `/captura/mapa`
- `/captura/detalle`
- `/captura/inicio`
- `/captura/confirmar`
- `/captura/cobro`
- `/captura/cierre`

Las imágenes de una corrida están en [docs/capturas](docs/capturas).
