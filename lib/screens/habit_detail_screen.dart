import 'dart:ui';
import 'package:flutter/material.dart';

class HabitDetailScreen extends StatefulWidget {
  final String habitName;
  final String frequency;
  final IconData icon;

  const HabitDetailScreen({
    super.key,
    required this.habitName,
    required this.frequency,
    required this.icon,
  });

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  static const Color bgColor    = Color(0xFF0A0A0C);
  static const Color accentBlue = Color(0xFF256AF4);
  static const Color textPrimary  = Colors.white;
  static const Color textMuted    = Color(0xFF64748B);

  // Mock data — replace with real data from Firestore later
  final Set<int> _completedDays = {4, 5, 7, 8, 10, 11, 12, 13, 15, 16, 17, 19, 22, 23};
  final int _todayDay = 16;
  final int _currentMonth = 10; // October
  final int _firstWeekdayOfMonth = 2; // October 1 = Tuesday (0=Sun,1=Mon,2=Tue...)

  final List<String> _weekDays  = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final List<String> _weekDayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  // Week ribbon: show current week (days 13-19 for this mock)
  final List<Map<String, dynamic>> _weekRibbon = [
    {'day': 'Mon', 'date': 13, 'state': 'completed'},
    {'day': 'Tue', 'date': 14, 'state': 'today'},
    {'day': 'Wed', 'date': 15, 'state': 'dot'},
    {'day': 'Thu', 'date': 16, 'state': 'none'},
    {'day': 'Fri', 'date': 17, 'state': 'partial'},
    {'day': 'Sat', 'date': 18, 'state': 'none'},
    {'day': 'Sun', 'date': 19, 'state': 'none'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── Atmospheric glows ──────────────────────
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
          // ──────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      children: [
                        _buildTopNav(context),
                        _buildTitle(),
                        _buildWeekRibbon(),
                        _buildMonthlyCalendar(),
                        _buildStats(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Floating bottom nav ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  // ── Top nav ────────────────────────────────────────────
  Widget _buildTopNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _glassCircleButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(context),
          ),
          const Text(
            'OVERVIEW',
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          _glassCircleButton(icon: Icons.more_horiz, onTap: () {}),
        ],
      ),
    );
  }

  Widget _glassCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: _glass(
        borderRadius: 999,
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: textPrimary, size: 20),
      ),
    );
  }

  // ── Title ──────────────────────────────────────────────
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Text(
            widget.habitName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
              shadows: [
                Shadow(
                  color: Color(0x99256AF4),
                  blurRadius: 15,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, color: accentBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                widget.frequency,
                style: const TextStyle(
                  color: accentBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Week ribbon ────────────────────────────────────────
  Widget _buildWeekRibbon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('This Week',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('October',
                  style: TextStyle(color: textMuted, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weekRibbon.map((d) => _weekDayItem(d)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _weekDayItem(Map<String, dynamic> d) {
    final state = d['state'] as String;
    final isToday    = state == 'today';
    final isCompleted = state == 'completed';
    final isPartial  = state == 'partial';
    final hasDot     = state == 'dot';

    return Column(
      children: [
        Text(
          d['day'] as String,
          style: const TextStyle(
              color: textMuted, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Circle
            isToday || isCompleted
                ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBlue,
                boxShadow: [
                  BoxShadow(
                    color: accentBlue.withOpacity(0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${d['date']}',
                  style: const TextStyle(
                      color: textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            )
                : isPartial
                ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBlue.withOpacity(0.2),
                border: Border.all(
                    color: accentBlue.withOpacity(0.3), width: 1),
              ),
              child: Center(
                child: Text(
                  '${d['date']}',
                  style: const TextStyle(
                      color: accentBlue, fontWeight: FontWeight.bold),
                ),
              ),
            )
                : _glass(
              borderRadius: 999,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Text(
                    '${d['date']}',
                    style: const TextStyle(color: textPrimary),
                  ),
                ),
              ),
            ),
            // Dot indicator
            if (hasDot)
              Positioned(
                bottom: -6,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentBlue,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Monthly calendar ───────────────────────────────────
  Widget _buildMonthlyCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _glass(
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('October Progress',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Icon(Icons.chevron_left, color: textMuted),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: textMuted),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Day labels
            Row(
              children: _weekDayLabels
                  .map((l) => Expanded(
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),

            // Calendar grid
            _buildCalendarGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    const int daysInMonth = 31;
    final int startOffset = _firstWeekdayOfMonth; // 2 = Tuesday
    final int totalCells = startOffset + daysInMonth;
    final int rows = (totalCells / 7).ceil();

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
        final isCompleted = _completedDays.contains(dayNumber);
        final isToday = dayNumber == _todayDay;

        if (isEmpty) {
          return _calendarCell(
            completed: false,
            isToday: false,
            opacity: 0.15,
          );
        }

        return _calendarCell(
          completed: isCompleted,
          isToday: isToday,
        );
      },
    );
  }

  Widget _calendarCell({
    required bool completed,
    required bool isToday,
    double opacity = 1.0,
  }) {
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

  // ── Stats ──────────────────────────────────────────────
  Widget _buildStats() {
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
                  Row(
                    children: const [
                      Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 6),
                      Text('STREAK',
                          style: TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('12 Days',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Personal best: 24',
                      style: TextStyle(color: textMuted, fontSize: 10)),
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
                  Row(
                    children: const [
                      Icon(Icons.task_alt, color: accentBlue, size: 18),
                      SizedBox(width: 6),
                      Text('TOTAL',
                          style: TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('142',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Completed this year',
                      style: TextStyle(color: textMuted, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Floating bottom nav ────────────────────────────────
  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: _glass(
        borderRadius: 999,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(icon: Icons.home_outlined, label: 'Home', active: false),
            _navItem(icon: Icons.check_circle, label: 'Habits', active: true),
            // FAB in the middle
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentBlue,
                  boxShadow: [
                    BoxShadow(
                      color: accentBlue.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: textPrimary, size: 28),
              ),
            ),
            _navItem(icon: Icons.bar_chart_outlined, label: 'Stats', active: false),
            _navItem(icon: Icons.person_outline, label: 'Profile', active: false),
          ],
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required bool active}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? accentBlue : textMuted, size: 24),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: active ? accentBlue : textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Glass helper ───────────────────────────────────────
  Widget _glass({
    required Widget child,
    required double borderRadius,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
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