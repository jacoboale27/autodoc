import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/dashboard/data/services/invoice_upload_service.dart';

void main() {
  group('InvoiceUploadService.getFileMetadata', () {
    // --- PDF detection ---
    test('returns application/pdf content-type for .pdf extension', () {
      final metadata = InvoiceUploadService.getFileMetadata('invoice.pdf');
      expect(metadata['extension'], '.pdf');
      expect(metadata['contentType'], 'application/pdf');
    });

    test('is case-insensitive: .PDF (uppercase) is treated as pdf', () {
      final metadata = InvoiceUploadService.getFileMetadata('FACTURA.PDF');
      expect(metadata['extension'], '.pdf');
      expect(metadata['contentType'], 'application/pdf');
    });

    // --- Image detection ---
    test('returns image/jpeg content-type for .jpg extension', () {
      final metadata = InvoiceUploadService.getFileMetadata('photo.jpg');
      expect(metadata['extension'], '.jpg');
      expect(metadata['contentType'], 'image/jpeg');
    });

    test(
      'falls back to image/jpeg for unrecognised extensions (e.g. .png)',
      () {
        // PNG is not a PDF so the service should treat it as an image upload.
        final metadata = InvoiceUploadService.getFileMetadata('scan.png');
        expect(metadata['extension'], '.jpg');
        expect(metadata['contentType'], 'image/jpeg');
      },
    );

    test('returns map with both extension and contentType keys', () {
      final metadata = InvoiceUploadService.getFileMetadata('receipt.pdf');
      expect(metadata.containsKey('extension'), isTrue);
      expect(metadata.containsKey('contentType'), isTrue);
    });
  });
}
