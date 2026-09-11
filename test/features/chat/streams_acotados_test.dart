import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/data/repositories/reserva_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';

/// Los tres streams sin tope que dejó anotados el §9 de
/// `GAPS-FUNC-02-cierre-de-residuales.md` (gaps 9.2 y 9.3).
///
/// Los tres tenían la misma forma que el tablero Kanban antes de acotarlo: un
/// `where` por usuario y nada más — ni orden en el servidor ni límite. El
/// coste no depende del uso de una sesión sino de toda la historia de la
/// cuenta: un mecánico con 800 conversaciones pagaba 800 lecturas en cada
/// apertura del chat y en cada reattach del listener.
///
/// Lo que fijan estos tests es lo mismo que fijó `tablero_acotado_test.dart`:
/// recortar sin ordenar en el SERVIDOR deja fuera documentos arbitrarios (sin
/// `orderBy`, Firestore ordena por `__name__`, un id aleatorio), y recortar
/// sin avisar los hace desaparecer en silencio. Ordenar en memoria después de
/// traerlo todo no acota nada: es justo lo que hacía la bandeja.
void main() {
  group('bandeja de conversaciones (gap 9.2)', () {
    Future<FakeFirebaseFirestore> conConversaciones(int cuantas) async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < cuantas; i += 1) {
        // La conversación i es un día MÁS ANTIGUA que la anterior: `c0` es la
        // más reciente.
        await db.collection('conversaciones').doc('c$i').set({
          'id_propietario': 'p1',
          'id_mecanico': 'm1',
          'nombre_propietario': 'Ana',
          'nombre_mecanico': 'Taller',
          'ultimo_mensaje': 'hola',
          'ultimo_mensaje_ts': Timestamp.fromDate(
            DateTime(2026, 1, 1).add(Duration(days: cuantas - i)),
          ),
          'no_leidos_propietario': 0,
          'no_leidos_mecanico': 0,
          'estado': 'activo',
        });
      }
      return db;
    }

    test('la bandeja se acota al tope y trae las MÁS RECIENTES', () async {
      final db = await conConversaciones(maxConversacionesBandeja + 5);
      final repo = ChatRepository(firestore: db);

      final lista = await repo.streamConversaciones('p1', false).first;

      expect(lista, hasLength(maxConversacionesBandeja));
      expect(lista.first.id, 'c0');
      expect(
        lista.map((c) => c.id),
        isNot(contains('c${maxConversacionesBandeja + 4}')),
        reason:
            'la conversación más rancia es la que debe caer fuera; si cae '
            'una cualquiera, el recorte no está ordenado en el servidor',
      );
    });

    test('el recorte se hace en el SERVIDOR, no en memoria', () async {
      final db = await conConversaciones(maxConversacionesBandeja + 5);
      final repo = ChatRepository(firestore: db);

      final lista = await repo.streamConversaciones('m1', true).first;

      // `FakeFirebaseFirestore` no instrumenta lecturas, así que lo que se
      // afirma es la consecuencia observable: el stream entrega menos
      // documentos de los que hay. Un `sort` en cliente los entregaría todos.
      final sinTope = await db
          .collection('conversaciones')
          .where('id_mecanico', isEqualTo: 'm1')
          .get();
      expect(sinTope.docs, hasLength(maxConversacionesBandeja + 5));
      expect(lista.length, lessThan(sinTope.docs.length));
    });

    test('al llegar al tope, el provider lo dice', () async {
      final db = await conConversaciones(maxConversacionesBandeja + 5);
      final provider = ChatProvider(repository: ChatRepository(firestore: db));

      provider.inicializarConversaciones('p1', false);
      await Future<void>.delayed(Duration.zero);

      expect(
        provider.bandejaTruncada,
        isTrue,
        reason:
            'sin esta señal faltan conversaciones y el usuario no tiene forma '
            'de saberlo',
      );
    });

    test('por debajo del tope no se anuncia nada', () async {
      final db = await conConversaciones(3);
      final provider = ChatProvider(repository: ChatRepository(firestore: db));

      provider.inicializarConversaciones('p1', false);
      await Future<void>.delayed(Duration.zero);

      expect(provider.conversaciones, hasLength(3));
      expect(provider.bandejaTruncada, isFalse);
    });
  });

  group('hilo de mensajes (gap 9.3)', () {
    Future<FakeFirebaseFirestore> conMensajes(int cuantos) async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < cuantos; i += 1) {
        // El mensaje i es el i-ésimo en el tiempo: `m0` el más antiguo.
        await db
            .collection('conversaciones')
            .doc('c1')
            .collection('mensajes')
            .doc('m$i')
            .set({
              'id_remitente': 'p1',
              'contenido': 'mensaje $i',
              'tipo': 'texto',
              'timestamp': Timestamp.fromDate(
                DateTime(2026, 1, 1).add(Duration(minutes: i)),
              ),
              'estado': 'enviado',
            });
      }
      return db;
    }

    test('el hilo se acota por el FINAL: trae los más recientes', () async {
      final db = await conMensajes(maxMensajesHilo + 5);
      final repo = ChatRepository(firestore: db);

      final mensajes = await repo.streamMensajes('c1').first;

      expect(mensajes, hasLength(maxMensajesHilo));
      // El stream viene descendente: el primero es el más reciente.
      expect(mensajes.first.id, 'm${maxMensajesHilo + 4}');
      expect(
        mensajes.map((m) => m.id),
        isNot(contains('m0')),
        reason:
            'un hilo recortado por delante sin avisar es peor que uno lento: '
            'lo que sobra tiene que ser lo viejo, nunca lo último dicho',
      );
    });

    test('al llegar al tope, el provider lo dice', () async {
      final db = await conMensajes(maxMensajesHilo + 5);
      final provider = ChatProvider(repository: ChatRepository(firestore: db));

      provider.inicializarMensajes('c1');
      await Future<void>.delayed(Duration.zero);

      expect(provider.hiloTruncado, isTrue);
    });
  });

  group('historial de reservas (gap 9.3)', () {
    Future<FakeFirebaseFirestore> conReservas(int cuantas) async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < cuantas; i += 1) {
        await db.collection('reservas').doc('r$i').set({
          'id_conversacion': 'c1',
          'id_propietario': 'p1',
          'id_mecanico': 'm1',
          'id_vehiculo': 'v1',
          'id_taller': 't1',
          'fecha_hora_propuesta': Timestamp.fromDate(
            DateTime(2026, 1, 1).add(Duration(days: cuantas - i)),
          ),
          'tipo_servicio': 'revision',
          'estado': 'pendiente',
          'fecha_creacion': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
      }
      return db;
    }

    test('el historial se acota al tope y trae las MÁS RECIENTES', () async {
      final db = await conReservas(maxReservasHistorial + 5);
      final repo = ReservaRepository(firestore: db);

      final reservas = await repo.streamReservasUsuario('p1').first;

      expect(reservas, hasLength(maxReservasHistorial));
      expect(reservas.first.id, 'r0');
    });

    test('al llegar al tope, el provider lo dice', () async {
      final db = await conReservas(maxReservasHistorial + 5);
      final provider = ReservaProvider(
        repository: ReservaRepository(firestore: db),
      );

      provider.inicializarReservasUsuario('p1');
      await Future<void>.delayed(Duration.zero);

      expect(provider.reservasTruncadas, isTrue);
    });
  });
}
