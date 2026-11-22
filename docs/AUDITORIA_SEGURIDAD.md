# Auditoría de Kufi

Fecha: 2026-11-22. Revisión del MVP en la rama `cursor/kufi-mvp-eb00`, después de correr la app en Chrome con Flutter 3.47 / Dart 3.13. El código se dejó compatible con `sdk: ">=3.8.0 <4.0.0"` para que ese Dart y el stable más nuevo resuelvan las dependencias.

La app **no está conectada a Supabase ni a Postgres**. El saldo, los usuarios y el libro viven en el teléfono (`shared_preferences` para el estado, `flutter_secure_storage` para el PIN y la clave HMAC). Las migraciones SQL son el contrato para cuando exista un servidor; hoy no se ejecutan.

## Hallazgos

| Sev. | Hallazgo | Estado |
| --- | --- | --- |
| Alta | El PIN se guardaba como hash SHA-256 dentro del JSON de `shared_preferences`, sin sal y junto al resto del estado. | Corregido. El hash usa sal aleatoria y 8000 rondas de SHA-256. Vive en `flutter_secure_storage` (preferencias cifradas en Android). El JSON ya no lleva `pinHash`. |
| Alta | No había límite de intentos. Se podía probar el PIN sin pausa. | Corregido. 5 fallos bloquean 5 minutos (`ControlIntentosPin`, con tests). |
| Alta | `secretoDesarrollo = kufi-dev-santa-cruz` estaba en el código y firmaba todos los QR si no había `--dart-define`. | Corregido. Esa constante ya no existe. Si `KUFI_TOKEN_SECRET` no viene en el entorno, el teléfono genera una clave de 32 bytes y la guarda en el almacenamiento seguro. No está en el repositorio. |
| Alta | Las tablas SQL no tenían RLS. Cualquier rol con acceso leía el libro de todos. `aplicar_pasaje` no era `SECURITY DEFINER` ni fijaba `search_path`. | Corregido en `backend/migraciones/004_rls_seguridad.sql`. Un pasajero solo lee sus cuentas y sus apuntes. La función fija `search_path = public, pg_temp`, rechaza montos fuera de rango y solo deja cobrar al dueño de la cuenta (o a `postgres` / `service_role` al sembrar). |
| Media | Registro sin formato de celular boliviano, carnet, correo ni PIN trivial (`1234`, `1111`, secuencias). | Corregido. Validadores puros en `kufi_core` y `FilteringTextInputFormatter` en los campos. El PIN `1234` de las cuentas demo sigue entrando porque ya existía; un registro nuevo lo rechaza. |
| Media | No había placa, carnet ni aceptación de términos. | Corregido. Carnet en el registro, placa boliviana al abrir el turno, casilla de términos y privacidad. |
| Media | Android permitía backup de la app y no declaraba la política de texto claro. `BLUETOOTH_SCAN` podía pedir ubicación. | Corregido. `allowBackup=false`, `usesCleartextTraffic=false`, `network_security_config`, `BLUETOOTH_SCAN` con `neverForLocation`. NFC y HCE son opcionales (`required=false`). |
| Media | El release no ofuscaba. | Corregido en Gradle: R8 (`isMinifyEnabled` y `isShrinkResources`) con reglas para Flutter y el servicio NFC. La firma del release de equipo sigue siendo la de debug para poder instalarlo; no es un keystore de producción. |
| Media | BLE y NFC eran solo simulación, también en Android. | Parcial. El APK anuncia (chofer) y escanea (pasajero) por BLE real, filtra RSSI y verifica el anuncio compacto firmado. El pasajero puede emular una tarjeta NFC (HCE) al acercar el celular. En Chrome y en pruebas se mantiene la lista simulada. No hay un lector NFC en el teléfono del chofer: el cobro se confirma en la app, no contra un validador de la calle. |
| Baja | Textos legales ausentes. Borrar cuenta no existía. | Corregido. Pantallas de términos y privacidad marcadas como borrador. El perfil borra la cuenta local. Aviso ASFI en la recarga: esta versión no mueve dinero real. |
| Baja | Un monto negativo o enorme podía intentar entrar al libro si alguien llamaba el servicio a mano. | Corregido. El libro rechaza centavos en cero y el servicio rechaza montos fuera de 0 y Bs 20.000. La recarga de la UI queda entre Bs 1,00 y Bs 2.000,00, con máximo 2 decimales. |
| Info | En la web, `flutter_secure_storage` no es un enclave: el navegador no ofrece el mismo cifrado que Android. | Pendiente de producto. La demo en Chrome sigue siendo local. No guardar datos reales ahí. |
| Info | El libro del servidor es inmutable a propósito. Borrar la cuenta en el teléfono no borra apuntes que ya se hubieran sincronizado. | Documentado. Cuando exista el backend hay que anonimizar, no editar, esas filas. |
| Info | La clave HMAC de un teléfono no la conoce el otro si no se pasa `KUFI_TOKEN_SECRET` igual en los dos. | Esperado. En producción la firma la comprueba el servidor, no el pasajero. |
| Info | Dos teléfonos con BLE real solo se ven si ambos tienen el mismo secreto (el define) porque el anuncio compacto va firmado. Sin el define, cada aparato tiene su clave y el anuncio del otro no verifica; la UI cae a la lista simulada. | Pendiente: el servidor debe publicar la clave de turno o el pasajero solo debe transportar el token, no verificarlo con un secreto embebido. |
| Info | No hay escáner de cámara para el QR (`mobile_scanner`). Se pega el código o se lee el QR del mismo teléfono. | Pendiente. |
| Info | El release se firma con la clave de debug. | Pendiente antes de Play Store: keystore propio, fuera del repo. |

## Qué se revisó y ya estaba bien

- Idempotencia del libro: la misma clave no descuenta dos veces. Tests de doble cobro, token vencido, firma rota y sincronización offline.
- El trigger SQL impide `UPDATE` y `DELETE` en `libro_mayor`.
- No hay `print` ni `debugPrint` con PIN, carnet o tokens.
- Teselas OSM solo como valor por defecto de desarrollo, configurables.
- `.env.example` no trae llaves reales.

## BLE y NFC en el APK

- Chofer: al iniciar el turno, Android anuncia un paquete de 23 bytes (ruta, sentido, vencimiento, nonce y 8 bytes de HMAC) con `flutter_ble_peripheral`.
- Pasajero: `flutter_blue_plus` escanea unos segundos, se queda con el fabricante `0xFFF0`, ordena por RSSI y descarta firma mala o anuncio vencido (`FiltroAnuncios`, umbral −90 dBm).
- Si el radio no está (Chrome, escritorio, o ningún Kufi cerca), se muestra la lista simulada para que la demo siga.
- NFC: el APK incluye `KufiHostApduService`, un HCE propio. Al tocar «Ya lo acerqué» el pasajero deja el nombre de la ruta para un lector NFC. iOS no entra en ese camino. Falta el lado lector en el chofer y devolver el token firmado completo. El plugin `flutter_nfc_hce` no se usa: no compila contra las librerías AndroidX actuales.

## Base de datos hoy

Ninguna en la nube. Datos locales de demostración. Postgres/PostGIS queda preparado en `backend/migraciones`, incluida la semilla de las 126 rutas, y no se llama desde la app.
