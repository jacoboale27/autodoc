import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppSecrets {
  // Firebase Web
  static String get firebaseWebApiKey => dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
  static String get firebaseAppIdWeb => dotenv.env['FIREBASE_APP_ID_WEB'] ?? '';
  static String get firebaseMeasurementId => dotenv.env['FIREBASE_MEASUREMENT_ID'] ?? '';

  // Firebase Android
  static String get firebaseAndroidApiKey => dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '';
  static String get firebaseAppIdAndroid => dotenv.env['FIREBASE_APP_ID_ANDROID'] ?? '';

  // Firebase iOS
  static String get firebaseIosApiKey => dotenv.env['FIREBASE_IOS_API_KEY'] ?? '';
  static String get firebaseAppIdIos => dotenv.env['FIREBASE_APP_ID_IOS'] ?? '';
  static String get firebaseIosClientId => dotenv.env['FIREBASE_IOS_CLIENT_ID'] ?? '';
  static String get firebaseIosBundleId => dotenv.env['FIREBASE_IOS_BUNDLE_ID'] ?? '';

  // Shared Firebase
  static String get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseAuthDomain => dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get firebaseDatabaseUrl => dotenv.env['FIREBASE_DATABASE_URL'] ?? '';
  static String get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';

  // Search API (Fotos de vehículos en concesionario con fondo sólido)
  static String get vehicleImageApiKey => dotenv.env['VEHICLE_IMAGE_API_KEY'] ?? '';

  // Google Maps & Translation API Key
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Google Custom Search API (Opcional)
  static String get googleCustomSearchApiKey => dotenv.env['GOOGLE_CUSTOM_SEARCH_API_KEY'] ?? '';
  static String get googleCustomSearchCx => dotenv.env['GOOGLE_CUSTOM_SEARCH_CX'] ?? '';
}
