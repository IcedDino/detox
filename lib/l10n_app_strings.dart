import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context));

  bool get isEs => locale.languageCode.toLowerCase().startsWith('es');

  /// Strings for the current app language, usable outside the widget tree
  /// (notifications, background services, snackbar messages from services).
  static AppStrings get current => AppStrings(AppLocale.current);

  String get home => isEs ? 'Inicio' : 'Home';
  String get focus => isEs ? 'Enfoque' : 'Focus';
  String get stats => isEs ? 'Estadísticas' : 'Stats';
  String get settings => isEs ? 'Configuración' : 'Settings';

  String get ownYourAttention =>
      isEs ? 'Toma control de tu atención' : 'Own your attention';
  String get authSubtitle => isEs
      ? 'Crea tu cuenta y sincroniza tus ajustes de enfoque, apps bloqueadas y zonas de concentración entre dispositivos.'
      : 'Create your account and sync your focus settings, blocked apps, and study zones across devices.';
  String get continueWithGoogle =>
      isEs ? 'Continuar con Google' : 'Continue with Google';
  String get continueWithPhone =>
      isEs ? 'Continuar con teléfono' : 'Continue with phone';
  String get signIn => isEs ? 'Iniciar sesión' : 'Sign in';
  String get createAccount => isEs ? 'Crear cuenta' : 'Create account';
  String get welcomeBack => isEs ? 'Bienvenido de vuelta' : 'Welcome back';
  String get signInSubtitle =>
      isEs ? 'Continúa donde lo dejaste.' : 'Pick up where you left off.';
  String get createAccountTitle => isEs ? 'Crear cuenta' : 'Create account';
  String get createAccountSubtitle =>
      isEs ? 'Toma un minuto.' : 'Takes a minute.';
  String get name => isEs ? 'Nombre' : 'Name';
  String get email => isEs ? 'Correo' : 'Email';
  String get password => isEs ? 'Contraseña' : 'Password';
  String get enterName => isEs ? 'Escribe tu nombre' : 'Enter your name';
  String get enterValidEmail =>
      isEs ? 'Escribe un correo válido' : 'Enter a valid email';
  String get useSixChars =>
      isEs ? 'Usa al menos 6 caracteres' : 'Use at least 6 characters';
  String get phoneSignIn => isEs ? 'Acceso con teléfono' : 'Phone sign-in';
  String get phoneInstructions => isEs
      ? 'Usa tu número con lada, por ejemplo +526000000000.'
      : 'Use your number with country code, for example +526000000000.';
  String get phoneNumber => isEs ? 'Número de teléfono' : 'Phone number';
  String get smsCode => isEs ? 'Código SMS' : 'SMS code';
  String get cancel => isEs ? 'Cancelar' : 'Cancel';
  String get sendCode => isEs ? 'Enviar código' : 'Send code';
  String get verifyCode => isEs ? 'Verificar código' : 'Verify code';
  String get smsCodeSent => isEs ? 'Código SMS enviado.' : 'SMS code sent.';

  String get welcomeToDetox => isEs ? 'Bienvenido a Detox' : 'Welcome to Detox';
  String get permReadUsage => isEs
      ? 'Leer el tiempo de uso y las apps principales.'
      : 'Read screen-time usage and top apps.';
  String get permShield => isEs
      ? 'Cubrir apps seleccionadas durante sesiones de enfoque.'
      : 'Shield selected apps during focus sessions.';
  String get permZones => isEs
      ? 'Activar zonas de estudio automáticamente cuando llegues.'
      : 'Auto-activate study zones when you arrive at them.';
  String get permissionStatus =>
      isEs ? 'Estado de permisos' : 'Permission status';
  String get checkingPermissions =>
      isEs ? 'Verificando permisos…' : 'Checking permissions...';
  String get returnAndRefresh => isEs
      ? 'Cuando regreses de Configuración, Detox detectará el permiso automáticamente.'
      : 'As soon as you return from Android settings, Detox will detect the permission automatically.';
  String get specialPermissionsTitle => isEs
      ? 'Los permisos especiales necesitan una visita rápida a Configuración.'
      : 'Special permissions need one quick trip to Android Settings.';
  String get specialPermissionsBody => isEs
      ? 'Toca cada botón para abrir Configuración. Cuando regreses a Detox, esta pantalla revisará automáticamente y avanzará en cuanto todo esté listo.'
      : 'Tap each button to open Android Settings. When you come back to Detox, this screen will automatically check again and continue as soon as everything is ready.';
  String get openUsageAccess =>
      isEs ? 'Abrir acceso de uso' : 'Open usage access';
  String get openOverlayPermission =>
      isEs ? 'Abrir permiso de superposición' : 'Open overlay permission';
  String get continueText => isEs ? 'Continuar' : 'Continue';
  String get allowLocationForZones => isEs
      ? 'Permitir ubicación para zonas de estudio'
      : 'Allow location for study zones';
  String get skipForNow => isEs ? 'Omitir por ahora' : 'Skip for now';
  String get usageReadyDetected => isEs
      ? 'Acceso de uso detectado y listo.'
      : 'Usage access detected and ready.';
  String get usageNeededMessage => isEs
      ? 'Activa Acceso de uso para que Detox pueda leer el tiempo de pantalla y detectar la app al frente.'
      : 'Enable Usage Access so Detox can read screen time and detect the foreground app.';
  String get overlayReady =>
      isEs ? 'Permiso de superposición listo.' : 'Overlay permission ready.';
  String get overlayNeeded => isEs
      ? 'Aún falta el permiso de superposición para proteger apps.'
      : 'Overlay permission still needed for app shielding.';

  String get darkMode => isEs ? 'Modo oscuro' : 'Dark mode';
  String get darkModeSubtitle => isEs
      ? 'Cambia entre la apariencia oscura y clara de Detox.'
      : 'Switch between Detox dark and light appearance.';
  String get language => isEs ? 'Idioma' : 'Language';
  String get dailyScreenTimeLimit =>
      isEs ? 'Límite diario de tiempo de pantalla' : 'Daily screen-time limit';
  String minutesLabel(int n) => isEs ? '$n minutos' : '$n minutes';
  String get openAndroidUsageSettings =>
      isEs ? 'Abrir ajustes de uso de Android' : 'Open Android usage settings';
  String get grantUsageAndRefresh => isEs
      ? 'Concede Acceso de uso y Detox se actualizará automáticamente.'
      : 'Grant Usage Access and Detox will refresh automatically.';
  String get focusShieldOverlay =>
      isEs ? 'Superposición del escudo de enfoque' : 'Focus shield overlay';
  String get overlayGrantShield => isEs
      ? 'Concede superposición para que Detox cubra apps bloqueadas durante el enfoque.'
      : 'Grant overlay permission so Detox can cover blocked apps during focus mode.';
  String get overlayReadyShield => isEs
      ? 'La superposición está lista para cubrir apps bloqueadas.'
      : 'Overlay is ready to shield blocked apps.';
  String get perAppLimits => isEs ? 'Límites por app' : 'Per-app limits';
  String get pickAppsBody => isEs
      ? 'Elige apps instaladas y marca cuáles participan en el bloqueo de enfoque.'
      : 'Pick apps from your installed list and mark which ones join focus blocking.';
  String get noPerAppLimits =>
      isEs ? 'Aún no hay límites por app.' : 'No per-app limits yet.';
  String get blockInFocusMode =>
      isEs ? 'Bloquear en modo enfoque' : 'Block in focus mode';
  String get focusModeBlockSubtitle => isEs
      ? 'Esta app será cubierta durante el temporizador y las zonas de estudio.'
      : 'This app will be shielded during timer focus and study zones.';

  String get accountOptions => isEs ? 'Opciones de cuenta' : 'Account options';
  String get manageAccount => isEs ? 'Gestionar cuenta' : 'Manage account';
  String get deleteAccount => isEs ? 'Eliminar cuenta' : 'Delete account';
  String get deleteAccountForever =>
      isEs ? 'Eliminar cuenta para siempre' : 'Delete account forever';
  String get deleteAccountWarning => isEs
      ? 'Esto borrará tu cuenta, tus horarios, zonas, límites, progreso y cualquier vínculo con padrino.'
      : 'This will erase your account, schedules, zones, limits, progress, and any sponsor link.';
  String get deleteAccountConfirm =>
      isEs ? 'Sí, eliminar cuenta' : 'Yes, delete account';
  String get deleteAccountSuccess => isEs
      ? 'Tu cuenta y tus datos se eliminaron.'
      : 'Your account and data were deleted.';
  String get tapToManageAccount =>
      isEs ? 'Toca para ver opciones de cuenta' : 'Tap to view account options';
  String get signOut => isEs ? 'Cerrar sesión' : 'Sign out';

  String get manageAccountSubtitle => isEs
      ? 'Toca para ver opciones de sesión y cuenta.'
      : 'Tap to view session and account options.';

  String get deleteAccountSubtitle => isEs
      ? 'Borra tu cuenta y tus datos sincronizados.'
      : 'Delete your account and synced data.';
  String get deleteAccountTitle => isEs ? 'Eliminar cuenta' : 'Delete account';
  String get deleteAccountBody => isEs
      ? 'Esta acción eliminará tu cuenta de Detox, tus datos sincronizados y cerrará tu sesión en este dispositivo.'
      : 'This will delete your Detox account, your synced data, and sign you out on this device.';

  String get deletingAccount =>
      isEs ? 'Eliminando cuenta…' : 'Deleting account...';
  String get returnLoginScreen =>
      isEs ? 'Volver a la pantalla de acceso' : 'Return to the login screen';
  String get sponsorCenter => isEs ? 'Centro de padrino' : 'Sponsor center';
  String get open => isEs ? 'Abrir' : 'Open';
  String get concentrationZones =>
      isEs ? 'Zonas de concentración' : 'Concentration zones';

  String get orUseEmail => isEs ? 'O usa correo' : 'Or use email';
  String get useEmailFirst =>
      isEs ? 'Enfoque sin distracciones' : 'Focus without distractions';
  String get otherWaysToContinue =>
      isEs ? 'Otras formas de acceso' : 'Other ways to continue';
  String get noAccountYet =>
      isEs ? '¿No tienes cuenta aún?' : "Don't have an account yet?";
  String get alreadyHaveAccount =>
      isEs ? '¿Ya tienes cuenta?' : 'Already have an account?';
  String get permissionsOverview =>
      isEs ? 'Resumen de permisos' : 'Permissions overview';
  String get iosSeparatePath => isEs
      ? 'En iOS esto usa una ruta nativa separada de Screen Time.'
      : 'iOS support uses a separate native Screen Time path.';
  String get iosAppsBody => isEs
      ? 'En iOS aún no se pueden listar apps instaladas de la misma manera.'
      : 'On iOS, installed apps cannot be listed the same way yet.';

  String get today => isEs ? 'Hoy' : 'Today';
  String get pickups => isEs ? 'Desbloqueos' : 'Pickups';
  String get topApp => isEs ? 'App principal' : 'Top app';
  String get topAppsToday => isEs ? 'Apps más usadas hoy' : 'Top apps today';
  String goalUsed(String goal, int pct) =>
      isEs ? 'Meta: $goal · $pct% usado' : 'Goal: $goal · $pct% used';
  String get estimatedUnlocks =>
      isEs ? 'Desbloqueos estimados' : 'Estimated unlocks';
  String minToday(int mins) => isEs ? '$mins min hoy' : '$mins min today';
  String get noDataYet => isEs ? 'Sin datos aún' : 'No data yet';
  String get noAppUsageYet => isEs
      ? 'Aún no hay uso de apps disponible.'
      : 'No app usage available yet.';
  String get usageUnavailableNotice => isEs
      ? 'Sin datos reales todavía — concede Acceso de uso en Android para verlos.'
      : 'No real data yet — grant Usage Access on Android to see it.';

  String get focusTitle => isEs ? 'Temporizador de enfoque' : 'Focus timer';
  String get focusBeforeStart => isEs ? 'Antes de empezar' : 'Before you start';
  String get focusNeedUsage => isEs
      ? 'Concede Acceso de uso en Configuración para que Detox detecte la app al frente y la cubra.'
      : 'Grant Usage Access in Settings so Detox can detect the foreground app and shield it.';
  String get focusNeedOverlay => isEs
      ? 'Concede permiso de superposición para que Detox pueda cubrir apps bloqueadas durante el enfoque.'
      : 'Grant overlay permission so Detox can cover blocked apps during focus.';
  String get focusChooseApps => isEs
      ? 'Elige apps en Configuración y márcalas para el modo enfoque.'
      : 'Choose apps in Settings and mark them for focus mode.';
  String get focusShieldActive =>
      isEs ? 'Escudo de enfoque activo' : 'Focus shield active';
  String get focusReadyToStart =>
      isEs ? 'Listo para empezar' : 'Ready to start';
  String minuteShort(int minutes) => isEs ? '$minutes min' : '$minutes min';
  String get stopSession => isEs ? 'Detener sesión' : 'Stop session';
  String get startFocusSession =>
      isEs ? 'Iniciar sesión de enfoque' : 'Start focus session';
  String get shieldedDuringFocus => isEs
      ? 'Apps protegidas durante el enfoque'
      : 'Apps shielded during focus';
  String get addAppsForFocus => isEs
      ? 'Agrega apps en Configuración para que tu zona de enfoque tenga objetivos listos para bloquear.'
      : 'Add apps in Settings so your focus zone has targets ready to block.';
  String get studyZoneAutomation =>
      isEs ? 'Automatización de zonas de estudio' : 'Study-zone automation';
  String get studyZoneAutomationBody => isEs
      ? 'Detox puede activar automáticamente el enfoque educativo cuando llegues a una zona de estudio.'
      : 'Detox can auto-activate educational focus when you arrive at a study zone.';
  String get grantUsageSnack => isEs
      ? 'Primero concede Acceso de uso para que Detox pueda detectar la app en primer plano.'
      : 'Grant Usage Access first so Detox can detect the foreground app.';
  String get grantOverlaySnack => isEs
      ? 'Primero concede el permiso de superposición para que Detox pueda cubrir apps bloqueadas.'
      : 'Grant overlay permission first so Detox can shield blocked apps.';
  String get addAppsSnack => isEs
      ? 'Agrega apps en Configuración para que Detox sepa qué debe cubrir.'
      : 'Add apps in Settings so Detox knows what to shield.';
  String get focusSessionActiveReason =>
      isEs ? 'Temporizador de enfoque activo' : 'Focus timer active';
  String get focusSessionLabel =>
      isEs ? 'Temporizador de enfoque' : 'Focus timer';
  String get focusCompleteSnack => isEs
      ? 'Sesión de enfoque completada. Buen trabajo.'
      : 'Focus session complete. Great job.';

  String get statsTitle => isEs ? 'Estadísticas' : 'Stats';

  String get sponsorApprovalRequired =>
      isEs ? 'Aprobación de padrino requerida' : 'Sponsor approval required';
  String get sponsorApprovalBody => isEs
      ? 'Como ya vinculaste un padrino, quitar apps o zonas requiere un código temporal de autorización.'
      : 'Because you linked a sponsor, removing apps or zones needs a one-time sponsor code.';
  String get requestCodeFromSponsor =>
      isEs ? 'Solicitar código al padrino' : 'Request code from sponsor';
  String get enterSponsorCode =>
      isEs ? 'Ingresar código del padrino' : 'Enter sponsor code';
  String get openSponsorCenter =>
      isEs ? 'Abrir centro de padrino' : 'Open sponsor center';
  String get sponsorRequestSent => isEs
      ? 'Se envió una solicitud de desbloqueo de ajustes a tu padrino.'
      : 'Settings-unlock request sent to your sponsor.';
  String settingsUnlockedFor(int minutes) => isEs
      ? 'Ajustes desbloqueados por $minutes minutos.'
      : 'Settings unlocked for $minutes minutes.';
  String get yourCode => isEs ? 'Tu código' : 'Your code';
  String get loading => isEs ? 'cargando…' : 'loading…';
  String linkedWith(String name, bool unlocked) => isEs
      ? 'Vinculado con ${name.isEmpty ? "tu padrino" : name} · ${unlocked ? "ajustes desbloqueados" : "quitar apps o zonas requiere código"}'
      : 'Linked with ${name.isEmpty ? "your sponsor" : name} · ${unlocked ? "settings unlocked" : "removing apps or zones needs a sponsor code"}';
  String settingsUnlockedUntil(String hhmm) => isEs
      ? 'Ajustes desbloqueados hasta $hhmm'
      : 'Settings unlocked until $hhmm';
  String appLimitSubtitle(int minutes, String packageName) => isEs
      ? '$minutes minutos · $packageName'
      : '$minutes minutes · $packageName';
  String get zonesIntro => isEs
      ? 'Mueve el mapa libremente, coloca una zona en cualquier punto y elige qué apps bloquea.'
      : 'Move the map freely, drop a zone anywhere, and choose which apps it blocks.';
  String get noConcentrationZonesYet => isEs
      ? 'Aún no hay zonas de concentración.'
      : 'No concentration zones yet.';
  String zoneRadiusUsesFocus(int radius) => isEs
      ? '$radius m de radio · Usa apps de enfoque'
      : '$radius m radius · Uses focus apps';
  String zoneRadiusSelectedApps(int radius, int count) => isEs
      ? '$radius m de radio · $count app(s) seleccionada(s)'
      : '$radius m radius · $count selected app(s)';
  String get addAppLimit => isEs ? 'Agregar límite por app' : 'Add app limit';
  String get searchApp => isEs ? 'Buscar app' : 'Search app';
  String get noAppsFound => isEs ? 'No se encontraron apps.' : 'No apps found.';
  String get addSelectedApp =>
      isEs ? 'Agregar app seleccionada' : 'Add selected app';
  String selectedAppsCount(int count) =>
      isEs ? '$count apps seleccionadas' : '$count apps selected';
  String addSelectedApps(int count) =>
      isEs ? 'Agregar $count apps' : 'Add $count apps';
  String get retryLoadingApps => isEs
      ? 'No se pudieron cargar las apps. Reintentar'
      : 'Could not load apps. Retry';
  String get newConcentrationZone =>
      isEs ? 'Nueva zona de concentración' : 'New concentration zone';
  String get zoneName => isEs ? 'Nombre de la zona' : 'Zone name';
  String get mapZoneHelp => isEs
      ? 'Mueve el mapa al lugar que quieras. El pin permanece en el centro, así puedes guardar una universidad, biblioteca, oficina o cualquier punto lejano.'
      : 'Move the map to any place you want. The pin stays in the center, so you can save a university, library, office, or any faraway point.';
  String get myLocation => isEs ? 'Mi ubicación' : 'My location';
  String centerText(String lat, String lng) =>
      isEs ? 'Centro: $lat, $lng' : 'Center: $lat, $lng';
  String radiusText(int meters) =>
      isEs ? 'Radio: $meters m' : 'Radius: $meters m';
  String get appsBlockedInThisZone =>
      isEs ? 'Apps bloqueadas en esta zona' : 'Apps blocked in this zone';
  String get zoneAppsHelp => isEs
      ? 'Primero agrega apps en la sección de límites por app. Si dejas esto vacío, la zona usará todas las apps marcadas para enfoque.'
      : 'Add apps in the Per-app limits section first. If you leave this empty, the zone will use all apps marked for focus mode.';
  String get studyZoneDefaultName => isEs ? 'Zona de estudio' : 'Study Zone';
  String get saveZone => isEs ? 'Guardar zona' : 'Save zone';

  // Automation settings
  String get automationAndHardMode =>
      isEs ? 'Automatización y modo estricto' : 'Automation & hard mode';
  String get automationAndHardModeBody => isEs
      ? 'Horarios, modo estricto, presets inteligentes y reglas de zona + horario.'
      : 'Schedules, strict mode, smart presets, and zone + schedule rules.';
  String get automationTitle => isEs ? 'Automatización' : 'Automation';
  String get hardModeStrictMode =>
      isEs ? 'Modo estricto' : 'Hard mode / Strict mode';
  String get hardModeStrictModeBody => isEs
      ? 'Desactiva pausas, anuncios y salidas mientras el bloqueo de enfoque esté activo.'
      : 'Disables pauses, ads, and exit buttons while focus blocking is active.';
  String get smartPresets => isEs ? 'Presets inteligentes' : 'Smart presets';
  String get addSocialPreset =>
      isEs ? 'Agregar preset de redes' : 'Add social preset';
  String get addEntertainmentPreset =>
      isEs ? 'Agregar preset de entretenimiento' : 'Add entertainment preset';
  String get automationPresetsBody => isEs
      ? 'Tus límites diarios por app ahora bloquean automáticamente cuando se alcanza el límite. Las reglas por horario también pueden restringirse para funcionar solo dentro de zonas de concentración.'
      : 'Your per-app daily limits now auto-block when the limit is reached. Schedule rules can also be restricted to work only inside concentration zones.';
  String get scheduleRules => isEs ? 'Reglas por horario' : 'Schedule rules';
  String get noAutomaticSchedulesYet =>
      isEs ? 'Aún no hay horarios automáticos.' : 'No automatic schedules yet.';
  String get zoneAndSchedule => isEs ? 'Zona + horario' : 'Zone + schedule';
  String get scheduleOnly => isEs ? 'Solo horario' : 'Schedule only';
  String get strictLabel => isEs ? 'Estricto' : 'Strict';
  String get normalLabel => isEs ? 'Normal' : 'Normal';
  String get deleteLabel => isEs ? 'Eliminar' : 'Delete';
  String get ruleName => isEs ? 'Nombre de la regla' : 'Rule name';
  String get newSchedule => isEs ? 'Nuevo horario' : 'New schedule';
  String get startLabel => isEs ? 'Inicio' : 'Start';
  String get endLabel => isEs ? 'Fin' : 'End';
  List<String> get automationWeekdayShort => isEs
      ? ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get useStrictModeInSchedule => isEs
      ? 'Usar modo estricto en este horario'
      : 'Use strict mode in this schedule';
  String get onlyApplyInsideZones => isEs
      ? 'Aplicar solo dentro de zonas de concentración'
      : 'Only apply inside concentration zones';
  String get appsToBlock => isEs ? 'Apps a bloquear' : 'Apps to block';
  String get saveRule => isEs ? 'Guardar regla' : 'Save rule';
  String get scheduleRuleDefaultName =>
      isEs ? 'Regla de horario' : 'Schedule rule';
  String get socialPresetName =>
      isEs ? 'Redes sociales 08:00-14:00' : 'Social media 08:00-14:00';
  String get entertainmentPresetName =>
      isEs ? 'Entretenimiento 22:00-07:00' : 'Entertainment 22:00-07:00';

  // Stats screen
  String get statsWeeklyTitle =>
      isEs ? 'Estadísticas semanales' : 'Weekly Stats';
  String get statsWeeklySubtitle => isEs
      ? 'Mira tu tendencia de tiempo de pantalla y mantén la racha.'
      : 'See your screen-time trend and keep the streak alive.';
  String get statsTrendInsight => isEs ? 'Tendencia' : 'Trend insight';
  String get statsTrendDown => isEs
      ? 'Tu tiempo de pantalla va a la baja esta semana.'
      : 'Your screen time is trending downward this week.';
  String get statsTrendUp => isEs
      ? 'Tu tiempo de pantalla aumentó esta semana. Considera más sesiones de enfoque.'
      : 'Your screen time increased this week. Consider more focus sessions.';
  String get statsWeeklyGoal => isEs ? 'Meta semanal' : 'Weekly goal';
  String get statsGoalMet => isEs
      ? 'Buen trabajo. Estuviste bajo tu límite la mayoría de los días.'
      : 'Great job. You stayed under your limit most days.';
  String get statsGoalMiss => isEs
      ? 'Intenta pasar al menos 5 días bajo tu límite diario.'
      : 'Aim for at least 5 days under your daily limit.';
  List<String> get weekDayLabels => isEs
      ? ['L', 'M', 'X', 'J', 'V', 'S', 'D']
      : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // Sponsor screen
  String get yourSponsorCode =>
      isEs ? 'Tu código de padrino' : 'Your sponsor code';
  String get sponsorCodeShare => isEs
      ? 'Comparte este código con la persona de confianza que aprobará tus cambios en Detox.'
      : 'Share this code with the one person you trust to approve Detox overrides.';
  String get addSponsor => isEs ? 'Agregar padrino' : 'Add a sponsor';
  String get enterSponsorCodeHint =>
      isEs ? 'Ingresa el código de padrino' : 'Enter sponsor code';
  String get linkSponsor => isEs ? 'Vincular padrino' : 'Link sponsor';
  String get onlyOneSponsor => isEs
      ? 'Solo puedes tener un padrino a la vez.'
      : 'You can only have one sponsor at a time.';
  String get requestZonePause =>
      isEs ? 'Solicitar pausa de zona' : 'Request zone pause';
  String get requestSettingsApproval =>
      isEs ? 'Solicitar aprobación de ajustes' : 'Request settings approval';
  String get endSponsorLink =>
      isEs ? 'Terminar vínculo con padrino' : 'End sponsor link';
  String get currentSafeguards =>
      isEs ? 'Protecciones actuales' : 'Current safeguards';
  String get zonePause => isEs ? 'Pausa de zona' : 'Zone pause';
  String get protectedSettings =>
      isEs ? 'Ajustes protegidos' : 'Protected settings';
  String get protectedSettingsBody => isEs
      ? 'Quitar apps o zonas requiere aprobación del padrino.'
      : 'Removing apps or zones needs sponsor approval.';
  String get yourOutgoingRequests =>
      isEs ? 'Tus solicitudes enviadas' : 'Your outgoing requests';
  String get noOutgoingRequests => isEs
      ? 'Aún no has enviado solicitudes.'
      : 'You have not sent any requests yet.';
  String get historyLabel => isEs ? 'Historial' : 'History';
  String get noSponsorHistory =>
      isEs ? 'Aún no hay historial de padrino.' : 'No sponsor history yet.';
  String get incomingSponsorLinkRequests => isEs
      ? 'Solicitudes de vínculo entrantes'
      : 'Incoming sponsor link requests';
  String get acceptLinkBody => isEs
      ? 'Acepta esta solicitud para vincular ambas cuentas.'
      : 'Accept this request to link both accounts.';
  String get pendingSponsorLinkRequests => isEs
      ? 'Solicitudes de vínculo pendientes'
      : 'Pending sponsor link requests';
  String get noIncomingRequests => isEs
      ? 'Sin solicitudes entrantes por ahora.'
      : 'No incoming requests right now.';
  String get incomingRequestsTitle =>
      isEs ? 'Solicitudes entrantes' : 'Incoming requests';
  String get incomingRequestsSubtitle => isEs
      ? 'Personas que necesitan tu aprobación o quieren vincularse.'
      : 'People who need your approval or want to link with you.';
  String get yourLinkTitle => isEs ? 'Tu vínculo' : 'Your link';
  String get yourLinkSubtitle => isEs
      ? 'Quién puede aprobar tus cambios en Detox.'
      : 'Who can approve your Detox overrides.';
  String get noActiveLink => isEs ? 'Sin vínculo activo' : 'No active link';
  String get linkedState => isEs ? 'Vinculado' : 'Linked';
  String get protectionActive =>
      isEs ? 'Protección activa' : 'Protection active';
  String get yourRequestsSubtitle => isEs
      ? 'Tus solicitudes enviadas y su estado actual.'
      : 'Requests you sent and their current status.';
  String linkPartnerWantsToLink(String name) =>
      isEs ? '$name quiere vincularse contigo' : '$name wants to link with you';
  String get noPendingRequests => isEs
      ? 'No tienes solicitudes pendientes.'
      : 'You have no pending requests.';

  // ── Messages attached to sponsor requests ──
  String get messageOptional =>
      isEs ? 'Mensaje (opcional)' : 'Message (optional)';
  String get requestMessageTitle =>
      isEs ? 'Pedir acceso a tu padrino' : 'Ask your sponsor for access';
  String get requestMessageHint => isEs
      ? 'Ej. Necesito revisar algo en Instagram'
      : 'E.g. I need to check something on Instagram';
  String get sendRequestLabel => isEs ? 'Enviar solicitud' : 'Send request';
  String get replyMessageTitle =>
      isEs ? 'Responder al solicitante' : 'Reply to the request';
  String get replyMessageHint =>
      isEs ? 'Ej. No es necesario' : 'E.g. Nothing urgent needed';
  String get approveWithMessage => isEs ? 'Aceptar' : 'Accept';
  String get denyWithMessage => isEs ? 'Denegar' : 'Deny';
  String get requestMessageLabel =>
      isEs ? 'Motivo del solicitante' : 'Requester note';
  String get yourMessageLabel => isEs ? 'Tu mensaje' : 'Your message';
  String get sponsorReplyLabel =>
      isEs ? 'Respuesta de tu padrino' : 'Your sponsor replied';
  String get yourReplyLabel => isEs ? 'Tu respuesta' : 'Your reply';
  String get notifyRequestDeniedTitle =>
      isEs ? 'Solicitud denegada' : 'Request denied';
  String notifyRequestDeniedBody(String type) =>
      isEs ? 'Tu padrino denegó $type.' : 'Your sponsor denied $type.';
  String get notifyUnlinkDeniedTitle =>
      isEs ? 'Desvinculación denegada' : 'Unlink denied';
  String get notifyUnlinkDeniedBody => isEs
      ? 'Tu padrino denegó la desvinculación.'
      : 'Your sponsor denied the unlink request.';
  String get reject => isEs ? 'Rechazar' : 'Reject';
  String get accept => isEs ? 'Aceptar' : 'Accept';
  String get approve => isEs ? 'Aprobar' : 'Approve';
  String get generateCode => isEs ? 'Generar código' : 'Generate code';
  String get done => isEs ? 'Listo' : 'Done';
  String get useCode => isEs ? 'Usar código' : 'Use code';
  String get endSponsorLinkTitle =>
      isEs ? 'Terminar vínculo con padrino' : 'End sponsor link';
  String get endSponsorLinkBody => isEs
      ? 'Tu padrino recibe la solicitud y la acepta o la deniega. Si acepta, el vínculo se elimina al instante.'
      : 'Your sponsor gets the request and accepts or denies it. If accepted, the link is removed right away.';
  String get requestSponsorUnlink =>
      isEs ? 'Solicitar desvinculación al padrino' : 'Request sponsor unlink';
  String get requestSupportUnlink =>
      isEs ? 'Solicitar desvinculación a soporte' : 'Request support unlink';
  String get supportUnlinkTitle =>
      isEs ? 'Desvinculación con soporte' : 'Support unlink request';
  String get supportUnlinkRequestTitle => isEs
      ? 'Solicitar desvinculación a soporte'
      : 'Request unlink from support';
  String get supportUnlinkRequestHint => isEs
      ? 'Explica por qué necesitas desvincular las cuentas'
      : 'Explain why you need to unlink the accounts';
  String get supportUnlinkAlreadyPending => isEs
      ? 'Ya tienes una solicitud pendiente con soporte. Espera su respuesta.'
      : 'You already have a pending support request. Wait for a response.';
  String get supportDenialReason =>
      isEs ? 'Motivo de soporte' : 'Reason from support';
  String get supportDeniedState => isEs ? 'Denegada' : 'Denied';
  String get errNoSponsorLinked => isEs
      ? 'No tienes un padrino vinculado.'
      : 'You do not have a linked sponsor.';
  String get requestSupportUnlinkHelp => isEs
      ? 'Soporte recibe un correo con enlaces para revisar, aceptar o denegar la solicitud.'
      : 'Support receives an email with links to review, approve, or deny the request.';
  String get unlinkRequestSentSupport => isEs
      ? 'Solicitud de desvinculación enviada a soporte.'
      : 'Unlink request sent to support.';
  String get unlinkCodeSentEmail => isEs
      ? 'Enviamos una solicitud de código de desvinculación a tu correo.'
      : 'We sent an unlink code request to your email.';
  String get unlinkRequestSentSponsor => isEs
      ? 'Solicitud de desvinculación enviada a tu padrino. Debe aceptarla para completar el proceso.'
      : 'Unlink request sent to your sponsor. They must accept it to complete the process.';
  String get acceptUnlink => isEs ? 'Aceptar desvinculación' : 'Accept unlink';
  String get denyUnlink => isEs ? 'Denegar' : 'Deny';
  String get sponsorLinkRemoved =>
      isEs ? 'Vínculo con padrino eliminado.' : 'Sponsor link removed.';
  String get enterSponsorCodeSnack =>
      isEs ? 'Ingresa un código de padrino' : 'Enter a sponsor code';
  String get requestSentWaiting => isEs
      ? 'Solicitud enviada. Esperando aprobación.'
      : 'Request sent. Waiting for approval.';
  String get sponsorRequestAccepted =>
      isEs ? 'Solicitud de padrino aceptada.' : 'Sponsor request accepted.';
  String get sponsorRequestRejected =>
      isEs ? 'Solicitud de padrino rechazada.' : 'Sponsor request rejected.';
  String get requestRejected =>
      isEs ? 'Solicitud rechazada.' : 'Request rejected.';
  String get settingsAccessApproved =>
      isEs ? 'Acceso a ajustes aprobado.' : 'Settings access approved.';
  String get shieldPauseApproved =>
      isEs ? 'Pausa del escudo aprobada.' : 'App shield pause approved.';
  String get zonePauseApproved =>
      isEs ? 'Pausa de zona aprobada.' : 'Zone pause approved.';
  String get settingsRequestSent => isEs
      ? 'Solicitud de desbloqueo de ajustes enviada a tu padrino.'
      : 'Settings approval request sent to your sponsor.';
  String get zonePauseRequestSent => isEs
      ? 'Solicitud de pausa de zona enviada a tu padrino.'
      : 'Zone-pause approval request sent to your sponsor.';
  String get expired => isEs ? 'Expirado' : 'Expired';
  String get statusUsed => isEs ? 'Usado' : 'Used';
  String get statusApproved => isEs ? 'Aprobado' : 'Approved';
  String get statusRejected => isEs ? 'Rechazado' : 'Rejected';
  String get statusPending => isEs ? 'Pendiente' : 'Pending';
  String get statusCompleted => isEs ? 'Completado' : 'Completed';
  String get statusEmailed => isEs ? 'Enviado por email' : 'Emailed';
  String get giveCodeTo => isEs ? 'Da este código a' : 'Give this code to';
  String get codeExpiresOnce => isEs
      ? 'Expira en 3 minutos y solo funciona una vez.'
      : 'It expires in 3 minutes and only works once.';
  String get expiresSoon => isEs ? 'Expira pronto' : 'Expires soon';
  String durationMinLabel(int min) =>
      isEs ? 'Duración: $min min' : 'Duration: $min min';
  String get waitingForTarget => isEs ? 'Esperando que' : 'Waiting for';
  String get toAcceptRequest =>
      isEs ? 'acepte tu solicitud.' : 'to accept your request.';
  String get requestStillPending => isEs
      ? 'Esta solicitud sigue pendiente.'
      : 'This request is still pending.';
  String get pendingState => isEs ? 'Pendiente' : 'Pending';
  String get approvedState => isEs ? 'Aprobada' : 'Approved';
  String get waitingForApproval => isEs
      ? 'Esperando la respuesta de tu padrino.'
      : 'Waiting for your sponsor to respond.';
  String get sponsorApprovalNeededTitle =>
      isEs ? 'Se necesita aprobación del padrino' : 'Sponsor approval required';
  String get sponsorApprovalNeededBody => isEs
      ? 'Los cambios protegidos necesitan aprobación del padrino.'
      : 'Protected changes need sponsor approval.';
  String get requestApproval =>
      isEs ? 'Solicitar aprobación' : 'Request approval';
  String get accountSectionTitle => isEs ? 'Tu cuenta' : 'Your account';
  String get reminderNotifications =>
      isEs ? 'Avisos de solicitudes' : 'Request alerts';
  String get reminderNotificationsSubtitle => isEs
      ? 'Notificaciones cuando llegue una solicitud o una aprobación.'
      : 'Notifications when a request or approval arrives.';
  String get zonePauseApprovalTitle =>
      isEs ? 'Aprobación de pausa de zona' : 'Zone pause approval';
  String get settingsApprovalTitle =>
      isEs ? 'Aprobación de ajustes' : 'Settings approval';
  String get shieldPauseTitle =>
      isEs ? 'Pausa del escudo de apps' : 'App shield pause';
  String get unlinkApprovalTitle =>
      isEs ? 'Solicitud de desvinculación' : 'Unlink request';
  String zoneActiveLabel(String time) =>
      isEs ? 'Activa · $time' : 'Active · $time';
  String insideZoneLabel(String name) =>
      isEs ? 'Dentro de $name' : 'Inside $name';
  String get zoneInactive => isEs ? 'Inactiva' : 'Inactive';
  String get settingsUnlockedLabel => isEs ? 'Desbloqueado' : 'Unlocked';
  String waitingForName(String name) => isEs
      ? 'Esperando que $name acepte tu solicitud.'
      : 'Waiting for $name to accept your request.';

  String get startConcentrationHour =>
      isEs ? 'Empezar hora de concentración' : 'Start concentration hour';
  String get deny => isEs ? 'Denegar' : 'Deny';
  String get smartSuggestionTitle =>
      isEs ? 'Detox te recomienda una pausa' : 'Detox recommends a pause';
  String smartSuggestionNotification(String appName, String time) => isEs
      ? 'Hoy llevas $time usando $appName. ¿Quieres pausarla durante 1 hora?'
      : 'You have used $appName for $time today. Pause it for 1 hour?';
  String smartPauseStarted(String appName) => isEs
      ? 'Pausa de $appName iniciada por 1 hora.'
      : '$appName is paused for 1 hour.';
  String get smartPauseDenied =>
      isEs ? 'Pausa descartada.' : 'Pause dismissed.';
  String get smartPauseFailed => isEs
      ? 'No se pudo iniciar la pausa. Revisa los permisos de uso y superposición.'
      : 'Could not start the pause. Check usage and overlay permissions.';
  String get progressStartedSnack =>
      isEs ? 'Tu racha quedó activa hoy.' : 'Your streak is active today.';
  String get autoFocusStartedSnack => isEs
      ? 'Se inició una hora de concentración.'
      : 'A one-hour focus session started.';

  // Automation, Pomodoro, limits, anti-bypass
  String get automationSubtitle => isEs
      ? 'Horarios normales o estrictos, límites y reglas combinadas.'
      : 'Clean normal or strict schedules, limits, and combined rules.';
  String get automationAndHardModeSubtitle => isEs
      ? 'Horarios, modo estricto, presets y reglas por zona + horario.'
      : 'Schedules, strict mode, presets, and zone + schedule rules.';
  String get noSchedulesYet =>
      isEs ? 'Aún no hay horarios automáticos.' : 'No automatic schedules yet.';
  String get normalMode => isEs ? 'Normal' : 'Normal';
  String get strictModeLabel => isEs ? 'Estricto' : 'Strict';
  String get deleteText => isEs ? 'Eliminar' : 'Delete';
  String get createSchedule => isEs ? 'Crear horario' : 'Create schedule';
  String get editSchedule => isEs ? 'Editar horario' : 'Edit schedule';
  String get startTime => isEs ? 'Inicio' : 'Start';
  String get endTime => isEs ? 'Fin' : 'End';
  String get weekdays => isEs ? 'Días' : 'Weekdays';
  String get chooseApps => isEs ? 'Apps a bloquear' : 'Apps to block';
  String get saveText => isEs ? 'Guardar' : 'Save';
  String get normalSchedulesBody => isEs
      ? 'Los horarios normales bloquean apps automáticamente sin obligar modo estricto.'
      : 'Normal schedules automatically block apps without forcing strict mode.';
  String get hardModeGlobal =>
      isEs ? 'Modo estricto global' : 'Global hard mode';
  String get hardModeGlobalSubtitle => isEs
      ? 'Hace que foco manual y reglas activas no permitan pausas ni bypass.'
      : 'Makes manual focus and active rules disallow pauses and bypass.';
  String get antiBypassTitle =>
      isEs ? 'Protección anti-bypass' : 'Anti-bypass protection';
  String get antiBypassBody => isEs
      ? 'Detox vigila permisos clave, conserva reglas activas tras reinicio y vuelve a levantar el escudo si sigue habiendo bloqueo pendiente.'
      : 'Detox watches key permissions, preserves active rules after reboot, and restores the shield when blocking is still pending.';
  String get antiBypassHealthy =>
      isEs ? 'Protección activa' : 'Protection active';
  String get antiBypassNeedsAttention =>
      isEs ? 'Requiere atención' : 'Needs attention';
  String get pomodoroTitle =>
      isEs ? 'Pomodoro integrado' : 'Integrated Pomodoro';
  String get pomodoroSubtitle => isEs
      ? 'Alterna bloques de trabajo y descanso usando el mismo escudo de enfoque.'
      : 'Alternate work and break blocks using the same focus shield.';
  String get pomodoroStart => isEs ? 'Iniciar Pomodoro' : 'Start Pomodoro';
  String get pomodoroWork => isEs ? 'Trabajo' : 'Work';
  String get pomodoroBreak => isEs ? 'Descanso' : 'Break';
  String pomodoroCycleLabel(int current, int total) =>
      isEs ? 'Ciclo $current de $total' : 'Cycle $current of $total';
  String get appLimitReached =>
      isEs ? 'Límite diario alcanzado' : 'Daily limit reached';
  String limitReachedForApp(String appName) => isEs
      ? 'Has alcanzado el límite diario de $appName.'
      : 'You reached the daily limit for $appName.';
  String get startHourFocus =>
      isEs ? 'Empezar hora de concentración' : 'Start concentration hour';
  String get denyText => isEs ? 'Denegar' : 'Deny';
  String get automationSaved =>
      isEs ? 'Automatización actualizada.' : 'Automation updated.';
  String get extraPauseAd =>
      isEs ? 'Pausa extra con anuncio' : 'Extra pause with ad';
  String get extraPauseAdSubtitle => isEs
      ? 'Mantienes 1 pausa gratis diaria y 1 pausa adicional al completar un anuncio.'
      : 'Keep 1 free daily pause and 1 extra pause after completing an ad.';
  String get topApps => isEs ? 'Apps más usadas' : 'Top apps';

  // ── Sponsor request types ──
  String get requestTypeSettingsUnlock =>
      isEs ? 'Cambios de ajustes' : 'Settings changes';
  String get requestTypeZoneOverride => isEs ? 'Pausa de zona' : 'Zone pause';
  String get requestTypeShieldPause =>
      isEs ? 'Pausa del escudo de apps' : 'App shield pause';
  String get requestTypeUnlinkSponsor =>
      isEs ? 'Desvincular padrino' : 'Sponsor unlink';
  String get requestTypeUnlinkEmail =>
      isEs ? 'Desvinculación por correo' : 'Email unlink';
  String get defaultUserName => isEs ? 'Usuario de Detox' : 'Detox user';

  // ── Notifications ──
  String get notifySponsorRequestTitle =>
      isEs ? 'Solicitud del padrino' : 'Sponsor request';
  String notifySponsorRequestBody(String name, String type, [String? message]) {
    final base = isEs ? '$name solicitó $type.' : '$name requested $type.';
    final note = (message ?? '').trim();
    return note.isEmpty ? base : '$base\n“$note”';
  }

  String get notifyPauseApprovedTitle =>
      isEs ? 'Pausa de 15 minutos aprobada' : '15-minute pause approved';
  String get notifyPauseApprovedBody => isEs
      ? 'Tu padrino aprobó una pausa del escudo de apps.'
      : 'Your sponsor approved an app shield pause.';
  String get notifyCodeReadyTitle =>
      isEs ? 'Tu código de padrino está listo' : 'Your sponsor code is ready';
  String notifyCodeReadyBody(String type) => isEs
      ? 'Código de $type recibido. Expira en 3 minutos.'
      : '$type code received. It expires in 3 minutes.';
  String get notifyUnlinkEmailTitle => isEs
      ? 'Código de desvinculación solicitado'
      : 'Unlink code email requested';
  String get notifyUnlinkEmailBody => isEs
      ? 'Revisa tu correo para el código de desvinculación de Detox.'
      : 'Check your email for the Detox unlink code.';
  String get notifyLinkRequestTitle =>
      isEs ? 'Nueva solicitud de vínculo' : 'New sponsor link request';
  String notifyLinkRequestBody(String name) => isEs
      ? '$name quiere vincular su cuenta contigo.'
      : '$name wants to link accounts with you.';
  String get notifyLinkAcceptedTitle =>
      isEs ? 'Solicitud de vínculo aceptada' : 'Sponsor link accepted';
  String notifyLinkAcceptedBody(String name) => isEs
      ? '$name aceptó vincular su cuenta contigo.'
      : '$name accepted your link request.';
  String get notifyLinkRejectedTitle =>
      isEs ? 'Solicitud de vínculo rechazada' : 'Sponsor link rejected';
  String notifyLinkRejectedBody(String name) => isEs
      ? '$name rechazó tu solicitud de vínculo.'
      : '$name rejected your link request.';
  String get notifyUnlinkRequestTitle =>
      isEs ? 'Solicitud de desvinculación' : 'Unlink request';
  String notifyUnlinkRequestBody(String name, [String? message]) {
    final base = isEs
        ? '$name solicita desvincular su cuenta contigo.'
        : '$name asks to unlink their account from yours.';
    final note = (message ?? '').trim();
    return note.isEmpty ? base : '$base\n“$note”';
  }

  String get notifyUnlinkApprovedTitle =>
      isEs ? 'Vínculo eliminado' : 'Sponsor link removed';
  String get notifyUnlinkApprovedBody => isEs
      ? 'Tu padrino aceptó la desvinculación.'
      : 'Your sponsor accepted the unlink request.';

  // ── Zone state messages ──
  String zoneNoAppsSelected(String name) => isEs
      ? 'Estás en $name, pero no hay apps seleccionadas para esta zona.'
      : 'You are in $name, but no apps are selected for this zone.';
  String zoneFocusActive(String name) => isEs
      ? 'El enfoque educativo está activo en $name.'
      : 'Educational focus is active in $name.';
  String get zoneOutsideAll => isEs
      ? 'Estás fuera de las zonas de concentración.'
      : 'You are outside concentration zones.';
  String get zoneAutomationPaused => isEs
      ? 'La automatización de zonas se pausó tras un error.'
      : 'Zone automation was paused after an error.';

  // ── Sponsor service errors ──
  String get errSignInFirst =>
      isEs ? 'Inicia sesión primero.' : 'Sign in first.';
  String get errNeedSignIn =>
      isEs ? 'Necesitas iniciar sesión primero.' : 'You need to sign in first.';
  String get errRequestNotFound =>
      isEs ? 'No se encontró la solicitud.' : 'Request not found.';
  String get errRequestNotYours => isEs
      ? 'Esa solicitud no te pertenece.'
      : 'That request does not belong to you.';
  String get errRequestNotForYou =>
      isEs ? 'Esta solicitud no es para ti.' : 'This request is not for you.';
  String get errManualCodeFlow => isEs
      ? 'Este tipo de solicitud todavía requiere el flujo de código manual.'
      : 'This request type still requires the manual code flow.';
  String get errRequestNotPending => isEs
      ? 'Esta solicitud ya no está pendiente.'
      : 'This request is no longer pending.';
  String get errRequestNotApprovable => isEs
      ? 'Esta solicitud ya no se puede aprobar.'
      : 'This request can no longer be approved.';
  String get errUnsupportedRequestType =>
      isEs ? 'Tipo de solicitud no soportado.' : 'Unsupported request type.';
  String get errEnterValidSponsorCode => isEs
      ? 'Ingresa un código de padrino válido.'
      : 'Enter a valid sponsor code.';
  String get errEnterSponsorCode =>
      isEs ? 'Ingresa el código del padrino.' : 'Enter the sponsor code.';
  String get errAlreadyHasSponsor => isEs
      ? 'Ya tienes un padrino vinculado.'
      : 'You already have a sponsor linked.';
  String get errSponsorCodeNotFound => isEs
      ? 'No se encontró ese código de padrino.'
      : 'That sponsor code was not found.';
  String get errOwnSponsorCode => isEs
      ? 'No puedes usar tu propio código de padrino.'
      : 'You cannot use your own sponsor code.';
  String get errTargetHasSponsor => isEs
      ? 'Ese usuario ya tiene un padrino vinculado.'
      : 'That user already has a sponsor linked.';
  String get errPendingRequestExists => isEs
      ? 'Ya existe una solicitud pendiente.'
      : 'A pending request already exists.';
  String get errSponsorRequestAccepted => isEs
      ? 'Esta solicitud de padrino ya fue aceptada.'
      : 'This sponsor request was already accepted.';
  String get errUsersAlreadyLinked => isEs
      ? 'Uno de los usuarios ya está vinculado.'
      : 'One of the users is already linked.';
  String get errLinkSponsorFirst =>
      isEs ? 'Vincula un padrino primero.' : 'Link a sponsor first.';
  String get errAddEmailFirst => isEs
      ? 'Agrega un correo a tu cuenta primero.'
      : 'Add an email address to your account first.';
  String get errEmailUnlinkPending => isEs
      ? 'Ya tienes una solicitud de desvinculación por correo activa.'
      : 'You already have an active email unlink request.';
  String get errEnterEmailCode =>
      isEs ? 'Ingresa el código del correo.' : 'Enter the email code.';
  String get errEmailCodeInvalid => isEs
      ? 'Ese código de correo es inválido o expiró.'
      : 'That email code is invalid or expired.';
  String get errCodeInvalid => isEs
      ? 'Ese código es inválido o expiró.'
      : 'That code is invalid or expired.';
  String get errCodeAlreadyUsed =>
      isEs ? 'Ese código ya se usó.' : 'That code was already used.';
  String get unlinkCodeEmailSubject =>
      isEs ? 'Código de desvinculación de Detox' : 'Detox unlink code';
  String unlinkCodeEmailText(String code) => isEs
      ? 'Tu código de desvinculación de Detox es $code. Expira en 10 minutos.'
      : 'Your Detox unlink code is $code. It expires in 10 minutes.';
  String unlinkCodeEmailHtml(String code) => isEs
      ? '<p>Tu código de desvinculación de Detox es <strong>$code</strong>.</p><p>Expira en 10 minutos.</p>'
      : '<p>Your Detox unlink code is <strong>$code</strong>.</p><p>It expires in 10 minutes.</p>';

  // ── Auth service errors ──
  String get authSessionNotRestored => isEs
      ? 'La cuenta se creó, pero no se pudo restaurar la sesión.'
      : 'Account created, but session could not be restored.';
  String get authSessionNotStarted =>
      isEs ? 'No se pudo iniciar tu sesión.' : 'Could not start your session.';
  String get authGoogleCancelled => isEs
      ? 'Se canceló el acceso con Google.'
      : 'Google sign-in was cancelled.';
  String get authGoogleFailed =>
      isEs ? 'Falló el acceso con Google.' : 'Google sign-in failed.';
  String get authGoogleBuildSetup => isEs
      ? 'El acceso con Google falló en esta compilación. Verifica que Google esté habilitado en Firebase y que las huellas SHA de Android estén registradas.'
      : 'Google sign-in failed on this build. Verify Google is enabled in Firebase and that the Android SHA fingerprints were added.';
  String get authPhoneStartFailed => isEs
      ? 'No se pudo iniciar el acceso con teléfono. Verifica que la autenticación por teléfono esté habilitada en Firebase.'
      : 'Phone sign-in could not be started. Make sure Phone authentication is enabled in Firebase.';
  String get authNoSmsVerification => isEs
      ? 'No hay una verificación por SMS activa. Solicita un código primero.'
      : 'No SMS verification is active. Request a code first.';
  String get authSmsVerifyFailed => isEs
      ? 'No se pudo verificar el código SMS.'
      : 'The SMS code could not be verified.';
  String get authNoActiveSession => isEs
      ? 'No hay una sesión activa que eliminar.'
      : 'No active session to delete.';
  String get authDeleteRequiresRecentLogin => isEs
      ? 'Tus datos de Detox se eliminaron, pero Firebase requiere un inicio de sesión reciente para borrar la cuenta de acceso por completo. Inicia sesión de nuevo y repite la eliminación una vez más.'
      : 'Your Detox data was deleted, but Firebase requires a recent sign-in to remove the access account completely. Sign in again and repeat the deletion once more.';
  String get authEmailInUse =>
      isEs ? 'Ese correo ya está en uso.' : 'That email is already in use.';
  String get authInvalidEmail =>
      isEs ? 'Ingresa un correo válido.' : 'Enter a valid email address.';
  String get authUserNotFound => isEs
      ? 'No existe una cuenta con ese correo.'
      : 'No account exists with that email.';
  String get authWrongCredentials => isEs
      ? 'Correo o contraseña incorrectos.'
      : 'Incorrect email or password.';
  String get authWeakPassword =>
      isEs ? 'Usa una contraseña más fuerte.' : 'Use a stronger password.';
  String get authNetworkError => isEs
      ? 'Error de red. Revisa tu conexión e inténtalo de nuevo.'
      : 'Network error. Check your connection and try again.';
  String get authTooManyRequests => isEs
      ? 'Demasiados intentos. Inténtalo más tarde.'
      : 'Too many attempts. Try again later.';
  String get authMethodNotAllowed => isEs
      ? 'Este método de acceso aún no está habilitado en Firebase.'
      : 'This sign-in method is not enabled in Firebase yet.';
  String get authInvalidSmsCode =>
      isEs ? 'El código SMS no es válido.' : 'The SMS code is not valid.';
  String get authSmsExpired => isEs
      ? 'El código SMS expiró. Solicita otro.'
      : 'The SMS code expired. Request another one.';
  String get authFailed =>
      isEs ? 'Falló la autenticación.' : 'Authentication failed.';
}

/// Process-wide language holder.
///
/// Widgets read the locale from `Localizations`, but background services and
/// notifications have no `BuildContext`, so the app records the active locale
/// here and services render text through `AppStrings.current`.
class AppLocale {
  AppLocale._();

  static Locale current = const Locale('es');

  static void set(Locale? locale) {
    if (locale == null) return;
    current = locale;
  }

  static void setLanguageCode(String? code) {
    if (code == null || code.isEmpty) return;
    current = Locale(code);
  }
}
