import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../models/automation_rule.dart';
import '../services/automation_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AutomationSettingsScreen extends StatefulWidget {
  const AutomationSettingsScreen({super.key});

  @override
  State<AutomationSettingsScreen> createState() => _AutomationSettingsScreenState();
}

class _AutomationSettingsScreenState extends State<AutomationSettingsScreen> {
  final StorageService _storage = StorageService();

  bool _loading = true;
  bool _strictMode = false;
  List<AppLimit> _appLimits = const [];
  List<AutomationRule> _rules = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>([
      _storage.loadStrictModeEnabled(),
      _storage.loadAppLimits(),
      _storage.loadAutomationRules(),
    ]);
    if (!mounted) return;
    setState(() {
      _strictMode = results[0] as bool;
      _appLimits = results[1] as List<AppLimit>;
      _rules = results[2] as List<AutomationRule>;
      _loading = false;
    });
  }

  Future<void> _saveRules(List<AutomationRule> rules) async {
    setState(() => _rules = rules);
    await _storage.saveAutomationRules(rules);
    await AutomationService.instance.refresh();
  }

  Future<void> _addPreset(String name, List<String> packages) async {
    if (packages.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final rule = AutomationRule(
      id: now,
      name: name,
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 14 * 60,
      weekdays: const [1, 2, 3, 4, 5],
      blockedPackages: packages,
    );
    await _saveRules([..._rules, rule]);
  }

  Future<AutomationRule?> _showRuleEditor({AutomationRule? initialRule}) {
    return showModalBottomSheet<AutomationRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AutomationRuleEditor(
        appLimits: _appLimits,
        initialRule: initialRule,
      ),
    );
  }

  String _formatMinutesOfDay(int value) {
    final h = (value ~/ 60) % 24;
    final m = value % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<String> _socialPreset() {
    const known = {
      'com.instagram.android',
      'com.zhiliaoapp.musically',
      'com.twitter.android',
      'com.facebook.katana',
      'com.snapchat.android',
      'com.reddit.frontpage',
    };
    final fromLimits = _appLimits
        .where((e) => known.contains(e.packageName))
        .map((e) => e.packageName!)
        .toSet()
        .toList();
    return fromLimits.isNotEmpty ? fromLimits : known.toList();
  }

  List<String> _entertainmentPreset() {
    const known = {
      'com.google.android.youtube',
      'com.netflix.mediaclient',
      'com.spotify.music',
      'tv.twitch.android.app',
      'com.disney.disneyplus',
    };
    final fromLimits = _appLimits
        .where((e) => known.contains(e.packageName))
        .map((e) => e.packageName!)
        .toSet()
        .toList();
    return fromLimits.isNotEmpty ? fromLimits : known.toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.automationTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _strictMode,
                    onChanged: (value) async {
                      setState(() => _strictMode = value);
                      await _storage.saveStrictModeEnabled(value);
                      await AutomationService.instance.refresh();
                    },
                    title: Text(t.hardModeStrictMode),
                    subtitle: Text(
                      t.hardModeStrictModeBody,
                      style: const TextStyle(color: DetoxColors.muted),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.smartPresets,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _addPreset(
                              t.socialPresetName,
                              _socialPreset(),
                            ),
                            child: Text(t.addSocialPreset),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _addPreset(
                              t.entertainmentPresetName,
                              _entertainmentPreset(),
                            ),
                            child: Text(t.addEntertainmentPreset),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.automationPresetsBody,
                        style: const TextStyle(color: DetoxColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.scheduleRules,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final created = await _showRuleEditor();
                              if (created != null) {
                                await _saveRules([..._rules, created]);
                              }
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      if (_rules.isEmpty)
                        Text(
                          t.noAutomaticSchedulesYet,
                          style: const TextStyle(color: DetoxColors.muted),
                        )
                      else
                        ..._rules.map(
                          (rule) => Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(rule.name),
                                subtitle: Text(
                                  '${_formatMinutesOfDay(rule.startMinuteOfDay)} - ${_formatMinutesOfDay(rule.endMinuteOfDay)} • ${rule.onlyInsideZone ? t.zoneAndSchedule : t.scheduleOnly} • ${rule.strictMode ? t.strictLabel : t.normalLabel}',
                                  style: const TextStyle(color: DetoxColors.muted),
                                ),
                                trailing: Switch(
                                  value: rule.enabled,
                                  onChanged: (value) async {
                                    await _saveRules(
                                      _rules
                                          .map(
                                            (e) => e.id == rule.id
                                                ? e.copyWith(enabled: value)
                                                : e,
                                          )
                                          .toList(),
                                    );
                                  },
                                ),
                                onTap: () async {
                                  final updated = await _showRuleEditor(
                                    initialRule: rule,
                                  );
                                  if (updated != null) {
                                    await _saveRules(
                                      _rules
                                          .map((e) => e.id == rule.id ? updated : e)
                                          .toList(),
                                    );
                                  }
                                },
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await _saveRules(
                                      _rules.where((e) => e.id != rule.id).toList(),
                                    );
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(t.deleteLabel),
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
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
  late TextEditingController _name;
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
    _name = TextEditingController(
      text: rule?.name ?? '',
    );
    _start = TimeOfDay(
      hour: (rule?.startMinuteOfDay ?? 480) ~/ 60,
      minute: (rule?.startMinuteOfDay ?? 480) % 60,
    );
    _end = TimeOfDay(
      hour: (rule?.endMinuteOfDay ?? 840) ~/ 60,
      minute: (rule?.endMinuteOfDay ?? 840) % 60,
    );
    _weekdays = {...(rule?.weekdays ?? const [1, 2, 3, 4, 5])};
    _packages = {
      ...(rule?.blockedPackages ??
          widget.appLimits
              .where(
                (e) => e.useInFocusMode && (e.packageName ?? '').isNotEmpty,
              )
              .map((e) => e.packageName!))
    };
    _strictMode = rule?.strictMode ?? false;
    _onlyInsideZone = rule?.onlyInsideZone ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final weekdayLabels = t.automationWeekdayShort;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Material(
      color: cardColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: t.ruleName),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.startLabel),
                        subtitle: Text(_start.format(context)),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _start,
                          );
                          if (picked != null) setState(() => _start = picked);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.endLabel),
                        subtitle: Text(_end.format(context)),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _end,
                          );
                          if (picked != null) setState(() => _end = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final dayValue = index + 1;
                    return FilterChip(
                      label: Text(weekdayLabels[index]),
                      selected: _weekdays.contains(dayValue),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _weekdays.add(dayValue);
                          } else {
                            _weekdays.remove(dayValue);
                          }
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _strictMode,
                  onChanged: (value) => setState(() => _strictMode = value),
                  title: Text(t.useStrictModeInSchedule),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onlyInsideZone,
                  onChanged: (value) => setState(() => _onlyInsideZone = value),
                  title: Text(t.onlyApplyInsideZones),
                ),
                const SizedBox(height: 8),
                Text(
                  t.appsToBlock,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.appLimits
                      .where((e) => (e.packageName ?? '').isNotEmpty)
                      .map(
                        (app) => FilterChip(
                          label: Text(app.appName),
                          selected: _packages.contains(app.packageName),
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _packages.add(app.packageName!);
                              } else {
                                _packages.remove(app.packageName);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _packages.isEmpty || _weekdays.isEmpty
                        ? null
                        : () {
                            final startMinutes = _start.hour * 60 + _start.minute;
                            final endMinutes = _end.hour * 60 + _end.minute;
                            Navigator.pop(
                              context,
                              AutomationRule(
                                id: widget.initialRule?.id ??
                                    DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                                name: _name.text.trim().isEmpty
                                    ? t.scheduleRuleDefaultName
                                    : _name.text.trim(),
                                startMinuteOfDay: startMinutes,
                                endMinuteOfDay: endMinutes,
                                weekdays: _weekdays.toList()..sort(),
                                blockedPackages: _packages.toList()..sort(),
                                strictMode: _strictMode,
                                onlyInsideZone: _onlyInsideZone,
                                enabled: widget.initialRule?.enabled ?? true,
                              ),
                            );
                          },
                    child: Text(t.saveRule),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
