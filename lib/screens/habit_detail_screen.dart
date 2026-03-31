import 'dart:ui';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/habit.dart';

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;

  const HabitDetailScreen({
    super.key,
    required this.habit,
  });

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  static const Color bgColor    = Color(0xFF0A0A0C);
  static const Color accentBlue = Color(0xFF256AF4);
  static const Color textPrimary  = Colors.white;
  static const Color textMuted    = Color(0xFF64748B);

  // Build real completed-day set from habit data
  // Habit.completedToday tells us about today; streak tells us the run length.
  // We approximate the calendar by marking the last `streak` consecutive days as done.
  Set<int> _buildCompletedDays(DateTime now) {
    final completed = <int>{};
    if (widget.habit.streak <= 0) return completed;
    for (int i = 0; i < widget.habit.streak && i < now.day; i++) {
      completed.add(now.day - i);
    }
    if (widget.habit.completedToday) {
      completed.add(now.day);
    }
    return completed;
  }

  List<Map<String, dynamic>> _buildWeekRibbon(DateTime now, Set<int> completedDays) {
    // Find Monday of current week
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final ribbon = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final dayOffset = i - (weekday - 1);
      final date = now.add(Duration(days: dayOffset));
      final dayNum = date.day;
      final isToday = dayOffset == 0;
      final isCompleted = completedDays.contains(dayNum) && date.month == now.month;
      String state;
      if (isToday) {
        state = isCompleted ? 'completed' : 'today';
      } else if (isCompleted) {
        state = 'completed';
      } else {
        state = 'none';
      }
      ribbon.add({'dayNum': dayNum, 'state': state, 'date': date});
    }
    return ribbon;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final now = DateTime.now();
    final completedDays = _buildCompletedDays(now);
    final weekRibbon = _buildWeekRibbon(now, completedDays);
    final weekLabels = t.weekDayLabels; // localized

    // Month stats
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7; // 0=Sun

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.habitOverview,
          style: const TextStyle(
            color: textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.8),
                  radius: 0.8,
                  colors: [Color(0x26256AF4), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.8, 0.8),
                  radius: 0.6,
                  colors: [Color(0x1A256AF4), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  _buildTitle(t),
                  _buildWeekRibbonWidget(weekRibbon, weekLabels, now, t),
                  _buildMonthlyCalendar(now, daysInMonth, firstWeekday, completedDays, weekLabels, t),
                  _buildStats(t, now),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(AppStrings t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Text(
            widget.habit.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
              shadows: [Shadow(color: Color(0x99256AF4), blurRadius: 15)],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.track_changes, color: accentBlue, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.habit.targetDescription,
                  style: const TextStyle(color: accentBlue, fontWeight: FontWeight.w600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekRibbonWidget(
      List<Map<String, dynamic>> ribbon,
      List<String> weekLabels,
      DateTime now,
      AppStrings t,
      ) {
    final monthName = _monthName(now.month, t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.thisWeek, style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(monthName, style: const TextStyle(color: textMuted, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ribbon.asMap().entries.map((e) {
              final i = e.key;
              final d = e.value;
              final label = weekLabels[i == 6 ? 6 : i]; // Mon=0..Sun=6
              return _weekDayItem(d, label);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _weekDayItem(Map<String, dynamic> d, String dayLabel) {
    final state = d['state'] as String;
    final dayNum = d['dayNum'] as int;
    final isToday     = state == 'today';
    final isCompleted = state == 'completed';

    return Column(
      children: [
        Text(dayLabel, style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isToday || isCompleted) ? accentBlue : Colors.white.withOpacity(0.06),
            boxShadow: (isToday || isCompleted)
                ? [BoxShadow(color: accentBlue.withOpacity(0.5), blurRadius: 15)]
                : null,
            border: isToday && !isCompleted
                ? Border.all(color: accentBlue.withOpacity(0.6), width: 2)
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
              '$dayNum',
              style: TextStyle(
                color: isToday ? Colors.white : textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyCalendar(
      DateTime now,
      int daysInMonth,
      int firstWeekday,
      Set<int> completedDays,
      List<String> weekLabels,
      AppStrings t,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _glass(
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_monthName(now.month, t),
                style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: weekLabels
                  .map((l) => Expanded(
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            _buildCalendarGrid(now, daysInMonth, firstWeekday, completedDays),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime now, int daysInMonth, int startOffset, Set<int> completedDays) {
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNumber = index - startOffset + 1;
        final isEmpty = dayNumber < 1 || dayNumber > daysInMonth;
        if (isEmpty) {
          return _calendarCell(completed: false, isToday: false, opacity: 0.0);
        }
        return _calendarCell(
          completed: completedDays.contains(dayNumber),
          isToday: dayNumber == now.day,
        );
      },
    );
  }

  Widget _calendarCell({required bool completed, required bool isToday, double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: isToday
          ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.transparent,
          border: Border.all(color: accentBlue.withOpacity(0.6), width: 2),
        ),
      )
          : completed
          ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            colors: [accentBlue, Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      )
          : _glass(
        borderRadius: 4,
        padding: EdgeInsets.zero,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildStats(AppStrings t, DateTime now) {
    // Calculate real completion rate for current month
    final totalDays = now.day;
    final completedCount = _buildCompletedDays(now).length;
    final completionRate = totalDays > 0 ? (completedCount / totalDays * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: _glass(
              borderRadius: 16,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                    SizedBox(width: 6),
                    Text('STREAK', style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    t.streakDaysLabel(widget.habit.streak),
                    style: const TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.habit.completedToday ? t.completedToday : t.notCompletedToday,
                    style: const TextStyle(color: textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _glass(
              borderRadius: 16,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.task_alt, color: accentBlue, size: 18),
                    SizedBox(width: 6),
                    Text('TOTAL', style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '$completionRate%',
                    style: const TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(t.completionThisMonth, style: const TextStyle(color: textMuted, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month, AppStrings t) => t.monthName(month);

  Widget _glass({required Widget child, required double borderRadius, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}