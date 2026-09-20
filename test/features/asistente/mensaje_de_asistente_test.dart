import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/asistente/presentation/utils/mensaje_de_asistente.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// IA-01 — el mapeo de errores del asistente.
///
/// **Por que este fichero existe aparte de la pantalla.** El defecto que UX-04
/// documento y que INNO-01 tuvo que corregir por segunda vez no es un fallo de
/// maquetado: es que el mapeo GENERICO manda codigos que significan una cosa a
/// un mensaje que dice otra. Aqui hay tres codigos asi, y los tres llevarian a
/// la persona a pelearse con algo que no puede arreglar:
///
///   - `unavailable` → "revisa tu conexion", cuando significa que el
///     interruptor de `configuracion/asistente_ia` esta apagado.
///   - `resource-exhausted` → "algo fallo", cuando significa que hoy ya no
///     quedan consultas.
///   - `permission-denied` → "vuelve a iniciar sesion", cuando significa que
///     el taller todavia no esta aprobado.
///
/// Se afirma en las DOS direcciones: que cada codigo da su mensaje propio, y
/// que ese mensaje **no es** el generico. Sin la segunda mitad, el dia que
/// alguien borre una rama del `switch` el test seguiria verde por casualidad
/// si el generico coincidiera.
void main() {
  late AppLocalizations es;
  late AppLocalizations en;

  setUpAll(() async {
    es = await AppLocalizations.delegate.load(const Locale('es'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  FirebaseFunctionsException fallo(String codigo, [Object? motivo]) =>
      FirebaseFunctionsException(
        code: codigo,
        message: 'irrelevante',
        details: motivo,
      );

  group('mensajeDeAsistente', () {
    test('cada codigo del callable tiene su mensaje propio', () {
      final esperados = <String, String>{
        // Sin motivo, el par ambiguo cae a su lado por defecto: el cupo
        // propio y el proveedor caido. El caso con motivo lo cubre el grupo
        // «los cuatro motivos».
        'resource-exhausted': es.asistenteErrorCupo,
        'unavailable': es.asistenteErrorProveedor,
        'failed-precondition': es.asistenteErrorNoDisponible,
        'deadline-exceeded': es.asistenteErrorLento,
        'aborted': es.asistenteErrorSinRespuesta,
        'permission-denied': es.asistenteErrorTallerPendiente,
        'invalid-argument': es.asistenteErrorPreguntaVacia,
      };

      esperados.forEach((codigo, mensaje) {
        expect(
          mensajeDeAsistente(es, fallo(codigo)),
          mensaje,
          reason: 'el codigo $codigo no da su mensaje propio',
        );
        expect(
          mensajeDeAsistente(es, fallo(codigo)),
          isNot(es.errorDatosGenerico),
          reason:
              'el codigo $codigo cae en el mensaje generico de UX-04, que '
              'dice "intentalo mas tarde" y no explica nada de lo que pasa',
        );
      });
    });

    test('ninguno de los siete manda a revisar la conexion', () {
      // Es el defecto concreto: `mensajeDeError` manda `unavailable` y
      // `deadline-exceeded` a `errorDatosConexion`. Aqui el primero significa
      // "apagado" y el segundo "el modelo tardo", y ninguno se arregla
      // mirando el wifi.
      for (final codigo in const [
        'resource-exhausted',
        'unavailable',
        'failed-precondition',
        'deadline-exceeded',
        'aborted',
        'permission-denied',
        'invalid-argument',
      ]) {
        expect(
          mensajeDeAsistente(es, fallo(codigo)),
          isNot(es.errorDatosConexion),
          reason: '$codigo manda a revisar la conexion',
        );
        expect(
          mensajeDeAsistente(es, fallo(codigo)),
          isNot(es.errorDatosPermiso),
          reason: '$codigo manda a volver a iniciar sesion',
        );
      }
    });

    test('un codigo desconocido cae en el generico de UX-04', () {
      // Y cae ahi a proposito: el generico ya registra el detalle tecnico en
      // el log sin ensenarlo. Inventar un mensaje por codigo desconocido
      // seria adivinar.
      expect(mensajeDeAsistente(es, fallo('internal')), es.errorDatosGenerico);
      expect(mensajeDeAsistente(es, Exception('x')), es.errorDatosGenerico);
      expect(mensajeDeAsistente(es, null), es.errorDatosGenerico);
    });

    test('traduce, no devuelve siempre el castellano', () {
      // El asistente responde en el idioma que se le pide, pero SUS ERRORES
      // los redacta el cliente. Si esto no estuviera traducido, la app en
      // ingles contestaria en ingles y fallaria en espanol.
      expect(
        mensajeDeAsistente(en, fallo('resource-exhausted')),
        en.asistenteErrorCupo,
      );
      expect(
        mensajeDeAsistente(en, fallo('resource-exhausted')),
        isNot(es.asistenteErrorCupo),
      );
    });
  });

  group('asistenteMereceReintento', () {
    test('no ofrece reintentar donde reintentar no puede funcionar', () {
      for (final codigo in const [
        'resource-exhausted', // hoy ya no quedan consultas
        'failed-precondition', // falta la clave o el modelo no sirve
        'permission-denied', // el taller no esta aprobado
        'invalid-argument', // la pregunta llego vacia
        'unauthenticated', // no hay sesion
      ]) {
        expect(
          asistenteMereceReintento(fallo(codigo)),
          isFalse,
          reason:
              '$codigo ofrece un boton de reintentar que va a fallar siempre',
        );
      }
    });

    test('si ofrece reintentar donde puede salir distinto', () {
      for (final codigo in const [
        'deadline-exceeded', // el modelo tardo; la siguiente puede no tardar
        'aborted', // el filtro del proveedor; no es determinista
        'unavailable', // el proveedor caido se levanta
        'internal',
      ]) {
        expect(
          asistenteMereceReintento(fallo(codigo)),
          isTrue,
          reason: '$codigo deja la pantalla en un callejon sin salida',
        );
      }
      expect(asistenteMereceReintento(Exception('red')), isTrue);
    });
  });

  group('los cuatro motivos', () {
    // **Dos codigos, cuatro situaciones.** Sin `details` la pantalla tiene que
    // elegir un texto que miente en la mitad de los casos. Esto es lo que
    // cierra el gap anotado al terminar la Fase 4.

    test('el cupo propio y el global no se cuentan la misma historia', () {
      final propio = mensajeDeAsistente(
        es,
        fallo('resource-exhausted', MotivoAsistente.cupoUsuario),
      );
      final global = mensajeDeAsistente(
        es,
        fallo('resource-exhausted', MotivoAsistente.cupoGlobal),
      );

      expect(propio, es.asistenteErrorCupo);
      expect(global, es.asistenteErrorCupoGlobal);
      expect(
        propio,
        isNot(global),
        reason:
            'culpar a la persona del cupo global es echarle encima un limite '
            'que no controla',
      );
    });

    test('el interruptor apagado no se confunde con el proveedor caido', () {
      final apagado = mensajeDeAsistente(
        es,
        fallo('unavailable', MotivoAsistente.apagado),
      );
      final caido = mensajeDeAsistente(
        es,
        fallo('unavailable', MotivoAsistente.proveedor),
      );

      expect(apagado, es.asistenteErrorApagado);
      expect(caido, es.asistenteErrorProveedor);
      expect(apagado, isNot(caido));
    });

    test('con el interruptor apagado NO se ofrece reintentar', () {
      // Es la mitad del valor del motivo: reintentar no enciende nada. Antes
      // los dos compartian respuesta y habia que elegir cual tratar mal.
      expect(
        asistenteMereceReintento(fallo('unavailable', MotivoAsistente.apagado)),
        isFalse,
      );
      expect(
        asistenteMereceReintento(
          fallo('unavailable', MotivoAsistente.proveedor),
        ),
        isTrue,
      );
    });

    test('sin motivo se cae del lado que SI se arregla solo', () {
      // Un servidor viejo, o un error que no pasa por el filtro, no trae
      // `details`. Ahi se elige el proveedor: prometer que el interruptor se
      // va a encender solo es la version que deja a alguien esperando.
      expect(
        mensajeDeAsistente(es, fallo('unavailable')),
        es.asistenteErrorProveedor,
      );
      expect(asistenteMereceReintento(fallo('unavailable')), isTrue);
      expect(
        mensajeDeAsistente(es, fallo('resource-exhausted')),
        es.asistenteErrorCupo,
      );
    });

    test('un `details` que no es cadena no revienta la pantalla de error', () {
      // `details` es `dynamic` y lo rellena el servidor. Esto se ejecuta
      // MIENTRAS se pinta la pantalla de error: si lanzara aqui, el fallo
      // original quedaria tapado por uno peor.
      for (final basura in <Object?>[
        42,
        {'motivo': 'apagado'},
        <String>['apagado'],
        true,
      ]) {
        expect(
          mensajeDeAsistente(es, fallo('unavailable', basura)),
          es.asistenteErrorProveedor,
        );
        expect(asistenteMereceReintento(fallo('unavailable', basura)), isTrue);
      }
    });

    test('los motivos son los mismos cuatro que publica el servidor', () {
      // Espejo de `MOTIVOS` en functions/src/asistente.js. Si el servidor
      // anade uno y aqui no, el mensaje vuelve al ambiguo en silencio.
      expect(
        const [
          MotivoAsistente.cupoUsuario,
          MotivoAsistente.cupoGlobal,
          MotivoAsistente.apagado,
          MotivoAsistente.proveedor,
        ],
        ['cupo_usuario', 'cupo_global', 'apagado', 'proveedor'],
      );
    });
  });
}
