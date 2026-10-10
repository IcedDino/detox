import 'package:detox/main.dart';
import 'package:detox/screens/sponsor_screen.dart';
import 'package:detox/screens/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('web preview navigates through the four main app tabs',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DetoxWebPreviewApp());
    await tester.pump();

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Hoy'), findsOneWidget);

    await tester.tap(find.text('Enfoque').last);
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('Estadísticas').last);
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.text('Vista demo'), findsOneWidget);

    await tester.tap(find.text('Configuración').last);
    await tester.pumpAndSettle();
    expect(find.text('Centro de padrino'), findsOneWidget);
  });

  testWidgets('sponsor preview opens without signing in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DetoxWebPreviewApp());
    await tester.pump();
    await tester.tap(find.text('Configuración').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centro de padrino'));
    await tester.pumpAndSettle();
    expect(find.byType(SponsorScreen), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('desktop preview opens every secondary screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DetoxWebPreviewApp());
    await tester.pump();

    const titles = [
      'Centro de padrino',
      'Protección activa',
      'Horarios de Detox',
      'Acceso al tiempo de uso',
      'Bienvenida / acceso',
      'Nombre anónimo',
      'Crear cuenta',
      'Términos y condiciones',
      'Aviso de privacidad',
    ];

    for (var index = 4; index <= 12; index++) {
      tester
          .widget<PopupMenuButton<int>>(find.byType(PopupMenuButton<int>))
          .onSelected!(index);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull,
          reason: 'Screen $index should render in the desktop preview.');
      expect(find.text(titles[index - 4]), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    }
  });
}
