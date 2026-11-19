# Data Safety Form — Detox (com.nerqova.detox)

**Versión:** 1.1.11+14 | **Fecha:** 2026-11-19
**Basado en:** `aviso-de-privacidad.html`, `AndroidManifest.xml`, `pubspec.yaml`, código de la app

---

## 📋 **Resumen Ejecutivo para Play Console**

| Pregunta | Respuesta |
|----------|-----------|
| **¿La app recopila o comparte datos de usuario?** | **Sí** |
| **¿Los datos están cifrados en tránsito?** | **Sí** (TLS 1.2+) |
| **¿Los usuarios pueden solicitar eliminación de datos?** | **Sí** (in-app y web) |
| **¿La app sigue la política de "Families"?** | **No** (app para 16+) |

---

## 🗂️ **SECCIÓN 1: RECOPILACIÓN Y USO DE DATOS**

### **1.1 Información Personal**

| Dato | ¿Se recopila? | ¿Se comparte? | Finalidad | Proveedor receptor |
|------|---------------|---------------|-----------|-------------------|
| **Nombre** | Sí (al crear cuenta) | Sí | Identificar usuario, mostrar en perfil | Firebase Authentication, Cloud Firestore |
| **Correo electrónico** | Sí (opcional, al vincular) | Sí | Recuperación de cuenta, login | Firebase Authentication, Cloud Firestore |
| **Número de teléfono** | Sí (solo si login por SMS) | Sí | Verificación SMS (2FA) | Firebase Authentication |
| **Nombre de usuario (alias)** | Sí (perfil anónimo) | Sí (solo con padrino) | Identidad visible en app | Cloud Firestore |

**Detalles:**
- El correo y teléfono son **opcionales** — se puede usar la app 100% anónima
- Al vincular Google, el email viene del proveedor OAuth
- El alias lo elige el usuario; no tiene que ser nombre real

---

### **1.2 Ubicación**

| Dato | ¿Se recopila? | ¿Se comparte? | Finalidad | Proveedor receptor |
|------|---------------|---------------|-----------|-------------------|
| **Ubicación precisa (GPS)** | Sí (solo si usuario crea zonas) | **No** | Activar bloqueo automático al entrar/salir de zona de concentración definida por el usuario | **Ninguno** (procesado localmente en dispositivo y servicio nativo Android) |
| **Ubicación aproximada** | No | No | — | — |

**⚠️ Crítico para revisor:**
- La app **NO** guarda historial de ubicaciones
- La app **NO** envía coordenadas actuales a servidores
- Solo guarda **coordenadas de zonas que el usuario crea a propósito** (nombre, lat, lng, radio) en Firestore
- El monitoreo ocurre en **servicio en primer plano (foreground service)** con tipo `location` — visible para el usuario con notificación persistente
- Permisos: `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE_LOCATION`

---

### **1.3 Actividad de la App (App Activity)**

| Dato | ¿Se recopila? | ¿Se comparte? | Finalidad | Proveedor receptor |
|------|---------------|---------------|-----------|-------------------|
| **Uso de apps (tiempo de pantalla, apps en primer plano)** | Sí (local) | **No** (nunca sale del dispositivo) | Mostrar estadísticas, top apps, estimar pickups, calcular racha | **Ninguno** (solo almacenamiento local via SharedPreferences) |
| **Apps bloqueadas / límites / horarios** | Sí | Sí (sync) | Sincronizar configuración entre dispositivos, aplicar bloqueo | Cloud Firestore |
| **Zonas de concentración** | Sí | Sí (sync) | Activar bloqueo geográfico | Cloud Firestore |
| **Interacciones con padrino** (solicitudes, mensajes, decisiones) | Sí | Sí (solo con padrino vinculado) | Función de responsabilidad voluntaria | Cloud Firestore |

**⚠️ Crítico:**
- **El detalle de uso de apps NUNCA sale del dispositivo** — se lee via `PACKAGE_USAGE_STATS` (UsageStatsManager), se procesa localmente, solo se muestran agregados al usuario
- Lo que se sincroniza a Firestore son **ajustes configurados por el usuario** (qué apps bloquear, límites, zonas), no el historial de uso
- La racha (streak) se calcula **localmente** comparando uso diario vs límite

---

### **1.4 Identificadores de Dispositivo**

| Dato | ¿Se recopila? | ¿Se comparte? | Finalidad | Proveedor receptor |
|------|---------------|---------------|-----------|-------------------|
| **Advertising ID (AAID / GAID)** | Sí | Sí | Mostrar anuncio recompensado (pausa extra), medir rendimiento | Google AdMob |
| **Push Token (FCM)** | Sí | Sí | Notificaciones push (timer, sponsor, smart suggestions) | Firebase Cloud Messaging |
| **Firebase Installation ID (FID)** | Sí | Sí | Identificar instalación para Analytics, Crashlytics | Firebase |

**Detalles:**
- AdMob: **Solo anuncio recompensado** — usuario elige verlo para ganar 15 min extra de pausa. No hay intersticiales ni banners.
- Push: Tokens rotados, almacenados en subcolección `push_tokens` con expiración y locale.

---

### **1.5 Autenticación y Cuenta**

| Dato | ¿Se recopila? | ¿Se comparte? | Finalidad | Proveedor receptor |
|------|---------------|---------------|-----------|-------------------|
| **Proveedor de acceso** (Google, Email/Password, Teléfono, Anónimo) | Sí | Sí | Mantener sesión, recuperar cuenta | Firebase Authentication |
| **UID de Firebase** | Sí | Sí (interno) | Clave primaria para todos los datos en Firestore | Cloud Firestore |

---

## 🗂️ **SECCIÓN 2: COMPARTIR DATOS CON TERCEROS**

| Tercero | Qué recibe | Finalidad | Ubicación de procesamiento |
|---------|------------|-----------|----------------------------|
| **Google LLC (Firebase Authentication)** | Email, nombre, teléfono, proveedor OAuth, UID | Gestión de cuentas, login, recuperación | Global (Google Cloud) |
| **Google LLC (Cloud Firestore)** | Ajustes usuario (apps, límites, zonas, hábitos, sponsor code, vínculo padrino) | Sincronización multi-dispositivo, backup | Global (Google Cloud) |
| **Google LLC (AdMob)** | Advertising ID, datos técnicos del anuncio (impresión, clic, recompensa) | Publicidad recompensada | Global (Google Ads) |
| **Google LLC (FCM)** | Push token, locale, foreground state | Notificaciones push | Global (Google Cloud) |
| **Google LLC (Apps Script + Gmail)** | Contenido de solicitud de desvinculación (cuando usuario la inicia) | Flujo soporte: email a `nerqovaassist@gmail.com` con enlaces Aprobar/Denegar | Global (Google Workspace) |

**⚠️ No se comparten datos con:**
- Redes publicitarias de terceros (solo AdMob/Google)
- Data brokers
- Analytics de terceros (no hay Firebase Analytics, Mixpanel, Amplitude, etc.)
- Ningún tercero para fines de marketing

---

## 🗂️ **SECCIÓN 3: PRÁCTICAS DE SEGURIDAD**

| Práctica | Implementación |
|----------|----------------|
| **Cifrado en tránsito** | TLS 1.2+ para todo tráfico (Firebase, AdMob, FCM, Apps Script) |
| **Cifrado en reposo** | Google Cloud (Firestore, Auth, FCM) — cifrado por defecto AES-256 |
| **Autenticación** | Firebase Auth (OAuth 2.0 / OIDC / Email-Password / Phone / Anonymous) |
| **Control de acceso** | Reglas de Firestore: cada usuario solo lee/escribe sus documentos; padrino solo ve solicitudes propias |
| **Eliminación de datos** | In-app (Settings → Delete account) + Web (`https://detox-legal.vercel.app/delete-account.html`) — borra Auth + Firestore + revoca tokens |
| **Retención mínima** | Datos de cuenta: mientras esté activa. Solicitudes padrino: 12 meses post-vínculo. Push tokens: rotados. Códigos desvinculación: 10 min. |

---

## 🗂️ **SECCIÓN 4: DERECHOS DEL USUARIO (ARCO / GDPR)**

| Derecho | Cómo ejercerlo |
|---------|----------------|
| **Acceso** | Ver perfil en app (Settings → Cuenta) o email a `nerqovaassist@gmail.com` |
| **Rectificación** | Editar username en app (Settings → Cuenta → Cambiar username) o email |
| **Cancelación (Eliminación)** | **In-app:** Settings → Tu cuenta → Eliminar cuenta (inmediato). **Web:** `https://detox-legal.vercel.app/delete-account.html` |
| **Oposición a publicidad** | Email `nerqovaassist@gmail.com` asunto "Oposición a publicidad" + resetear AAID en Android Settings |
| **Portabilidad** | Email solicitando exportación JSON de datos de Firestore |
| **Revocar consentimiento** | Revocar permisos Android (Settings → Apps → Detox → Permisos) o eliminar cuenta |

**Plazos:** Respuesta ≤ 20 días hábiles, ejecución ≤ 15 días hábiles posteriores. Gratuito.

---

## 🗂️ **SECCIÓN 5: DATOS SENSIBLES Y MENORES**

| Categoría | ¿Se recopila? | Detalle |
|-----------|---------------|---------|
| **Origen étnico/racial** | No | — |
| **Salud / información genética** | No | La app es bienestar digital, **no es tratamiento médico** (ver Términos §10) |
| **Creencias religiosas/filosóficas** | No | — |
| **Afiliación sindical** | No | — |
| **Preferencia sexual** | No | — |
| **Datos biométricos** | No | — |
| **Menores de 16 años** | **No** (política: 16+ años) | Términos §2 y Privacidad §8: se elimina si se detecta |

---

## 🗂️ **SECCIÓN 6: PERMISOS ANDROID Y JUSTIFICACIÓN**

| Permiso | Tipo | Justificación para Play Console |
|---------|------|---------------------------------|
| `PACKAGE_USAGE_STATS` | Especial (uso de apps) | **Núcleo de la app:** leer tiempo de pantalla, detectar app en primer plano para mostrar stats y activar bloqueo. App de bienestar digital legítima. |
| `SYSTEM_ALERT_WINDOW` | Especial (superposición) | **Núcleo de la app:** mostrar pantalla de bloqueo encima de app bloqueada durante sesión de enfoque. Solo para bloqueo, nunca para ads ni imitar otras apps. |
| `ACCESS_FINE_LOCATION` | Peligroso | Verificar entrada a zonas de concentración creadas por usuario. |
| `ACCESS_BACKGROUND_LOCATION` | Peligroso + Sensible | Monitoreo de zonas aunque app cerrada/reiniciado. Servicio en primer plano visible (`ForegroundService` tipo `location`). No historial, no envío a servidor. |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` / `FOREGROUND_SERVICE_LOCATION` | Normal | Servicios persistentes: bloqueo (specialUse) + monitor zonas (location). Subtipo `specialUse`: "Continuous user-enabled app blocking during focus sessions and schedules". |
| `POST_NOTIFICATIONS` | Peligroso | Mostrar timer de enfoque, estado de bloqueo, sugerencias inteligentes, avisos de padrino. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Especial | Evitar que Android mate servicio de bloqueo/monitor. Usuario guiado a settings, no forzado. |
| `RECEIVE_BOOT_COMPLETED` | Normal | Reiniciar monitor de zonas tras reboot. |
| `INTERNET` | Normal | Firebase sync, AdMob, FCM, Apps Script. |

---

## 🗂️ **SECCIÓN 7: RESPUESTAS PARA FORMULARIO PLAY CONSOLE (COPY-PASTE)**

### **7.1 Data Collection Summary**

> **Does your app collect or share any of the following user data?**
>
> ✅ **Personal info** — Name, Email address, Phone number, Username
> ✅ **Location** — Precise location (GPS) — *Only for user-defined geofences; no history stored or transmitted*
> ✅ **App activity** — App interactions, In-app search history, Other user-generated content (blocked apps, limits, zones, sponsor requests)
> ✅ **Device or other IDs** — Advertising ID, Push token, Firebase Installation ID
> ✅ **Authentication info** — Firebase UID, Auth provider
>
> ❌ Health & fitness, Financial info, Contacts, Messages, Photos, Files, Calendar, Microphone, Camera, Biometric data, Web browsing history

---

### **7.2 Data Sharing Summary**

> **Is any of this user data shared with third parties?**
>
> ✅ **Yes** — Shared with **Google LLC** for:
> - **Firebase Authentication** (account management)
> - **Cloud Firestore** (settings sync across devices)
> - **AdMob** (rewarded ads only — user-initiated)
> - **Firebase Cloud Messaging** (push notifications)
> - **Google Apps Script / Gmail** (support unlink flow — only when user requests)
>
> All processors act as **data processors** on our behalf. No data sold. No third-party ad networks beyond AdMob.

---

### **7.3 Data Collected but NOT Shared**

> **App usage statistics (screen time, top apps, pickups, streaks) are processed ENTIRELY LOCALLY on the device. They are NEVER transmitted to any server or shared with any third party. Only user-configured settings (which apps to block, daily limits, zones) are synced to Firestore.**

---

### **7.4 Security Practices**

> ✅ Data encrypted in transit (TLS 1.2+)
> ✅ Data encrypted at rest (Google Cloud default AES-256)
> ✅ User can delete account and all associated data from within the app (Settings → Account → Delete account) or via web (https://detox-legal.vercel.app/delete-account.html)
> ✅ Access controls via Firestore Security Rules (per-user isolation, sponsor-only access to unlock requests)
> ✅ Minimal retention: account data while active; sponsor requests 12 months; push tokens rotated; unlink codes 10 min expiry

---

### **7.5 User Rights**

> ✅ Users can request access, rectification, deletion, opposition, portability via email (nerqovaassist@gmail.com) or in-app deletion
> ✅ Response within 20 business days, execution within 15 business days
> ✅ Free of charge
> ✅ Advertising ID can be reset/limited in Android Settings; personalized ads can be opted out

---

### **7.6 Children / Sensitive Data**

> ❌ **No data collected from children under 16** — app requires 16+ (Terms §2, Privacy §8). Accounts detected under 16 are deleted.
> ❌ **No sensitive personal data collected** (health, biometrics, ethnicity, beliefs, sexual orientation, etc.) — Privacy §5.

---

## 🗂️ **SECCIÓN 8: MAPEO TÉCNICO → FORMULARIO**

| Campo Formulario Play | Valor en App | Código / Archivo |
|----------------------|--------------|------------------|
| **Nombre de la app** | Detox | `android:label="Detox"` |
| **Package name** | `com.nerqova.detox` | `applicationId` |
| **Versión** | 1.1.11+14 | `pubspec.yaml` |
| **URL Privacidad** | `https://detox-legal.vercel.app/aviso-de-privacidad.html` | `web/aviso-de-privacidad.html` |
| **URL Eliminación** | `https://detox-legal.vercel.app/delete-account.html` | `web/delete-account.html` |
| **Contacto privacidad** | `nerqovaassist@gmail.com` | `aviso-de-privacidad.html` §16 |
| **Categoría principal** | Herramientas / Estilo de vida | — |
| **Público objetivo** | 16+ años | `aviso-de-privacidad.html` §8 |

---

## ✅ **CHECKLIST FINAL ANTES DE ENVIAR**

- [ ] Todas las secciones completadas en Play Console
- [ ] URLs de privacidad y eliminación funcionan (200 OK)
- [ ] Video de ubicación background subido
- [ ] Credenciales de prueba configuradas en "App Access"
- [ ] Gráfico destacado + capturas subidas
- [ ] Data Safety form **coincide exactamente** con lo que hace la app (auditado arriba)
- [ ] No hay datos "fantasma" declarados que la app no recoja
- [ ] Permisos sensibles justificados con texto del formulario

---

**Generado automáticamente desde el código y documentación del proyecto.**
**Última actualización:** 2026-11-19