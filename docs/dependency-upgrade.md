# Actualización de dependencias Android y Flutter

Fecha: 2026-09-24. SDK de validación: Flutter 3.47.3 / Dart 3.13.3.

## Dependencias utilizadas

| Paquete | Antes | Después | Adaptación |
| --- | --- | --- | --- |
| `shared_preferences` | 2.5.4 | 2.5.5 | API de la app sin cambios; plugin Android transitivo 2.4.28. |
| `fl_chart` | 0.69.2 | 1.2.0 | El gráfico semanal compila con la API existente. |
| `flutter_map` | 7.0.2 | 8.3.2 | El editor de zonas compila con su mapa, capa de teselas y círculo existentes. |
| `latlong2` | 0.9.1 | 0.10.1 | Coordenadas y distancias conservadas. |
| `geolocator` | 13.0.4 | 14.0.3 | Permisos, posición y stream compilan. |
| `flutter_local_notifications` | 17.2.4 | 22.3.1 | `initialize`, `show` y `cancel` migrados a parámetros con nombre; se conservan canales, acciones y payload. |
| `firebase_core` | 3.15.2 | 4.15.0 | Inicialización conservada. |
| `firebase_auth` | 5.7.0 | 6.7.0 | Email, teléfono, sesión y credencial Google conservados. |
| `cloud_firestore` | 5.6.12 | 6.10.0 | Consultas y sincronización compilan. |
| `google_sign_in` | 6.3.0 | 7.2.0 | Singleton, inicialización única y `authenticate`; cancelación distinguible. El `google-services.json` contiene el cliente web OAuth necesario en Android. |

Se retiraron `cupertino_icons`, `app_usage`, `android_intent_plus`, `installed_apps`, `firebase_messaging` y `google_mobile_ads` del árbol Flutter porque no tenían importaciones ni llamadas en Dart. Uso, catálogo y anuncios siguen implementados en los canales y clases nativas del proyecto.

## Cadena Android

- Gradle wrapper 9.1.0, Android Gradle Plugin 9.0.1 y Kotlin 2.3.20 declarado para resolución de plugins. La app usa Kotlin integrado de AGP 9.
- Google Services Gradle Plugin 4.5.0, Firebase Android BoM 34.19.0 y Google Mobile Ads SDK 25.5.0. Las llamadas nativas a autenticación, Firestore y anuncios recompensados se conservaron.
- Se creó `android/app/proguard-rules.pro` con una regla puntual para conservar el constructor de `androidx.work.impl.WorkDatabase_Impl`, que Room invoca por reflexión. R8 lo había eliminado: el APK release compilaba, pero se cerraba antes de iniciar Flutter cuando `androidx.startup.InitializationProvider` cargaba WorkManager desde Google Mobile Ads.
- El mínimo declarado es Flutter 3.47 / Dart 3.13, necesario para esta configuración de AGP 9 y las versiones de paquetes seleccionadas.

## Validación y avisos restantes

- `dart analyze lib`: sin errores ni advertencias; conserva avisos informativos de estilo y APIs Flutter previas.
- `flutter test --no-pub`: 6 pruebas superadas.
- `flutter build apk --debug --no-pub`: APK construido.
- `flutter build apk --release --no-pub`: APK construido con R8.
- APK release corregido instalado con `adb install -r` en HONOR WDY-LX3 (Android 14). `MainActivity` quedó en estado `RESUMED`, el proceso siguió activo y no se registró un crash nuevo. La reproducción anterior quedó documentada en `dumpsys dropbox` como `Failed to create an instance of androidx.work.impl.WorkDatabase`; se tradujo con `retrace` y el `mapping.txt` del APK.
- En Enfoque se reemplazó la lista anidada en `ExpansionTile`, que mostraba un rectángulo gris al expandirse, por un resumen de hasta tres apps y una acción para ver el resto. Se verificó visualmente en el mismo dispositivo con tres apps bloqueadas.
- `pub outdated` deja cinco paquetes **transitivos** fuera de su última versión (`dbus`, `equatable`, `gsettings`, `material_color_utilities`, `test_api`). El solucionador no puede subirlos con las restricciones publicadas por sus paquetes padres o por Flutter; no se añadieron overrides incompatibles.
- Flutter 3.47 aún avisa que las versiones publicadas de `firebase_auth` y `firebase_core` aplican KGP, aunque los APK compilan con AGP 9. Este aviso requiere que FlutterFire migre sus plugins a Kotlin integrado.
- El aviso de SDK XML versión 4 aparece de forma intermitente al leer la instalación local de Android SDK. Las herramientas de línea de comandos instaladas indican versión 23.0 y el build continúa correctamente. No se modificó el SDK global desde este proyecto.
- `cloud_firestore` 6.10.0 emite una nota Java sobre operaciones sin comprobación de tipos en código del plugin; no hay advertencias equivalentes en código de la app.
- No había dispositivo Android conectado; las rutas reales de Google/Firebase, geolocalización, notificaciones y anuncios requieren una comprobación manual en dispositivo.
