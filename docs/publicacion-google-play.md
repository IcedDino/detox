# Publicación en Google Play — estado y pendientes

**App:** Detox · **Paquete:** `com.nerqova.detox` · **Versión:** 1.1.3 (versionCode 5)
**Desarrolladora:** Nerqova

Revisión hecha sobre el código y sobre un build real (`flutter build apk --debug`),
no sobre suposiciones. Cada dato de la sección 1 está verificado y se indica cómo.

---

## 1. Lo que ya está cumplido

| Requisito | Estado | Cómo se verificó |
| --- | --- | --- |
| `targetSdk` 36 (Android 16) | Cumple | Play exige API 36 para apps nuevas desde el 31-08-2026. `FlutterExtension.kt` del SDK 3.47.3 fija `targetSdkVersion = 36`. |
| `minSdk` 24 | Cumple | Mismo archivo: `minSdkVersion = 24`. |
| Soporte de páginas de 16 KB | Cumple | `zipalign -c -P 16` sobre el APK real → correcto. Obligatorio desde nov-2025. |
| `applicationId` | Cumple | `com.nerqova.detox`. |
| Firma de release | Cumple | `android/key.properties` completo y `android/app/upload-key.jks` presente. Ambos fuera de git (`android/.gitignore`). |
| Minificación y ofuscación | Cumple | `isMinifyEnabled` + `isShrinkResources` + `proguard-rules.pro`. |
| Icono adaptable | Cumple | Ya aplicado: `mipmap-anydpi-v26/` con capas `foreground` y `monochrome`. |
| Icono heredado y redondo | Cumple | 5 densidades de `ic_launcher` y `ic_launcher_round`; `android:roundIcon` en el manifiesto. |
| Anuncios con IDs reales | Cumple | `ca-app-pub-5614533913981580~9515972522` en release; los IDs de prueba solo en debug. |
| Eliminación de cuenta en la app | Cumple | `settings_screen.dart`, con borrado de datos sincronizados. |
| Bilingüe es/en | Cumple | `lib/l10n_app_strings.dart` + `values-en/strings.xml`. |
| Tipo de servicio en primer plano | Parcial | `specialUse` con subtipo declarado. Falta declararlo en Play Console (ver 3.3). |

---

## 2. Bloqueantes

Sin esto no se publica, por mucho que el build funcione.

### 2.1 Cuenta de desarrollador y acceso a producción

- **Decidir el tipo de cuenta.** Si se registra como **organización** (Nerqova), Play pide un
  número **D-U-N-S** y verificación de la empresa. Si es **personal**, y se creó después del
  13-11-2023, hereda la regla de pruebas: **12 testers inscritos de forma continua durante 14 días**
  en una prueba cerrada, *antes* de poder pedir acceso a producción. Las cuentas de organización
  no tienen esa regla.
- **Email de contacto público.** Hoy el flujo de soporte depende de `nerqovaassist@gmail.com`.
  Para la ficha conviene un correo del dominio (`soporte@nerqova.com`): un Gmail personal en la
  ficha de Play resta credibilidad y complica la verificación.
- **Nombre del desarrollador** que verán los usuarios: debe ser «Nerqova».

### 2.2 Privacidad y datos

| Elemento | Estado |
| --- | --- |
| Política de privacidad con URL pública | **Redactada, sin publicar.** El Aviso de Privacidad y los Términos están en `docs/legal/`, con Markdown fuente y HTML listo. Falta publicarlos en una URL: la app ya los muestra sin ella, pero Play la pide para la ficha. |
| Formulario de seguridad de los datos | **Falta.** Debe declarar: correo, nombre, teléfono, ubicación, uso de apps, identificadores de publicidad. |
| Clasificación de contenido (IARC) | **Falta.** |
| URL de eliminación de cuenta | **Existe, sin publicar** (según tu indicación). Hay que publicarla y poner la URL en el Aviso §11.2 y los Términos §13. |
| Aceptación de los Términos dentro de la app | **Cumple.** `auth_screen.dart` muestra «Leo y acepto los Términos y Condiciones y el Aviso de Privacidad» con los dos documentos como enlaces pulsables, en es/en, y Configuración → Legal los deja siempre a mano. Se abren con widgets nativos (`legal_document_screen.dart`), sin navegador ni WebView, así que no se pasa por el filtro de *App Links* ni se pierde al usuario. Verificado por `test/legal_document_test.dart`. |
| Declaración de acceso a la app | **Falta y es crítica.** Detox exige iniciar sesión: hay que marcar «parte de la funcionalidad está restringida» y entregar al revisor **credenciales de prueba con datos ya cargados**. Sin esto la revisión se rechaza por no poder evaluar la app. |

### 2.3 Permisos sensibles — el riesgo real de rechazo

Aquí está el verdadero peligro del proyecto, no en el código.

| Permiso | Veredicto |
| --- | --- |
| `PACKAGE_USAGE_STATS` | **Justificable.** Es el núcleo de una app de bienestar digital. Hay que explicarlo bien en la ficha. |
| `SYSTEM_ALERT_WINDOW` | **Justificable**, es el bloqueo. Regla que no se puede romper: la superposición solo puede servir para bloquear, nunca para anuncios ni para imitar otra app. |
| `ACCESS_BACKGROUND_LOCATION` | **Riesgo máximo.** Ver 2.4. |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Hay que declararlo en Play Console (App content → Tipos de servicio en primer plano) con la justificación escrita. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Permitido, pero Play pide justificarlo. Alternativa más segura: llevar al usuario a los ajustes de batería sin pedir el permiso. |
| `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `INTERNET` | Sin objeción. |

### 2.4 Ubicación en segundo plano — ✅ ACLARADO

**Uso real confirmado:** el único uso de ubicación es verificar si el usuario se encuentra
dentro de una zona de concentración que él mismo definió (obtener coordenadas + comparar con el
radio de la zona). No hay rastreo continuo, ni historial, ni envío a servidor.

**Diagnóstico:** dado que `FocusBlockerService` es ya un servicio en primer plano (`specialUse`),
la lectura de ubicación ocurre mientras ese servicio está activo, lo que equivale a primer plano
desde la perspectiva del SO. Por lo tanto, `ACCESS_BACKGROUND_LOCATION` **no es necesario**.

**Cambio a hacer en `AndroidManifest.xml`:**
```xml
<!-- QUITAR -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>

<!-- AÑADIR -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>

<!-- En FocusBlockerService, cambiar foregroundServiceType -->
android:foregroundServiceType="location|specialUse"
```

En el código Dart/Kotlin, pedir `ACCESS_FINE_LOCATION` (o `COARSE`) **antes** de arrancar el
servicio (Android 14+ lo exige).

**Resultado:** se elimina la Declaración de permisos de ubicación, el vídeo obligatorio y el
riesgo de rechazo. El revisor verá un permiso perfectamente justificado por las zonas de
concentración.

### 2.5 Ficha de Play — assets

| Asset | Estado |
| --- | --- |
| Icono 512 × 512 | **Listo**: `docs/brand/detox-icon/icono_app.png` |
| Gráfico destacado 1024 × 500 | **Falta.** Obligatorio. |
| Capturas de teléfono | **Faltan.** Mínimo 2, hasta 8. |
| Nombre (≤ 30 car.) | Falta redactar |
| Descripción corta (≤ 80 car.) | Falta redactar |
| Descripción completa (≤ 4000 car.) | Falta redactar |
| Categoría y etiquetas | Falta elegir (probablemente *Estilo de vida* o *Herramientas*) |

### 2.6 Anuncios

- Declarar **«Contiene anuncios»** en la ficha.
- **Falta el consentimiento para el EEE.** Al servir anuncios personalizados a usuarios de la
  Unión Europea y el Reino Unido hace falta un CMP certificado por Google (SDK UMP). No hay
  ninguno integrado. Sin él, AdMob puede dejar de servir en el EEE.
- El anuncio recompensado que da la pausa extra está bien planteado: se pide a propósito y no
  interrumpe. Mantenerlo así y no añadir intersticiales al abrir la app.

---

## 3. Cosas que funcionan en local y romperán en producción

### 3.1 Google Sign-In dejará de funcionar al publicar — el fallo clásico

Firebase valida la firma de la app. Cuando Play firma la app con **Play App Signing**, la huella
que ve Firebase **no** es la de `upload-key.jks`, sino la de Google. Si solo está registrada la
huella de tu keystore de subida, el acceso con Google fallará justo después de publicar, en la
versión que ya nadie puede arreglar rápido.

**Arreglo:** en Play Console → *Integridad de la app* → copiar la **SHA-1 y SHA-256 de App
Signing** y añadirlas en Firebase → *Configuración del proyecto* → tus apps Android. Hacerlo
**antes** de subir a producción. El propio código ya avisa de esto
(`authGoogleBuildSetup` en `l10n_app_strings.dart`).

### 3.2 Otros puntos a probar en un build de release real

- **R8 + `shrinkResources`**: los IDs de recursos y las clases por reflexión se pueden romper. Ya
  hay una regla para Room en `proguard-rules.pro`, señal de que esto ya pasó una vez. Probar el
  APK/AAB de release completo en un teléfono, no solo el de debug.
- **Edge-to-edge obligatorio**: al apuntar a API 35+ Android fuerza el dibujado a pantalla
  completa. Revisar que ninguna pantalla quede tapada por las barras del sistema en Android 15/16.
- **Reglas de Firestore**: verificar que `firestore.rules` esté desplegado en el proyecto
  `detox-c0790` y no solo en el repositorio.
- **Flujo de soporte**: el Apps Script debe estar desplegado y con el disparador activo, o las
  solicitudes de desvinculación se quedan colgadas sin respuesta durante la revisión.
- **Nombre «Detox»**: es una palabra genérica y ya existe software con ese nombre. No es un
  bloqueo, pero conviene revisar que no colisione con una marca registrada antes de invertir en la
  ficha, y que la búsqueda en Play no quede enterrada.

---

## 4. Orden recomendado

**Fase 0 — técnico (antes de tocar Play)**
1. Decidir el camino de ubicación (2.4) e implementarlo.
2. Probar un build de release real en dispositivo: login de Google, bloqueo, zonas, anuncios.
3. Subir `versionCode` a 6.

**Fase 1 — cuenta y papeleo**
4. Crear la cuenta de desarrollador como Nerqova y verificar la identidad.
5. Publicar la política de privacidad y la página de eliminación de cuenta.
6. Rellenar Data Safety, clasificación de contenido y declaración de acceso (con credenciales).
7. Declarar los tipos de servicio en primer plano y los anuncios.
8. Preparar el gráfico destacado, las capturas y los textos.

**Fase 2 — pruebas cerradas**
9. Generar el AAB y subirlo a prueba cerrada.
10. Si la cuenta es personal: 12 testers, 14 días seguidos, recogiendo feedback real.
11. Añadir la huella SHA-1 de Play App Signing a Firebase.

**Fase 3 — producción**
12. Pedir acceso a producción, responder el cuestionario de pruebas.
13. Despliegue por etapas al 20 %, vigilando *Android vitals* y las reseñas.

---

## 5. Comandos

```bash
# Subir la versionCode en pubspec.yaml antes de cada entrega (1.1.3+5 -> 1.1.3+6)

# AAB, que es el formato que Play acepta para publicar
flutter build appbundle --release

# APK de release para probar en un dispositivo real
flutter build apk --release

# Comprobar que el paquete respeta la alineación de 16 KB
"$ANDROID_HOME/build-tools/<version>/zipalign" -c -P 16 -v 4 \
  build/app/outputs/flutter-apk/app-release.apk

# Desplegar las reglas de Firestore
npx firebase-tools deploy --only firestore:rules --project detox-c0790
```

---

## 6. Resumen

**Lo técnico está en buen estado.** `targetSdk` 36, 16 KB, firma, minificación e iconos ya cumplen;
el trabajo del símbolo dejó el icono adaptable y el splash en su sitio. El problema no es el build.

**Lo que falta es papeleo y una decisión de producto.** Tres cosas son bloqueantes de verdad:

1. **Publicar los documentos legales.** Los textos ya están escritos en `docs/legal/` y la app ya
   los enlaza y los dibuja dentro de la app; lo que falta es publicar los `.html` en una URL para
   la ficha de Play. La página de eliminación ya existe según tu indicación: solo hay que
   publicarla.
2. **La declaración de acceso con credenciales de prueba**: sin poder entrar, el revisor rechaza.
3. **La ubicación en segundo plano**: o se reestructura como servicio en primer plano, o toca
   declaración más vídeo con riesgo de rechazo.

Y un cuarto que no bloquea pero que rompe en producción si se olvida: **la huella SHA-1 de Play
App Signing en Firebase**, sin la cual el acceso con Google muere justo al publicar.
