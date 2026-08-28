/// Decide si hay que renderizar el aviso de "mapa no disponible" en lugar de
/// un [GoogleMap] que saldria en gris.
///
/// En web la clave viaja por `--dart-define=GOOGLE_MAPS_API_KEY`, y `main()`
/// solo inyecta el `<script>` de Maps si esa clave no viene vacia. Si falta,
/// `google_maps_flutter_web` monta un div sin la libreria de Google detras y
/// el usuario ve un rectangulo gris sin ninguna explicacion. Preferimos
/// decirlo: un mapa muerto en produccion es facil de no detectar durante
/// semanas.
///
/// Fuera de web la clave no viaja por --dart-define (Android la lee del
/// manifest, iOS del Info.plist), asi que verla vacia aqui no dice nada.
bool isMapUnavailable({required bool isWeb, required String apiKey}) =>
    isWeb && apiKey.trim().isEmpty;
