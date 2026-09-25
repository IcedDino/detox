# Documentos legales

| Archivo | Qué es |
| --- | --- |
| `aviso-de-privacidad.md` | **Aviso de Privacidad** en el marco de la LFPDPPP mexicana. Es el texto fuente y lo que se revisa y versiona. |
| `aviso-de-privacidad.html` | La misma página lista para publicar en una URL. |
| `terminos-y-condiciones.md` | Términos y Condiciones. Texto fuente. |
| `terminos-y-condiciones.html` | Versión publicable. |
| `generar.py` | Convierte los `.md` en los `.html` publicables **y** en el JSON que la app dibuja. |
| `assets/legal/*.json` | La copia que lee la app. No se edita a mano: la escribe `generar.py`. |

Los `.md` son la única fuente de verdad. **No edites los `.html` ni el `.json` a mano**: se
sobrescriben. Para regenerarlo todo:

```bash
python docs/legal/generar.py
```

El script comprueba que la raíz del repositorio contiene `pubspec.yaml` antes de escribir fuera de
`docs/legal`, así que no puede dejar archivos sueltos por el disco.

El conversor es pequeño y solo cubre lo que estos documentos usan: títulos, párrafos, listas,
tablas, citas, reglas, negritas y `código`. Si un documento necesita algo que no soporta, se añade
al conversor en vez de escribir HTML suelto, o las dos versiones se separan. Si alguna construcción
de Markdown sobrevive a la conversión, el script **falla en vez de publicar una página rota**.

`lib/screens/legal_document_screen.dart` dibuja esos mismos bloques, así que un documento nuevo
aparece en la app sin tocar Dart: basta con volver a ejecutar `generar.py`.

---

## 1. Antes de publicar: datos por completar

Los documentos están redactados, pero tienen marcadores entre corchetes. Búscalos con:

```bash
grep -n "\[" docs/legal/*.md
```

| Marcador | Dónde | Qué poner |
| --- | --- | --- |
| `[DOMICILIO]` | Ambos documentos, sección de identificación | Domicilio fiscal o de contacto de Nerqova |
| `[CIUDAD]`, `[ESTADO]` | Ambos documentos | Ciudad y estado del domicilio y del fuero elegido |
| `[URL DE ELIMINACIÓN DE CUENTA]` | Aviso §11.2 y Términos §13 | URL pública de la página de eliminación que ya existe |

Cuando Nerqova quede constituida como entidad legal, hay que añadir en los dos documentos la
**razón social** y el **RFC**, y quitar la frase que hoy dice que opera como marca comercial.

---

## 2. Correo de contacto: confirmado

El correo de los dos documentos es **`nerqovaassist@gmail.com`**, confirmado por ti, y es el mismo
que ya usa `apps_script/Code.gs` en `SUPPORT_EMAIL`. La política y el flujo real de soporte
coinciden: no hay nada que corregir.

Queda una mejora opcional, no un error. Un Gmail personal en la ficha de Play resta algo de
credibilidad ante el revisor; cuando exista el dominio, lo ideal es `soporte@nerqova.com`. Al
cambiarlo hay que sustituirlo en los dos documentos **y** en `SUPPORT_EMAIL` de
`apps_script/Code.gs`, para que no vuelvan a separarse.

---

## 3. Consentimiento dentro de la app: resuelto

La aceptación informada ya existe y no manda al usuario a ningún navegador.

- **Lector nativo.** `lib/screens/legal_document_screen.dart` lee `assets/legal/*.json` y dibuja
  títulos, párrafos, listas, tablas, citas y reglas con widgets de la app, con los colores y la
  tipografía de Detox. No hay WebView ni salto al navegador.
- **Aceptación visible al crear cuenta.** `lib/screens/auth_screen.dart` muestra «Leo y acepto los
  Términos y Condiciones y el Aviso de Privacidad» bajo el formulario, en los dos idiomas y con los
  dos documentos como enlaces pulsables. La misma línea cubre el acceso con Google o con teléfono,
  porque también crean cuenta.
- **Acceso permanente.** Configuración → Legal abre los dos documentos. Es lo que pide Play para
  la ficha y lo que necesita un usuario que ya tiene cuenta.
- **Prueba automática.** `test/legal_document_test.dart` comprueba que el Aviso se dibuja con su
  contenido real y que el enlace de aceptación abre los Términos dentro de la app.

Lo que queda pendiente ya no es código:

1. **Publicar los `.html`** en una URL. La app ya no depende de esa URL para mostrar los
   documentos, pero Play la pide para la ficha y los correos de soporte deberían apuntar ahí.
2. **Decidir qué hacer con `create_account_screen.dart`**, que sigue siendo código huérfano en
   inglés. Se puede borrar sin efecto alguno.

---

## 4. De dónde sale cada afirmación

Los documentos describen lo que el código hace de verdad, no una plantilla. Estas afirmaciones se
verificaron y hay que **revisarlas si la app cambia**:

| Afirmación | Dónde se comprobó |
| --- | --- |
| El tiempo de pantalla nunca sale del dispositivo | `lib/services/usage_service.dart` no referencia Firestore en ningún punto |
| No hay historial de ubicación, solo las zonas creadas | `lib/models/concentration_zone.dart` guarda latitud, longitud y radio, nada más |
| No se recogen datos sensibles | Revisión de todos los campos de `users/{uid}` |
| El padrino solo ve nombre, tipo de solicitud, mensaje y decisiones | `lib/services/sponsor_service.dart` lee `sponsorUid` y `profile.displayName`, y **no** lee apps, zonas, límites ni hábitos |
| La app es gratuita y sin compras | No hay ninguna dependencia de facturación en `pubspec.yaml` |
| Hay publicidad recompensada de AdMob | `RewardAdActivity.kt` carga un `RewardedInterstitialAd` |
| El borrado deja un registro mínimo | `CloudSyncService.markAccountDeleted` conserva `accountDeletedAt` y el nombre visible |
| No hay notificaciones push | `pushToken` solo aparece para borrarse; nunca se escribe |

**Si más adelante se añade sincronización de uso, notificaciones push o cualquier dato nuevo, el
Aviso de Privacidad deja de ser cierto.** Hay que actualizarlo en el mismo cambio, no después.

---

## 5. Advertencia importante

Estos documentos están redactados con cuidado y se ajustan a la **Ley Federal de Protección de
Datos Personales en Posesión de los Particulares vigente desde el 21 de marzo de 2025**. Esa
reforma extinguió al INAI y trasladó la supervisión del sector privado a la **Secretaría
Anticorrupción y Buen Gobierno**, a través de la Dirección General de Datos Personales en el Sector
Privado.

Tres cosas que conviene tener presentes:

1. **El reglamento de esa ley todavía no se publica.** El marco secundario puede cambiar y arrastrar
   obligaciones nuevas.
2. **Esto no es asesoría legal.** Antes de publicar en Google Play, y sobre todo antes de
   distribuir en el Espacio Económico Europeo, conviene que lo revise un abogado. La sección
   «Si usas la app fuera de México» del Aviso es un punto de partida razonable, no un programa de
   cumplimiento del RGPD.
3. **Los plazos de 20 y 15 días hábiles** para atender derechos ARCO son los de la ley. Suponen
   que alguien vigile el buzón de contacto de forma constante. Si nadie lo hace, el plazo se
   incumple igual.
