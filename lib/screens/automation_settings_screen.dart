import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../models/automation_rule.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../widgets/ui_kit.dart';

class AutomationSettingsScreen extends StatefulWidget {
  const AutomationSettingsScreen({super.key});

  @override
  State<AutomationSettingsScreen> createState() => _AutomationSettingsScreenState();
}

class _AutomationSettingsScreenState extends State<AutomationSettingsScreen> {
  final StorageService _storage = StorageService();
  List<AutomationRule> _rules = const [];
  List<AppLimit> _appLimits = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await _storage.loadAutomationRules();
    final limits = await _storage.loadAppLimits();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _appLimits = limits;
      _loading = false;
    });
  }

  Future<void> _saveRules(List<AutomationRule> rules) async {
    await _storage.saveAutomationRules(rules);
    if (!mounted) return;
    setState(() => _rules = rules);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).automationSaved)));
  }

  AutomationRule _socialPreset() => AutomationRule(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: 'Social 08:00-14:00',
    startMinuteOfDay: 8 * 60,
    endMinuteOfDay: 14 * 60,
    weekdays: const [1, 2, 3, 4, 5],
    blockedPackages: _appLimits.where((e) => (e.packageName ?? '').contains('instagram') || (e.packageName ?? '').contains('musically')).map((e) => e.packageName!).toList(),
    strictMode: false,
  );

  AutomationRule _nightPreset() => AutomationRule(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: 'Night 22:00-07:00',
    startMinuteOfDay: 22 * 60,
    endMinuteOfDay: 7 * 60,
    weekdays: const [1, 2, 3, 4, 5, 6, 7],
    blockedPackages: _appLimits.where((e) => (e.packageName ?? '').isNotEmpty).map((e) => e.packageName!).toList(),
    strictMode: false,
  );

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.isEs ? 'Horarios de Detox' : 'Detox schedules')),
      backgroundColor: Colors.transparent,
      body: DetoxBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    AppPageHeader(
                      eyebrow: t.isEs ? 'Horarios de Detox' : 'Detox schedules',
                      title: t.isEs ? 'Programa sesiones automáticas de Detox' : 'Schedule automatic Detox sessions',
                      subtitle: t.isEs
                          ? 'Úsalo como alternativa a las zonas: crea horarios y presets de apps para activar Detox en ciertos momentos del día.'
                          : 'Use it as an alternative to zones: create schedules and app presets to activate Detox at specific times of day.',
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(height: 16),
                    SectionTitle(
                      title: t.isEs ? 'Presets rápidos' : 'Quick presets',
                      subtitle: t.isEs
                          ? 'Atajos para crear horarios útiles en pocos toques.'
                          : 'Shortcuts to create useful schedules in just a few taps.',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _saveRules([..._rules, _socialPreset()]),
                            child: Text(t.addSocialPreset),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _saveRules([..._rules, _nightPreset()]),
                            child: Text(t.addEntertainmentPreset),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionTitle(
                      title: t.isEs ? 'Horarios activos' : 'Active schedules',
                      subtitle: t.isEs
                          ? 'Bloqueos programados que se activan solos durante el día.'
                          : 'Scheduled blocks that turn on automatically during the day.',
                      trailing: IconButton(
                        onPressed: () async {
                          final created = await showModalBottomSheet<AutomationRule>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                            builder: (_) => _AutomationRuleEditor(appLimits: _appLimits),
                          );
                          if (created != null) {
                            await _saveRules([..._rules, created]);
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_rules.isEmpty)
                      GlassCard(
                        child: Text(
                          t.noSchedulesYet,
                          style: const TextStyle(color: DetoxColors.muted),
                        ),
                      )
                    else
                      GlassCard(
                        child: Column(
                          children: _rules.map((rule) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withOpacity(0.035)
                                      : const Color(0xFFF8FAFF),
                                  border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.06)
                                        : DetoxColors.lightCardBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_format(rule.startMinuteOfDay)} - ${_format(rule.endMinuteOfDay)} • ${rule.onlyInsideZone ? t.zoneAndSchedule : t.scheduleOnly}',
                                                style: const TextStyle(color: DetoxColors.muted),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                rule.strictMode ? t.strictModeLabel : t.normalMode,
                                                style: const TextStyle(color: DetoxColors.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: rule.enabled,
                                          onChanged: (value) => _saveRules(
                                            _rules.map((e) => e.id == rule.id ? e.copyWith(enabled: value) : e).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        StatusPill(
                                          label: rule.strictMode ? t.strictModeLabel : t.normalMode,
                                          icon: rule.strictMode ? Icons.lock_outline_rounded : Icons.tune_rounded,
                                          color: rule.strictMode ? DetoxColors.warning : DetoxColors.accentSoft,
                                        ),
                                        StatusPill(
                                          label: '${rule.blockedPackages.length} ${t.isEs ? 'apps' : 'apps'}',
                                          icon: Icons.apps_rounded,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              final updated = await showModalBottomSheet<AutomationRule>(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Theme.of(context).colorScheme.surface,
                                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                                                builder: (_) => _AutomationRuleEditor(appLimits: _appLimits, initialRule: rule),
                                              );
                                              if (updated != null) {
                                                await _saveRules(_rules.map((e) => e.id == rule.id ? updated : e).toList());
                                              }
                                            },
                                            icon: const Icon(Icons.edit_outlined),
                                            label: Text(t.editSchedule),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _saveRules(_rules.where((e) => e.id != rule.id).toList()),
                                            icon: const Icon(Icons.delete_outline),
                                            label: Text(t.deleteText),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }


  String _format(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _AutomationRuleEditor extends StatefulWidget {
  const _AutomationRuleEditor({required this.appLimits, this.initialRule});
  final List<AppLimit> appLimits;
  final AutomationRule? initialRule;

  @override
  State<_AutomationRuleEditor> createState() => _AutomationRuleEditorState();
}

class _AutomationRuleEditorState extends State<_AutomationRuleEditor> {
  late final TextEditingController _name;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _weekdays;
  late Set<String> _packages;
  bool _strictMode = false;
  bool _onlyInsideZone = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    final t = AppStrings(WidgetsBinding.instance.platformDispatcher.locale);
    _name = TextEditingController(text: rule?.name ?? (t.isEs ? 'Nuevo horario' : 'New schedule'));
    _start = TimeOfDay(hour: (rule?.startMinuteOfDay ?? 480) ~/ 60, minute: (rule?.startMinuteOfDay ?? 480) % 60);
    _end = TimeOfDay(hour: (rule?.endMinuteOfDay ?? 840) ~/ 60, minute: (rule?.endMinuteOfDay ?? 840) % 60);
    _weekdays = {...(rule?.weekdays ?? const [1,2,3,4,5])};
    _packages = {...(rule?.blockedPackages ?? widget.appLimits.where((e) => (e.packageName ?? '').isNotEmpty).map((e) => e.packageName!))};
    _strictMode = rule?.strictMode ?? false;
    _onlyInsideZone = rule?.onlyInsideZone ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initialRule == null ? t.createSchedule : t.editSchedule, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: InputDecoration(labelText: t.ruleName)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(t.startTime), subtitle: Text(_start.format(context)), onTap: () async { final picked = await showTimePicker(context: context, initialTime: _start); if (picked != null) setState(() => _start = picked); })),
              Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(t.endTime), subtitle: Text(_end.format(context)), onTap: () async { final picked = await showTimePicker(context: context, initialTime: _end); if (picked != null) setState(() => _end = picked); })),
            ]),
            const SizedBox(height: 10),
            Text(t.weekdays, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final day in [
                (1, t.isEs ? 'Lun' : 'Mon'),
                (2, t.isEs ? 'Mar' : 'Tue'),
                (3, t.isEs ? 'Mié' : 'Wed'),
                (4, t.isEs ? 'Jue' : 'Thu'),
                (5, t.isEs ? 'Vie' : 'Fri'),
                (6, t.isEs ? 'Sáb' : 'Sat'),
                (7, t.isEs ? 'Dom' : 'Sun'),
              ])
                FilterChip(label: Text(day.$2), selected: _weekdays.contains(day.$1), onSelected: (value) => setState(() => value ? _weekdays.add(day.$1) : _weekdays.remove(day.$1)))
            ]),
            const SizedBox(height: 12),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _strictMode, onChanged: (value) => setState(() => _strictMode = value), title: Text(t.strictModeLabel), subtitle: Text(_strictMode ? t.hardModeGlobalSubtitle : t.normalSchedulesBody)),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _onlyInsideZone, onChanged: (value) => setState(() => _onlyInsideZone = value), title: Text(t.zoneAndSchedule), subtitle: Text(t.scheduleOnly)),
            const SizedBox(height: 8),
            Text(t.chooseApps, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: widget.appLimits.where((e) => (e.packageName ?? '').isNotEmpty).map((item) => FilterChip(label: Text(item.appName), selected: _packages.contains(item.packageName!), onSelected: (value) => setState(() => value ? _packages.add(item.packageName!) : _packages.remove(item.packageName!)))).toList()),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _packages.isEmpty ? null : () {
                Navigator.pop(context, AutomationRule(
                  id: widget.initialRule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _name.text.trim().isEmpty ? (t.isEs ? 'Horario' : 'Schedule') : _name.text.trim(),
                  startMinuteOfDay: _start.hour * 60 + _start.minute,
                  endMinuteOfDay: _end.hour * 60 + _end.minute,
                  weekdays: _weekdays.toList()..sort(),
                  blockedPackages: _packages.toList()..sort(),
                  enabled: widget.initialRule?.enabled ?? true,
                  strictMode: _strictMode,
                  onlyInsideZone: _onlyInsideZone,
                ));
              },
              child: Text(t.saveText),
            ),
          ],
        ),
      ),
    );
  }
}
