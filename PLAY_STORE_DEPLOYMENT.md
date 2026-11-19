# Detox — Google Play Store Deployment Checklist

**App:** Detox · **Package:** `com.nerqova.detox` · **Version:** 1.1.11+14 (versionCode 14)
**Developer:** Nerqova · **Firebase Project:** `detox-c0790` · **Vercel Project:** `detox-legal`

---

## ✅ **COMPLETADO — Bloqueantes Críticos Resueltos**

| Ítem | Estado | Detalles |
|------|--------|----------|
| **Política de Privacidad URL pública** | ✅ **LISTO** | `https://detox-legal.vercel.app/aviso-de-privacidad.html` |
| **Términos y Condiciones URL pública** | ✅ **LISTO** | `https://detox-legal.vercel.app/terminos-y-condiciones.html` |
| **Página de eliminación de cuenta URL pública** | ✅ **LISTO** | `https://detox-legal.vercel.app/delete-account.html` |
| **SHA-1/256 de Play App Signing en Firebase** | ✅ **REGISTRADO** | Confirmado por el usuario |

> **Nota:** Las URLs directas `.html` funcionan perfectamente (HTTP 200). Los rewrites (`/privacidad`, `/terminos`, `/eliminar-cuenta`) no están activos pero **no son necesarios** para Play Store.

---

## 📋 **PENDIENTE — Para Envío a Play Console**

### **1. Formulario de Seguridad de Datos (Data Safety)** ⏳
**Play Console → Contenido de la app → Seguridad de los datos**

**Datos a declarar (basado en `aviso-de-privacidad.html` y permisos):**

| Categoría | Datos | ¿Se comparte? | ¿Se recopila? |
|-----------|-------|---------------|---------------|
| **Información personal** | Nombre, correo electrónico, número de teléfono | Sí (Firebase, Google) | Sí |
| **Ubicación** | Ubicación precisa (`ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`) | No | Sí |
| **Actividad de la app** | Uso de apps (`PACKAGE_USAGE_STATS`), apps bloqueadas, límites, horarios | No (solo local) | Sí |
| **Identificadores de dispositivo** | Advertising ID (AdMob), push token (FCM) | Sí (Google AdMob, Firebase) | Sí |
| **Autenticación** | Proveedor de acceso (Google, email, teléfono, anónimo) | Sí (Firebase) | Sí |

**Finalidades:**
- Funcionamiento de la app (primaria)
- Publicidad recompensada (secundaria, opcional)

**Prácticas de seguridad:**
- Cifrado en tránsito (TLS) ✅
- Eliminación de cuenta disponible ✅
- Datos de uso de apps **nunca salen del dispositivo** ✅

---

### **2. Clasificación de Contenido (IARC)** ⏳
**Play Console → Contenido de la app → Clasificación del contenido**

- **Categoría probable:** "Everyone" (Todos) o "Teen" (Adolescentes)
- **Contenido:** Bienestar digital, sin violencia, sin contenido adulto, sin compras
- **Cuestionario IARC:** Completar y enviar

---

### **3. Credenciales de Prueba (App Access) — CRÍTICO** ⏳
**Play Console → Contenido de la app → Acceso a la app**

> **Sin esto, el revisor no puede entrar y la app es rechazada automáticamente.**

**Crear cuenta de prueba real con datos precargados:**

| Campo | Valor sugerido |
|-------|----------------|
| **Email** | `reviewer@nerqova.com` (o cuenta Google real) |
| **Password** | `TestPass123!` |
| **Datos precargados:** | |
| • Límite diario | 180 min (3h) |
| • Apps limitadas | Instagram (30 min), TikTok (25 min), YouTube (45 min) — todas `useInFocusMode: true` |
| • Zona de concentración | "Casa" / "Oficina" (coordenadas reales, radio 400m, apps bloqueadas) |
| • Patrocinador vinculado | Código patrocinador generado, con solicitud de desbloqueo pendiente |
| • Historial de uso | Algunos días con datos para que Dashboard/Stats no estén vacíos |

**Instrucciones para revisor:** Incluir en el campo "Notas" cómo probar el bloqueo, zonas y patrocinador.

---

### **4. Ubicación en Segundo Plano — Video + Declaración** ⏳
**Play Console → Contenido de la app → Permisos sensibles → Ubicación en segundo plano**

**Requisitos:**
1. **Declaración escrita** explicando:
   - Único uso: verificar si el usuario entra en una zona de concentración **creada por él**
   - No se guarda historial de ubicaciones
   - No se envía ubicación al servidor
   - Solo coordenadas de zonas guardadas en Firestore

2. **Video demo (grabación de pantalla):**
   - Usuario abre app → Configuración → Zonas → Crear zona
   - Usuario simula entrada a la zona (GPS mock o caminando)
   - Bloqueo se activa automáticamente
   - Mostrar que en ajustes de Android → Permisos → Ubicación → "Permitir todo el tiempo"

**Duración sugerida:** 60-90 segundos, narrado en inglés.

---

### **5. Tipos de Servicio en Primer Plano** ⏳
**Play Console → Contenido de la app → Tipos de servicio en primer plano**

| Tipo | Subtipo declarado en `AndroidManifest.xml` |
|------|--------------------------------------------|
| **Special use** | `Continuous user-enabled app blocking during focus sessions and schedules` |
| **Location** | (para el monitor de zonas en background) |

**Acción:** Seleccionar ambos y pegar la justificación del `specialUse`.

---

### **6. Declaración de Anuncios** ⏳
**Play Console → Contenido de la app → Anuncios**

- ✅ **Contiene anuncios:** Sí (AdMob recompensado)
- **ID de app AdMob (release):** `ca-app-pub-5614533913981580~9515972522`
- **Formato:** Solo recompensado (usuario elige verlo para pausa extra)
- **Consentimiento EEE/UK:** ⚠️ Pendiente integrar **Google UMP SDK**

---

### **7. Assets de la Ficha (Store Listing)** ⏳
**Play Console → Ficha de la tienda → Ficha principal**

| Asset | Especificación | Estado |
|-------|----------------|--------|
| **Icono 512×512** | PNG, sin transparencia en bordes | ✅ `docs/brand/detox-icon/icono_app.png` |
| **Gráfico destacado** | **1024 × 500 px**, JPG/PNG, **OBLIGATORIO** | ❌ **FALTA** |
| **Capturas teléfono** | Mín 2, máx 8 (16:9 o 9:16) | ❌ **FALTAN** |
| **Descripción corta** | ≤ 80 caracteres | ❌ **REDactar** |
| **Descripción completa** | ≤ 4000 caracteres | ❌ **REDactar** |
| **Categoría** | Estilo de vida / Herramientas | ❌ **ELEGIR** |
| **Etiquetas** | 5 máx (ej: focus, screen time, digital wellbeing) | ❌ **ELEGIR** |

**Sugerencia descripción corta:** "Controla tu tiempo de pantalla, bloquea distracciones y enfócate en lo importante."

---

### **8. Build y Pruebas Técnicas** ⏳

```bash
# 1. Bump versionCode (pubspec.yaml)
version: 1.1.11+14   # era +13

# 2. Build AAB release
flutter build appbundle --release

# 3. Verificar alineación 16 KB
"$ANDROID_HOME/build-tools/<version>/zipalign" -c -P 16 -v 4 \
  build/app/outputs/bundle/release/app-release.aab

# 4. Probar en DISPOSITIVO REAL (no emulador):
#    ✅ Google Sign-In funciona
#    ✅ App blocking se activa
#    ✅ Zonas de concentración disparan bloqueo
#    ✅ Anuncio recompensado carga y da pausa
#    ✅ Notificaciones muestran timer
#    ✅ Reinicio → zonas siguen activas (BootReceiver)

# 5. Subir AAB a Prueba Cerrada (Closed Testing)
```

---

### **9. Configuración Firebase Post-Upload** ⏳
**Tras subir primer AAB a Play Console:**

1. Play Console → **Integridad de la app** → Copiar **SHA-1 y SHA-256 de "Firma de apps de Play"**
2. Firebase Console → **Autenticación** → **Método de acceso** → Android → **Agregar ambos hashes**
3. Verificar que Google Sign-In sigue funcionando en Internal Testing

> ✅ **Ya confirmado por el usuario: SHA-1 registrado correctamente.**

---

### **10. Facturación Firebase (Blaze)** ⏳
**Firebase Console → Configuración del proyecto → Uso y facturación**

- Requerido para: Apps Script (Firestore REST), Cloud Functions, quotas aumentadas
- Plan: **Blaze (pago por uso)** — costo mínimo si solo Apps Script

---

### **11. Apps Script — Soporte Desvinculación** ⏳
**Seguir `FIREBASE_EMAIL_SETUP.md` pasos 1-5:**

1. Abrir script en `https://script.google.com/d/1o1WUWZylnx2WiJRkr75ZnoRygIvfUwGno5dgB5cJhtShboVHQHwGn6s0/edit`
2. Deploy → Web App → Execute as: Me / Who has access: Anyone
3. Ejecutar `installPollingTrigger` una vez
4. Probar flujo: App → Solicitar desvinculación → Email → Aprobar/Denegar

---

### **12. Google UMP SDK (Consentimiento EEE/UK)** ⏳
**Requerido para AdMob personalizado en Europa.**

- Integrar `google_user_messaging_platform` en `pubspec.yaml`
- Configurar en AdMob → Privacidad y mensajes → Crear mensaje GDPR
- Mostrar antes de cargar anuncios si usuario en EEE/UK

---

## 🏢 **TIPO DE CUENTA DE DESARROLLADOR — Define el Camino**

| Tipo de cuenta | Requisito previo a producción |
|----------------|-------------------------------|
| **Organización (Nerqova)** | D-U-N-S + verificación empresarial. **NO hay regla de 14 días.** |
| **Personal (creada después 13-nov-2023)** | **12 testers × 14 días continuos** en Prueba Cerrada antes de pedir producción. |

> **Recomendación:** Registrar como **Organización** si tienes D-U-N-S. Ahorra 2 semanas.

---

## 📅 **ORDEN RECOMENDADO DE EJECUCIÓN**

### **Fase 0 — Preparación (1-2 días)**
- [ ] Redactar Data Safety form (usar tabla arriba)
- [ ] Completar cuestionario IARC
- [ ] Crear **cuenta de prueba real** con datos precargados
- [ ] Grabar **video demo ubicación background** (60-90s, narrado en inglés)
- [ ] Redactar textos de ficha + crear **gráfico destacado 1024×500** + **4+ capturas**
- [ ] Subir `versionCode` a 14 en `pubspec.yaml`

### **Fase 1 — Play Console (1 día)**
- [ ] Completar *Contenido de la app*:
  - [ ] Data Safety
  - [ ] Clasificación IARC
  - [ ] **Acceso a la app (con credenciales de prueba)**
  - [ ] **Permisos sensibles → Ubicación background (subir video + declaración)**
  - [ ] Tipos de servicio en primer plano (specialUse + location)
  - [ ] Anuncios → "Contiene anuncios"
  - [ ] URLs legales (ya tienes las 3)
- [ ] Subir AAB a **Prueba cerrada**

### **Fase 2 — Firebase (inmediato tras subir AAB)**
- [ ] Copiar **SHA-1/256 Play App Signing** → Firebase Auth → Android app ✅ (confirmado)
- [ ] Habilitar **Facturación (Blaze)** en Firebase
- [ ] Desplegar **Apps Script** (flujo desvinculación email)

### **Fase 3 — Pruebas (0-14 días)**
- [ ] Si cuenta **personal**: reclutar 12 testers, 14 días activos
- [ ] Si cuenta **organización**: saltar a Fase 4

### **Fase 4 — Producción**
- [ ] Solicitar **acceso a producción** + cuestionario de pruebas
- [ ] Despliegue escalonado 20% → vigilar *Android Vitals* y reseñas

---

## 🔗 **URLS DE REFERENCIA RÁPIDA**

| Recurso | URL |
|---------|-----|
| **Play Console** | `https://play.google.com/console/u/0/developers/` |
| **Firebase Console (detox-c0790)** | `https://console.firebase.google.com/project/detox-c0790` |
| **Vercel (detox-legal)** | `https://vercel.com/nerqova/detox-legal` |
| **Privacidad** | `https://detox-legal.vercel.app/aviso-de-privacidad.html` |
| **Términos** | `https://detox-legal.vercel.app/terminos-y-condiciones.html` |
| **Eliminar cuenta** | `https://detox-legal.vercel.app/delete-account.html` |
| **Apps Script** | `https://script.google.com/d/1o1WUWZylnx2WiJRkr75ZnoRygIvfUwGno5dgB5cJhtShboVHQHwGn6s0/edit` |
| **AdMob** | `https://apps.admob.com/v2/apps/5614533913981580` |

---

## ⚠️ **TOP 3 MOTIVOS DE RECHAZO PARA ESTA APP**

1. **Sin credenciales de prueba** → Revisor no entra → **Rechazo automático**
2. **Ubicación background sin video/declaración** → Política sensible → **Rechazo**
3. **Data Safety incompleto o inconsistente** → **Rechazo**

---

## ✅ **LO QUE YA TIENES BIEN (No tocar)**

- `targetSdk = 36`, `minSdk = 24`, alineación 16 KB
- Firma release + `key.properties` fuera de git
- Minificación R8 + ProGuard
- Icono adaptable + legacy round
- AdMob IDs reales en release
- Eliminación de cuenta in-app (`AuthService.deleteAccount()`)
- Bilingüe ES/EN nativo
- Foreground service `specialUse` + `location` en Manifest
- Reglas Firestore desplegadas y correctas (5 usuarios reales)
- Apps Script listo para desplegar
- Páginas legales en Vercel (3 URLs funcionando)

---

**Última actualización:** $(date)  
**Próximo paso sugerido:** Crear cuenta de prueba + grabar video ubicación + gráfico destacado