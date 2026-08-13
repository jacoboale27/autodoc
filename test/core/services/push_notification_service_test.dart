import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import '../../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService Tests', () {
    // Un solo test/instancia: PushNotificationService es singleton
    // (`_instance ??= ...`), asi que un segundo `PushNotificationService(...)`
    // en otro test reutilizaria en silencio los mocks del primero en vez de
    // crear una instancia nueva.
    test(
      'updateUserToken usa update() (no set/merge) y no lanza si el doc aun no existe',
      () async {
        final mockMessaging = MockFirebaseMessaging();
        final mockFirestore = MockFirebaseFirestore();

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();

        when(mockMessaging.getToken()).thenAnswer((_) async => 'test_token');
        when(mockFirestore.collection('usuarios')).thenReturn(mockCollection);
        when(mockCollection.doc('user123')).thenReturn(mockDoc);
        when(mockDoc.update(any)).thenAnswer((_) async {});

        final service = PushNotificationService(
          messaging: mockMessaging,
          firestore: mockFirestore,
        );

        await service.updateUserToken('user123');

        verify(mockFirestore.collection('usuarios')).called(1);
        verify(mockCollection.doc('user123')).called(1);
        verify(mockDoc.update({'fcmToken': 'test_token'})).called(1);
        verifyNever(mockDoc.set(any, any));

        // Cuenta recien creada: el doc de usuarios/{uid} aun no existe
        // (profile_setup todavia no corre). `update()` en Firestore falla
        // con not-found en ese caso; updateUserToken debe tragarse el error
        // en vez de propagarlo (y, sobre todo, nunca debe usar
        // set(merge:true), que crearia el doc a medias y le haria saltar
        // profile_setup al usuario nuevo).
        when(
          mockDoc.update(any),
        ).thenThrow(Exception('NOT_FOUND: no document to update'));

        await service.updateUserToken('user123');

        verify(mockDoc.update({'fcmToken': 'test_token'})).called(1);
      },
    );
  });
}
