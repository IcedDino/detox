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
  final _tab = ValueNotifier<int>(0);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final t = AppStrings.of(context);
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Scaffold(
      body: DetoxBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AuthHeader(
                          title: 'Detox',
                          subtitle: t.useEmailFirst,
                        ),
                        const SizedBox(height: 24),
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable: _tab,
                                builder: (context, value, _) => Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.045)
                                        : Colors.white.withOpacity(0.82),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isDark
                                          ? DetoxColors.cardBorder
                                          : DetoxColors.lightCardBorder,
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
                              const SizedBox(height: 22),
                              ValueListenableBuilder<int>(
                                valueListenable: _tab,
                                builder: (context, value, _) => AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: value == 0
                                      ? _buildSignInPanel(mutedColor)
                                      : _buildSignUpPanel(mutedColor),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _DividerLabel(label: t.otherWaysToContinue),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SecondaryAuthButton(
                                      icon: Icons.g_mobiledata_rounded,
                                      label: 'Google',
                                      onTap: _busy ? null : _signInWithGoogle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SecondaryAuthButton(
                                      icon: Icons.phone_iphone_rounded,
                                      label: t.phoneSignIn,
                                      onTap: _busy ? null : _showPhoneSheet,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPanel(Color mutedColor) {
    final t = AppStrings.of(context);
    return Form(
      key: _signInFormKey,
      child: AutofillGroup(
        key: const ValueKey('signin'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.welcomeBack,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(t.signInSubtitle, style: TextStyle(color: mutedColor, height: 1.35)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _signInEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: InputDecoration(
                labelText: t.email,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) => (value == null || !value.contains('@')) ? t.enterValidEmail : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signInPassword,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: t.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) => (value == null || value.length < 6) ? t.useSixChars : null,
              onFieldSubmitted: (_) {
                if (!_busy) _signIn();
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _signIn,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(t.signIn),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _tab.value = 1,
                child: Text('${t.noAccountYet} ${t.createAccount}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpPanel(Color mutedColor) {
    final t = AppStrings.of(context);
    return Form(
      key: _signUpFormKey,
      child: AutofillGroup(
        key: const ValueKey('signup'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.createAccountTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(t.createAccountSubtitle, style: TextStyle(color: mutedColor, height: 1.35)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _signUpName,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: t.name,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value == null || value.trim().length < 2) ? t.enterName : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signUpEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: InputDecoration(
                labelText: t.email,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) => (value == null || !value.contains('@')) ? t.enterValidEmail : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signUpPassword,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: t.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) => (value == null || value.length < 6) ? t.useSixChars : null,
              onFieldSubmitted: (_) {
                if (!_busy) _signUp();
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _signUp,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(t.createAccount),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _tab.value = 0,
                child: Text('${t.alreadyHaveAccount} ${t.signIn}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Row(
      children: [
        const DetoxLogo(size: 44),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder;
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Row(
      children: [
        Expanded(child: Divider(color: borderColor, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: borderColor, height: 1)),
      ],
    );
  }
}

class _SecondaryAuthButton extends StatelessWidget {
  const _SecondaryAuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        side: BorderSide(
          color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? DetoxColors.accent.withOpacity(isDark ? 0.26 : 0.12)
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).smsCodeSent)),
          );
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
            Text(
              t.phoneSignIn,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Text(t.phoneInstructions, style: const TextStyle(color: DetoxColors.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t.phoneNumber,
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.smsCode,
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                ),
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
