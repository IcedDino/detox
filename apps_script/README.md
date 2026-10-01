# Avisos de padrino con FCM

`Code.gs` usa el Apps Script de soporte ya existente. No necesita Cloud Functions ni
facturación Blaze. El disparador `processSponsorPush_` consulta solicitudes recientes
cada minuto y envía FCM HTTP v1 a los dispositivos registrados por la app.

## Activación en el proyecto `detox-c0790`

1. Actualizar el Apps Script desplegado con `Code.gs` y `appsscript.json` de este
   directorio. El manifiesto añade el alcance `firebase.messaging`.
2. Habilitar la API **Firebase Cloud Messaging API (V1)** en el proyecto de Google
   Cloud vinculado a Firebase. La cuenta que ejecuta el script necesita permiso para
   enviar mensajes FCM y leer/escribir Firestore.
3. Volver a autorizar el script por los nuevos alcances y ejecutar
   `installPollingTrigger()` una vez. Deben existir los disparadores de soporte
   (cada cinco minutos) y de avisos de padrino (cada minuto).
4. Desplegar `firestore.rules` del repositorio para que cada usuario pueda registrar
   su token bajo `users/{uid}/push_tokens/{deviceId}`.
5. Con dos dispositivos, comprobar solicitud nueva, aceptación y permiso con la
   app receptora cerrada; después comprobar que tocar el aviso abre el centro de
   padrino. Si la app está abierta, el mensaje FCM se muestra como aviso local.

El script deduplica cada revisión con `meta/push_delivery/events/{hash}`. Un error
de FCM deja la revisión pendiente para el siguiente disparador. Los tokens que no
han actualizado en 30 días se omiten. Google Apps Script y FCM tienen cuotas; el
disparador no garantiza entrega inmediata ni sustituye una prueba en dispositivos.
