import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/username_policy.dart';
import '../theme/app_theme.dart';

class AnonymousUsernameScreen extends StatefulWidget {
  const AnonymousUsernameScreen({super.key, required this.onAuthenticated});
  final Future<void> Function(AuthUser) onAuthenticated;
  @override
  State<AnonymousUsernameScreen> createState() =>
      _AnonymousUsernameScreenState();
}

class _AnonymousUsernameScreenState extends State<AnonymousUsernameScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await AuthService.instance.continueAnonymously(
        _username.text,
      );
      if (!mounted) return;
      final onAuthenticated = widget.onAuthenticated;
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop();
      await onAuthenticated(user);
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = e is AuthException
              ? e.message
              : AppStrings.of(context).authFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: DetoxBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.isEs ? 'Elige tu username' : 'Choose your username',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _username,
                          autofocus: true,
                          enabled: !_busy,
                          maxLength: 30,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            counterText: '',
                          ),
                          validator: (value) =>
                              UsernamePolicy.validate(value, isEs: t.isEs),
                          onFieldSubmitted: (_) => _continue(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _continue,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(t.isEs ? 'Continuar' : 'Continue'),
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
}
