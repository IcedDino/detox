import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  static AppStrings of(BuildContext context) => AppStrings(Localizations.localeOf(context));

  bool get isEs => locale.languageCode.toLowerCase().startsWith('es');

  String get home => isEs ? 'Inicio' : 'Home';
  String get focus => isEs ? 'Enfoque' : 'Focus';
  String get habits => isEs ? 'Progreso' : 'Progress';
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

  String get accountOptions => isEs ? 'Opciones de cuenta' : 'Account options';
  String get manageAccount => isEs ? 'Gestionar cuenta' : 'Manage account';
  String get deleteAccount => isEs ? 'Eliminar cuenta' : 'Delete account';
  String get deleteAccountForever => isEs ? 'Eliminar cuenta para siempre' : 'Delete account forever';
  String get deleteAccountWarning => isEs
      ? 'Esto borrará tu cuenta, tus horarios, zonas, límites, progreso y cualquier vínculo con padrino.'
      : 'This will erase your account, schedules, zones, limits, progress, and any sponsor link.';
  String get deleteAccountConfirm => isEs ? 'Sí, eliminar cuenta' : 'Yes, delete account';
  String get deleteAccountSuccess => isEs ? 'Tu cuenta y tus datos se eliminaron.' : 'Your account and data were deleted.';
  String get tapToManageAccount => isEs ? 'Toca para ver opciones de cuenta' : 'Tap to view account options';
  String get signOut => isEs ? 'Cerrar sesión' : 'Sign out';
  String get manageAccount => isEs ? 'Cuenta' : 'Account';
  String get manageAccountSubtitle => isEs ? 'Toca para ver opciones de sesión y cuenta.' : 'Tap to view session and account options.';
  String get accountOptions => isEs ? 'Opciones de cuenta' : 'Account options';
  String get deleteAccount => isEs ? 'Eliminar cuenta' : 'Delete account';
  String get deleteAccountSubtitle => isEs ? 'Borra tu cuenta y tus datos sincronizados.' : 'Delete your account and synced data.';
  String get deleteAccountTitle => isEs ? 'Eliminar cuenta' : 'Delete account';
  String get deleteAccountBody => isEs ? 'Esta acción eliminará tu cuenta de Detox, tus datos sincronizados y cerrará tu sesión en este dispositivo.' : 'This will delete your Detox account, your synced data, and sign you out on this device.';
  String get deleteAccountWarning => isEs ? 'No podrás recuperar esta información después.' : 'You will not be able to recover this information afterwards.';
  String get deleteAccountConfirm => isEs ? 'Sí, eliminar' : 'Yes, delete';
  String get deletingAccount => isEs ? 'Eliminando cuenta…' : 'Deleting account...';
  String get returnLoginScreen => isEs ? 'Volver a la pantalla de acceso' : 'Return to the login screen';
  String get sponsorCenter => isEs ? 'Centro de padrino' : 'Sponsor center';
  String get open => isEs ? 'Abrir' : 'Open';
  String get concentrationZones => isEs ? 'Zonas de concentración' : 'Concentration zones';

  String get orUseEmail => isEs ? 'O usa correo' : 'Or use email';
  String get useEmailFirst => isEs ? 'Accede con tu correo' : 'Sign in with your email';
  String get otherWaysToContinue => isEs ? 'Otras formas de acceso' : 'Other ways to continue';
  String get noAccountYet => isEs ? '¿No tienes cuenta aún?' : "Don't have an account yet?";
  String get alreadyHaveAccount => isEs ? '¿Ya tienes cuenta?' : 'Already have an account?';
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

  // Automation settings
  String get automationAndHardMode => isEs ? 'Automatización y modo estricto' : 'Automation & hard mode';
  String get automationAndHardModeBody => isEs ? 'Horarios, modo estricto, presets inteligentes y reglas de zona + horario.' : 'Schedules, strict mode, smart presets, and zone + schedule rules.';
  String get automationTitle => isEs ? 'Automatización' : 'Automation';
  String get hardModeStrictMode => isEs ? 'Modo estricto' : 'Hard mode / Strict mode';
  String get hardModeStrictModeBody => isEs ? 'Desactiva pausas, anuncios y salidas mientras el bloqueo de enfoque esté activo.' : 'Disables pauses, ads, and exit buttons while focus blocking is active.';
  String get smartPresets => isEs ? 'Presets inteligentes' : 'Smart presets';
  String get addSocialPreset => isEs ? 'Agregar preset de redes' : 'Add social preset';
  String get addEntertainmentPreset => isEs ? 'Agregar preset de entretenimiento' : 'Add entertainment preset';
  String get automationPresetsBody => isEs ? 'Tus límites diarios por app ahora bloquean automáticamente cuando se alcanza el límite. Las reglas por horario también pueden restringirse para funcionar solo dentro de zonas de concentración.' : 'Your per-app daily limits now auto-block when the limit is reached. Schedule rules can also be restricted to work only inside concentration zones.';
  String get scheduleRules => isEs ? 'Reglas por horario' : 'Schedule rules';
  String get noAutomaticSchedulesYet => isEs ? 'Aún no hay horarios automáticos.' : 'No automatic schedules yet.';
  String get zoneAndSchedule => isEs ? 'Zona + horario' : 'Zone + schedule';
  String get scheduleOnly => isEs ? 'Solo horario' : 'Schedule only';
  String get strictLabel => isEs ? 'Estricto' : 'Strict';
  String get normalLabel => isEs ? 'Normal' : 'Normal';
  String get deleteLabel => isEs ? 'Eliminar' : 'Delete';
  String get ruleName => isEs ? 'Nombre de la regla' : 'Rule name';
  String get newSchedule => isEs ? 'Nuevo horario' : 'New schedule';
  String get startLabel => isEs ? 'Inicio' : 'Start';
  String get endLabel => isEs ? 'Fin' : 'End';
  List<String> get automationWeekdayShort => isEs ? ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'] : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get useStrictModeInSchedule => isEs ? 'Usar modo estricto en este horario' : 'Use strict mode in this schedule';
  String get onlyApplyInsideZones => isEs ? 'Aplicar solo dentro de zonas de concentración' : 'Only apply inside concentration zones';
  String get appsToBlock => isEs ? 'Apps a bloquear' : 'Apps to block';
  String get saveRule => isEs ? 'Guardar regla' : 'Save rule';
  String get scheduleRuleDefaultName => isEs ? 'Regla de horario' : 'Schedule rule';
  String get socialPresetName => isEs ? 'Redes sociales 08:00-14:00' : 'Social media 08:00-14:00';
  String get entertainmentPresetName => isEs ? 'Entretenimiento 22:00-07:00' : 'Entertainment 22:00-07:00';

  // Stats screen
  String get statsWeeklyTitle => isEs ? 'Estadísticas semanales' : 'Weekly Stats';
  String get statsWeeklySubtitle => isEs ? 'Mira tu tendencia de tiempo de pantalla y mantén la racha.' : 'See your screen-time trend and keep the streak alive.';
  String get statsTrendInsight => isEs ? 'Tendencia' : 'Trend insight';
  String get statsTrendDown => isEs ? 'Tu tiempo de pantalla va a la baja esta semana.' : 'Your screen time is trending downward this week.';
  String get statsTrendUp => isEs ? 'Tu tiempo de pantalla aumentó esta semana. Considera más sesiones de enfoque.' : 'Your screen time increased this week. Consider more focus sessions.';
  String get statsWeeklyGoal => isEs ? 'Meta semanal' : 'Weekly goal';
  String get statsGoalMet => isEs ? 'Buen trabajo. Estuviste bajo tu límite la mayoría de los días.' : 'Great job. You stayed under your limit most days.';
  String get statsGoalMiss => isEs ? 'Intenta pasar al menos 5 días bajo tu límite diario.' : 'Aim for at least 5 days under your daily limit.';
  List<String> get weekDayLabels => isEs
      ? ['L', 'M', 'X', 'J', 'V', 'S', 'D']
      : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // Sponsor screen
  String get yourSponsorCode => isEs ? 'Tu código de padrino' : 'Your sponsor code';
  String get sponsorCodeShare => isEs ? 'Comparte este código con la persona de confianza que aprobará tus cambios en Detox.' : 'Share this code with the one person you trust to approve Detox overrides.';
  String get addSponsor => isEs ? 'Agregar padrino' : 'Add a sponsor';
  String get enterSponsorCodeHint => isEs ? 'Ingresa el código de padrino' : 'Enter sponsor code';
  String get linkSponsor => isEs ? 'Vincular padrino' : 'Link sponsor';
  String get onlyOneSponsor => isEs ? 'Solo puedes tener un padrino a la vez.' : 'You can only have one sponsor at a time.';
  String get requestZonePause => isEs ? 'Solicitar pausa de zona' : 'Request zone pause';
  String get requestSettingsApproval => isEs ? 'Solicitar aprobación de ajustes' : 'Request settings approval';
  String get endSponsorLink => isEs ? 'Terminar vínculo con padrino' : 'End sponsor link';
  String get currentSafeguards => isEs ? 'Protecciones actuales' : 'Current safeguards';
  String get zonePause => isEs ? 'Pausa de zona' : 'Zone pause';
  String get protectedSettings => isEs ? 'Ajustes protegidos' : 'Protected settings';
  String get protectedSettingsBody => isEs ? 'Quitar apps o zonas requiere aprobación del padrino.' : 'Removing apps or zones needs sponsor approval.';
  String get yourOutgoingRequests => isEs ? 'Tus solicitudes enviadas' : 'Your outgoing requests';
  String get noOutgoingRequests => isEs ? 'Aún no has solicitado ninguna acción al padrino.' : 'You have not requested any sponsor actions yet.';
  String get historyLabel => isEs ? 'Historial' : 'History';
  String get noSponsorHistory => isEs ? 'Aún no hay historial de padrino.' : 'No sponsor history yet.';
  String get incomingSponsorLinkRequests => isEs ? 'Solicitudes de vínculo entrantes' : 'Incoming sponsor link requests';
  String get acceptLinkBody => isEs ? 'Acepta esta solicitud para vincular ambas cuentas.' : 'Accept this request to link both accounts.';
  String get pendingSponsorLinkRequests => isEs ? 'Solicitudes de vínculo pendientes' : 'Pending sponsor link requests';
  String get noIncomingRequests => isEs ? 'Sin solicitudes entrantes por ahora.' : 'No incoming requests right now.';
  String get incomingRequestsTitle => isEs ? 'Solicitudes entrantes' : 'Incoming requests';
  String get reject => isEs ? 'Rechazar' : 'Reject';
  String get accept => isEs ? 'Aceptar' : 'Accept';
  String get approve => isEs ? 'Aprobar' : 'Approve';
  String get generateCode => isEs ? 'Generar código' : 'Generate code';
  String get done => isEs ? 'Listo' : 'Done';
  String get useCode => isEs ? 'Usar código' : 'Use code';
  String get enterEmailUnlinkCode => isEs ? 'Ingresar código de desvinculación por email' : 'Enter email unlink code';
  String get enterSponsorUnlinkCode => isEs ? 'Ingresar código de desvinculación del padrino' : 'Enter sponsor unlink code';
  String get endSponsorLinkTitle => isEs ? 'Terminar vínculo con padrino' : 'End sponsor link';
  String get endSponsorLinkBody => isEs ? 'Puedes desvincular con un código del padrino o solicitar uno por correo.' : 'You can unlink with a sponsor-generated code or request a code by email.';
  String get requestSponsorUnlinkCode => isEs ? 'Solicitar código de desvinculación al padrino' : 'Request sponsor unlink code';
  String get emailMeUnlinkCode => isEs ? 'Enviarme un código de desvinculación por email' : 'Email me an unlink code';
  String get enterEmailUnlinkCodeBtn => isEs ? 'Ingresar código de email' : 'Enter email unlink code';
  String get unlinkCodeSentEmail => isEs ? 'Enviamos una solicitud de código de desvinculación a tu correo.' : 'We sent an unlink code request to your email.';
  String get unlinkRequestSentSponsor => isEs ? 'Solicitud de desvinculación enviada a tu padrino.' : 'Unlink request sent to your sponsor.';
  String get sponsorLinkRemoved => isEs ? 'Vínculo con padrino eliminado.' : 'Sponsor link removed.';
  String get enterSponsorCodeSnack => isEs ? 'Ingresa un código de padrino' : 'Enter a sponsor code';
  String get requestSentWaiting => isEs ? 'Solicitud enviada. Esperando aprobación.' : 'Request sent. Waiting for approval.';
  String get sponsorRequestAccepted => isEs ? 'Solicitud de padrino aceptada.' : 'Sponsor request accepted.';
  String get sponsorRequestRejected => isEs ? 'Solicitud de padrino rechazada.' : 'Sponsor request rejected.';
  String get requestRejected => isEs ? 'Solicitud rechazada.' : 'Request rejected.';
  String get settingsAccessApproved => isEs ? 'Acceso a ajustes aprobado.' : 'Settings access approved.';
  String get shieldPauseApproved => isEs ? 'Pausa del escudo aprobada.' : 'App shield pause approved.';
  String get zonePauseApproved => isEs ? 'Pausa de zona aprobada.' : 'Zone pause approved.';
  String get settingsRequestSent => isEs ? 'Solicitud de desbloqueo de ajustes enviada a tu padrino.' : 'Settings approval request sent to your sponsor.';
  String get zonePauseRequestSent => isEs ? 'Solicitud de pausa de zona enviada a tu padrino.' : 'Zone-pause approval request sent to your sponsor.';
  String get expired => isEs ? 'Expirado' : 'Expired';
  String get statusUsed => isEs ? 'Usado' : 'Used';
  String get statusApproved => isEs ? 'Aprobado' : 'Approved';
  String get statusRejected => isEs ? 'Rechazado' : 'Rejected';
  String get statusPending => isEs ? 'Pendiente' : 'Pending';
  String get statusCompleted => isEs ? 'Completado' : 'Completed';
  String get statusEmailed => isEs ? 'Enviado por email' : 'Emailed';
  String get giveCodeTo => isEs ? 'Da este código a' : 'Give this code to';
  String get codeExpiresOnce => isEs ? 'Expira en 3 minutos y solo funciona una vez.' : 'It expires in 3 minutes and only works once.';
  String get expiresSoon => isEs ? 'Expira pronto' : 'Expires soon';
  String  durationMinLabel(int min) => isEs ? 'Duración: $min min' : 'Duration: $min min';
  String get waitingForTarget => isEs ? 'Esperando que' : 'Waiting for';
  String get toAcceptRequest => isEs ? 'acepte tu solicitud.' : 'to accept your request.';
  String get requestStillPending => isEs ? 'Esta solicitud sigue pendiente.' : 'This request is still pending.';
  String get zonePauseApprovalTitle => isEs ? 'Aprobación de pausa de zona' : 'Zone pause approval';
  String get settingsApprovalTitle => isEs ? 'Aprobación de ajustes' : 'Settings approval';
  String get shieldPauseTitle => isEs ? 'Pausa del escudo de apps' : 'App shield pause';
  String get unlinkApprovalTitle => isEs ? 'Aprobación de desvinculación' : 'Unlink approval';
  String zoneActiveLabel(String time) => isEs ? 'Activa · $time' : 'Active · $time';
  String insideZoneLabel(String name) => isEs ? 'Dentro de $name' : 'Inside $name';
  String get zoneInactive => isEs ? 'Inactiva' : 'Inactive';
  String get settingsUnlockedLabel => isEs ? 'Desbloqueado' : 'Unlocked';
  String waitingForName(String name) => isEs ? 'Esperando que $name acepte tu solicitud.' : 'Waiting for $name to accept your request.';



  String get progressTitle => isEs ? 'Progreso' : 'Progress';
  String get progressSubtitle => isEs ? 'Tus rachas, retos y medallas viven aquí.' : 'Your streaks, challenges, and medals live here.';
  String get startStreak => isEs ? 'Iniciar racha' : 'Start streak';
  String get continueToday => isEs ? 'Continuar hoy' : 'Continue today';
  String get currentStreak => isEs ? 'Racha actual' : 'Current streak';
  String get longestStreak => isEs ? 'Mejor racha' : 'Longest streak';
  String get achievements => isEs ? 'Logros' : 'Achievements';
  String get dailyChallenges => isEs ? 'Retos de hoy' : "Today's challenges";
  String get sponsorShowcase => isEs ? 'Visible para sponsor' : 'Visible to sponsor';
  String get sponsorShowcaseBody => isEs ? 'Cuando tengas sponsor, aquí verá tu racha y tus medallas desbloqueadas.' : 'When you have a sponsor, they will see your streak and unlocked medals here.';
  String get startConcentrationHour => isEs ? 'Empezar hora de concentración' : 'Start concentration hour';
  String get deny => isEs ? 'Denegar' : 'Deny';
  String get smartSuggestionTitle => isEs ? 'Detox te recomienda una pausa' : 'Detox recommends a pause';
  String smartSuggestionNotification(String appName, String time) => isEs ? 'Hoy has usado $time horas $appName, ¿no crees que es momento de una pausa?' : "You have used $appName for $time today. Isn't it time for a pause?";
  String get progressStartedSnack => isEs ? 'Tu racha quedó activa hoy.' : 'Your streak is active today.';
  String get autoFocusStartedSnack => isEs ? 'Se inició una hora de concentración.' : 'A one-hour focus session started.';

  // HabitDetailScreen
  String get habitOverview => isEs ? 'RESUMEN' : 'OVERVIEW';
  String get thisWeek => isEs ? 'Esta semana' : 'This week';
  String streakDaysLabel(int n) => isEs ? '$n días' : '$n days';
  String get completedToday => isEs ? 'Completado hoy' : 'Completed today';
  String get notCompletedToday => isEs ? 'Pendiente hoy' : 'Not done today';
  String get completionThisMonth => isEs ? 'Completado este mes' : 'Completion this month';
  String get demoDataNotice => isEs ? 'Mostrando datos de ejemplo — concede Acceso de uso para ver datos reales.' : 'Showing sample data — grant Usage Access to see real data.';
  String monthName(int month) {
    const es = ['', 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    const en = ['', 'January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return isEs ? es[month] : en[month];
  }


  // Automation, Pomodoro, limits, anti-bypass
  String get automationSubtitle => isEs ? 'Horarios normales o estrictos, límites y reglas combinadas.' : 'Clean normal or strict schedules, limits, and combined rules.';
  String get automationAndHardModeSubtitle => isEs ? 'Horarios, modo estricto, presets y reglas por zona + horario.' : 'Schedules, strict mode, presets, and zone + schedule rules.';
  String get noSchedulesYet => isEs ? 'Aún no hay horarios automáticos.' : 'No automatic schedules yet.';
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
  String get normalSchedulesBody => isEs ? 'Los horarios normales bloquean apps automáticamente sin obligar modo estricto.' : 'Normal schedules automatically block apps without forcing strict mode.';
  String get hardModeGlobal => isEs ? 'Modo estricto global' : 'Global hard mode';
  String get hardModeGlobalSubtitle => isEs ? 'Hace que foco manual y reglas activas no permitan pausas ni bypass.' : 'Makes manual focus and active rules disallow pauses and bypass.';
  String get antiBypassTitle => isEs ? 'Protección anti-bypass' : 'Anti-bypass protection';
  String get antiBypassBody => isEs ? 'Detox vigila permisos clave, conserva reglas activas tras reinicio y vuelve a levantar el escudo si sigue habiendo bloqueo pendiente.' : 'Detox watches key permissions, preserves active rules after reboot, and restores the shield when blocking is still pending.';
  String get antiBypassHealthy => isEs ? 'Protección activa' : 'Protection active';
  String get antiBypassNeedsAttention => isEs ? 'Requiere atención' : 'Needs attention';
  String get pomodoroTitle => isEs ? 'Pomodoro integrado' : 'Integrated Pomodoro';
  String get pomodoroSubtitle => isEs ? 'Alterna bloques de trabajo y descanso usando el mismo escudo de enfoque.' : 'Alternate work and break blocks using the same focus shield.';
  String get pomodoroStart => isEs ? 'Iniciar Pomodoro' : 'Start Pomodoro';
  String get pomodoroWork => isEs ? 'Trabajo' : 'Work';
  String get pomodoroBreak => isEs ? 'Descanso' : 'Break';
  String pomodoroCycleLabel(int current, int total) => isEs ? 'Ciclo $current de $total' : 'Cycle $current of $total';
  String get appLimitReached => isEs ? 'Límite diario alcanzado' : 'Daily limit reached';
  String limitReachedForApp(String appName) => isEs ? 'Has alcanzado el límite diario de $appName.' : 'You reached the daily limit for $appName.';
  String get startHourFocus => isEs ? 'Empezar hora de concentración' : 'Start concentration hour';
  String get denyText => isEs ? 'Denegar' : 'Deny';
  String get automationSaved => isEs ? 'Automatización actualizada.' : 'Automation updated.';
  String get progressMedalsSubtitle => isEs ? 'Convierte tus decisiones diarias en rachas, logros y medallas visibles.' : 'Turn your daily decisions into streaks, achievements, and visible medals.';
  String get startTodayProgress => isEs ? 'Activar progreso hoy' : 'Activate progress today';
  String get sessionsCompleted => isEs ? 'Sesiones completadas' : 'Completed sessions';
  String get suggestionsAccepted => isEs ? 'Sugerencias aceptadas' : 'Accepted suggestions';
  String get suggestionsShown => isEs ? 'Sugerencias mostradas' : 'Suggestions shown';
  String get pomodoroCycles => isEs ? 'Ciclos Pomodoro' : 'Pomodoro cycles';
  String get extraPauseAd => isEs ? 'Pausa extra con anuncio' : 'Extra pause with ad';
  String get extraPauseAdSubtitle => isEs ? 'Mantienes 1 pausa gratis diaria y 1 pausa adicional al completar un anuncio.' : 'Keep 1 free daily pause and 1 extra pause after completing an ad.';
  String get progressStats => isEs ? 'Resumen de progreso' : 'Progress summary';
  String get progressStatsBody => isEs
      ? 'Aquí ves tu resumen personal. El sponsor sigue recibiendo tu progreso sin mostrar esta sección como un panel especial.'
      : 'This is your personal summary. Your sponsor still receives your progress without showing this section as a special panel.';
  String get topApps => isEs ? 'Apps más usadas' : 'Top apps';


}
