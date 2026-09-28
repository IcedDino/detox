# Acceso anónimo — 1.1.4 (6)

## Ajuste de cuenta — 1.1.6 (8)

La sección de Ajustes muestra un solo perfil con su alias y proveedor. Al abrirlo
aparecen Cambiar username, Vincular con Google, salir y eliminar cuenta. El panel
puede desplazarse en pantallas bajas.

## Ajuste de interfaz — 1.1.5 (7)

La entrada separa iniciar sesión, crear cuenta e iniciar como anónimo. El acceso
anónimo usa una pantalla propia de username y después el permiso de acceso a datos
de uso. La creación y edición de alias comparten validación de formato y un filtro
local de palabras ofensivas y nombres reservados, con normalización de variantes
comunes. No se muestra texto explicativo sobre el filtro.
En Ajustes, la vinculación se reduce a un botón de Google: enlaza la credencial al
usuario actual y conserva UID y alias; un conflicto no cambia la sesión de perfil.

- Entrada anónima con alias y recuperación opcional por correo/contraseña o SMS.
- Vinculación mediante `linkWithCredential` para conservar el UID, datos y padrino.
- Username editable en Ajustes; el correo del padrino deja de mostrarse.
- Los accesos Google existentes siguen disponibles. El perfil de Detox usa su alias.
- Los conflictos de credenciales no fusionan ni reemplazan cuentas.
- Firebase Anonymous está habilitado en `detox-c0790`.

## Limpieza del servidor

`apps_script/Code.gs` extiende el proceso existente de cinco minutos: consulta
`anonymousLastSeenAt` anterior a siete días, comprueba Firebase Auth y corta ambos
lados del vínculo y sus solicitudes. Las escrituras usan precondiciones de versión;
una apertura concurrente o cambio de padrino impide aplicar datos antiguos.
La última apertura se registra al iniciar y reanudar la app con conexión. La
desinstalación no se detecta. El vínculo se corta por inactividad, sin borrar el perfil.

El código requiere añadir el permiso `cloud-platform` al proyecto Apps Script y
autorizarlo con la cuenta propietaria antes de actualizar el proceso activo.
El código y manifiesto se publicaron en Apps Script el 27 de septiembre de 2026.
La cuenta propietaria confirmó haber autorizado el nuevo permiso el mismo día,
tras ejecutar `installPollingTrigger` desde el editor. La comprobación remota del
historial está pendiente: el acceso de clasp no incluye los permisos de lectura
de ejecuciones y la invocación remota devolvió NOT_FOUND. Confirmar en el editor
que `processSupportUnlinkRequests_` se ejecuta cada cinco minutos y que sus registros
no muestran `Anonymous cleanup unavailable` ni `Anonymous expiry deferred`.

Proyecto: https://script.google.com/home/projects/1o1WUWZylnx2WiJRkr75ZnoRygIvfUwGno5dgB5cJhtShboVHQHwGn6s0/edit

Después de publicar los cambios, ejecutar `installPollingTrigger` desde el editor y
aceptar los permisos. El trigger existente usa HEAD; no es necesario reemplazar la
URL del despliegue web de soporte.

## Comprobaciones

Las pruebas de Flutter cubren persistencia del indicador anónimo, alias, separación
entre vincular e iniciar sesión, Ajustes y documentos. Las pruebas de Node cubren
la caducidad, exclusión de perfiles recuperables, carreras con actividad y el flujo
de soporte. Queda la prueba manual de SMS en un dispositivo con un número real.
