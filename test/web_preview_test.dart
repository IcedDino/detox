import 'package:detox/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('web preview navigates through the four main app tabs',
      (tester) async {
    await tester.pumpWidget(const DetoxWebPreviewApp());
    await tester.pump();

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Hoy'), findsOneWidget);

    await tester.tap(find.text('Enfoque').last);
    await tester.pumpAndSettle();
    expect(find.text('Temporizador de enfoque'), findsOneWidget);

    await tester.tap(find.text('Estadísticas').last);
    await tester.pumpAndSettle();
    expect(find.text('Tu racha'), findsOneWidget);

    await tester.tap(find.text('Configuración').last);
    await tester.pumpAndSettle();
    expect(find.text('Centro de padrino'), findsOneWidget);
  });

  testWidgets('sponsor preview opens without signing in', (tester) async {
    await tester.pumpWidget(const DetoxWebPreviewApp());
    await tester.pump();
    await tester.tap(find.text('Configuración').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centro de padrino'));
    await tester.pumpAndSettle();
    expect(find.text('Tu padrino'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });
}
