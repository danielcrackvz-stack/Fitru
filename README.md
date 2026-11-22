# Subí

Subí es la billetera para pagar trufis y minibuses en Santa Cruz de la Sierra. El lema es **Subí y pagá con un toque**. Hay dos roles en la misma app Flutter: **pasajero** y **chofer**. Trae las 126 rutas reales (250 recorridos ida/vuelta) y un libro de pagos que no se borra ni cobra dos veces.

El nombre visible es Subí. Los paquetes Dart siguen llamándose `kufi` y `kufi_core` para no romper imports ni el historial del repositorio. Esa decisión está anotada en [docs/NOMBRE.md](docs/NOMBRE.md).

El plan técnico está en [docs/PLAN.md](docs/PLAN.md). La auditoría de seguridad está en [docs/AUDITORIA_SEGURIDAD.md](docs/AUDITORIA_SEGURIDAD.md).

## Estructura

```
apps/kufi/                 App Flutter (mapa, pago, chofer)
packages/kufi_core/        Modelos, rutas, libro y protocolo. Sin Flutter
backend/migraciones/       SQL para Postgres + PostGIS (también sirve en Supabase)
backend/semilla/           Carga de las 126 rutas
datos/                     GeoJSON y CSV de origen
docs/                      Plan, auditoría y capturas
.github/workflows/ci.yml   Analyze, tests y APK de depuración
```

Hoy la app no se conecta a una base en la nube: el saldo y el libro viven en el teléfono. Postgres queda preparado para cuando haya servidor.

## Cómo correrla

Hace falta Flutter 3.35 o más nuevo (en el equipo ya corrió con 3.47). El SDK del proyecto acepta Dart 3.8 en adelante, incluido 3.13 y 3.14.

```bash
cd apps/kufi
flutter pub get
flutter run -d chrome
```

En un celular Android:

```bash
cd apps/kufi
flutter build apk --debug
```

El archivo queda en `apps/kufi/build/app/outputs/flutter-apk/app-debug.apk`.

## APK para el equipo

El APK de depuración pesa más de 150 MB. Para el celular usa el release partido por ABI (firma de depuración, R8 activo). En un teléfono actual baja el **arm64**.

Cada push a `main` publica dos artifacts:

- `kufi-apk-debug`: un solo APK de depuración, pesado.
- `subi-apk-release`: `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk` y `app-x86_64-release.apk`.

La demo para el celular es el prerelease v0.4.0, con `Subi-v0.4.0-arm64.apk` y `Subi-v0.4.0-armv7.apk`:

https://github.com/danielcrackvz-stack/Fitru/releases/tag/v0.4.0-demo

La v0.3.0 sigue en https://github.com/danielcrackvz-stack/Fitru/releases/tag/v0.3.0-demo

Corridas: https://github.com/danielcrackvz-stack/Fitru/actions/workflows/ci.yml

## Cuentas de demostración

Las dos usan el PIN `1234`. Un registro nuevo no acepta ese PIN ni `1111`: es solo para estas cuentas ya creadas.

| Rol | Persona | Qué ver |
| --- | --- | --- |
| Pasajero | Juanito Perez Gonzales | Saldo Bs 50,00, mapa, NFC, Bluetooth y QR |
| Chofer | Carlos Mamani | Turno, cobro y cierre. «Ver un día de ejemplo» arma 37 pasajeros |

Para recuperar el PIN, el SMS de la demo es `481936`.

En el perfil se cambia de rol, se simula la falta de internet y se simula un lector que no responde.

## Mapa y pago

El mapa dibuja las 250 polilíneas con el color del panter. La ida va continua y la vuelta punteada. La búsqueda ignora tildes (`piyos`, `1er anillo`). Si no hay permiso de ubicación, el centro es Santa Cruz. El bus que se mueve sobre la línea es una posición simulada.

Inicio es la billetera: saldo, recarga, pago por NFC, Bluetooth o QR, y los últimos viajes. Una tarjeta chica, «¿A dónde vas?», abre la pestaña Mapa.

En Mapa se elige el origen y el destino: con el GPS, tocando el mapa o buscando el lugar. Si no hay GPS, se marca el punto en el mapa. La hoja de abajo lista las opciones por tiempo, con la caminata y el tramo de cada línea. La comparación con Cruzero y Trufi está en [docs/COMPARATIVA.md](docs/COMPARATIVA.md).

Para un ruteador futuro:

```bash
python3 tools/exportar_gtfs.py
```

Las paradas de ese GTFS son sintéticas, cada 300 m. El detalle y el límite de cobertura (sin Pentaguazú, Monte Carmelo ni Satélite Norte) están en [docs/IMPLEMENTACION_INDEPENDIENTE.md](docs/IMPLEMENTACION_INDEPENDIENTE.md).

El QR del chofer está firmado, vence y sirve una sola vez. En Android el chofer también anuncia por Bluetooth y el pasajero filtra por la señal. NFC es opcional y no existe en iPhone. Sin conexión el pasaje se guarda y se envía después, sin cobrarse dos veces.

## Base de datos (cuando haga falta)

```bash
psql "$DATABASE_URL" -f backend/migraciones/001_extensiones.sql
psql "$DATABASE_URL" -f backend/migraciones/002_gtfs_rutas.sql
psql "$DATABASE_URL" -f backend/migraciones/003_billetera.sql
psql "$DATABASE_URL" -f backend/migraciones/004_rls_seguridad.sql
python3 backend/semilla/generar_semilla.py
psql "$DATABASE_URL" -f backend/semilla/rutas.sql
```

Las variables están en [.env.example](.env.example). No hay secretos reales en el repo.

## Tests

```bash
cd packages/kufi_core && dart test
cd apps/kufi && flutter analyze && flutter test
```

## Capturas

Están en [docs/capturas](docs/capturas). Con la app en el navegador, `/captura/mapa` y `/captura/inicio` arman la demo sin pedir el PIN.
