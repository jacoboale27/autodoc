class AppSecrets {
  // Firebase Web
  static String get firebaseWebApiKey =>
      const String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
  static String get firebaseAppIdWeb =>
      const String.fromEnvironment('FIREBASE_APP_ID_WEB', defaultValue: '');
  static String get firebaseMeasurementId =>
      const String.fromEnvironment('FIREBASE_MEASUREMENT_ID', defaultValue: '');

  // Firebase Android
  static String get firebaseAndroidApiKey => const String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: '',
  );
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
  static String get firebaseMessagingSenderId => const String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static String get firebaseProjectId =>
      const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static String get firebaseAuthDomain =>
      const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
  static String get firebaseDatabaseUrl =>
      const String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: '');
  static String get firebaseStorageBucket =>
      const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');

  // Google Maps & Translation API Key
  static String get googleMapsApiKey =>
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  // SearchAPI.io (engine google_images) — fotos de vehiculos estilo concesionario
  static String get vehicleImageApiKey =>
      const String.fromEnvironment('VEHICLE_IMAGE_API_KEY', defaultValue: '');

  // Google Sign-In (web)
  static String get googleSignInClientIdWeb => const String.fromEnvironment(
    'GOOGLE_SIGNIN_CLIENT_ID_WEB',
    defaultValue: '',
  );

  // Huella SHA-1 del certificado que firma el binario Android. Google Cloud la
  // exige en la cabecera X-Android-Cert para validar peticiones REST hechas con
  // una API key restringida a apps Android. NO puede ir hardcodeada: cambia
  // segun quien firme (keystore de debug en local, de release en CI), y una
  // huella que no corresponde con la firma real hace que Google devuelva 403.
  static String get androidCertSha1 =>
      const String.fromEnvironment('ANDROID_CERT_SHA1', defaultValue: '');

  // App Check (web) — clave de sitio de reCAPTCHA Enterprise
  static String get recaptchaSiteKey =>
      const String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');
}
