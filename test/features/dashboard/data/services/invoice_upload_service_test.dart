import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/data/services/invoice_upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  group('Invoice Upload Tests', () {
    test('getFileMetadata returns correct metadata for PDF', () {
      final metadata = InvoiceUploadService.getFileMetadata('invoice.pdf');
      expect(metadata['extension'], '.pdf');
      expect(metadata['contentType'], 'application/pdf');
    });

    test('getFileMetadata returns correct metadata for Image', () {
      final metadata = InvoiceUploadService.getFileMetadata('photo.jpg');
      expect(metadata['extension'], '.jpg');
      expect(metadata['contentType'], 'image/jpeg');
    });

    test('AlertProvider tallerUpdateService passes correct contentType for PDF', () async {
      final mockFirestore = MockFirebaseFirestore();
      final mockStorage = MockFirebaseStorage();
      final mockReference = MockReference();
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockDocumentReference = MockDocumentReference<Map<String, dynamic>>();

      final provider = AlertProvider(firestore: mockFirestore, storage: mockStorage);

      // Setup minimal mocks to allow tallerUpdateService to run
      when(mockFirestore.collection(any)).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDocumentReference);
      when(mockCollection.add(any)).thenAnswer((_) async => mockDocumentReference);
      when(mockDocumentReference.update(any)).thenAnswer((_) async => {});

      when(mockStorage.ref()).thenReturn(mockReference);
      when(mockReference.child(any)).thenReturn(mockReference);
      when(mockReference.putData(any, any)).thenAnswer((_) async => MockTaskSnapshot());
      when(mockReference.getDownloadURL()).thenAnswer((_) async => 'http://example.com/invoice.pdf');

      // Create a mock XFile for a PDF
      final pdfBytes = Uint8List.fromList([1, 2, 3]);
      final pdfFile = XFile.fromData(pdfBytes, name: 'test_invoice.pdf');

      // Execute
      await provider.tallerUpdateService(
        taskId: 'test_task_1',
        nuevoKilometraje: 50000,
        tallerId: 'taller_1',
        descripcion: 'Test update',
        receiptImage: pdfFile,
      );

      // Verify
      final verification = verify(mockReference.putData(any, captureAny));
      verification.called(1);
      final SettableMetadata capturedMetadata = verification.captured.first;

      // The contentType should be application/pdf because we passed a .pdf file
      expect(capturedMetadata.contentType, 'application/pdf');
    });
  });
}

class MockTaskSnapshot extends Mock implements TaskSnapshot {}
