import 'package:autodoc/core/utils/municipio_publicado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los talleres del directorio decian todos «Ubicacion no especificada».
///
/// No era un dato que faltara: `publishTallerProfile` escribe `municipio` en
/// `talleres`, y el perfil publico lo pintaba bien. La tarjeta leia
/// `ubicacion_municipio`, que es el OTRO campo que `UserModel` serializa, y
/// que esa proyeccion no escribe nunca. Medido en produccion el 2026-09-22
/// sobre los 16 talleres visibles del directorio.
void main() {
  group('municipioDeTaller', () {
    test('lee `municipio`, que es lo que publica la proyeccion publica', () {
      expect(
        municipioDeTaller({'municipio': 'San Salvador Este'}),
        'San Salvador Este',
      );
    });

    test('sigue aceptando `ubicacion_municipio` de fichas antiguas', () {
      expect(
        municipioDeTaller({'ubicacion_municipio': 'Soyapango'}),
        'Soyapango',
      );
    });

    test('con los dos, gana el heredado: no cambia lo que ya se veia', () {
      expect(
        municipioDeTaller({
          'ubicacion_municipio': 'Soyapango',
          'municipio': 'Apopa',
        }),
        'Soyapango',
      );
    });

    test(
      'sin ninguno devuelve null, para que la pantalla ponga su literal',
      () {
        expect(municipioDeTaller({}), isNull);
      },
    );

    test('una cadena vacia o en blanco no cuenta como municipio', () {
      expect(municipioDeTaller({'municipio': ''}), isNull);
      expect(
        municipioDeTaller({'ubicacion_municipio': '   ', 'municipio': 'Apopa'}),
        'Apopa',
      );
    });

    test('un tipo que no es cadena no revienta la tarjeta', () {
      expect(municipioDeTaller({'municipio': 42}), isNull);
    });
  });
}
