import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../services/username_policy.dart';

class UsernameDialog extends StatefulWidget {
  const UsernameDialog({super.key, this.initialValue = ''});
  final String initialValue;
  @override
  State<UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<UsernameDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return AlertDialog(
      title: const Text('Username'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Username',
            counterText: '',
          ),
          validator: (value) => UsernamePolicy.validate(value, isEs: t.isEs),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.isEs ? 'Cancelar' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (_form.currentState!.validate()) Navigator.pop(context, value);
          },
          child: Text(t.isEs ? 'Guardar' : 'Save'),
        ),
      ],
    );
  }
}
