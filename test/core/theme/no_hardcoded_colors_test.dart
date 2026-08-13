// test/core/theme/no_hardcoded_colors_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rutas cuya tokenización ya está terminada y no puede regresionar.
///
/// **Cada fase del plan de refactorización UI/UX añade aquí sus rutas como
/// último paso**, tras dejarlas sin colores literales. Ver
/// `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md` §2.
const List<String> kTokenizedPaths = [
  'lib/core/theme',
  'lib/core/widgets/app_page_body.dart',
  'lib/core/widgets/app_grid.dart',
  // ── Fase 2 ──
  'lib/core/widgets/navigation',
  'lib/core/widgets/main_scaffold.dart',
  'lib/core/widgets/app_scaffold.dart',
  'lib/core/widgets/app_top_nav_bar.dart',
  'lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart',
];

/// Ficheros exentos, con su motivo. `app_shadows.dart` define las sombras
/// mismas: `Colors.black` ahí *es* el token.
const Map<String, String> kExemptFiles = {
  'lib/core/theme/app_shadows.dart': 'define las sombras; el negro es el token',
  'lib/core/theme/app_colors.dart':
      'define la paleta; los literales son la fuente',
  'lib/core/theme/app_theme.dart': 'mapea la paleta al ThemeData de Material',
};

final RegExp _hardcodedColor = RegExp(
  // El `\d*` tras `white`/`black` es imprescindible: sin él, en
  // `Colors.white70` el carácter siguiente a `white` es un dígito, no hay
  // frontera de palabra, la alternativa falla y la línea pasa el test. Así
  // escapaban las 13 constantes de opacidad de Flutter (`white10 white12
  // white24 white30 white38 white54 white70`, `black12 black26 black38
  // black45 black54 black87`) — justo las que usan `main_scaffold.dart` y
  // `mechanic_sidebar.dart`, que entran al ratchet en la Fase 2.
  r'Colors\.(white|black)\d*\b'
  r'|Colors\.(grey|gray|blue|red|green|orange|purple|yellow|pink|teal|indigo'
  r'|amber|cyan|lime|brown)\b'
  r'|Color\(0x[0-9a-fA-F]{8}\)',
);

Iterable<File> _dartFilesUnder(String path) sync* {
  final entity = FileSystemEntity.typeSync(path);
  if (entity == FileSystemEntityType.file) {
    yield File(path);
    return;
  }
  yield* Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

void main() {
  test('las rutas ya tokenizadas no contienen colores literales', () {
    final violations = <String>[];

    for (final path in kTokenizedPaths) {
      for (final file in _dartFilesUnder(path)) {
        final normalized = file.path.replaceAll(r'\', '/');
        if (kExemptFiles.keys.any(normalized.endsWith)) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (line.contains('Colors.transparent')) continue;
          if (_hardcodedColor.hasMatch(line)) {
            violations.add('$normalized:${i + 1}  ${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Color literal en ruta ya tokenizada. Usa context.appColors.<token> '
          'o Theme.of(context). Ver CONVENTIONS.md §2.1.\n'
          '${violations.join('\n')}',
    );
  });

  test('la regex detecta las formas que debe detectar', () {
    for (final sample in [
      'color: Colors.white,',
      'color: Colors.black87,',
      'border: Border.all(color: Colors.grey),',
      'color: const Color(0xFF522C81),',
    ]) {
      expect(_hardcodedColor.hasMatch(sample), isTrue, reason: sample);
    }

    for (final sample in [
      'color: Colors.transparent,',
      'color: colors.primary,',
      'color: Theme.of(context).colorScheme.surface,',
    ]) {
      expect(
        _hardcodedColor.hasMatch(sample) &&
            !sample.contains('Colors.transparent'),
        isFalse,
        reason: sample,
      );
    }
  });
}
