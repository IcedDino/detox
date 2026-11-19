# Background Location Video Script — Detox (com.nerqova.detox)

**Duración objetivo:** 60–90 segundos  
**Idioma:** Inglés (narración) — requerido por revisores de Play Console  
**Formato:** Grabación de pantalla (screen record) + voz en off  
**Dispositivo:** Android real (no emulador) — preferiblemente con GPS mock para control total

---

## 🎬 **Guion Completo (Escena por Escena)**

| Tiempo | Acción en Pantalla | Narración (Inglés) | Notas Técnicas |
|--------|-------------------|-------------------|----------------|
| **0:00–0:05** | **Intro** — App icon → tap → abre Detox en pantalla principal (Dashboard) | "This is Detox, a digital wellbeing app that helps users focus by blocking distracting apps." | Muestra logo + nombre. Dashboard con datos de demo. |
| **0:05–0:12** | **Navegación a Zonas** — Tap en **Settings** (4ª pestaña) → Scroll a **Concentration Zones** → Tap **"Add zone"** | "Users can create concentration zones — specific locations where selected apps are automatically blocked." | Muestra la lista vacía o con 1 zona existente. |
| **0:12–0:25** | **Crear zona** —<br>1. Nombre: "Office"<br>2. Mapa: centrar en ubicación actual (botón GPS)<br>3. Radio: 100–200 m (slider)<br>4. Apps bloqueadas: seleccionar 2–3 (Instagram, TikTok, YouTube)<br>5. Tap **Save** | "The user names the zone, sets the radius, and chooses which apps to block when inside. All configuration is explicit and user-initiated." | **Clave:** Mostrar que el usuario ELIGE apps y coordenadas. No hay tracking oculto. |
| **0:25–0:32** | **Zona creada** — Lista muestra "Office · Enabled · 150m · 3 apps" → Toggle **ON** (ya está) | "The zone is now active. Detox will monitor location only while this zone is enabled." | Resaltar que el toggle controla el monitoreo. |
| **0:32–0:40** | **Permiso de ubicación** — Salir de app → **Android Settings** → Apps → Detox → Permissions → Location → Seleccionar **"Allow all the time"** | "Because zones work even when the app is closed, the user grants 'Allow all the time' location permission. This is clearly disclosed before the request." | **Crítico para revisor:** Mostrar el diálogo del sistema y la selección explícita. |
| **0:40–0:45** | **Servicio en primer plano** — Volver a app → Swipe down notification shade → Mostrar notificación persistente: **"Detox is monitoring concentration zones"** | "A persistent foreground service notification is always visible while zone monitoring is active. The user can tap it to return to the app or disable zones." | Mostrar que la notificación NO se puede swipiar (ongoing). |
| **0:45–0:55** | **Entrada a zona (GPS Mock)** —<br>Opción A: **GPS mock app** (Fake GPS, GPS Joystick) → Set coordenadas dentro del radio → Tap "Start"<br>Opción B: **Caminar físicamente** si estás en la ubicación real | "When the user enters the zone radius, Detox detects the location locally and activates the blocking screen for the selected apps." | **GPS mock recomendado:** Control total, reproducible, sin depender de GPS real. |
| **0:55–1:05** | **Bloqueo activado** —<br>1. Intentar abrir Instagram (tap icono)<br>2. Pantalla de bloqueo Detox aparece: "Focus time — This app is blocked"<br>3. Botones: "Exit focus", "Request pause (sponsor)"<br>4. Volver a Home → Instagram sigue bloqueado | "The blocking screen covers the target app immediately. The user cannot access the blocked app unless they end the focus session or request a sponsor-approved pause." | Mostrar que el bloqueo es real (overlay SYSTEM_ALERT_WINDOW). |
| **1:05–1:12** | **Salida de zona** — GPS mock → Mover coordenadas fuera del radio → Tap "Start" → Esperar 5–10 seg → Notificación: "You left Office zone" → Instagram se desbloquea | "When the user leaves the zone, blocking stops automatically. No manual action required." | Demostrar que es **bidireccional**: entra → bloquea, sale → desbloquea. |
| **1:12–1:18** | **No hay historial** — Settings → Concentration Zones → Tap zona "Office" → Mostrar: **solo** nombre, coordenadas, radio, apps. **No** lista de entradas/salidas, **no** timestamps de ubicación | "Detox does not store location history. Only the zone definition (name, coordinates, radius) is saved. No timestamps, no tracks, no server upload." | **Punto clave de política:** Subrayar visualmente la ausencia de historial. |
| **1:18–1:25** | **Firestore (opcional)** — Abrir Firebase Console → Firestore → users/{uid}/concentrationZones → Mostrar documento: solo `name`, `latitude`, `longitude`, `radiusMeters`, `blockedPackages`, `enabled` | "The same data synced to Firestore: only the zone configuration. No location history, no real-time position." | Solo si tienes acceso rápido a Firebase Console en el dispositivo (o captura previa). |
| **1:25–1:30** | **Cierre** — Pantalla principal Detox → Texto en pantalla: **"Location used only for user-defined zones • No history • No server upload"** | "Detox uses background location exclusively for user-defined concentration zones. No history is stored. No location data leaves the device." | Texto final en pantalla + voz. |

---

## 📝 **Guion de Voz en Off (Solo Texto — Para Grabar Audio)**

> "This is Detox, a digital wellbeing app that helps users focus by blocking distracting apps.
>
> Users can create concentration zones — specific locations where selected apps are automatically blocked. The user names the zone, sets the radius, and chooses which apps to block when inside. All configuration is explicit and user-initiated.
>
> The zone is now active. Detox will monitor location only while this zone is enabled.
>
> Because zones work even when the app is closed, the user grants 'Allow all the time' location permission. This is clearly disclosed before the request.
>
> A persistent foreground service notification is always visible while zone monitoring is active. The user can tap it to return to the app or disable zones.
>
> When the user enters the zone radius, Detox detects the location locally and activates the blocking screen for the selected apps.
>
> The blocking screen covers the target app immediately. The user cannot access the blocked app unless they end the focus session or request a sponsor-approved pause.
>
> When the user leaves the zone, blocking stops automatically. No manual action required.
>
> Detox does not store location history. Only the zone definition — name, coordinates, radius — is saved. No timestamps, no tracks, no server upload.
>
> The same data synced to Firestore: only the zone configuration. No location history, no real-time position.
>
> Detox uses background location exclusively for user-defined concentration zones. No history is stored. No location data leaves the device."

---

## 🛠 **Preparación Técnica (Antes de Grabar)**

| Paso | Acción | Herramienta |
|------|--------|-------------|
| **1. GPS Mock** | Instalar app de GPS falso (no requiere root en Android 12+) | **Fake GPS Location** (Lexa), **GPS Joystick** (App Ninja), o **Mock Location** (developer options) |
| **2. Developer Options** | Habilitar "Select mock location app" → elegir tu GPS mock | Settings → System → Developer options |
| **3. Coordenadas de prueba** | Calcular lat/lng + 100m radio desde tu ubicación actual | Google Maps → click derecho → "What's here?" + calcular offset |
| **4. Apps a bloquear** | Instalar Instagram, TikTok, YouTube (o las que uses en demo) | Play Store |
| **5. Cuenta de prueba** | Iniciar sesión en Detox con cuenta que tenga zona "Office" precreada | `reviewer@nerqova.com` |
| **6. Grabación** | Screen recorder nativo (Android 11+) o AZ Screen Recorder | Sin audio del sistema, solo micrófono para voz |
| **7. Resolución** | 1080p (1920×1080) o 720p — Play Console acepta ambos | Landscape (horizontal) preferido |

---

## 📱 **Coordenadas de Ejemplo (Para GPS Mock)**

Si estás en **Aguascalientes, México** (oficina del proyecto):

| Punto | Latitud | Longitud | Descripción |
|-------|---------|----------|-------------|
| **Centro zona "Office"** | `21.8853` | `-102.2916` | Centro ciudad |
| **Dentro (50m)** | `21.8858` | `-102.2912` | ~50m NE — **activa bloqueo** |
| **Fuera (300m)** | `21.8880` | `-102.2880` | ~300m NE — **desactiva bloqueo** |

> **Tip:** Usa [gps-coordinates.net](https://gps-coordinates.net) o Google Maps para calcular puntos exactos a 100m/300m de tu centro.

---

## ✅ **Checklist de Calidad (Antes de Subir a Play Console)**

- [ ] **Duración:** 60–90 segundos exactos
- [ ] **Audio:** Inglés claro, sin ruido de fondo, volumen constante
- [ ] **Video:** 1080p, horizontal, sin marcas de agua, sin notificaciones personales visibles
- [ ] **Permiso mostrado:** Diálogo sistema "Allow all the time" visible y seleccionado
- [ ] **Foreground service:** Notificación persistente visible en shade
- [ ] **Bloqueo real:** App objetivo (Instagram/TikTok) se abre → pantalla bloqueo Detox aparece
- [ ] **Bidireccional:** Entrada → bloqueo, Salida → desbloqueo
- [ ] **Sin historial:** Se muestra UI donde **no** hay lista de entradas/salidas
- [ ] **Firestore (opcional):** Documento zona solo tiene config, no timestamps de ubicación
- [ ] **Texto final:** Pantalla con las 3 frases clave visibles 3+ segundos

---

## 📤 **Entrega a Play Console**

| Campo en Play Console | Qué subir |
|----------------------|-----------|
| **Background location video** | Archivo `.mp4` (≤ 100 MB recomendado) |
| **Background location declaration** | Texto del formulario (ver `DATA_SAFETY_FORM.md` §6) |

**Nombre de archivo sugerido:** `detox_background_location_demo.mp4`

---

## 🎯 **Frases Clave para el Revisor (Incluir en Texto Declaración)**

> 1. **"Location is used ONLY for user-defined concentration zones."**
> 2. **"No location history is stored — locally or on servers."**
> 3. **"No real-time position is transmitted to any backend."**
> 4. **"Monitoring runs in a visible foreground service with persistent notification."**
> 5. **"User explicitly grants 'Allow all the time' after in-app disclosure."**
> 6. **"Zone configuration (name, coordinates, radius, blocked apps) is the only data synced to Firestore."**

---

## 📋 **Versión Corta (Si Revisor Pide Resumen Escrito)**

> **Detox uses `ACCESS_BACKGROUND_LOCATION` exclusively to monitor user-defined concentration zones. The user creates a zone (name, coordinates, radius, blocked apps), enables it, and grants 'Allow all the time' permission after an in-app disclosure. Monitoring runs in a foreground service with a persistent notification. When the user enters the zone radius, selected apps are blocked via overlay; when they leave, blocking stops automatically. No location history is stored locally or synced to Firestore. Only the zone definition is saved. No real-time position leaves the device.**

---

**Generado para:** Detox v1.1.11+14 (`com.nerqova.detox`)  
**Fecha:** 2026-11-19  
**Basado en:** `LocationZoneService`, `FocusBlockerService`, `AndroidManifest.xml`, `aviso-de-privacidad.html`