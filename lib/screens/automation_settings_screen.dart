import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../models/automation_rule.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/ui_kit.dart';

class AutomationSettingsScreen extends StatefulWidget {
  const AutomationSettingsScreen({super.key});

  @override
  State<AutomationSettingsScreen> createState() =>
      _AutomationSettingsScreenState();
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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).automationSaved)));
  }

  Future<void> _openEditor({AutomationRule? rule}) async {
    final result = await showModalBottomSheet<AutomationRule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AutomationRuleEditor(appLimits: _appLimits, initialRule: rule),
    );
    if (result == null) return;

    final next = rule == null
        ? [..._rules, result]
        : _rules.map((e) => e.id == result.id ? result : e).toList();
    await _saveRules(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Scaffold(
      appBar: AppBar(
          title: Text(t.isEs ? 'Horarios de Detox' : 'Detox schedules')),
      backgroundColor: Colors.transparent,
      body: DetoxBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      DetoxSpace.page, 8, DetoxSpace.page, 28),
                  children: [
                    SectionTitle(
                      title: t.isEs ? 'Horarios activos' : 'Active schedules',
                      subtitle: t.isEs
                          ? 'Bloqueos programados que se activan solos durante el día.'
                          : 'Scheduled blocks that turn on automatically during the day.',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(t.createSchedule),
                    ),
                    const SizedBox(height: 18),
                    if (_rules.isEmpty)
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.isEs
                                  ? 'Sin horarios programados'
                                  : 'No schedules yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.isEs
                                  ? 'Crea uno para bloquear apps en los horarios que elijas.'
                                  : 'Create one to block apps at the times you choose.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._rules.map((rule) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RuleCard(
                              rule: rule,
                              onToggle: (value) => _saveRules(
                                _rules
                                    .map((e) => e.id == rule.id
                                        ? e.copyWith(enabled: value)
                                        : e)
                                    .toList(),
                              ),
                              onEdit: () => _openEditor(rule: rule),
                              onDelete: () => _saveRules(_rules
                                  .where((e) => e.id != rule.id)
                                  .toList()),
                            ),
                          )),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One schedule: name, active hours, weekday summary and its live state.
class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final AutomationRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rule.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: t.isEs
                  ? 'Activar ${rule.name}'
                  : 'Enable ${rule.name}',
              child: Switch(value: rule.enabled, onChanged: onToggle),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${_format(rule.startMinuteOfDay)} – ${_format(rule.endMinuteOfDay)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '${_weekdaysLabel(rule.weekdays, t)} · '
          '${rule.blockedPackages.length} ${t.isEs ? 'apps' : 'apps'}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!rule.enabled)
              StatusPill(
                label: t.isEs ? 'Pausado' : 'Paused',
                icon: Icons.pause_circle_outline_rounded,
                color: muted,
              ),
            if (rule.strictMode)
              StatusPill(
                label: t.strictModeLabel,
                icon: Icons.lock_outline_rounded,
                color: DetoxColors.warning,
              ),
            if (rule.onlyInsideZone)
              StatusPill(
                label: t.zoneAndSchedule,
                icon: Icons.location_on_outlined,
                color: DetoxColors.accentSoft,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: t.editSchedule,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              color: muted,
            ),
            IconButton(
              tooltip: t.isEs ? 'Eliminar ${rule.name}' : 'Delete ${rule.name}',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: muted,
            ),
          ],
        ),
      ],
    );

    return GlassCard(
      child: rule.enabled ? content : Opacity(opacity: 0.55, child: content),
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
  late final TextEditingController _name;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _weekdays;
  late Set<String> _packages;
  final TextEditingController _appSearch = TextEditingController();
  String _appQuery = '';
  bool _strictMode = false;
  bool _onlyInsideZone = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    final t = AppStrings(WidgetsBinding.instance.platformDispatcher.locale);
    _name = TextEditingController(
        text: rule?.name ?? (t.isEs ? 'Nuevo horario' : 'New schedule'));
    _start = TimeOfDay(
        hour: (rule?.startMinuteOfDay ?? 480) ~/ 60,
        minute: (rule?.startMinuteOfDay ?? 480) % 60);
    _end = TimeOfDay(
        hour: (rule?.endMinuteOfDay ?? 840) ~/ 60,
        minute: (rule?.endMinuteOfDay ?? 840) % 60);
    _weekdays = {...(rule?.weekdays ?? const [1, 2, 3, 4, 5])};
    _packages = {
      ...(rule?.blockedPackages ??
          widget.appLimits
              .where((e) => (e.packageName ?? '').isNotEmpty)
              .map((e) => e.packageName!))
    };
    _strictMode = rule?.strictMode ?? false;
    _onlyInsideZone = rule?.onlyInsideZone ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _appSearch.dispose();
    super.dispose();
  }

  List<AppLimit> get _selectableApps => widget.appLimits
      .where((e) => (e.packageName ?? '').isNotEmpty)
      .toList();

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    final t = AppStrings.of(context);
    Navigator.pop(
      context,
      AutomationRule(
        id: widget.initialRule?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _name.text.trim().isEmpty
            ? (t.isEs ? 'Horario' : 'Schedule')
            : _name.text.trim(),
        startMinuteOfDay: _start.hour * 60 + _start.minute,
        endMinuteOfDay: _end.hour * 60 + _end.minute,
        weekdays: _weekdays.toList()..sort(),
        blockedPackages: _packages.toList()..sort(),
        enabled: widget.initialRule?.enabled ?? true,
        strictMode: _strictMode,
        onlyInsideZone: _onlyInsideZone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final media = MediaQuery.of(context);
    final sheetHeight =
        (media.size.height - media.viewInsets.bottom - 96).clamp(320.0, 680.0);
    final selectableApps = _selectableApps;
    final query = _appQuery.trim().toLowerCase();
    final visibleApps = selectableApps
        .where((item) =>
            query.isEmpty ||
            item.appName.toLowerCase().contains(query) ||
            (item.packageName ?? '').toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.appName.toLowerCase().compareTo(
            b.appName.toLowerCase(),
          ));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: media.viewInsets.bottom + 16,
      ),
      child: GlassCard(
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialRule == null ? t.createSchedule : t.editSchedule,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: detoxWeightEmphasis),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: t.ruleName,
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeField(
                              label: t.startTime,
                              value: _start.format(context),
                              icon: Icons.login_rounded,
                              onTap: () => _pickTime(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeField(
                              label: t.endTime,
                              value: _end.format(context),
                              icon: Icons.logout_rounded,
                              onTap: () => _pickTime(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t.weekdays,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: detoxWeightEmphasis),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final day in _weekdayShortLabels(t).indexed)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    left: day.$1 == 0 ? 0 : 4),
                                child: _DayToggle(
                                  label: day.$2,
                                  semanticLabel: _weekdayFullLabels(t)[day.$1],
                                  selected: _weekdays.contains(day.$1 + 1),
                                  onTap: () => setState(() {
                                    final value = day.$1 + 1;
                                    if (_weekdays.contains(value)) {
                                      _weekdays.remove(value);
                                    } else {
                                      _weekdays.add(value);
                                    }
                                  }),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _weekdays = {1, 2, 3, 4, 5}),
                            child: Text(t.isEs ? 'Lun a vie' : 'Mon to Fri'),
                          ),
                          TextButton(
                            onPressed: () => setState(
                                () => _weekdays = {1, 2, 3, 4, 5, 6, 7}),
                            child: Text(t.isEs ? 'Todos' : 'Every day'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ToggleRow(
                        title: t.strictModeLabel,
                        subtitle: _strictMode
                            ? t.hardModeGlobalSubtitle
                            : t.normalSchedulesBody,
                        value: _strictMode,
                        onChanged: (value) =>
                            setState(() => _strictMode = value),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: t.zoneAndSchedule,
                        subtitle: _onlyInsideZone
                            ? (t.isEs
                                ? 'Se activa solo dentro de tus zonas de concentración.'
                                : 'Only activates inside your concentration zones.')
                            : t.scheduleOnly,
                        value: _onlyInsideZone,
                        onChanged: (value) =>
                            setState(() => _onlyInsideZone = value),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t.chooseApps,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: detoxWeightEmphasis),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectableApps.isEmpty
                            ? (t.isEs
                                ? 'Sin apps disponibles.'
                                : 'No apps available.')
                            : (t.isEs
                                ? '${_packages.length} de ${selectableApps.length} seleccionadas.'
                                : '${_packages.length} of ${selectableApps.length} selected.'),
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 10),
                      if (selectableApps.isEmpty)
                        Text(
                          t.zoneAppsHelp,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                        )
                      else ...[
                        if (selectableApps.length > 8) ...[
                          TextField(
                            controller: _appSearch,
                            onChanged: (value) =>
                                setState(() => _appQuery = value),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: t.isEs ? 'Buscar app' : 'Search app',
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _packages
                                  .addAll(selectableApps
                                      .map((e) => e.packageName!))),
                              child: Text(
                                  t.isEs ? 'Seleccionar todas' : 'Select all'),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () => setState(_packages.clear),
                              child: Text(t.isEs ? 'Quitar todas' : 'Clear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _AppSelectionList(
                          apps: visibleApps,
                          selectedPackages: _packages,
                          onChanged: (package, value) => setState(() => value
                              ? _packages.add(package)
                              : _packages.remove(package)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_packages.isEmpty) ...[
                Text(
                  t.isEs
                      ? 'Selecciona al menos una app para guardar.'
                      : 'Select at least one app to save.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _packages.isEmpty ? null : _submit,
                child: Text(t.saveText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select listbox of the apps that can be blocked by a schedule.
class _AppSelectionList extends StatelessWidget {
  const _AppSelectionList({
    required this.apps,
    required this.selectedPackages,
    required this.onChanged,
  });

  final List<AppLimit> apps;
  final Set<String> selectedPackages;
  final void Function(String package, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final border =
        isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder;

    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          t.isEs
              ? 'Ninguna app coincide con la búsqueda.'
              : 'No app matches your search.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(detoxRadius),
        color: isDark ? DetoxColors.cardSubtle : DetoxColors.lightCardSubtle,
        border: Border.all(color: border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: apps.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, thickness: 1, color: border),
        itemBuilder: (context, index) {
          final app = apps[index];
          final package = app.packageName!;
          return CheckboxListTile(
            dense: true,
            value: selectedPackages.contains(package),
            onChanged: (value) => onChanged(package, value ?? false),
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            secondary: AppIconBadge(
              packageName: package,
              size: 34,
              borderRadius: 10,
            ),
            title: Text(
              app.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        },
      ),
    );
  }
}

/// Tappable time slot used for the schedule start and end.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(detoxRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(detoxRadius),
            color:
                isDark ? DetoxColors.cardSubtle : DetoxColors.lightCardSubtle,
            border: Border.all(
              color:
                  isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: muted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isDark ? DetoxColors.accent : DetoxColors.accentDeep,
                  ),
                  const SizedBox(width: 6),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single weekday selector cell with a 48 dp touch target.
class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final radius = BorderRadius.circular(detoxRadius);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: DetoxSpace.touch,
        child: Material(
          color: selected
              ? DetoxColors.accent.withOpacity(isDark ? 0.22 : 0.16)
              : (isDark ? DetoxColors.cardSubtle : DetoxColors.lightCardSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected
                  ? DetoxColors.accent.withOpacity(0.45)
                  : (isDark
                      ? DetoxColors.cardBorder
                      : DetoxColors.lightCardBorder),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? (isDark
                              ? DetoxColors.accentSoft
                              : DetoxColors.accentDeep)
                          : muted,
                      fontWeight: detoxWeightEmphasis,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered row with a title, a short explanation and a switch.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(detoxRadius),
        color: isDark ? DetoxColors.cardSubtle : DetoxColors.lightCardSubtle,
        border: Border.all(
          color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: title,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

List<String> _weekdayShortLabels(AppStrings t) => t.isEs
    ? const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
    : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<String> _weekdayFullLabels(AppStrings t) => t.isEs
    ? const [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ]
    : const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];

String _weekdaysLabel(List<int> weekdays, AppStrings t) {
  final sorted = weekdays.toList()..sort();
  if (sorted.isEmpty) return t.isEs ? 'Sin días' : 'No days';
  if (sorted.length == 7) return t.isEs ? 'Todos los días' : 'Every day';
  if (sorted.join(',') == '1,2,3,4,5') {
    return t.isEs ? 'Lun a vie' : 'Mon to Fri';
  }
  final labels = _weekdayShortLabels(t);
  return sorted
      .where((day) => day >= 1 && day <= 7)
      .map((day) => labels[day - 1])
      .join(' · ');
}

String _format(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final m = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
