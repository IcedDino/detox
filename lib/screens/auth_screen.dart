import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/auth_user.dart';
import '../screens/legal_document_screen.dart';
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
  bool _obscurePassword = true;

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
              padding: const EdgeInsets.fromLTRB(
                DetoxSpace.section,
                28,
                DetoxSpace.section,
                28,
              ),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 56),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Brand statement, quiet and centered ──
                        const Center(
                          child: DetoxLogo(size: 64, showLabel: true),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          t.ownYourAttention,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium,
                        ),
                        const SizedBox(height: 30),
                        // ── One surface holds the whole sign-in flow ──
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable: _tab,
                                builder: (context, value, _) =>
                                    AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: KeyedSubtree(
                                    key: ValueKey<int>(value),
                                    child: value == 0
                                        ? _buildSignInPanel(mutedColor)
                                        : _buildSignUpPanel(mutedColor),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Short on purpose: the label sits between two
                              // rules and must survive narrow screens.
                              _DividerLabel(label: t.orContinueWith),
                              const SizedBox(height: 16),
                              // Stacked, not side by side: at 320 dp two buttons
                              // in a row cannot hold "Continuar con teléfono".
                              _SecondaryAuthButton(
                                icon: Icons.g_mobiledata_rounded,
                                label: t.continueWithGoogle,
                                onTap: _busy ? null : _signInWithGoogle,
                              ),
                              const SizedBox(height: 10),
                              _SecondaryAuthButton(
                                icon: Icons.phone_iphone_rounded,
                                label: t.continueWithPhone,
                                onTap: _busy ? null : _showPhoneSheet,
                              ),
                              const SizedBox(height: 18),
                              _LegalAcceptance(mutedColor: mutedColor),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<int>(
                          valueListenable: _tab,
                          builder: (context, value, _) => _AuthSwitchLink(
                            prompt: value == 0
                                ? t.noAccountYet
                                : t.alreadyHaveAccount,
                            action: value == 0
                                ? t.switchToSignUp
                                : t.switchToSignIn,
                            onTap: () => _tab.value = value == 0 ? 1 : 0,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            t.developedBy,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: mutedColor,
                              letterSpacing: 0.2,
                            ),
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
    final theme = Theme.of(context);
    return Form(
      key: _signInFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.welcomeBack, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              t.signInSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _signInEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email
              ],
              decoration: InputDecoration(
                labelText: t.email,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) => (value == null || !value.contains('@'))
                  ? t.enterValidEmail
                  : null,
            ),
            const SizedBox(height: DetoxSpace.item),
            TextFormField(
              controller: _signInPassword,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: t.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: _passwordToggle(mutedColor),
              ),
              validator: (value) =>
                  (value == null || value.length < 6) ? t.useSixChars : null,
              onFieldSubmitted: (_) {
                if (!_busy) _signIn();
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _signIn,
              child: _busy ? const _ButtonSpinner() : Text(t.signIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpPanel(Color mutedColor) {
    final t = AppStrings.of(context);
    final theme = Theme.of(context);
    return Form(
      key: _signUpFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.createAccountTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              t.createAccountSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _signUpName,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: t.name,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value == null || value.trim().length < 2)
                  ? t.enterName
                  : null,
            ),
            const SizedBox(height: DetoxSpace.item),
            TextFormField(
              controller: _signUpEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email
              ],
              decoration: InputDecoration(
                labelText: t.email,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) => (value == null || !value.contains('@'))
                  ? t.enterValidEmail
                  : null,
            ),
            const SizedBox(height: DetoxSpace.item),
            TextFormField(
              controller: _signUpPassword,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: t.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: _passwordToggle(mutedColor),
              ),
              validator: (value) =>
                  (value == null || value.length < 6) ? t.useSixChars : null,
              onFieldSubmitted: (_) {
                if (!_busy) _signUp();
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _signUp,
              child: _busy ? const _ButtonSpinner() : Text(t.createAccount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordToggle(Color mutedColor) {
    final t = AppStrings.of(context);
    return IconButton(
      tooltip: _obscurePassword ? t.showPassword : t.hidePassword,
      color: mutedColor,
      iconSize: 20,
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2.2),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder;
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
              fontWeight: FontWeight.w500,
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
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}

/// Switch between signing in and creating an account, inline and quiet.
class _AuthSwitchLink extends StatelessWidget {
  const _AuthSwitchLink({
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final accent = isDark ? DetoxColors.accent : DetoxColors.accentDeep;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(prompt, style: TextStyle(color: muted, fontSize: 14)),
        InkWell(
          borderRadius: BorderRadius.circular(detoxRadius),
          onTap: onTap,
          child: Text(
            action,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: detoxWeightEmphasis,
              decoration: TextDecoration.underline,
              decorationColor: accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// Acceptance line shown under the form: the documents open inside the app.
class _LegalAcceptance extends StatelessWidget {
  const _LegalAcceptance({required this.mutedColor});

  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final base = TextStyle(
      color: mutedColor,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 3,
      children: [
        Text(t.legalAcceptance, style: base),
        _LegalLink(label: t.legalTerms, document: LegalDocument.terms),
        Text(t.legalJoin, style: base),
        _LegalLink(label: t.legalPrivacy, document: LegalDocument.privacy),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.document});

  final String label;
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DetoxColors.accent : DetoxColors.accentDeep;

    return InkWell(
      borderRadius: BorderRadius.circular(detoxRadius),
      onTap: () => LegalDocumentScreen.open(context, document),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: detoxWeightEmphasis,
          height: 1.45,
          decoration: TextDecoration.underline,
          decorationColor: accent,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _sending = true);
    try {
      final user =
          await AuthService.instance.verifySmsCode(_codeController.text);
      if (!mounted) return;
      Navigator.pop(context, user);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.phoneSignIn, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              t.phoneInstructions,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t.phoneNumber,
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: DetoxSpace.item),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.smsCode,
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed:
                  _sending ? null : (_codeSent ? _verifyCode : _requestCode),
              child: Text(_codeSent ? t.verifyCode : t.sendCode),
            ),
            const SizedBox(height: DetoxSpace.item),
            TextButton(
              onPressed: _sending ? null : () => Navigator.pop(context),
              child: Text(t.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
