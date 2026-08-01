/// Fallback implementation used when neither `dart.library.html` nor
/// `dart.library.io` conditions apply (required by Dart for conditional
/// imports to have a default branch).
Future<void> downloadCsv(String filename, String csvContent) {
  throw UnimplementedError(
    'downloadCsv no está implementado para esta plataforma.',
  );
}
