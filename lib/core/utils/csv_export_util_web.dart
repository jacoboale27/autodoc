import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Dispara una descarga real de [csvContent] como archivo [filename] en el
/// navegador, usando `Blob` + `URL.createObjectURL` + un `<a download>`
/// sintético (patrón estándar para descargas client-side en la web).
///
/// Verificado contra `package:web` `1.1.1` (versión instalada, ver
/// `pubspec.lock`):
/// - `Blob(JSArray<BlobPart> blobParts, [BlobPropertyBag options])` en
///   `lib/src/dom/fileapi.dart`.
/// - `URL.createObjectURL(JSObject obj)` / `URL.revokeObjectURL(String url)`
///   (static) en `lib/src/dom/url.dart`.
/// - `HTMLAnchorElement.download` (String getter/setter) en
///   `lib/src/dom/html.dart`.
/// Todas coinciden con la firma usada en el brief original, por lo que no
/// fue necesario adaptar la API.
Future<void> downloadCsv(String filename, String csvContent) async {
  // BOM (﻿) para que Excel detecte UTF-8 correctamente.
  final bytes = utf8.encode('﻿$csvContent');
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  web.document.body!.removeChild(anchor);
  web.URL.revokeObjectURL(url);
}
