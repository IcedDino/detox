import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../theme/app_theme.dart';

/// Asks for an optional note that travels with a sponsor request.
///
/// Returns the trimmed text, an empty string when the user continues without
/// writing anything, or null when the dialog is dismissed (nothing is sent).
Future<String?> showMessagePrompt(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  bool isDestructive = false,
}) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      final t = AppStrings.of(context);
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(detoxRadius),
        ),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: t.messageOptional,
            hintText: hint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: DetoxColors.danger)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return result;
}
