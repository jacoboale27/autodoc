// test/core/theme/single_breakpoint_source_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ningún fichero de lib/ importa responsive_framework', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('responsive_framework'))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'responsive_framework introduce una segunda escala de breakpoints '
          '(DESKTOP >= 801) que contradice a AppBreakpoints (large >= 1200). '
          'Migra a AppBreakpoints. Ver el plan maestro §3.\n'
          '${offenders.join('\n')}',
    );
  });

  test('responsive_framework no está en pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('responsive_framework'), isFalse);
  });

  test('lib/features no decide layout con MediaQuery crudo', () {
    final offenders = <String>[];

    for (final file
        in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('MediaQuery.of(context).size.width') ||
            lines[i].contains('MediaQuery.sizeOf(context).width')) {
          offenders.add(
            '${file.path.replaceAll(r'\', '/')}:${i + 1}  ${lines[i].trim()}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Usa AppBreakpoints.of(context) o LayoutBuilder + '
          'AppBreakpoints.fromWidth(constraints.maxWidth).\n'
          '${offenders.join('\n')}',
    );
  });
}
