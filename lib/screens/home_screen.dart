import 'dart:math';
import 'dart:ui';

import 'package:detox/models/habit.dart';
import 'package:detox/screens/habit_detail_screen.dart';
import 'package:detox/services/storage_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final StorageService _storageService = StorageService();
  List<Habit> _habits = [];

  static const Color bgColor = Color(0xFF0A1120);
  static const Color accentBlue = Color(0xFF256AF4);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    try {
      final habits = await _storageService.loadHabits();
      if (!mounted) return;
      setState(() {
        _habits = habits;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _habits = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: _glowBlob(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.5,
            ),
          ),
          Positioned(
            bottom: 80,
            right: -80,
            child: _glowBlob(
              width: MediaQuery.of(context).size.width * 0.65,
              height: MediaQuery.of(context).size.height * 0.4,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildScreenTimeCard(),
                        const SizedBox(height: 16),
                        _buildFocusButton(),
                        if (_habits.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildHabitProgress(),
                        ],
                        const SizedBox(height: 16),
                        _buildWeeklyInsight(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        color: accentBlue.withOpacity(0.25),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildHeader() {
    final totalStreak = _habits.isEmpty
        ? 0
        : _habits.fold<int>(0, (sum, habit) => sum + habit.streak);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'WELCOME BACK',
              style: TextStyle(
                color: textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Alex Johnson',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Spacer(),
        _glassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          borderRadius: 999,
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '$totalStreak',
                style: const TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _glassContainer(
          padding: const EdgeInsets.all(10),
          borderRadius: 999,
          child: const Icon(
            Icons.notifications_outlined,
            color: textPrimary,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTimeCard() {
    return _glassContainer(
      padding: const EdgeInsets.all(32),
      borderRadius: 32,
      child: Column(
        children: [
          const Text(
            'DAILY SCREEN TIME',
            style: TextStyle(
              color: textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _RingPainter(progress: 0.74),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '3h 42m',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.trending_down,
                          color: Color(0xFF34D399),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '15% vs yesterday',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _statBox(label: 'LIMIT', value: '5h 00m')),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(label: 'TOP APP', value: 'Social Media'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_filled,
                  color: textPrimary,
                  size: 26,
                ),
                SizedBox(width: 10),
                Text(
                  'Start Focus Session',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitProgress() {
    final visibleHabits = _habits.take(4).toList();

    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Habit Progress',
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              'View all',
              style: TextStyle(
                color: accentBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: visibleHabits.asMap().entries.map((entry) {
            final index = entry.key;
            final habit = entry.value;

            return Expanded(
              child: Padding(
                padding: index < visibleHabits.length - 1
                    ? const EdgeInsets.only(right: 12)
                    : EdgeInsets.zero,
                child: _buildHabitCard(habit),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHabitCard(Habit habit) {
    final isActive = habit.completedToday;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habit: habit),
        ),
      ),
      child: _glassContainer(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        borderRadius: 24,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? accentBlue.withOpacity(0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: isActive ? accentBlue : textMuted.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                isActive
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                color: isActive ? accentBlue : textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              habit.title,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Racha: ${habit.streak}',
              style: const TextStyle(
                color: textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyInsight() {
    return _glassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: accentBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Insight',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "You've decreased evening screen time by 20% this week. Keep it up!",
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.grid_view_rounded, 'label': 'Dashboard'},
      {'icon': Icons.check_circle_outline, 'label': 'Habits'},
      {'icon': Icons.timer_outlined, 'label': 'Focus'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (i) {
          final selected = i == _selectedIndex;

          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  items[i]['icon'] as IconData,
                  color: selected ? accentBlue : textMuted,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  items[i]['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: selected ? accentBlue : textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _glassContainer({
    required Widget child,
    required double borderRadius,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;
    const strokeWidth = 14.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = const Color(0xFF256AF4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}