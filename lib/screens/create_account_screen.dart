import 'package:flutter/material.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Collected data
  String _name = '';
  int _age = 18;
  final List<String> _selectedGoals = [];
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Colors
  static const Color bgColor = Color(0xFF0D1B2A);
  static const Color cardColor = Color(0xFF1A2535);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8A9BB0);

  final List<Map<String, dynamic>> _goals = [
    {'label': 'Reduce screen time', 'icon': Icons.phone_android},
    {'label': 'Improve sleep',       'icon': Icons.bedtime},
    {'label': 'Be more focused',     'icon': Icons.center_focus_strong},
    {'label': 'Spend less time on social media', 'icon': Icons.thumb_down_alt},
  ];

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  void _submit() {
    // TODO: hook up to Firebase Auth + Firestore
    debugPrint('Name: $_name');
    debugPrint('Age: $_age');
    debugPrint('Goals: $_selectedGoals');
    debugPrint('Email: ${_emailController.text}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Glowing background ──────────────────────
            Positioned(
              top: -100,
              left: -80,
              child: _glowCircle(350, const Color(0x554A90E2)),
            ),
            Positioned(
              bottom: 100,
              right: -80,
              child: _glowCircle(300, const Color(0x334A90E2)),
            ),
            // ────────────────────────────────────────────

            Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 8),
                _buildProgressBar(),
                const SizedBox(height: 32),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildNamePage(),
                      _buildAgePage(),
                      _buildGoalsPage(),
                      _buildAccountPage(),
                    ],
                  ),
                ),
                _buildNavButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Glow circle helper ───────────────────────────────────
  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, const Color(0x00000000)],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    final titles = [
      "What's your name?",
      "How old are you?",
      "What are your goals?",
      "Create your account",
    ];
    final subtitles = [
      "Let's get to know you",
      "We'll personalize your experience",
      "Choose everything that applies to you",
      "You're almost there",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          if (_currentPage > 0)
            GestureDetector(
              onTap: _prevPage,
              child: const Icon(Icons.arrow_back_ios,
                  color: textSecondary, size: 20),
            ),
          if (_currentPage > 0) const SizedBox(height: 12),
          Text(
            titles[_currentPage],
            style: const TextStyle(
              color: textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitles[_currentPage],
            style: const TextStyle(color: textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: List.generate(4, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              height: 4,
              decoration: BoxDecoration(
                color: i <= _currentPage ? accentBlue : cardColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Page 1: Name ─────────────────────────────────────────
  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _textField(
            hint: 'Your first name',
            icon: Icons.person_outline,
            onChanged: (v) => _name = v,
          ),
        ],
      ),
    );
  }

  // ── Page 2: Age ──────────────────────────────────────────
  Widget _buildAgePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    if (_age > 10) setState(() => _age--);
                  },
                  icon: const Icon(Icons.remove, color: textPrimary),
                ),
                Text(
                  '$_age',
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_age < 100) setState(() => _age++);
                  },
                  icon: const Icon(Icons.add, color: textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Use + and − to set your age',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Page 3: Goals ────────────────────────────────────────
  Widget _buildGoalsPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ..._goals.map((goal) {
            final selected = _selectedGoals.contains(goal['label']);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedGoals.remove(goal['label']);
                  } else {
                    _selectedGoals.add(goal['label'] as String);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: selected ? accentBlue.withOpacity(0.15) : cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? accentBlue : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      goal['icon'] as IconData,
                      color: selected ? accentBlue : textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      goal['label'] as String,
                      style: TextStyle(
                        color: selected ? textPrimary : textSecondary,
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: accentBlue, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Page 4: Account ──────────────────────────────────────
  Widget _buildAccountPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _textField(
            hint: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
          ),
          const SizedBox(height: 14),
          _textField(
            hint: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            controller: _passwordController,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'By creating an account you agree to our Terms of Service and Privacy Policy.',
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Nav buttons ──────────────────────────────────────────
  Widget _buildNavButtons() {
    final isLast = _currentPage == 3;
    final canProceed = _canProceed();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: canProceed ? (isLast ? _submit : _nextPage) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentBlue,
            disabledBackgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            isLast ? 'Create Account' : 'Continue',
            style: const TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ── Validation ───────────────────────────────────────────
  bool _canProceed() {
    switch (_currentPage) {
      case 0: return _name.trim().isNotEmpty;
      case 1: return _age >= 10 && _age <= 100;
      case 2: return _selectedGoals.isNotEmpty;
      case 3:
        return _emailController.text.contains('@') &&
            _passwordController.text.length >= 6;
      default: return false;
    }
  }

  // ── Reusable text field ──────────────────────────────────
  Widget _textField({
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
    Widget? suffixIcon,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textSecondary),
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
      ),
    );
  }
}