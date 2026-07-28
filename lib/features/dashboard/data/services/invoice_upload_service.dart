class InvoiceUploadService {
  static Map<String, String> getFileMetadata(String fileName) {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    return {
      'extension': isPdf ? '.pdf' : '.jpg',
      'contentType': isPdf ? 'application/pdf' : 'image/jpeg',
    };
  }
}
