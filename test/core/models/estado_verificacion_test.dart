import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';

/// Taller con TODOS los campos que exige la revision. Cada test degrada
/// exactamente uno para aislar que campo falta.
UserModel tallerCompleto({
  String nombreCompleto = 'Taller El Buen Motor',
  String? telefono = '+503 7777-8888',
  String? especialidad = 'Frenos',
  String? departamento = 'San Salvador',
  String? municipio = 'Soyapango',
  double? latitud = 13.69,
  double? longitud = -89.19,
  String estado = 'pendiente',
}) {
  return UserModel(
    idUsuario: 'taller-1',
    nombreCompleto: nombreCompleto,
    correo: 'taller@example.com',
    rol: 'Taller',
    fechaRegistro: DateTime(2026, 1, 1),
    telefono: telefono,
    especialidad: especialidad,
    departamento: departamento,
    municipio: municipio,
    latitud: latitud,
    longitud: longitud,
    estado: estado,
  );
}

void main() {
  group('AppEstadoVerificacion.parse', () {
    test('reconoce el vocabulario persistido', () {
      expect(
        AppEstadoVerificacion.parse('perfil_incompleto'),
        EstadoVerificacion.perfilIncompleto,
      );
      expect(
        AppEstadoVerificacion.parse('listo_para_revision'),
        EstadoVerificacion.listoParaRevision,
      );
      expect(
        AppEstadoVerificacion.parse('en_revision'),
        EstadoVerificacion.enRevision,
      );
      expect(
        AppEstadoVerificacion.parse('aprobada'),
        EstadoVerificacion.aprobada,
      );
      expect(
        AppEstadoVerificacion.parse('rechazada'),
        EstadoVerificacion.rechazada,
      );
    });

    test('normaliza espacios y mayusculas', () {
      expect(
        AppEstadoVerificacion.parse('  En_Revision '),
        EstadoVerificacion.enRevision,
      );
    });

    test(
      'cualquier valor desconocido, vacio o nulo cae en perfilIncompleto',
      () {
        for (final entrada in <String?>[null, '', '   ', 'vete-a-saber']) {
          expect(
            AppEstadoVerificacion.parse(entrada),
            EstadoVerificacion.perfilIncompleto,
            reason: 'default conservador: nada enviado todavia',
          );
        }
      },
    );

    test('serializa de vuelta al mismo texto que lee', () {
      for (final estado in EstadoVerificacion.values) {
        expect(
          AppEstadoVerificacion.parse(AppEstadoVerificacion.serializar(estado)),
          estado,
        );
      }
    });
  });

  group('camposFaltantes', () {
    test('un taller con todo puesto no tiene campos faltantes', () {
      expect(AppEstadoVerificacion.camposFaltantes(tallerCompleto()), isEmpty);
      expect(AppEstadoVerificacion.perfilCompleto(tallerCompleto()), isTrue);
    });

    test('detecta cada campo obligatorio por separado', () {
      final casos = <String, UserModel>{
        'Nombre del taller': tallerCompleto(nombreCompleto: '   '),
        'Especialidad': tallerCompleto(especialidad: ''),
        'Departamento': tallerCompleto(departamento: null),
        'Municipio': tallerCompleto(municipio: null),
      };

      casos.forEach((etiqueta, taller) {
        expect(
          AppEstadoVerificacion.camposFaltantes(taller),
          [etiqueta],
          reason: 'degradar solo $etiqueta debe reportar solo $etiqueta',
        );
      });
    });

    test(
      'la ubicacion falta si le falta CUALQUIERA de las dos coordenadas',
      () {
        const etiqueta = 'Ubicación en el mapa';
        expect(
          AppEstadoVerificacion.camposFaltantes(tallerCompleto(latitud: null)),
          [etiqueta],
        );
        expect(
          AppEstadoVerificacion.camposFaltantes(tallerCompleto(longitud: null)),
          [etiqueta],
        );
      },
    );

    test(
      'acumula varios faltantes en orden estable, apto para pintar una lista',
      () {
        final taller = tallerCompleto(
          telefono: null,
          municipio: null,
          latitud: null,
        );

        expect(AppEstadoVerificacion.camposFaltantes(taller), [
          'Teléfono de contacto',
          'Municipio',
          'Ubicación en el mapa',
        ]);
      },
    );

    test('el telefono es obligatorio para la revision aunque el formulario de '
        'ajustes lo trate como opcional', () {
      // workshop_settings_screen.dart:538 devuelve null ("No es obligatorio")
      // cuando el telefono viene vacio. La barra para PUBLICAR un taller es
      // mas alta que la de guardar un borrador: sin telefono el admin no
      // tiene como contrastar que el negocio existe.
      expect(
        AppEstadoVerificacion.camposFaltantes(tallerCompleto(telefono: '')),
        ['Teléfono de contacto'],
      );
    });
  });

  group('transiciones', () {
    test('un perfil incompleto solo avanza a listoParaRevision', () {
      expect(
        AppEstadoVerificacion.transicionesDesde(
          EstadoVerificacion.perfilIncompleto,
        ),
        {EstadoVerificacion.listoParaRevision},
      );
    });

    test('solo se aprueba o rechaza desde enRevision', () {
      for (final destino in [
        EstadoVerificacion.aprobada,
        EstadoVerificacion.rechazada,
      ]) {
        expect(
          AppEstadoVerificacion.puedeTransicionar(
            EstadoVerificacion.listoParaRevision,
            destino,
          ),
          isFalse,
          reason:
              'un admin debe tomar el caso (enRevision) antes de resolverlo',
        );
        expect(
          AppEstadoVerificacion.puedeTransicionar(
            EstadoVerificacion.enRevision,
            destino,
          ),
          isTrue,
        );
      }
    });

    test('un taller rechazado puede corregir y reenviar', () {
      expect(
        AppEstadoVerificacion.puedeTransicionar(
          EstadoVerificacion.rechazada,
          EstadoVerificacion.listoParaRevision,
        ),
        isTrue,
      );
    });

    test('una verificacion aprobada solo se reabre para re-revision', () {
      // Y vuelve a la COLA, no a manos de nadie: 'en_revision' significa que
      // un administrador lo tiene abierto, y reabrir directamente ahi saltaria
      // el paso de tomar el caso, que es lo unico que impide que dos
      // administradores resuelvan el mismo expediente a la vez.
      expect(
        AppEstadoVerificacion.transicionesDesde(EstadoVerificacion.aprobada),
        {EstadoVerificacion.listoParaRevision},
      );
    });

    test('un expediente reabierto recorre el mismo camino que uno nuevo', () {
      // La re-revision no es un flujo paralelo: una vez en la cola, tomar el
      // caso y resolverlo funcionan igual que en un alta.
      expect(
        AppEstadoVerificacion.puedeTransicionar(
          EstadoVerificacion.listoParaRevision,
          EstadoVerificacion.enRevision,
        ),
        isTrue,
      );
    });

    test('nadie puede saltar de aprobada a rechazada sin volver a mirar', () {
      // Retirar una aprobacion exige pasar por la cola y por un revisor. Sin
      // esto, un solo write revocaria una verificacion ya concedida.
      for (final destino in [
        EstadoVerificacion.enRevision,
        EstadoVerificacion.rechazada,
        EstadoVerificacion.perfilIncompleto,
      ]) {
        expect(
          AppEstadoVerificacion.puedeTransicionar(
            EstadoVerificacion.aprobada,
            destino,
          ),
          isFalse,
          reason: 'aprobada -> ${AppEstadoVerificacion.serializar(destino)}',
        );
      }
    });

    test('ningun estado transiciona a si mismo', () {
      for (final estado in EstadoVerificacion.values) {
        expect(
          AppEstadoVerificacion.puedeTransicionar(estado, estado),
          isFalse,
        );
      }
    });
  });

  group('separacion de ejes (regresion)', () {
    // El bug que acabamos de arreglar en WorkshopService nacio de tener DOS
    // vocabularios para "aprobado". Este eje NO puede convertirse en un
    // segundo origen de verdad sobre el acceso: quien decide si un taller
    // opera es `usuarios.estado` via AppEstadoCuenta.aprobados, espejo de
    // isMecanico() en firestore.rules. EstadoVerificacion solo gobierna el
    // flujo de onboarding.
    test('una verificacion aprobada NO implica por si sola acceso', () {
      final taller = tallerCompleto(estado: 'pendiente');

      expect(AppEstadoCuenta.esAprobada(taller.estado), isFalse);
      expect(AppEstadoVerificacion.perfilCompleto(taller), isTrue);
    });

    test('los dos vocabularios no comparten ni un solo valor', () {
      final verificacion = EstadoVerificacion.values
          .map(AppEstadoVerificacion.serializar)
          .toSet();

      expect(
        verificacion.intersection(AppEstadoCuenta.aprobados),
        isEmpty,
        reason: 'un valor compartido invita a comparar el campo equivocado',
      );
    });
  });
}
