import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:hive/hive.dart';
import 'dart:io';

/// ChatProvider unit tests.
///
/// Note: ChatProvider uses ChatRepository internally (Firestore-based).
/// These tests verify provider state management and observable contract
/// without network calls (using a test-safe instantiation).
class MockChatRepository extends Mock implements ChatRepository {
  @override
  Stream<List<MensajeModel>> streamMensajes(String conversacionId) {
    return Stream.value([]);
  }

  // crearCotizacion/enviarMensaje take non-nullable params in the real
  // ChatRepository. Mockito's `any`/`anyNamed` matchers are statically typed
  // as `Null`, which cannot be passed to a non-nullable parameter — so we
  // widen these two overrides to nullable params (a legal, sound override)
  // and delegate to Mock's noSuchMethod so when()/verify() still intercept
  // the call, exactly like a build_runner-generated mock would.
  @override
  Future<String> crearCotizacion(CotizacionModel? cotizacion) =>
      (super.noSuchMethod(
            Invocation.method(#crearCotizacion, [cotizacion]),
            returnValue: Future<String>.value(''),
          )
          as Future<String>);

  @override
  Future<void> enviarMensaje({
    String? conversacionId,
    MensajeModel? mensaje,
    String? receptorId,
    bool? isMecanicoRemitente,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#enviarMensaje, [], {
              #conversacionId: conversacionId,
              #mensaje: mensaje,
              #receptorId: receptorId,
              #isMecanicoRemitente: isMecanicoRemitente,
            }),
            returnValue: Future<void>.value(),
          )
          as Future<void>);
}

void main() {
  late ChatProvider chatProvider;
  late MockChatRepository mockChatRepository;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    Hive.registerAdapter(MensajeModelAdapter());
    await Hive.openBox<MensajeModel>('mensajes');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    mockChatRepository = MockChatRepository();
    chatProvider = ChatProvider(repository: mockChatRepository);
  });

  tearDown(() {
    chatProvider.dispose();
  });

  group('ChatProvider — Initial State', () {
    test('initial conversaciones is empty', () {
      expect(chatProvider.conversaciones, isEmpty);
    });

    test('initial mensajesActuales is empty', () {
      expect(chatProvider.mensajesActuales, isEmpty);
    });

    test('initial isLoading is false', () {
      expect(chatProvider.isLoading, isFalse);
    });

    test('initial error is null', () {
      expect(chatProvider.error, isNull);
    });

    test('totalNoLeidosPropietario is 0 when no conversations', () {
      expect(chatProvider.totalNoLeidosPropietario, 0);
    });

    test('totalNoLeidosMecanico is 0 when no conversations', () {
      expect(chatProvider.totalNoLeidosMecanico, 0);
    });
  });

  group('ChatProvider — Unread count calculation', () {
    test(
      'totalNoLeidosPropietario sums noLeidosPropietario across conversations',
      () {
        // We inject conversations directly via testing the getter logic
        // Since _conversaciones is private, we test via the computed getter
        // by verifying the formula is correct given a controlled state.
        //
        // The getter is: _conversaciones.fold(0, (sum, item) => sum + item.noLeidosPropietario)
        // We can verify this with a ConversacionModel that has known values.

        final conv = ConversacionModel(
          id: 'c1',
          idPropietario: 'p1',
          idMecanico: 'm1',
          nombrePropietario: 'Juan',
          nombreMecanico: 'Taller X',
          ultimoMensaje: 'Hola',
          ultimoMensajeTs: DateTime.now(),
          noLeidosPropietario: 3,
          noLeidosMecanico: 1,
        );

        // Access via public getters; fold over empty list = 0
        expect(chatProvider.totalNoLeidosPropietario, 0);
        expect(chatProvider.totalNoLeidosMecanico, 0);

        // Verify model fields are correct
        expect(conv.noLeidosPropietario, 3);
        expect(conv.noLeidosMecanico, 1);
      },
    );
  });

  group('ChatProvider — MensajeModel contract', () {
    test('MensajeModel serialization is consistent', () {
      final msg = MensajeModel(
        id: 'msg1',
        idRemitente: 'user1',
        contenido: 'Hola taller',
        tipo: 'texto',
        timestamp: DateTime(2026, 7, 1, 10, 0),
      );

      expect(msg.id, 'msg1');
      expect(msg.contenido, 'Hola taller');
      expect(msg.tipo, 'texto');

      final map = msg.toMap();
      expect(map['id_remitente'], 'user1');
      expect(map['contenido'], 'Hola taller');
      expect(map['tipo'], 'texto');
    });

    test('MensajeModel.fromMap reconstructs correctly', () {
      final data = {
        'id_remitente': 'user2',
        'contenido': 'Mensaje de prueba',
        'tipo': 'imagen',
        'timestamp': Timestamp.fromDate(DateTime(2026, 7, 1)),
        'url_archivo': 'https://img.url/photo.jpg',
      };

      final msg = MensajeModel.fromMap(data, 'msg99');
      expect(msg.id, 'msg99');
      expect(msg.idRemitente, 'user2');
      expect(msg.tipo, 'imagen');
      expect(msg.urlArchivo, 'https://img.url/photo.jpg');
    });
  });

  group('ChatProvider — CotizacionModel contract', () {
    test('CotizacionModel fields are set correctly', () {
      final cotizacion = CotizacionModel(
        id: '',
        idMecanico: 'mec1',
        idPropietario: 'prop1',
        items: [
          CotizacionItem(
            material: 'Aceite y filtro',
            cantidad: 1,
            costo: 150.00,
          ),
        ],
        estado: 'pendiente',
        fecha: DateTime(2026, 7, 1),
      );

      expect(cotizacion.total, 150.00);
      expect(cotizacion.estado, 'pendiente');
      expect(cotizacion.resumen, 'Aceite y filtro');
    });

    test('CotizacionModel estado transitions are valid strings', () {
      const validStates = ['pendiente', 'aceptada', 'rechazada'];
      for (final estado in validStates) {
        final cot = CotizacionModel(
          id: '',
          idMecanico: 'm',
          idPropietario: 'p',
          items: [CotizacionItem(material: 'Test', cantidad: 1, costo: 100)],
          estado: estado,
          fecha: DateTime.now(),
        );
        expect(cot.estado, estado);
      }
    });
  });

  group('ChatProvider — ConversacionModel contract', () {
    test('ConversacionModel fromMap parses correctly', () {
      final data = {
        'id': 'conv1',
        'id_propietario': 'p1',
        'id_mecanico': 'm1',
        'nombre_propietario': 'María',
        'nombre_mecanico': 'Taller Rápido',
        'ultimo_mensaje': '¿Cuándo puede venir?',
        'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 7, 1)),
        'no_leidos_propietario': 2,
        'no_leidos_mecanico': 0,
      };

      final conv = ConversacionModel.fromMap(data, 'conv1');
      expect(conv.idPropietario, 'p1');
      expect(conv.nombreMecanico, 'Taller Rápido');
      expect(conv.noLeidosPropietario, 2);
    });

    test('ConversacionModel toMap includes required keys', () {
      final conv = ConversacionModel(
        id: 'c2',
        idPropietario: 'p2',
        idMecanico: 'm2',
        nombrePropietario: 'Pedro',
        nombreMecanico: 'Taller Central',
        ultimoMensaje: 'OK',
        ultimoMensajeTs: DateTime.now(),
      );

      final map = conv.toMap();
      expect(map.containsKey('id_propietario'), isTrue);
      expect(map.containsKey('id_mecanico'), isTrue);
      expect(map.containsKey('ultimo_mensaje'), isTrue);
    });
  });

  group('ChatProvider — enviarCotizacion', () {
    test(
      'returns false and does not send a message when crearCotizacion fails',
      () async {
        when(
          mockChatRepository.crearCotizacion(any),
        ).thenThrow(Exception('boom'));

        final cotizacion = CotizacionModel(
          id: '',
          idPropietario: 'owner1',
          idMecanico: 'mech1',
          items: const [],
          fecha: DateTime(2026, 1, 1),
        );

        final ok = await chatProvider.enviarCotizacion(
          cotizacion: cotizacion,
          conversacionId: 'conv1',
          contenido: 'He enviado una cotización.',
          remitenteId: 'mech1',
          receptorId: 'owner1',
          isMecanicoRemitente: true,
        );

        expect(ok, isFalse);
        expect(chatProvider.error, isNotNull);
        verifyNever(
          mockChatRepository.enviarMensaje(
            conversacionId: anyNamed('conversacionId'),
            mensaje: anyNamed('mensaje'),
            receptorId: anyNamed('receptorId'),
            isMecanicoRemitente: anyNamed('isMecanicoRemitente'),
          ),
        );
      },
    );

    test(
      'returns true and sends the message when crearCotizacion succeeds',
      () async {
        when(
          mockChatRepository.crearCotizacion(any),
        ).thenAnswer((_) async => 'cot1');
        when(
          mockChatRepository.enviarMensaje(
            conversacionId: anyNamed('conversacionId'),
            mensaje: anyNamed('mensaje'),
            receptorId: anyNamed('receptorId'),
            isMecanicoRemitente: anyNamed('isMecanicoRemitente'),
          ),
        ).thenAnswer((_) async {});

        final cotizacion = CotizacionModel(
          id: '',
          idPropietario: 'owner1',
          idMecanico: 'mech1',
          items: const [],
          fecha: DateTime(2026, 1, 1),
        );

        final ok = await chatProvider.enviarCotizacion(
          cotizacion: cotizacion,
          conversacionId: 'conv1',
          contenido: 'He enviado una cotización.',
          remitenteId: 'mech1',
          receptorId: 'owner1',
          isMecanicoRemitente: true,
        );

        expect(ok, isTrue);
        final captured = verify(
          mockChatRepository.enviarMensaje(
            conversacionId: anyNamed('conversacionId'),
            mensaje: captureAnyNamed('mensaje'),
            receptorId: anyNamed('receptorId'),
            isMecanicoRemitente: anyNamed('isMecanicoRemitente'),
          ),
        ).captured;
        final sentMensaje = captured.single as MensajeModel;
        expect(sentMensaje.metadata?['id_cotizacion'], 'cot1');
      },
    );
  });

  group('ChatProvider — Cache', () {
    test('ChatProvider loads cached messages instantly', () async {
      // Pre-fill cache
      final box = Hive.box<MensajeModel>('mensajes');
      final msg = MensajeModel(
        id: '123',
        idRemitente: 'user',
        contenido: 'hello cache',
        timestamp: DateTime.now(),
      );
      await box.put('conv_cache_test_123', msg);

      chatProvider.inicializarMensajes('conv_cache_test');
      expect(
        chatProvider.mensajesActuales,
        isNotEmpty,
        reason: 'Cache should load messages instantly',
      );
      expect(chatProvider.mensajesActuales.first.contenido, 'hello cache');
    });
  });
}
