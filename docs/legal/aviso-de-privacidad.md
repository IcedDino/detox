# Aviso de Privacidad

**Última actualización:** 25 de septiembre de 2026

En México, el documento que informa cómo se tratan los datos personales se llama **Aviso de
Privacidad**. Este aviso cumple esa función y también sirve como política de privacidad para las
tiendas de aplicaciones.

---

## 1. Quién es el responsable

**Nerqova** («nosotros»), con domicilio en **[DOMICILIO]**, [CIUDAD], [ESTADO], México, es el
responsable del tratamiento de tus datos personales.

- **Correo de contacto y privacidad:** nerqovaassist@gmail.com
- **Aplicación:** Detox, distribuida con el identificador `com.nerqova.detox`

Nerqova opera actualmente como **marca comercial**. Cuando la entidad legal quede constituida, este
aviso se actualizará con la razón social y el registro federal de contribuyentes correspondientes.

---

## 2. Qué datos personales tratamos

| Dato | De dónde sale | Para qué | Dónde se guarda |
| --- | --- | --- | --- |
| Nombre y correo electrónico | Lo escribes al crear la cuenta | Identificarte y darte acceso | Firebase Authentication y Firestore |
| Número de teléfono | Solo si entras con teléfono | Verificar tu identidad por SMS | Firebase Authentication |
| Proveedor de acceso | Google o correo | Mantener tu sesión | Firebase Authentication |
| Apps bloqueadas, límites diarios y horarios | Los eliges tú | Prestar el servicio que pediste | Firestore |
| Zonas de concentración (nombre, coordenadas y radio) | Las creas tú | Activar el bloqueo cuando llegas a ese lugar | Firestore |
| Vínculo con tu padrino: identificador, fechas, tipo de solicitud, el mensaje que escribes y la decisión | Lo genera el uso de la función de padrino | Que tu padrino pueda aprobar o denegar | Firestore |
| Identificador de publicidad del dispositivo | Lo asigna el sistema operativo | Mostrar el anuncio que da la pausa extra | Google AdMob |

Firebase es un servicio de Google. Los datos de tu cuenta se alojan en la infraestructura de Google
Cloud, que puede estar fuera de México.

### 2.1 Qué NO recogemos

Queremos que esto quede muy claro, porque es la parte que más nos preguntan:

- **Tu tiempo de pantalla y el detalle de uso de tus apps nunca salen de tu dispositivo.** No se
  sincronizan, no se envían a nuestros servidores y no los podemos ver. El historial de uso se lee
  localmente y se queda localmente. Lo único que se sincroniza son los ajustes que tú configuras.
- **No hacemos un historial de tu ubicación.** Solo guardamos las coordenadas de las zonas de
  concentración que tú creas a propósito, para saber cuándo entras y sales de ellas.
- No accedemos a tus contactos, tus mensajes, tus fotos, tus archivos ni a lo que escribes.
- No leemos el contenido de las apps que bloqueas ni lo que haces dentro de ellas.

---

## 3. Finalidades primarias

Son las necesarias para prestarte el servicio. No puedes usarlo sin aceptarlas:

1. Crear y mantener tu cuenta.
2. Sincronizar tus ajustes de enfoque entre tus dispositivos.
3. Aplicar el bloqueo de apps, los límites y las zonas que tú configures.
4. Operar la función de padrino, cuando decidas vincular uno.
5. Atender tus solicitudes de soporte y las relacionadas con tus datos.

## 4. Finalidades secundarias

Son opcionales y **no afectan** la prestación del servicio:

1. **Publicidad.** La app es gratuita y se sostiene con anuncios. El anuncio recompensado que da
   una pausa extra se muestra a través de Google AdMob, que puede usar el identificador de
   publicidad de tu dispositivo para seleccionar el anuncio. **Si te opones a esta finalidad,
   simplemente no completes el anuncio:** la pausa gratuita diaria sigue funcionando igual y
   puedes seguir usando todo lo demás.

**Cómo oponerte a las finalidades secundarias:** escribe a nerqovaassist@gmail.com indicando
«Oposición a publicidad». También puedes restablecer o limitar tu identificador de publicidad
desde los ajustes de Android, y desactivar la personalización de anuncios.

---

## 5. Datos personales sensibles

**No tratamos datos personales sensibles.** Ninguna de las categorías que la ley considera
sensible —origen étnico o racial, estado de salud, información genética, creencias religiosas o
filosóficas, afiliación sindical o preferencia sexual— se recoge en esta aplicación.

Por eso no pedimos tu consentimiento expreso por escrito para datos sensibles: no hay ninguno que
tratar.

---

## 6. Permisos especiales del sistema

Detox funciona sobre Android y necesita permisos que el sistema trata de forma especial. Cada uno
se explica aquí y **tú decides si lo concedes**:

| Permiso | Para qué | Si lo niegas |
| --- | --- | --- |
| **Acceso de uso** (`PACKAGE_USAGE_STATS`) | Medir tu tiempo de pantalla y detectar qué app está en primer plano para poder cubrirla | Las estadísticas y el bloqueo no funcionarán |
| **Superposición** (`SYSTEM_ALERT_WINDOW`) | Mostrar la pantalla de bloqueo encima de la app que está bloqueada | El bloqueo no puede cubrir nada |
| **Ubicación** (`ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`) | Activar el bloqueo al llegar a una zona de concentración que tú creaste | Puedes omitirlo con «Omitir por ahora» y usar todo lo demás manualmente |
| **Notificaciones** (`POST_NOTIFICATIONS`) | Mostrar el temporizador y el estado del bloqueo | No verás el aviso del temporizador |
| **Batería** (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) | Evitar que Android apague el bloqueo mientras duerme | El bloqueo puede detenerse solo |

Puedes revocar cualquiera de estos permisos en cualquier momento desde los ajustes de Android.
Revocar Acceso de uso o Superposición detiene el servicio de bloqueo, porque sin ellos no puede
hacer su trabajo.

---

## 7. Con quién compartimos datos

No vendemos tus datos personales. No los compartimos con terceros para fines distintos de los de
este aviso. Usamos estos proveedores, que tratan datos **por nuestra cuenta**:

| Proveedor | Servicio | Qué recibe |
| --- | --- | --- |
| Google LLC (Firebase Authentication) | Inicio de sesión y cuentas | Correo, nombre, teléfono cuando aplica |
| Google LLC (Cloud Firestore) | Base de datos del servicio | Tus ajustes, zonas y vínculo con padrino |
| Google LLC (AdMob) | Publicidad recompensada | Identificador de publicidad y datos técnicos del anuncio |
| Google LLC (Google Apps Script y Gmail) | Envío del correo de soporte | El contenido de una solicitud de desvinculación, cuando tú la envías |

Estos proveedores pueden estar fuera de México, incluido Estados Unidos. Al aceptar este aviso
consientes esa transferencia. Google trata los datos conforme a sus propias políticas, disponibles
en `https://policies.google.com/privacy`.

### 7.1 Qué ve tu padrino

Si vinculas un padrino, esa persona verá **únicamente**:

- Tu nombre visible.
- El tipo de solicitud que le envías (por ejemplo, desbloquear ajustes o pausar una zona).
- El mensaje que tú escribas en esa solicitud.
- Su propia decisión y el historial de esas decisiones.

Tu padrino **no ve** tus apps bloqueadas, tus límites, tus zonas, tus hábitos ni tu tiempo de
pantalla. La vinculación es voluntaria y puedes pedir la desvinculación en cualquier momento.

---

## 8. Menores de edad

Detox es para personas de **16 años o más**. No recogemos conscientemente datos de menores de esa
edad. Si detectamos una cuenta de una persona menor de 16 años, la eliminaremos.

Si eres madre, padre o tutor y crees que una persona menor de 16 años creó una cuenta, escríbenos a
nerqovaassist@gmail.com y la eliminaremos.

---

## 9. Cuánto tiempo conservamos los datos

| Dato | Plazo |
| --- | --- |
| Datos de tu cuenta y tus ajustes | Mientras mantengas la cuenta activa |
| Solicitudes, mensajes y decisiones del padrino | Mientras exista el vínculo y hasta 12 meses después, para poder resolver reclamaciones |
| Registro de la eliminación de la cuenta | Se conserva un registro mínimo (fecha de eliminación y nombre visible) como evidencia de que la eliminación se atendió y para impedir usos abusivos |
| Códigos de desvinculación por correo | Caducan a los 10 minutos y se borran al usarse |

Una vez cumplidos los plazos, los datos se eliminan o se anonimizan de forma que ya no puedan
asociarse contigo.

---

## 10. Seguridad

Aplicamos medidas técnicas y administrativas razonables para proteger tus datos:

- El tráfico viaja cifrado mediante TLS.
- El acceso a la base de datos está restringido por reglas de seguridad: cada cuenta solo puede
  leer y escribir sus propios documentos.
- Las credenciales de la cuenta se gestionan a través de Firebase Authentication; nunca
  almacenamos tu contraseña.
- Las decisiones de desvinculación con soporte se hacen mediante enlaces de un solo uso con
  caducidad de siete días.

Ningún sistema es infalible. Si ocurriera una vulneración que afecte de forma significativa tus
derechos, te lo informaremos por los medios de contacto que tengas registrados.

---

## 11. Tus derechos ARCO

Como titular de los datos puedes ejercer en cualquier momento:

- **Acceso:** saber qué datos tenemos y cómo los usamos.
- **Rectificación:** pedir que se corrijan si son inexactos o están incompletos.
- **Cancelación:** pedir que se eliminen cuando no sean necesarios.
- **Oposición:** pedir que dejemos de tratarlos para una finalidad concreta.

También puedes **revocar tu consentimiento** en cualquier momento, sin efectos retroactivos.

### 11.1 Cómo ejercerlos

Envía un correo a **nerqovaassist@gmail.com** con:

1. Tu nombre y el correo con el que creaste la cuenta.
2. El derecho que quieres ejercer.
3. Una descripción clara de lo que solicitas.
4. Cualquier documento que ayude a acreditar tu identidad, si fuera necesario.

**Plazos:** te responderemos en un máximo de **20 días hábiles** contados desde que recibamos tu
solicitud. Si la solicitud procede, se hará efectiva dentro de los **15 días hábiles** siguientes.

Ejercer estos derechos es **gratuito**.

### 11.2 Alternativa directa

Para la cancelación total no necesitas escribirnos: puedes borrar tu cuenta desde la propia
aplicación en **Ajustes → Tu cuenta → Eliminar cuenta**. La eliminación es inmediata y borra tu
perfil, tus ajustes sincronizados y el vínculo con tu padrino.

También publicamos una página web para solicitar la eliminación sin instalar la app, en
**[URL DE ELIMINACIÓN DE CUENTA]**.

---

## 12. Cómo limitar el uso de tus datos

- Desactiva la personalización de anuncios desde los ajustes de Android.
- No vincules un padrino si no quieres compartir con nadie el hecho de tus solicitudes.
- No crees zonas de concentración si prefieres no guardar ninguna coordenada.
- Revoca los permisos especiales que ya no quieras conceder.
- Ejerce tus derechos ARCO por el procedimiento de la sección 11.

---

## 13. Autoridad

Si consideras que tu derecho a la protección de datos personales fue vulnerado, puedes acudir a la
autoridad competente en materia de datos personales de los particulares en México: la
**Secretaría Anticorrupción y Buen Gobierno**, a través de la Dirección General de Datos
Personales en el Sector Privado.

> **Nota de contexto:** la Ley Federal de Protección de Datos Personales en Posesión de los
> Particulares vigente rige desde el 21 de marzo de 2025. Esa reforma extinguió al INAI y trasladó
> sus funciones de supervisión al sector privado a la Secretaría mencionada. Si encuentras
> referencias al INAI en cualquier otro documento, están desactualizadas.

---

## 14. Si usas la app fuera de México

Detox se distribuye internacionalmente. Si la usas desde otro país, se aplican además las normas
locales de protección de datos, y te reconocemos los mismos derechos que este aviso describe.

**Si estás en el Espacio Económico Europeo o el Reino Unido:** la base legal para tratar los datos
de tu cuenta es la ejecución del contrato que aceptas al registrarte, y el interés legítimo para la
seguridad del servicio. Para la publicidad personalizada, la base legal es tu consentimiento, que
puedes retirar en cualquier momento. Tienes además derecho a la portabilidad de tus datos y a
presentar una reclamación ante la autoridad de control de tu país.

Estamos terminando de implementar el mecanismo de consentimiento específico para publicidad que
exige la normativa europea. Mientras no esté disponible, la publicidad personalizada no se mostrará
a usuarios del Espacio Económico Europeo.

---

## 15. Cambios a este aviso

Podemos actualizar este aviso cuando cambie el servicio o la ley. Publicaremos la versión vigente
en esta misma dirección, con su fecha de actualización, y si el cambio es sustancial te lo
avisaremos dentro de la aplicación.

---

## 16. Contacto

Para cualquier duda sobre este aviso, tus datos o el ejercicio de tus derechos:

**nerqovaassist@gmail.com**
