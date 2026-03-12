import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detox_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final Future<void> Function(AuthUser) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();
  final _signUpName = TextEditingController();
  final _signUpEmail = TextEditingController();
  final _signUpPassword = TextEditingController();
  final _tab = ValueNotifier<int>(1);
  bool _busy = false;

  @override
  void dispose() {
    _signInEmail.dispose();
    _signInPassword.dispose();
    _signUpName.dispose();
    _signUpEmail.dispose();
    _signUpPassword.dispose();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_signInFormKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final user = await AuthService.instance.signInWithEmail(
        email: _signInEmail.text.trim(),
        password: _signInPassword.text,
      );
      if (!mounted) return;
      await widget.onAuthenticated(user);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final user = await AuthService.instance.signUpWithEmail(
        displayName: _signUpName.text.trim(),
        email: _signUpEmail.text.trim(),
        password: _signUpPassword.text,
      );
      if (!mounted) return;
      await widget.onAuthenticated(user);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      await widget.onAuthenticated(user);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPhoneSheet() async {
    final user = await showModalBottomSheet<AuthUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PhoneAuthSheet(),
    );
    if (user != null && mounted) {
      await widget.onAuthenticated(user);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? DetoxColors.text : DetoxColors.lightText;
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final t = AppStrings.of(context);
    return Scaffold(
      body: DetoxBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DetoxLogo(size: 84, showLabel: true),
                    const SizedBox(height: 18),
                    Text(
                      t.ownYourAttention,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.authSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: mutedColor, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _AuthIconButton(
                                icon: Icons.g_mobiledata_rounded,
                                label: 'G',
                                onTap: _busy ? null : _signInWithGoogle,
                              ),
                              const SizedBox(width: 14),
                              _AuthIconButton(
                                icon: Icons.phone_iphone_rounded,
                                label: '📱',
                                onTap: _busy ? null : _showPhoneSheet,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t.orUseEmail,
                            style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<int>(
                      valueListenable: _tab,
                      builder: (context, value, _) => Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SegmentButton(
                                label: t.signIn,
                                selected: value == 0,
                                onTap: () => _tab.value = 0,
                              ),
                            ),
                            Expanded(
                              child: _SegmentButton(
                                label: t.createAccount,
                                selected: value == 1,
                                onTap: () => _tab.value = 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<int>(
                      valueListenable: _tab,
                      builder: (context, value, _) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: value == 0 ? _buildSignInCard(textColor, mutedColor) : _buildSignUpCard(textColor, mutedColor),
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

  Widget _buildSignInCard(Color textColor, Color mutedColor) {
    final t = AppStrings.of(context);
    return GlassCard(
      key: const ValueKey('signin'),
      child: Form(
        key: _signInFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.welcomeBack, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(t.signInSubtitle, style: TextStyle(color: mutedColor)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _signInEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: t.email),
              validator: (value) => (value == null || !value.contains('@')) ? t.enterValidEmail : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signInPassword,
              obscureText: true,
              decoration: InputDecoration(labelText: t.password),
              validator: (value) => (value == null || value.length < 6) ? t.useSixChars : null,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login_rounded),
              label: Text(t.signIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpCard(Color textColor, Color mutedColor) {
    final t = AppStrings.of(context);
    return GlassCard(
      key: const ValueKey('signup'),
      child: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.createAccountTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(t.createAccountSubtitle, style: TextStyle(color: mutedColor)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _signUpName,
              decoration: InputDecoration(labelText: t.name),
              validator: (value) => (value == null || value.trim().length < 2) ? t.enterName : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signUpEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: t.email),
              validator: (value) => (value == null || !value.contains('@')) ? t.enterValidEmail : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signUpPassword,
              obscureText: true,
              decoration: InputDecoration(labelText: t.password),
              validator: (value) => (value == null || value.length < 6) ? t.useSixChars : null,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _signUp,
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(t.createAccount),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthIconButton extends StatelessWidget {
  const _AuthIconButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? DetoxColors.accent.withOpacity(isDark ? 0.28 : 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected
                ? (isDark ? DetoxColors.text : DetoxColors.lightText)
                : (isDark ? DetoxColors.muted : DetoxColors.lightMuted),
          ),
        ),
      ),
    );
  }
}

class _PhoneAuthSheet extends StatefulWidget {
  const _PhoneAuthSheet();

  @override
  State<_PhoneAuthSheet> createState() => _PhoneAuthSheetState();
}

class _PhoneAuthSheetState extends State<_PhoneAuthSheet> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _sending = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() => _sending = true);
    try {
      await AuthService.instance.startPhoneVerification(
        phoneNumber: _phoneController.text,
        onCodeSent: () {
          if (!mounted) return;
          setState(() => _codeSent = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).smsCodeSent)));
        },
        onVerified: (user) {
          if (!mounted) return;
          Navigator.pop(context, user);
        },
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _sending = true);
    try {
      final user = await AuthService.instance.verifySmsCode(_codeController.text);
      if (!mounted) return;
      Navigator.pop(context, user);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.phoneSignIn, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(t.phoneInstructions, style: TextStyle(color: DetoxColors.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t.phoneNumber),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.smsCode),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    child: Text(t.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _sending ? null : (_codeSent ? _verifyCode : _requestCode),
                    child: Text(_codeSent ? t.verifyCode : t.sendCode),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
