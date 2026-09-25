import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';

/// Required Android setup shown after sign-in. Other permissions are requested
/// only when the user starts the feature that needs them.
class UsageAccessScreen extends StatefulWidget {
  const UsageAccessScreen({super.key, required this.onGranted});

  final Future<void> Function() onGranted;

  @override
  State<UsageAccessScreen> createState() => _UsageAccessScreenState();
}

class _UsageAccessScreenState extends State<UsageAccessScreen>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _openingSettings = false;
  bool _reportedGranted = false;
  bool _settingsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await UsageService().getPermissionStatus();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _openingSettings = false;
    });
    if (status.usageReady && !_reportedGranted) {
      _reportedGranted = true;
      await widget.onGranted();
    }
  }

  Future<void> _openSettings() async {
    setState(() {
      _openingSettings = true;
      _settingsError = false;
    });
    final opened = await UsageService().openUsageAccessSettings();
    if (mounted && !opened) setState(() => _settingsError = true);
    if (mounted) await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final es = t.isEs;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: DetoxBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      es ? 'Acceso al tiempo de uso' : 'Usage access',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: detoxWeightEmphasis,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      es
                          ? 'Detox necesita acceso a tus datos de uso para mostrar tu tiempo en pantalla y ayudarte a pausar las apps que elijas.'
                          : 'Detox needs Usage access to show your screen time and help pause the apps you choose.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(detoxRadius),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              color: colors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              es
                                  ? 'Solo se usa para estadísticas y funciones de enfoque. No vemos el contenido de tus apps.'
                                  : 'It is used only for stats and focus features. Detox cannot see what is inside your apps.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _checking || _openingSettings
                            ? null
                            : _openSettings,
                        icon: _openingSettings
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.tune_rounded),
                        label: Text(
                          _openingSettings
                              ? (es
                                  ? 'Vuelve aquí al terminar'
                                  : 'Return here when done')
                              : (es
                                  ? 'Activar acceso de uso'
                                  : 'Enable Usage access'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_settingsError) ...[
                      Text(
                        es
                            ? 'No se pudo abrir Ajustes. Inténtalo de nuevo.'
                            : 'Could not open Settings. Please try again.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.error),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      es
                          ? 'En Ajustes, selecciona Detox y activa “Permitir acceso de uso”.'
                          : 'In Settings, select Detox and enable “Permit usage access”.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
