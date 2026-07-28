import 'dart:html' as html;

void injectGoogleMapsScript(String apiKey) {
  if (html.document.head != null) {
    final script = html.ScriptElement()
      ..type = 'text/javascript'
      ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
      ..async = true;
    html.document.head!.append(script);
  }
}
