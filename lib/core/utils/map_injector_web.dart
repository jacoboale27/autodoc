import 'package:web/web.dart' as web;

void injectGoogleMapsScript(String apiKey) {
  final head = web.document.head;
  if (head != null) {
    final script = web.HTMLScriptElement()
      ..type = 'text/javascript'
      ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
      ..async = true;
    head.append(script);
  }
}
