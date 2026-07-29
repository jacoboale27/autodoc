class AppSecrets {
  // Firebase Web
  static String get firebaseWebApiKey =>
      const String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
  static String get firebaseAppIdWeb =>
      const String.fromEnvironment('FIREBASE_APP_ID_WEB', defaultValue: '');
  static String get firebaseMeasurementId =>
      const String.fromEnvironment('FIREBASE_MEASUREMENT_ID', defaultValue: '');

  // Firebase Android
  static String get firebaseAndroidApiKey =>
      const String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: '');
  static String get firebaseAppIdAndroid =>
      const String.fromEnvironment('FIREBASE_APP_ID_ANDROID', defaultValue: '');

  // Firebase iOS
  static String get firebaseIosApiKey =>
      const String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: '');
  static String get firebaseAppIdIos =>
      const String.fromEnvironment('FIREBASE_APP_ID_IOS', defaultValue: '');
  static String get firebaseIosClientId =>
      const String.fromEnvironment('FIREBASE_IOS_CLIENT_ID', defaultValue: '');
  static String get firebaseIosBundleId =>
      const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: '');

  // Shared Firebase
  static String get firebaseMessagingSenderId =>
      const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static String get firebaseProjectId =>
      const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static String get firebaseAuthDomain =>
      const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
  static String get firebaseDatabaseUrl =>
      const String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: '');
  static String get firebaseStorageBucket =>
      const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');

  // Search API (Fotos de vehículos en concesionario con fondo sólido)
  static String get vehicleImageApiKey =>
      const String.fromEnvironment('VEHICLE_IMAGE_API_KEY', defaultValue: '');

  // Google Maps & Translation API Key
  static String get googleMapsApiKey =>
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  // Google Custom Search API (Opcional)
  static String get googleCustomSearchApiKey =>
      const String.fromEnvironment('GOOGLE_CUSTOM_SEARCH_API_KEY', defaultValue: '');
  static String get googleCustomSearchCx =>
      const String.fromEnvironment('GOOGLE_CUSTOM_SEARCH_CX', defaultValue: '');
}
