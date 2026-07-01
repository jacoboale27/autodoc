import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:autodoc/config/secrets.dart';
import 'package:flutter/foundation.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Box<String>? _translationBox;
  final String _apiKey = AppSecrets.googleMapsApiKey;
  final String _baseUrl = 'https://translation.googleapis.com/language/translate/v2';

  bool get isInitialized => _translationBox != null;

  Future<void> initialize() async {
    if (isInitialized) return;
    try {
      _translationBox = await Hive.openBox<String>('translation_cache');
      debugPrint("Translation cache (Hive) initialized successfully.");
    } catch (e) {
      debugPrint("Error initializing translation box in Hive: $e");
    }
  }

  String? translateSync(String text, String targetLanguage) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return '';
    
    final targetLang = targetLanguage.toLowerCase();
    if (targetLang == 'es') return text;

    final cacheKey = '${targetLang}_${cleanText.hashCode}';
    if (_translationBox != null && _translationBox!.containsKey(cacheKey)) {
      return _translationBox!.get(cacheKey);
    }
    return null;
  }

  Future<String> translate(String text, String targetLanguage) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return '';
    
    final targetLang = targetLanguage.toLowerCase();
    if (targetLang == 'es') return text; // Base language is Spanish

    // Check cache
    final cacheKey = '${targetLang}_${cleanText.hashCode}';
    if (_translationBox != null && _translationBox!.containsKey(cacheKey)) {
      return _translationBox!.get(cacheKey)!;
    }

    // Call API
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
          // Cabeceras de seguridad requeridas por Google Cloud para validar peticiones REST 
          // que usan una API Key restringida para la app de Android.
          'X-Android-Package': 'com.example.autodoc',
          'X-Android-Cert': '9520B26195264F6D2DD7178EB2C9708A31B131A2',
        },
        body: jsonEncode({
          'q': [cleanText],
          'target': targetLang,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['data']['translations'][0]['translatedText'] as String;

        // Save to cache
        if (_translationBox != null) {
          await _translationBox!.put(cacheKey, translatedText);
        }
        
        debugPrint("Translation API Fetch [Google Cloud] successful for '$cleanText' -> '$translatedText'");
        return translatedText;
      } else {
        debugPrint("Translation API responded with error: ${response.statusCode} - ${response.body}");
        return text;
      }
    } catch (e) {
      debugPrint("Error calling translation API: $e");
      return text;
    }
  }
}
