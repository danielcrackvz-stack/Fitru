# Nombre visible: Subí

El producto se llama **Subí** (con tilde). El lema es «Subí y pagá con un toque».

Los paquetes Dart se quedan como `apps/kufi` y `packages/kufi_core`, y las clases internas (`KufiScope`, `ColoresKufi`, `BotonKufi`) también. Cambiarlos ahora rompería imports, el historial y el CI sin aportar nada a quien usa la app. El `applicationId` de Android pasa a `bo.subi.app` cuando se publique ese cambio; el paquete Kotlin `dev.kufi.kufi` se mantiene porque ahí vive el servicio NFC.

El protocolo interno (`kufi://pago`, la variable `KUFI_TOKEN_SECRET` y el prefijo `KF-` de los comprobantes) tampoco cambia: no se muestra como marca.
