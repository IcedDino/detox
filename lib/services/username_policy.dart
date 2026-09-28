/// Shared by creation and editing so changing screens cannot skip validation.
class UsernamePolicy {
  static final _characters = RegExp(r'^[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ0-9_.-]+$');
  static const _blocked = <String>[
    'puta',
    'puto',
    'putas',
    'putos',
    'putita',
    'putito',
    'putazo',
    'mierda',
    'mierdas',
    'cabron',
    'cabrona',
    'cabrones',
    'pendejo',
    'pendeja',
    'pendejos',
    'pendejas',
    'chingar',
    'chingado',
    'chingada',
    'chingados',
    'chingadas',
    'chingatumadre',
    'chinga',
    'chingas',
    'verga',
    'vergas',
    'vergazo',
    'culero',
    'culera',
    'culo',
    'culos',
    'mamon',
    'mamona',
    'mamones',
    'pinche',
    'pinches',
    'joder',
    'jodete',
    'gilipollas',
    'cojones',
    'coño',
    'maricon',
    'maricones',
    'marica',
    'zorra',
    'zorras',
    'bastardo',
    'bastarda',
    'hijodeputa',
    'hdp',
    'fuck',
    'fucker',
    'fucking',
    'motherfucker',
    'shit',
    'shithead',
    'bitch',
    'bitches',
    'asshole',
    'cunt',
    'dick',
    'cock',
    'pussy',
    'nigger',
    'nigga',
    'faggot',
    'fag',
    'slut',
    'whore',
    'nazi',
    'hitler',
    'porn',
    'porno',
    'pornhub',
    'xxx',
  ];
  static const _reserved = [
    'admin',
    'administrador',
    'moderador',
    'moderator',
    'soporte',
    'support',
    'detox',
    'nerqova',
  ];

  static String _fold(String input) {
    var text = input.toLowerCase();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '8': 'b',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text.replaceAllMapped(RegExp(r'(.)\1+'), (match) => match[1]!);
  }

  static String? validate(String? input, {required bool isEs}) {
    final value = (input ?? '').trim();
    if (value.length < 3 || value.length > 30 || !_characters.hasMatch(value) ||
        value.replaceAll(RegExp(r'[_.-]'), '').isEmpty) {
      return isEs
          ? 'Usa de 3 a 30 letras, números, puntos o guiones.'
          : 'Use 3–30 letters, numbers, dots or underscores/hyphens.';
    }
    final compact = _fold(value.replaceAll(RegExp(r'[_.-]'), ''));
    final parts = <String>{
      compact,
      _fold(
        value.replaceAll(RegExp(r'\d+$'), '').replaceAll(RegExp(r'[_.-]'), ''),
      ),
      ...value.split(RegExp(r'[_.-]')).map(_fold),
      ...value
          .split(RegExp(r'[_.-]|\d+'))
          .where((s) => s.isNotEmpty)
          .map(_fold),
    };
    final blocked = _blocked.any((word) {
      final folded = _fold(word);
      return parts.contains(folded) ||
          (folded.length >= 5 && compact.contains(folded));
    });
    if (blocked || _reserved.any((word) => parts.contains(_fold(word)))) {
      return isEs ? 'Elige otro username.' : 'Choose another username.';
    }
    return null;
  }
}
