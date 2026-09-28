import 'package:detox/services/username_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rejects insults, slurs, reserved names and common obfuscations', () {
    for (final name in [
      'puto',
      'PuT0',
      'Juan_Put0',
      'p.u.t.o',
      'p3nd3jo',
      'PENDEJO123',
      'cabrón',
      'puuuto',
      'f_u_c_k123',
      'shit',
      'nigger',
      'admin123',
      'soporte',
      'nerqova',
      'p\u200buto',
      '....',
    ]) {
      expect(
        UsernamePolicy.validate(name, isEs: true),
        isNotNull,
        reason: name,
      );
    }
  });
  test('Allows ordinary aliases without substring false positives', () {
    for (final name in [
      'Donnet',
      'Ana_23',
      'María',
      'Luna.azul',
      'Paco-77',
      'computadora',
      'disputa',
      'reputacion',
      'Scunthorpe',
      'Dickinson',
    ]) {
      expect(UsernamePolicy.validate(name, isEs: true), isNull, reason: name);
    }
  });
  test('Validates size and characters', () {
    for (final name in [
      '',
      'ab',
      'a' * 31,
      'nombre con espacios',
      '<script>',
      '😀😀😀',
    ]) {
      expect(UsernamePolicy.validate(name, isEs: true), isNotNull);
    }
  });
}
