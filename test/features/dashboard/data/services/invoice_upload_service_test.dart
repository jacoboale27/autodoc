import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/dashboard/data/services/invoice_upload_service.dart';

void main() {
  group('InvoiceUploadService Tests', () {
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
  });
}
