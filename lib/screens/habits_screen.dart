import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/habit.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final StorageService _storageService = StorageService();
  List<Habit> _habits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final habits = await _storageService.loadHabits();
    setState(() {
      _habits = habits;
      _loading = false;
    });
  }

  Future<void> _save() => _storageService.saveHabits(_habits);

  Future<void> _addHabit() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final t = AppStrings.of(context);

    final created = await showDialog<Habit>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DetoxColors.card,
        title: Text(t.addHabit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: t.habitName),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: t.target),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final desc = descController.text.trim();
              if (title.isEmpty || desc.isEmpty) return;
              Navigator.pop(
                context,
                Habit(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  targetDescription: desc,
                ),
              );
            },
            child: Text(t.addHabit),
          ),
        ],
      ),
    );

    if (created != null) {
      setState(() => _habits.add(created));
      await _save();
    }
  }

  // Tracks which habit IDs had their streak incremented this session,
  // preventing multiple increments if the user toggles on/off/on the same day.
  final Set<String> _streakIncrementedToday = {};

  Future<void> _toggleHabit(Habit habit, bool value) async {
    setState(() {
      final wasCompleted = habit.completedToday;
      habit.completedToday = value;

      if (value && !wasCompleted) {
        // Only increment streak once per session (guards re-taps on same day)
        if (!_streakIncrementedToday.contains(habit.id)) {
          habit.streak += 1;
          _streakIncrementedToday.add(habit.id);
        }
      } else if (!value && wasCompleted) {
        // Undo the streak increment only if we added it this session
        if (_streakIncrementedToday.contains(habit.id)) {
          habit.streak = habit.streak > 0 ? habit.streak - 1 : 0;
          _streakIncrementedToday.remove(habit.id);
        }
      }
    });
    await _save();
  }

  Future<void> _deleteHabit(Habit habit) async {
    setState(() => _habits.removeWhere((element) => element.id == habit.id));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final completed = _habits.where((e) => e.completedToday).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t.habitsTitle,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(t.completedTodayText(completed, _habits.length), style: const TextStyle(color: DetoxColors.muted)),
          const SizedBox(height: 18),
          ..._habits.map(
                (habit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: habit.completedToday,
                  onChanged: (value) => _toggleHabit(habit, value ?? false),
                  title: Text(habit.title),
                  subtitle: Text(
                    '${habit.targetDescription} • ${t.streakText(habit.streak)}',
                    style: const TextStyle(color: DetoxColors.muted),
                  ),
                  secondary: IconButton(
                    onPressed: () => _deleteHabit(habit),
                    icon: const Icon(Icons.delete_outline, color: DetoxColors.muted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHabit,
        icon: const Icon(Icons.add),
        label: Text(t.addHabit),
      ),
    );
  }
}