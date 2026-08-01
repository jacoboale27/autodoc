# Chat y Mensajería al 100% — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar el Chat de AutoDoc del 95.0% al 100%: notas de voz, recibos de lectura confiables, y notificaciones push por mensaje nuevo.

**Architecture:** Investigación previa confirmó que **2 de las 3 features ya están casi completas**: `MensajeModel.estado` (`'enviado'/'entregado'/'visto'`) ya existe y el doble check azul ya se renderiza en `chat_screen.dart`, y la Cloud Function `notifyOnNewChatMessage` (trigger `onCreate` en `conversaciones/{id}/mensajes/{id}`) ya envía el push. Este plan por tanto se enfoca principalmente en **notas de voz** (feature nueva, siguiendo exactamente el patrón ya usado para imágenes: `ChatProvider.subirImagenChat` → Storage → `enviarMensaje(tipo: 'imagen')` → `ImagenChatCard`), y cierra dos huecos puntuales detectados: (1) `marcarComoLeidos` no se dispara al abrir el chat, por lo que el doble check azul no se activa de forma confiable; (2) el push de audio no tiene un texto de notificación dedicado.

**Tech Stack:** Flutter, Provider, Cloud Firestore, Firebase Storage, Hive (cache offline), paquetes nuevos `record` y `audioplayers`, Cloud Functions (Node.js).

## Global Constraints

- Campos Firestore en snake_case español (`id_remitente`, `url_archivo`), modelos Dart en camelCase con `fromMap`/`toMap` manuales.
- Métodos en español (`subirAudioChat`, `enviarMensaje`), consistente con el resto de `ChatProvider`.
- El documento de mensaje vive en `conversaciones/{conversacionId}/mensajes/{mensajeId}` — cualquier campo nuevo (ej. `duracionSegundos`) se añade a `MensajeModel`, no a un modelo paralelo.
- `MensajeModel` usa Hive (`@HiveType(typeId: 0)`) para cache offline — cualquier campo nuevo requiere `@HiveField(N)` con el siguiente índice libre (9, ya que 0-8 están ocupados) y correr `build_runner` para regenerar `mensaje_model.g.dart`.
- No introducir modelo `AudioModel`/`VoiceNoteModel` separado — el audio es un `tipo: 'audio'` más de `MensajeModel`, igual que `'imagen'`.
- El envío real de push SIEMPRE ocurre en Cloud Functions; el cliente nunca llama `messaging.send()` directamente.
- Toda ruta de Storage nueva debe centralizarse en `lib/core/constants/storage_paths.dart` (hoy solo tiene `perfiles` y `facturas`; las imágenes de chat usan `'chat_images'` hardcodeado — se corrige de paso al añadir `chatAudios`, sin tocar el path existente de imágenes para no romper mensajes ya enviados).

---

## File Structure

- `pubspec.yaml` — añadir `record: ^5.2.0`, `audioplayers: ^6.1.0`.
- `lib/core/constants/storage_paths.dart` — añadir `chatAudios`.
- `lib/core/models/mensaje_model.dart` — añadir campo opcional `duracionSegundos` (int?, `@HiveField(9)`).
- `lib/features/chat/data/repositories/chat_repository.dart` — sin cambios de firma (ya soporta `tipo`/`urlArchivo`/`metadata` genéricos).
- `lib/features/chat/presentation/providers/chat_provider.dart` — añadir `subirAudioChat(...)`.
- `lib/features/chat/presentation/widgets/cards/audio_chat_card.dart` — **nuevo**, reproductor de nota de voz.
- `lib/features/chat/presentation/widgets/voice_record_button.dart` — **nuevo**, botón de grabación (press-and-hold).
- `lib/features/chat/presentation/pages/chat_screen.dart` — cablear grabación/envío, añadir case `'audio'` en `_buildMessageContent`, disparar `marcarComoLeidos` en `initState`.
- `functions/index.js` — añadir branch `'audio'` en `notifyOnNewChatMessage`.

---

### Task 1: Dependencias y `StoragePaths.chatAudios`

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/constants/storage_paths.dart`
- Test: `test/core/constants/storage_paths_test.dart`

**Interfaces:**
- Produces: `StoragePaths.chatAudios` (`String`, valor `'chat_audios'`).

- [ ] **Step 1: Añadir dependencias**

En `pubspec.yaml`, bajo `dependencies:`, añade:
```yaml
record: ^5.2.0
audioplayers: ^6.1.0
```
Ejecuta `flutter pub get`.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/constants/storage_paths_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/constants/storage_paths.dart';

void main() {
  test('StoragePaths.chatAudios está definido', () {
    expect(StoragePaths.chatAudios, 'chat_audios');
  });
}
```

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `flutter test test/core/constants/storage_paths_test.dart`
Expected: FAIL — `chatAudios` no existe en `StoragePaths`.

- [ ] **Step 4: Añadir la constante**

```dart
// lib/core/constants/storage_paths.dart
class StoragePaths {
  static const String perfiles = 'perfiles';
  static const String facturas = 'facturas';
  static const String chatAudios = 'chat_audios';
}
```

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/core/constants/storage_paths_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/core/constants/storage_paths.dart test/core/constants/storage_paths_test.dart
git commit -m "chore(chat): add record/audioplayers deps and chatAudios storage path"
```

---

### Task 2: Campo `duracionSegundos` en `MensajeModel` (Hive)

**Files:**
- Modify: `lib/core/models/mensaje_model.dart`
- Test: `test/core/models/mensaje_model_test.dart`

**Interfaces:**
- Produces: `MensajeModel.duracionSegundos` (`int?`, `@HiveField(9)`), incluido en `fromMap`/`toMap`.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/models/mensaje_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/mensaje_model.dart';

void main() {
  test('fromMap/toMap conservan duracionSegundos para mensajes de audio', () {
    final model = MensajeModel(
      id: 'm1',
      idRemitente: 'u1',
      contenido: '🎤 Nota de voz',
      tipo: 'audio',
      timestamp: DateTime(2026, 7, 31),
      urlArchivo: 'https://example.com/audio.m4a',
      duracionSegundos: 12,
    );

    expect(model.toMap()['duracion_segundos'], 12);

    final restored = MensajeModel.fromMap(model.toMap(), 'm1');
    expect(restored.duracionSegundos, 12);
  });

  test('duracionSegundos es null para mensajes de texto existentes (retrocompatibilidad)', () {
    final restored = MensajeModel.fromMap({
      'id_remitente': 'u1',
      'contenido': 'hola',
      'tipo': 'texto',
    }, 'm2');

    expect(restored.duracionSegundos, isNull);
  });
}
```

- [ ] **Step 2: Ejecutar test y verificar que falla**

Run: `flutter test test/core/models/mensaje_model_test.dart`
Expected: FAIL — `duracionSegundos` no existe en el constructor de `MensajeModel`.

- [ ] **Step 3: Añadir el campo al modelo**

En `lib/core/models/mensaje_model.dart`, añade:

```dart
@HiveField(9)
final int? duracionSegundos;
```

Al constructor, añade `this.duracionSegundos,`. En `fromMap`, añade `duracionSegundos: (map['duracion_segundos'] as num?)?.toInt(),`. En `toMap`, añade `if (duracionSegundos != null) 'duracion_segundos': duracionSegundos,`.

- [ ] **Step 4: Regenerar el adaptador Hive**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: `mensaje_model.g.dart` se regenera incluyendo el campo 9 en `MensajeModelAdapter`.

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/core/models/mensaje_model_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/mensaje_model.dart lib/core/models/mensaje_model.g.dart test/core/models/mensaje_model_test.dart
git commit -m "feat(chat): add duracionSegundos field to MensajeModel for voice notes"
```

---

### Task 3: `ChatProvider.subirAudioChat` (subida a Storage)

**Files:**
- Modify: `lib/features/chat/presentation/providers/chat_provider.dart`
- Test: `test/features/chat/presentation/providers/chat_provider_audio_test.dart`

**Interfaces:**
- Consumes: `StoragePaths.chatAudios` (Task 1).
- Produces: `Future<String?> subirAudioChat(String conversacionId, File audioFile)` → `Future<String?>` (URL de descarga o `null` si falla), calcado de `subirImagenChat`.

- [ ] **Step 1: Leer `subirImagenChat` completo (líneas 265-290 aprox.) para clonar el patrón exacto**

Confirma manejo de `_isLoading`, try/catch, y el nombre de archivo con timestamp.

- [ ] **Step 2: Escribir el test que falla**

Dado que `FirebaseStorage` no tiene un fake estándar usado en el proyecto (se confirmó que las imágenes tampoco se testean contra Storage real), el test cubre la parte determinística: construcción del nombre de archivo y manejo de estado ante fallo, usando un `ChatProvider` con un `MockFirebaseStorage`-like wrapper inyectado si el proyecto ya tiene uno en `test/helpers/test_helpers.mocks.dart` (confirmar antes de escribir). Si no existe mock de Storage, limita el test unitario a verificar que `_isLoading` se restablece incluso ante excepción, inyectando una función de subida fallida:

```dart
// test/features/chat/presentation/providers/chat_provider_audio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';

void main() {
  test('subirAudioChat retorna null y limpia isLoading si la subida falla', () async {
    // Se asume un ChatProvider testeable donde la dependencia de Storage puede
    // fallar de forma controlada al no existir el archivo indicado.
    final provider = ChatProvider();
    final result = await provider.subirAudioChat('conv1', File('/ruta/inexistente.m4a'));

    expect(result, isNull);
    expect(provider.isLoading, isFalse);
  });
}
```

Nota: revisa primero si `ChatProvider` ya acepta inyección de dependencias (constructor con `ChatRepository`) — si `FirebaseStorage.instance` está hardcodeado dentro del método (como en `subirImagenChat`), este test de fallo por archivo inexistente sigue siendo válido porque `File.readAsBytes()` lanzará antes de tocar Storage, ejercitando la rama catch sin red.

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `flutter test test/features/chat/presentation/providers/chat_provider_audio_test.dart`
Expected: FAIL — `subirAudioChat` no existe.

- [ ] **Step 4: Implementar `subirAudioChat`**

```dart
// lib/features/chat/presentation/providers/chat_provider.dart
Future<String?> subirAudioChat(String conversacionId, File audioFile) async {
  try {
    _isLoading = true;
    notifyListeners();

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
    final ref = FirebaseStorage.instance
        .ref()
        .child(StoragePaths.chatAudios)
        .child(conversacionId)
        .child(fileName);
    final bytes = await audioFile.readAsBytes();
    final metadata = SettableMetadata(contentType: 'audio/mp4');
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();

    _isLoading = false;
    notifyListeners();
    return url;
  } catch (e) {
    _error = e.toString();
    _isLoading = false;
    notifyListeners();
    return null;
  }
}
```

Añade el import `import 'dart:io';` y `import 'package:autodoc/core/constants/storage_paths.dart';` al inicio del archivo si no están presentes.

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/chat/presentation/providers/chat_provider_audio_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/presentation/providers/chat_provider.dart test/features/chat/presentation/providers/chat_provider_audio_test.dart
git commit -m "feat(chat): add subirAudioChat to ChatProvider"
```

---

### Task 4: `VoiceRecordButton` — grabación press-and-hold con `record`

**Files:**
- Create: `lib/features/chat/presentation/widgets/voice_record_button.dart`
- Test: `test/features/chat/presentation/widgets/voice_record_button_test.dart`

**Interfaces:**
- Produces: `VoiceRecordButton({required void Function(File audioFile, int duracionSegundos) onGrabacionCompleta})`, `StatefulWidget`.

- [ ] **Step 1: Verificar permisos de micrófono ya declarados**

Confirma que `permission_handler` (ya en `pubspec.yaml`) esté configurado para `Permission.microphone` en `android/app/src/main/AndroidManifest.xml` (`<uses-permission android:name="android.permission.RECORD_AUDIO"/>`) e `ios/Runner/Info.plist` (`NSMicrophoneUsageDescription`). Si faltan, añádelos siguiendo el mismo estilo que los permisos de cámara ya presentes (usados por `image_picker`).

- [ ] **Step 2: Escribir el test que falla (interacción básica de gesto)**

```dart
// test/features/chat/presentation/widgets/voice_record_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:autodoc/features/chat/presentation/widgets/voice_record_button.dart';

void main() {
  testWidgets('VoiceRecordButton renderiza el ícono de micrófono inactivo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VoiceRecordButton(onGrabacionCompleta: (File f, int d) {}),
      ),
    ));

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
```

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `flutter test test/features/chat/presentation/widgets/voice_record_button_test.dart`
Expected: FAIL — `voice_record_button.dart` no existe.

- [ ] **Step 4: Implementar el widget**

```dart
// lib/features/chat/presentation/widgets/voice_record_button.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:autodoc/core/theme/app_colors.dart';

class VoiceRecordButton extends StatefulWidget {
  final void Function(File audioFile, int duracionSegundos) onGrabacionCompleta;

  const VoiceRecordButton({super.key, required this.onGrabacionCompleta});

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _grabando = false;
  DateTime? _inicio;
  String? _rutaActual;

  Future<void> _iniciarGrabacion() async {
    final permiso = await Permission.microphone.request();
    if (!permiso.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requiere permiso de micrófono para grabar notas de voz')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    _rutaActual = '${dir.path}/nota_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: _rutaActual!);
    _inicio = DateTime.now();
    setState(() => _grabando = true);
  }

  Future<void> _detenerGrabacion() async {
    if (!_grabando) return;
    final ruta = await _recorder.stop();
    final duracion = _inicio == null ? 0 : DateTime.now().difference(_inicio!).inSeconds;
    setState(() => _grabando = false);

    if (ruta != null && duracion >= 1) {
      widget.onGrabacionCompleta(File(ruta), duracion);
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _iniciarGrabacion(),
      onLongPressEnd: (_) => _detenerGrabacion(),
      child: CircleAvatar(
        backgroundColor: _grabando ? Colors.red : AppColors.primary,
        child: Icon(_grabando ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
```

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/chat/presentation/widgets/voice_record_button_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/presentation/widgets/voice_record_button.dart test/features/chat/presentation/widgets/voice_record_button_test.dart android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat(chat): add press-and-hold voice recording button"
```

---

### Task 5: `AudioChatCard` — reproducción con `audioplayers`

**Files:**
- Create: `lib/features/chat/presentation/widgets/cards/audio_chat_card.dart`
- Test: `test/features/chat/presentation/widgets/cards/audio_chat_card_test.dart`

**Interfaces:**
- Consumes: `MensajeModel.urlArchivo`, `MensajeModel.duracionSegundos` (Task 2).
- Produces: `AudioChatCard({required String urlArchivo, required int? duracionSegundos, required bool isMe})`, `StatefulWidget`, calcado de `ImagenChatCard` en su firma (`isMe` para alinear a la derecha/izquierda).

- [ ] **Step 1: Leer `imagen_chat_card.dart` completo para copiar el patrón de burbuja (colores según `isMe`, padding, bordes)**

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/chat/presentation/widgets/cards/audio_chat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/audio_chat_card.dart';

void main() {
  testWidgets('AudioChatCard muestra botón de reproducir y duración formateada', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AudioChatCard(urlArchivo: 'https://example.com/a.m4a', duracionSegundos: 65, isMe: true),
      ),
    ));

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `flutter test test/features/chat/presentation/widgets/cards/audio_chat_card_test.dart`
Expected: FAIL — `audio_chat_card.dart` no existe.

- [ ] **Step 4: Implementar el widget**

```dart
// lib/features/chat/presentation/widgets/cards/audio_chat_card.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';

class AudioChatCard extends StatefulWidget {
  final String urlArchivo;
  final int? duracionSegundos;
  final bool isMe;

  const AudioChatCard({
    super.key,
    required this.urlArchivo,
    required this.duracionSegundos,
    required this.isMe,
  });

  @override
  State<AudioChatCard> createState() => _AudioChatCardState();
}

class _AudioChatCardState extends State<AudioChatCard> {
  final AudioPlayer _player = AudioPlayer();
  bool _reproduciendo = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _reproduciendo = false);
    });
  }

  Future<void> _toggle() async {
    if (_reproduciendo) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.urlArchivo));
    }
    setState(() => _reproduciendo = !_reproduciendo);
  }

  String get _duracionFormateada {
    final segundos = widget.duracionSegundos ?? 0;
    final min = segundos ~/ 60;
    final seg = (segundos % 60).toString().padLeft(2, '0');
    return '$min:$seg';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_reproduciendo ? Icons.pause : Icons.play_arrow, color: color),
            onPressed: _toggle,
          ),
          Text(_duracionFormateada, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/chat/presentation/widgets/cards/audio_chat_card_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/presentation/widgets/cards/audio_chat_card.dart test/features/chat/presentation/widgets/cards/audio_chat_card_test.dart
git commit -m "feat(chat): add AudioChatCard voice note player"
```

---

### Task 6: Cablear grabación → subida → envío en `chat_screen.dart`

**Files:**
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart`

**Interfaces:**
- Consumes: `VoiceRecordButton` (Task 4), `AudioChatCard` (Task 5), `ChatProvider.subirAudioChat` (Task 3).

- [ ] **Step 1: Leer `_pickAndSendImage` completo (líneas 689-722) como plantilla exacta del flujo subir→enviar**

- [ ] **Step 2: Añadir el método `_grabarYEnviarAudio`**

Justo después de `_pickAndSendImage`, añade:

```dart
Future<void> _grabarYEnviarAudio(
  File audioFile,
  int duracionSegundos,
  String userId,
  bool isMecanico,
  String receptorId,
) async {
  final provider = context.read<ChatProvider>();
  final url = await provider.subirAudioChat(widget.conversacionId, audioFile);

  if (!mounted) return;

  if (url != null) {
    provider.enviarMensaje(
      conversacionId: widget.conversacionId,
      contenido: '🎤 Nota de voz',
      remitenteId: userId,
      receptorId: receptorId,
      isMecanicoRemitente: isMecanico,
      tipo: 'audio',
      urlArchivo: url,
      metadata: {'duracion_segundos': duracionSegundos},
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo enviar la nota de voz')),
    );
  }
}
```

Nota: se envía `duracionSegundos` dentro de `metadata` en vez de como parámetro directo de `enviarMensaje`, porque `enviarMensaje` no tiene un parámetro `duracionSegundos` propio (ver `ChatProvider.enviarMensaje` — su firma actual no lo incluye) y el mensaje persistido usará `MensajeModel.fromMap`, que sí sabe leer `duracion_segundos` como clave de nivel superior. Verifica en `chat_repository.dart` cómo `enviarMensaje` construye el `MensajeModel` antes de escribir a Firestore: si construye el mapa manualmente con `tipo`/`urlArchivo`/`metadata`, añade ahí una línea que, cuando `tipo == 'audio'`, promueva `metadata['duracion_segundos']` a la clave raíz `duracion_segundos` del documento (para que `MensajeModel.fromMap` lo lea directo), o alternativamente añade `duracionSegundos` como parámetro explícito de `enviarMensaje` si se prefiere evitar ese paso intermedio — mantener el patrón más simple que no rompa las llamadas existentes a `enviarMensaje` sin ese argumento.

- [ ] **Step 3: Insertar `VoiceRecordButton` en la barra de envío**

Localiza el `Row` que contiene el `TextField` de mensaje y el botón de adjuntos (`_mostrarMenuAdjuntos`). Junto a él, añade:

```dart
VoiceRecordButton(
  onGrabacionCompleta: (file, duracion) => _grabarYEnviarAudio(file, duracion, userId, isMecanico, receptorId),
),
```

usando las mismas variables `userId`/`isMecanico`/`receptorId` ya resueltas en ese `build`/`Consumer` (las mismas que usa el botón de imagen).

- [ ] **Step 4: Añadir el case `'audio'` en `_buildMessageContent`**

Localiza el `switch (msg.tipo)` dentro de `_buildMessageContent` y añade:

```dart
case 'audio':
  return AudioChatCard(
    urlArchivo: msg.urlArchivo ?? '',
    duracionSegundos: msg.duracionSegundos ?? (msg.metadata?['duracion_segundos'] as num?)?.toInt(),
    isMe: msg.idRemitente == userId,
  );
```

(el fallback a `msg.metadata?['duracion_segundos']` cubre el caso de Step 2 si se optó por la ruta de metadata en vez de campo raíz).

- [ ] **Step 5: Verificar manualmente**

Run: `flutter run -d chrome` (nota: grabación de audio en Chrome requiere permisos del navegador; para probar en un dispositivo real usa `flutter run -d <android-device>`). Mantén presionado el botón de micrófono, suelta, confirma que la nota de voz se sube y aparece en el chat con controles de reproducción funcionales.

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/presentation/pages/chat_screen.dart lib/features/chat/data/repositories/chat_repository.dart
git commit -m "feat(chat): wire voice note recording, upload and playback into chat screen"
```

---

### Task 7: Cerrar el hueco de recibos de lectura — disparar `marcarComoLeidos` al abrir el chat

**Files:**
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart`
- Test: `test/features/chat/presentation/pages/chat_screen_read_receipts_test.dart`

**Interfaces:**
- Consumes: `ChatProvider.marcarComoLeidos(String conversacionId, bool isMecanico, String currentUserId)` (ya existe).

- [ ] **Step 1: Confirmar el hueco**

Lee `initState` de `chat_screen.dart` (línea ~49-53): hoy solo llama `context.read<ChatProvider>().inicializarMensajes(widget.conversacionId)`. `marcarComoLeidos` no se invoca ahí ni en ningún otro punto del ciclo de vida de la pantalla — por eso el doble check azul depende de que otra parte del código lo dispare manualmente, lo cual no es confiable.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/chat/presentation/pages/chat_screen_read_receipts_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
// ... imports de mocks del proyecto para UserProfileProvider/AuthSessionProvider según patrón existente

void main() {
  testWidgets('ChatScreen marca mensajes como leídos al abrir', (tester) async {
    // Sigue el mismo patrón de setup usado en reserva_detail_screen_test.dart
    // (mocks de Firestore/Auth vía test_helpers.mocks.dart) para montar
    // ChatScreen con una conversación de prueba y verificar que
    // ChatProvider.marcarComoLeidos fue invocado tras el primer frame.
  }, skip: true); // completar setup exacto de mocks siguiendo reserva_detail_screen_test.dart
}
```

Dado que `ChatScreen` depende de varios providers y de mocks de Firestore ya establecidos en `test/features/chat/presentation/pages/reserva_detail_screen_test.dart` (mencionado en la exploración previa), replica ese mismo andamiaje de test en vez de reinventarlo — lee ese archivo completo antes de completar este test y quita el `skip: true` una vez el setup esté igualado.

- [ ] **Step 3: Ejecutar test (documentar estado)**

Run: `flutter test test/features/chat/presentation/pages/chat_screen_read_receipts_test.dart`
Expected: el test con `skip: true` pasa trivialmente; quítalo tras completar el Step 2 con el setup real, y en ese punto debe FAIL antes del Step 4.

- [ ] **Step 4: Añadir la llamada en `initState`**

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final userId = context.read<AuthSessionProvider>().userId; // usar el getter real ya usado en el resto del archivo
    final isMecanico = /* misma lógica de rol ya usada en build() para determinar isMecanico */;
    context.read<ChatProvider>().inicializarMensajes(widget.conversacionId);
    context.read<ChatProvider>().marcarComoLeidos(widget.conversacionId, isMecanico, userId);
  });
}
```

Lee cómo `build()` calcula `isMecanico`/`userId` hoy (usados para el botón de imagen y el envío de mensajes) y reutiliza exactamente esa misma lógica en `initState`, en vez de duplicarla con una fuente de datos distinta.

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/chat/presentation/pages/chat_screen_read_receipts_test.dart`
Expected: PASS

- [ ] **Step 6: Verificar manualmente el doble check azul**

Run: `flutter run -d chrome` con dos sesiones (dos navegadores/perfiles) simulando propietario y taller. Envía un mensaje desde uno, abre el chat desde el otro, confirma que el remitente ve el ícono `Icons.done_all` azul en segundos.

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/presentation/pages/chat_screen.dart test/features/chat/presentation/pages/chat_screen_read_receipts_test.dart
git commit -m "fix(chat): trigger marcarComoLeidos on chat open so read receipts are reliable"
```

---

### Task 8: Texto de notificación push dedicado para notas de voz

**Files:**
- Modify: `functions/index.js`

**Interfaces:**
- Consumes: `exports.notifyOnNewChatMessage` (ya existe end-to-end).

- [ ] **Step 1: Leer el bloque `if/else if` que arma `title`/`body` según `msgData.tipo` dentro de `notifyOnNewChatMessage`**

- [ ] **Step 2: Añadir el branch de audio**

```js
// functions/index.js — dentro de notifyOnNewChatMessage, junto al branch de 'imagen'
} else if (msgData.tipo === 'audio') {
  body = '🎤 Nota de voz';
}
```

Colócalo en la misma cadena `if/else if` existente para `cotizacion_card`/`reserva_card`/`vehiculo_card`/`imagen`, siguiendo el estilo exacto ya presente.

- [ ] **Step 3: Verificar con emulador (o revisión de código si no hay emuladores configurados)**

Run: `firebase emulators:start --only functions,firestore` si el proyecto tiene emuladores configurados; crea un mensaje de prueba con `tipo: 'audio'` en `conversaciones/{id}/mensajes` y confirma en los logs de Functions que el `body` de la notificación es `'🎤 Nota de voz'`. Si no hay emuladores, deja constancia de que se verifica en el próximo despliegue.

- [ ] **Step 4: Commit**

```bash
git add functions/index.js
git commit -m "feat(chat): add dedicated push notification text for voice notes"
```

---

## Self-Review Notes

- **Cobertura del spec**: Notas de voz (Tasks 1-6), Recibos de lectura (Task 7 — la mayor parte ya existía, se cierra el hueco de activación), Notificaciones push por mensaje (Task 8 — la función ya existía end-to-end, solo se añade el texto de audio). Las 3 features del spec están cubiertas.
- **Decisión documentada**: no se creó un modelo `AudioModel` separado ni una colección nueva — el audio es un `tipo: 'audio'` más de `MensajeModel`, igual que ya ocurre con imágenes, para no fragmentar el modelo de datos del chat.
- **Riesgo a vigilar en ejecución**: Task 6 Step 2 señala una ambigüedad real (cómo persistir `duracionSegundos`: campo raíz vs. `metadata`) que debe resolverse leyendo `chat_repository.dart` en el momento de implementar, no asumirse de antemano.
