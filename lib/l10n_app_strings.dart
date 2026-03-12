
import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  static AppStrings of(BuildContext context) => AppStrings(Localizations.localeOf(context));

  bool get isEs => locale.languageCode.toLowerCase().startsWith('es');

  String get home => isEs ? 'Inicio' : 'Home';
  String get focus => isEs ? 'Enfoque' : 'Focus';
  String get habits => isEs ? 'Hábitos' : 'Habits';
  String get stats => isEs ? 'Estadísticas' : 'Stats';
  String get settings => isEs ? 'Configuración' : 'Settings';

  String get ownYourAttention => isEs ? 'Toma control de tu atención' : 'Own your attention';
  String get authSubtitle => isEs
      ? 'Crea tu cuenta primero y sincroniza tus hábitos de enfoque, apps bloqueadas y zonas de concentración entre dispositivos.'
      : 'Create your account first, then sync your focus habits, blocked apps, and study zones across devices.';
  String get continueWithGoogle => isEs ? 'Continuar con Google' : 'Continue with Google';
  String get continueWithPhone => isEs ? 'Continuar con teléfono' : 'Continue with phone';
  String get signIn => isEs ? 'Iniciar sesión' : 'Sign in';
  String get createAccount => isEs ? 'Crear cuenta' : 'Create account';
  String get welcomeBack => isEs ? 'Bienvenido de vuelta' : 'Welcome back';
  String get signInSubtitle => isEs ? 'Inicia sesión con el correo que ya vinculaste a Detox.' : 'Sign in with the email you already linked to Detox.';
  String get createAccountTitle => isEs ? 'Crea tu cuenta Detox' : 'Create your Detox account';
  String get createAccountSubtitle => isEs ? 'Empieza con correo y sincroniza tu progreso entre dispositivos.' : 'Start with email, then link your focus progress across devices.';
  String get name => isEs ? 'Nombre' : 'Name';
  String get email => isEs ? 'Correo' : 'Email';
  String get password => isEs ? 'Contraseña' : 'Password';
  String get enterName => isEs ? 'Escribe tu nombre' : 'Enter your name';
  String get enterValidEmail => isEs ? 'Escribe un correo válido' : 'Enter a valid email';
  String get useSixChars => isEs ? 'Usa al menos 6 caracteres' : 'Use at least 6 characters';
  String get phoneSignIn => isEs ? 'Acceso con teléfono' : 'Phone sign-in';
  String get phoneInstructions => isEs ? 'Usa tu número con lada, por ejemplo +526000000000.' : 'Use your number with country code, for example +526000000000.';
  String get phoneNumber => isEs ? 'Número de teléfono' : 'Phone number';
  String get smsCode => isEs ? 'Código SMS' : 'SMS code';
  String get cancel => isEs ? 'Cancelar' : 'Cancel';
  String get sendCode => isEs ? 'Enviar código' : 'Send code';
  String get verifyCode => isEs ? 'Verificar código' : 'Verify code';
  String get smsCodeSent => isEs ? 'Código SMS enviado.' : 'SMS code sent.';

  String get welcomeToDetox => isEs ? 'Bienvenido a Detox' : 'Welcome to Detox';
  String get permissionsIntro => isEs
      ? 'Reduce el scroll impulsivo, protege tu enfoque y crea hábitos digitales que sí se mantengan.'
      : 'Reduce mindless scrolling, protect your focus, and build digital habits that actually stick.';
  String get whatDetoxUses => isEs ? 'Lo que usará Detox' : 'What Detox will use';
  String get permReadUsage => isEs ? 'Leer el tiempo de uso y las apps principales.' : 'Read screen-time usage and top apps.';
  String get permShield => isEs ? 'Cubrir apps seleccionadas durante sesiones de enfoque.' : 'Shield selected apps during focus sessions.';
  String get permZones => isEs ? 'Activar zonas de estudio automáticamente cuando llegues.' : 'Auto-activate study zones when you arrive at them.';
  String get permissionStatus => isEs ? 'Estado de permisos' : 'Permission status';
  String get checkingPermissions => isEs ? 'Verificando permisos…' : 'Checking permissions...';
  String get returnAndRefresh => isEs ? 'Cuando regreses de Configuración, Detox detectará el permiso automáticamente.' : 'As soon as you return from Android settings, Detox will detect the permission automatically.';
  String get specialPermissionsTitle => isEs ? 'Los permisos especiales necesitan una visita rápida a Configuración.' : 'Special permissions need one quick trip to Android Settings.';
  String get specialPermissionsBody => isEs ? 'Toca cada botón para abrir Configuración. Cuando regreses a Detox, esta pantalla revisará automáticamente y avanzará en cuanto todo esté listo.' : 'Tap each button to open Android Settings. When you come back to Detox, this screen will automatically check again and continue as soon as everything is ready.';
  String get openUsageAccess => isEs ? 'Abrir acceso de uso' : 'Open usage access';
  String get openOverlayPermission => isEs ? 'Abrir permiso de superposición' : 'Open overlay permission';
  String get continueText => isEs ? 'Continuar' : 'Continue';
  String get allowLocationForZones => isEs ? 'Permitir ubicación para zonas de estudio' : 'Allow location for study zones';
  String get skipForNow => isEs ? 'Omitir por ahora' : 'Skip for now';
  String get usageReadyDetected => isEs ? 'Acceso de uso detectado y listo.' : 'Usage access detected and ready.';
  String get usageNeededMessage => isEs ? 'Activa Acceso de uso para que Detox pueda leer el tiempo de pantalla y detectar la app al frente.' : 'Enable Usage Access so Detox can read screen time and detect the foreground app.';
  String get overlayReady => isEs ? 'Permiso de superposición listo.' : 'Overlay permission ready.';
  String get overlayNeeded => isEs ? 'Aún falta el permiso de superposición para proteger apps.' : 'Overlay permission still needed for app shielding.';

  String get darkMode => isEs ? 'Modo oscuro' : 'Dark mode';
  String get darkModeSubtitle => isEs ? 'Cambia entre la apariencia oscura y clara de Detox.' : 'Switch between Detox dark and light appearance.';
  String get language => isEs ? 'Idioma' : 'Language';
  String get dailyScreenTimeLimit => isEs ? 'Límite diario de tiempo de pantalla' : 'Daily screen-time limit';
  String minutesLabel(int n) => isEs ? '$n minutos' : '$n minutes';
  String get openAndroidUsageSettings => isEs ? 'Abrir ajustes de uso de Android' : 'Open Android usage settings';
  String get grantUsageAndRefresh => isEs ? 'Concede Acceso de uso y Detox se actualizará automáticamente.' : 'Grant Usage Access and Detox will refresh automatically.';
  String get focusShieldOverlay => isEs ? 'Superposición del escudo de enfoque' : 'Focus shield overlay';
  String get overlayGrantShield => isEs ? 'Concede superposición para que Detox cubra apps bloqueadas durante el enfoque.' : 'Grant overlay permission so Detox can cover blocked apps during focus mode.';
  String get overlayReadyShield => isEs ? 'La superposición está lista para cubrir apps bloqueadas.' : 'Overlay is ready to shield blocked apps.';
  String get perAppLimits => isEs ? 'Límites por app' : 'Per-app limits';
  String get pickAppsBody => isEs ? 'Elige apps instaladas y marca cuáles participan en el bloqueo de enfoque.' : 'Pick apps from your installed list and mark which ones join focus blocking.';
  String get noPerAppLimits => isEs ? 'Aún no hay límites por app.' : 'No per-app limits yet.';
  String get blockInFocusMode => isEs ? 'Bloquear en modo enfoque' : 'Block in focus mode';
  String get focusModeBlockSubtitle => isEs ? 'Esta app será cubierta durante el temporizador y las zonas de estudio.' : 'This app will be shielded during timer focus and study zones.';
  String get signOut => isEs ? 'Cerrar sesión' : 'Sign out';
  String get returnLoginScreen => isEs ? 'Volver a la pantalla de acceso' : 'Return to the login screen';
  String get sponsorCenter => isEs ? 'Centro de padrino' : 'Sponsor center';
  String get open => isEs ? 'Abrir' : 'Open';
  String get concentrationZones => isEs ? 'Zonas de concentración' : 'Concentration zones';

  String get orUseEmail => isEs ? 'O usa correo' : 'Or use email';
  String get permissionsOverview => isEs ? 'Resumen de permisos' : 'Permissions overview';
  String get iosSeparatePath => isEs ? 'En iOS esto usa una ruta nativa separada de Screen Time.' : 'iOS support uses a separate native Screen Time path.';
  String get iosAppsBody => isEs ? 'En iOS aún no se pueden listar apps instaladas de la misma manera.' : 'On iOS, installed apps cannot be listed the same way yet.';

  String get dashboardTitle => isEs ? 'Panel Detox' : 'Detox Dashboard';
  String get dashboardSubtitle => isEs ? 'Reduce el scroll impulsivo y construye hábitos digitales con intención.' : 'Reduce mindless scrolling and build intentional digital habits.';
  String get today => isEs ? 'Hoy' : 'Today';
  String get pickups => isEs ? 'Desbloqueos' : 'Pickups';
  String get topApp => isEs ? 'App principal' : 'Top app';
  String get topAppsToday => isEs ? 'Apps más usadas hoy' : 'Top apps today';
  String goalUsed(String goal, int pct) => isEs ? 'Meta: $goal · $pct% usado' : 'Goal: $goal · $pct% used';
  String get estimatedUnlocks => isEs ? 'Desbloqueos estimados' : 'Estimated unlocks';
  String minToday(int mins) => isEs ? '$mins min hoy' : '$mins min today';
  String get noDataYet => isEs ? 'Sin datos aún' : 'No data yet';
  String get noAppUsageYet => isEs ? 'Aún no hay uso de apps disponible.' : 'No app usage available yet.';
  String get realUsageInactive => isEs ? 'El uso real del dispositivo aún no está activo en esta plataforma. En Android se actualiza automáticamente después de conceder Acceso de uso.' : 'Real device usage is not active yet on this platform. Android updates automatically after you grant Usage Access.';

  String get focusTitle => isEs ? 'Temporizador de enfoque' : 'Focus timer';
  String get focusSubtitle => isEs ? 'Inicia una sesión y cubre tus apps de distracción.' : 'Start a session and shield your distraction apps.';
  String get focusBeforeStart => isEs ? 'Antes de empezar' : 'Before you start';
  String get focusNeedUsage => isEs ? 'Concede Acceso de uso en Configuración para que Detox detecte la app al frente y la cubra.' : 'Grant Usage Access in Settings so Detox can detect the foreground app and shield it.';
  String get focusNeedOverlay => isEs ? 'Concede permiso de superposición para que Detox pueda cubrir apps bloqueadas durante el enfoque.' : 'Grant overlay permission so Detox can cover blocked apps during focus.';
  String get focusChooseApps => isEs ? 'Elige apps en Configuración y márcalas para el modo enfoque.' : 'Choose apps in Settings and mark them for focus mode.';
  String get focusShieldActive => isEs ? 'Escudo de enfoque activo' : 'Focus shield active';
  String get focusReadyToStart => isEs ? 'Listo para empezar' : 'Ready to start';
  String minuteShort(int minutes) => isEs ? '$minutes min' : '$minutes min';
  String get stopSession => isEs ? 'Detener sesión' : 'Stop session';
  String get startFocusSession => isEs ? 'Iniciar sesión de enfoque' : 'Start focus session';
  String get shieldedDuringFocus => isEs ? 'Apps protegidas durante el enfoque' : 'Apps shielded during focus';
  String get addAppsForFocus => isEs ? 'Agrega apps en Configuración para que tu zona de enfoque tenga objetivos listos para bloquear.' : 'Add apps in Settings so your focus zone has targets ready to block.';
  String get studyZoneAutomation => isEs ? 'Automatización de zonas de estudio' : 'Study-zone automation';
  String get studyZoneAutomationBody => isEs ? 'Detox puede activar automáticamente el enfoque educativo cuando llegues a una zona de estudio.' : 'Detox can auto-activate educational focus when you arrive at a study zone.';
  String get grantUsageSnack => isEs ? 'Primero concede Acceso de uso para que Detox pueda detectar la app en primer plano.' : 'Grant Usage Access first so Detox can detect the foreground app.';
  String get grantOverlaySnack => isEs ? 'Primero concede el permiso de superposición para que Detox pueda cubrir apps bloqueadas.' : 'Grant overlay permission first so Detox can shield blocked apps.';
  String get addAppsSnack => isEs ? 'Agrega apps en Configuración para que Detox sepa qué debe cubrir.' : 'Add apps in Settings so Detox knows what to shield.';
  String get focusSessionActiveReason => isEs ? 'Temporizador de enfoque activo' : 'Focus timer active';
  String get focusSessionLabel => isEs ? 'Temporizador de enfoque' : 'Focus timer';
  String get focusCompleteSnack => isEs ? 'Sesión de enfoque completada. Buen trabajo.' : 'Focus session complete. Great job.';

  String get habitsTitle => isEs ? 'Hábitos' : 'Habits';
  String completedTodayText(int done, int total) => isEs ? 'Completados hoy: $done / $total' : 'Completed today: $done / $total';
  String get addHabit => isEs ? 'Agregar hábito' : 'Add habit';
  String get habitName => isEs ? 'Nombre del hábito' : 'Habit name';
  String get target => isEs ? 'Meta' : 'Target';
  String streakText(int streak) => isEs ? 'Racha $streak' : 'Streak $streak';

  String get statsTitle => isEs ? 'Estadísticas' : 'Stats';

  String get sponsorApprovalRequired => isEs ? 'Aprobación de padrino requerida' : 'Sponsor approval required';
  String get sponsorApprovalBody => isEs ? 'Como ya vinculaste un padrino, quitar apps o zonas requiere un código temporal de autorización.' : 'Because you linked a sponsor, removing apps or zones needs a one-time sponsor code.';
  String get requestCodeFromSponsor => isEs ? 'Solicitar código al padrino' : 'Request code from sponsor';
  String get enterSponsorCode => isEs ? 'Ingresar código del padrino' : 'Enter sponsor code';
  String get openSponsorCenter => isEs ? 'Abrir centro de padrino' : 'Open sponsor center';
  String get sponsorRequestSent => isEs ? 'Se envió una solicitud de desbloqueo de ajustes a tu padrino.' : 'Settings-unlock request sent to your sponsor.';
  String settingsUnlockedFor(int minutes) => isEs ? 'Ajustes desbloqueados por $minutes minutos.' : 'Settings unlocked for $minutes minutes.';
  String get yourCode => isEs ? 'Tu código' : 'Your code';
  String get loading => isEs ? 'cargando…' : 'loading…';
  String linkedWith(String name, bool unlocked) => isEs
      ? 'Vinculado con ${name.isEmpty ? "tu padrino" : name} · ${unlocked ? "ajustes desbloqueados" : "quitar apps o zonas requiere código"}'
      : 'Linked with ${name.isEmpty ? "your sponsor" : name} · ${unlocked ? "settings unlocked" : "removing apps or zones needs a sponsor code"}';
  String settingsUnlockedUntil(String hhmm) => isEs ? 'Ajustes desbloqueados hasta $hhmm' : 'Settings unlocked until $hhmm';
  String appLimitSubtitle(int minutes, String packageName) => isEs ? '$minutes minutos · $packageName' : '$minutes minutes · $packageName';
  String get zonesIntro => isEs ? 'Mueve el mapa libremente, coloca una zona en cualquier punto y elige qué apps bloquea.' : 'Move the map freely, drop a zone anywhere, and choose which apps it blocks.';
  String get noConcentrationZonesYet => isEs ? 'Aún no hay zonas de concentración.' : 'No concentration zones yet.';
  String zoneRadiusUsesFocus(int radius) => isEs ? '$radius m de radio · Usa apps de enfoque' : '$radius m radius · Uses focus apps';
  String zoneRadiusSelectedApps(int radius, int count) => isEs ? '$radius m de radio · $count app(s) seleccionada(s)' : '$radius m radius · $count selected app(s)';
  String get addAppLimit => isEs ? 'Agregar límite por app' : 'Add app limit';
  String get searchApp => isEs ? 'Buscar app' : 'Search app';
  String get noAppsFound => isEs ? 'No se encontraron apps.' : 'No apps found.';
  String get addSelectedApp => isEs ? 'Agregar app seleccionada' : 'Add selected app';
  String get newConcentrationZone => isEs ? 'Nueva zona de concentración' : 'New concentration zone';
  String get zoneName => isEs ? 'Nombre de la zona' : 'Zone name';
  String get mapZoneHelp => isEs ? 'Mueve el mapa al lugar que quieras. El pin permanece en el centro, así puedes guardar una universidad, biblioteca, oficina o cualquier punto lejano.' : 'Move the map to any place you want. The pin stays in the center, so you can save a university, library, office, or any faraway point.';
  String get myLocation => isEs ? 'Mi ubicación' : 'My location';
  String centerText(String lat, String lng) => isEs ? 'Centro: $lat, $lng' : 'Center: $lat, $lng';
  String radiusText(int meters) => isEs ? 'Radio: $meters m' : 'Radius: $meters m';
  String get appsBlockedInThisZone => isEs ? 'Apps bloqueadas en esta zona' : 'Apps blocked in this zone';
  String get zoneAppsHelp => isEs ? 'Primero agrega apps en la sección de límites por app. Si dejas esto vacío, la zona usará todas las apps marcadas para enfoque.' : 'Add apps in the Per-app limits section first. If you leave this empty, the zone will use all apps marked for focus mode.';
  String get studyZoneDefaultName => isEs ? 'Zona de estudio' : 'Study Zone';
  String get saveZone => isEs ? 'Guardar zona' : 'Save zone';
}
