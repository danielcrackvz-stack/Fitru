# Plan Subí

El nombre visible es Subí. Este plan conserva los nombres internos (`EstadoKufi`, `kufi_core`). Ver [NOMBRE.md](NOMBRE.md).

Billetera para pagar trufis y minibuses en Santa Cruz de la Sierra. Equipo de cuatro personas. Este documento fija la arquitectura del MVP, el modelo de datos y el reparto de trabajo.

Los trufis **no tienen número de línea**. La gente los llama por la zona y el color del panter: «1er Anillo», «Trufi Los Piyos», «panter blanco». Los identificadores `R001`–`R126` son internos y no se muestran como si fueran un número oficial.

## Decisiones

**Una sola app Flutter, con selector de rol.** Pasajero y chofer comparten diseño, modelos, libro y protocolo. Dos flavors (`--flavor pasajero` / `chofer`) duplicarían pantallas y el CI para un equipo de cuatro. El rol se elige al ingresar y se puede cambiar desde el perfil. Los permisos de la tienda (NFC, Bluetooth, ubicación) se piden una vez.

**El teléfono es la fuente de la demo; Postgres es la fuente de producción.** El libro mayor está escrito dos veces con las mismas reglas: en Dart (`packages/kufi_core`), para que la app funcione sin red y los tests no necesiten una base, y en SQL (`backend/migraciones`), para Supabase o cualquier Postgres con PostGIS. No metimos un servidor Node a medias: el contrato HTTP queda descrito abajo y la función `aplicar_pasaje` ya cobra en una transacción.

**QR dinámico firmado es el transporte que siempre funciona.** BLE anuncia vehículo y ruta y el pasajero filtra por RSSI. NFC por HCE queda detrás de una interfaz: en Android es opcional, en iOS no existe (Apple no deja emular una tarjeta). En la web y en esta máquina la radio está simulada; la firma, el vencimiento y el anti-doble-cobro no lo están.

**OpenStreetMap solo en desarrollo.** La URL de las teselas sale de `--dart-define=TILE_URL_TEMPLATE`. El valor por defecto es `tile.openstreetmap.org`, con atribución visible y el user-agent `dev.kufi.kufi` en móvil. En producción hay que cambiarlo por MapTiler, Stadia o un PMTiles propio. El navegador no deja fijar el User-Agent; por eso las teselas públicas no deben usarse en un despliegue real.

**Tarifas del diseño, marcadas como «por confirmar».** Adulto Bs 2,30, estudiante Bs 1,00, niño Bs 1,00, adulto mayor Bs 1,50. Se editan en el perfil y en la tabla `tarifas`. No son una tarifa oficial de la asociación.

**Sin secretos en el repo.** La clave HMAC de desarrollo es `kufi-dev-santa-cruz` y está en `.env.example`. Sirve para que el QR del chofer y el lector del pasajero coincidan en la demo. En producción la firma la verifica el servidor y esa clave no viaja dentro de la app del pasajero.

## Arquitectura

```
datos/                         GeoJSON + CSV (fuente)
packages/kufi_core/            Dart puro: rutas, libro, tokens, BLE, QR
apps/kufi/                     Flutter (pasajero, mapa, pago, chofer)
backend/migraciones/           Postgres + PostGIS
backend/semilla/               SQL generado desde el GeoJSON
```

```
┌──────────────────── app Flutter ────────────────────┐
│  pantallas pasajero / chofer                        │
│  EstadoKufi  (sesión, turno, avisos, preferencias)  │
│  kufi_core   (reglas puras, testeadas)              │
│  transporte: QR  |  BLE  |  NFC (interfaz)          │
└───────────────────────┬─────────────────────────────┘
                        │ cuando hay red: enviar apuntes
                        │ pendientes, clave de idempotencia
┌───────────────────────▼─────────────────────────────┐
│  Postgres / Supabase                                 │
│  rutas GTFS + geometría PostGIS                     │
│  libro_mayor inmutable + aplicar_pasaje()           │
└─────────────────────────────────────────────────────┘
```

La app guarda el estado en `shared_preferences`. Al volver la conexión, los apuntes `pendiente` pasan a `sincronizado` sin crear filas nuevas. Un segundo envío con la misma clave no descuenta otra vez.

## Modelo de datos

### Rutas (GTFS + PostGIS)

| Tabla | Rol |
| --- | --- |
| `agencias` | Federación (16 de Noviembre, Fedetracruz, 24 de Septiembre…) |
| `rutas` | Una fila por `route_id`. Nombre común, operador, jurisdicción, colores del panter y del banderín, `nombre_revisar` |
| `viajes` | Un viaje por sentido (`ida` / `vuelta`), con km, minutos y origen/destino |
| `shapes` | `geometry(LineString, 4326)` del trazado ya corregido |
| `shape_puntos` | La misma línea explotada al formato GTFS (`shape_id`, secuencia, lat, lon) |

El GeoJSON trae 250 trazos (125 ida y 125 vuelta: dos rutas tienen un solo sentido) de 126 rutas. Once sentidos llegan con `geom_invertida_corregida = true`; no se vuelven a invertir. El CSV aporta `motivo_revisar` y `tipo_entidad` cuando el nombre común es dudoso.

La búsqueda pliega tildes y mayúsculas (`Piyós` = `piyos`) y exige que todas las palabras aparezcan en el nombre, la zona, el operador o la federación. «Cerca de mí» es la distancia mínima del punto al trazado, no solo a los vértices.

### Billetera

El saldo **no se guarda**. Es `sum(centavos)` de la cuenta.

`libro_mayor` solo acepta inserciones. Un trigger rechaza `UPDATE` y `DELETE`. Cada apunte lleva `clave_idempotencia` única. Un pasaje son dos apuntes con la misma `pago_id`:

- débito del pasajero (`centavos` negativo)
- crédito del chofer (positivo)

`aplicar_pasaje(clave, pasajero, chofer, centavos, pago_id, meta)` abre la transacción, y si la clave ya existe devuelve el pago original sin mover plata. Si el saldo no alcanza, lanza `saldo_insuficiente` y no inserta nada.

Los tipos son `recarga`, `pasaje` y `reverso`. Deshacer un pago manual no borra: agrega un reverso con clave `reverso:{pagoId}`.

## Protocolo de pago

1. El chofer abre turno (ruta + sentido). Su teléfono anuncia por BLE `vehiculoId`, `rutaId`, `sentido`, `nonce` del turno y una firma HMAC-SHA256. En paralelo muestra un QR `kufi://pago/v1/{token}` que rota cada 45 segundos. Ese token es de **un solo uso** y vence a los 50 segundos.
2. El pasajero elige el medio:
   - **QR:** lee el payload, verifica firma, vencimiento y que la ruta y la cuenta del chofer coincidan con lo que se va a cobrar.
   - **BLE:** se queda con los anuncios de RSSI ≥ −90 dBm, ordenados por señal. Descarta firma inválida o anuncio vencido. El más fuerte se ofrece como «muy cerca».
   - **NFC:** misma confirmación, pero el transporte real (HCE) solo se habilita en Android y es opcional. En iOS la pantalla explica que hay que usar QR o Bluetooth.
3. El pasajero elige tarifa y cantidad (1 a 8) y confirma con PIN o huella. La huella de la demo no sale del teléfono: es un interruptor local, no un biométrico de servidor.
4. El servicio arma la clave:
   - QR: `qr-{id del token}` y el token queda consumido.
   - BLE/NFC/mapa: una clave por pasajero, vehículo y anuncio, más una ventana de 2 minutos que impide un segundo cobro del mismo vehículo.
   - Manual: clave nueva cada vez, para poder cobrar y luego deshacer.
5. Si la firma falla, el token venció, ya se usó, el saldo no alcanza o el mismo vehículo se cobró hace menos de 2 minutos, **no se escribe nada**.
6. Sin conexión el cobro igual se escribe, con `sync = pendiente`, si la firma y el saldo cierran en el teléfono. La pantalla «Sin conexión» avisa que el pago quedó guardado. Al volver la red se marcan sincronizados. Reenviar no duplica.

Montos en centavos enteros. En pantalla: `Bs 2,30`.

### Contrato para cuando exista el servidor

`POST /v1/sync` recibe los apuntes pendientes. El servidor llama a `aplicar_pasaje` con la misma clave. Una respuesta repetida devuelve el `pago_id` ya creado. El cliente solo entonces pasa el apunte a `sincronizado`. Hoy ese paso lo hace en local el modo «en línea», y el perfil puede simular la caída de red.

## Notificaciones

Cada pago, rechazo, recarga, saldo bajo (al cruzar Bs 5,00) y cobro del chofer crea un aviso en la app. En Android, iOS, macOS y Linux se intenta una notificación local (`flutter_local_notifications`); si el sistema no deja, queda el aviso en pantalla. FCM está preparado: `PuertaFcm` lee `FCM_PROJECT_ID` y no envía nada si está vacío. No hay `google-services.json` ni llave de servidor en el repo.

## Qué está simulado

| Pieza | Estado |
| --- | --- |
| Catálogo y trazados | Reales, los 126 del GeoJSON |
| Mapa OSM | Teselas reales en desarrollo |
| Posición del trufi | Se mueve a lo largo del trazado; no hay GPS de flota |
| Libro, firmas, idempotencia, tarifas | Reales en el dispositivo |
| QR | Payload firmado de verdad. El escáner de cámara queda para `mobile_scanner`; hoy se pega el código o se lee el QR del turno en el mismo teléfono |
| BLE y NFC | Protocolo y filtro RSSI reales; la radio es simulada para poder probar en web |
| Recarga, Tigo Money, tarjeta | Acreditan el libro; no hay pasarela |
| KYC | La cuenta nueva queda «en revisión» y puede mirar el mapa |
| SMS del PIN | El código de la demo es `481936` |
| Push FCM y Postgres | Preparados, no conectados |

Cuentas de la demo, PIN `1234`:

- Pasajero: Juanito Perez Gonzales, saldo Bs 50,00
- Chofer: Carlos Mamani. «Ver un día de ejemplo» carga el cierre de 37 pasajeros (30 adulto, 5 estudiante, 2 adulto mayor, dos pagos pendientes).

## Reparto sugerido

### 1. Datos y mapas

- Cuidar `datos/rutas.geojson` y `datos/rutas_nombres.csv`. Cuando se corrija un nombre, regenerar `backend/semilla/rutas.sql`.
- Revisar las 50 rutas con `nombre_revisar` (banderines que distinguen ramales, operadores que son una fecha).
- Afinar «cerca de mí» (paradas, no solo distancia al eje) y el estilo del mapa cuando hay muchos panter del mismo color.
- Conseguir teselas de producción (MapTiler, Stadia o PMTiles de Santa Cruz) y documentar la cuota.
- Sumar el sentido que falta en las dos rutas que hoy tienen uno solo.

### 2. Backend y libro

- Levantar Supabase o Postgres, aplicar las tres migraciones y la semilla.
- Exponer `POST /v1/sync` y `GET /v1/rutas` (puede devolver el GeoJSON o un tile vectorial).
- Mover la verificación HMAC al servidor. Sacar `KUFI_TOKEN_SECRET` del binario del pasajero.
- Cuentas reales: el PIN se hashea en el servidor (hoy es SHA-256 local, solo para la demo).
- Liquidación del cierre: agrupar los créditos del turno y marcarlos como depositados a la asociación.
- Tests de la función `aplicar_pasaje` contra una base de usar y tirar.

### 3. App pasajero

- Pulir las pantallas contra los PNG de `kufi_disenos` (onboarding, permisos, PIN, mapa, ficha, historial).
- Reemplazar el marcador simulado por posición reportada por el chofer cuando el backend exista.
- Cámara para el carnet (`image_picker`) y para el QR.
- Ajustes de accesibilidad: contraste del panter blanco sobre el mapa, textos largos de zona.
- Pruebas en un teléfono de gama media en Santa Cruz, con el GeoJSON completo.

### 4. Pago en el vehículo y app chofer

- `flutter_blue_plus`: el chofer anuncia el payload que ya firma `FirmadorAnuncios`; el pasajero reemplaza la lista simulada por los anuncios reales y sigue usando `FiltroAnuncios`.
- HCE en Android, detrás de `TransportesDePago.nfc`, sin prometerlo en iPhone.
- Escáner QR con `mobile_scanner`.
- Notificación local al chofer en el momento del cobro (el canal `kufi_pagos` ya está creado) y, si el curso lo pide, FCM con un proyecto Firebase propio.
- Cierre del día conectado a la liquidación del backend. Confirmar las tarifas con cada asociación antes de cobrar en la calle.

## Cómo probar las reglas sin la app

```bash
cd packages/kufi_core
dart test
```

Ahí están el parseo de las 126 rutas, la búsqueda sin tildes, la distancia al trazado, el doble cobro, el saldo insuficiente, el token vencido, la sincronización offline y el cierre por tipo de pasaje.
