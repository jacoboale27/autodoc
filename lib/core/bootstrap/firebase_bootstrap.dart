/// Result of attempting to initialize Firebase before the app starts.
class FirebaseBootstrapResult {
  const FirebaseBootstrapResult._({required this.isReady, this.error});

  final bool isReady;
  final Object? error;
}

/// Isolates Firebase Core startup so callers can choose a safe UI on failure.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<FirebaseBootstrapResult> initialize(
    Future<void> Function() initializer,
  ) async {
    try {
      await initializer();
      return const FirebaseBootstrapResult._(isReady: true);
    } catch (error) {
      return FirebaseBootstrapResult._(isReady: false, error: error);
    }
  }
}
