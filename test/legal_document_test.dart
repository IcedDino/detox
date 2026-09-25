import 'package:detox/screens/auth_screen.dart';
import 'package:detox/screens/legal_document_screen.dart';
import 'package:detox/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The legal documents are bundled as JSON and drawn with native widgets, so
/// reading them never sends the user to a browser.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child) => MaterialApp(
        theme: DetoxTheme.dark,
        home: child,
      );

  testWidgets('The privacy notice renders its whole content in the app',
      (tester) async {
    // The narrowest phone the layout has to survive.
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(const LegalDocumentScreen(document: LegalDocument.privacy)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Aviso de Privacidad'), findsWidgets);
    // The date line under the title, and only once: the paragraph the
    // generator repeats in the body has to be dropped.
    expect(find.textContaining('25 de septiembre de 2026'), findsOneWidget);
    expect(find.textContaining('Quién es el responsable'), findsOneWidget);
    // A table row: first cell as the heading, the rest as labelled values.
    expect(find.text('Nombre y correo electrónico'), findsOneWidget);

    // Naming, paragraphs, lists, tables, quotes, rules and headings all render,
    // so the last section of the document is reachable.
    await tester.scrollUntilVisible(find.text('16. Contacto'), 400);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('16. Contacto'), findsOneWidget);
  });

  testWidgets('The acceptance line opens the terms without leaving the app',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(AuthScreen(onAuthenticated: (_) async {})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsNothing);

    final link = find.text('Terms and Conditions');
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    // Still inside the app, with a back button to return to the form.
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Términos y Condiciones'), findsWidgets);
  });

  testWidgets('Both auth panels fit a small phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(AuthScreen(onAuthenticated: (_) async {})),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final switchLink = find.text('Create an account');
    await tester.ensureVisible(switchLink);
    await tester.pumpAndSettle();
    await tester.tap(switchLink);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('I have read and accept the'), findsOneWidget);
  });
}
