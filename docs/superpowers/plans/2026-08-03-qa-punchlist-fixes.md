# QA Punch List Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 12 bugs/gaps found during manual QA of AutoDoc: voice notes (storage + recording UI), blank quote messages, wrong reservation time + broken "ver detalle" link, the reported-reviews and reply-permission gaps in the reviews system, workshop employee/catalog Firebase permission errors, numeric-only price input, a fixed specialty list, and El Salvador license-plate formatting/validation.

**Architecture:** No new subsystems. Each task is a targeted fix inside the existing Clean Architecture + Provider layering (`lib/features/<feature>/{data,presentation}`), plus two `firestore.rules` corrections and one Cloud Function fix. Two tasks are pure ops (verifying/deploying already-committed-but-possibly-undeployed `storage.rules`/`firestore.rules`/Cloud Functions) rather than code changes — the investigation found the code for those bugs is already correct in the working tree, and the most likely cause is a stale deployment.

**Tech Stack:** Flutter/Dart (client), Cloud Firestore + Firebase Storage + Cloud Functions (Node.js, `functions/index.js`), `firebase-rules-unit-testing` (Mocha, `test/firestore_rules/rules.test.js`), `flutter_test` + `mockito`.

## Global Constraints

- Every Dart file touched must remain `dart format`-clean (project has a post-edit auto-format hook — no manual action needed, but don't fight it).
- Do not introduce new abstractions beyond what each bug needs — these are surgical fixes, not refactors.
- Any step that runs `firebase deploy` is **hard-gated behind explicit user confirmation** — per this project's operating rules, deploys are a shared-system action that must never run unattended. Subagents executing this plan must stop and ask before running deploy commands.
- Firestore/Storage rule changes must ship with a passing `test/firestore_rules/rules.test.js` case (Mocha) — do not hand-wave rule correctness.
- Reuse existing patterns already proven in this codebase: `actuaPorTaller()` for taller-employee-write parity (already used for `reparaciones`/`catalogo_servicios`), `_buildDropdownField` for fixed-choice fields, `TextInputFormatter` for input shaping (already used for plates via `PlateFormatter`).

---

## File Structure

| File | Responsibility |
|---|---|
| `docs/DEPLOY_VERIFICATION.md` *(new, optional artifact of Task 1)* | Checklist output of the deploy-lag investigation — not required, see Task 1 |
| `lib/features/chat/presentation/widgets/voice_record_button.dart` | Recording button — gets a WhatsApp-style overlay (timer, mic pulse, slide-to-cancel) |
| `test/features/chat/presentation/widgets/voice_record_button_test.dart` | Widget/unit tests for the button + new duration formatter |
| `lib/features/chat/presentation/providers/chat_provider.dart` | Gets a new `enviarCotizacion()` method that atomically creates+sends a quote and reports failure |
| `test/features/chat/presentation/chat_provider_test.dart` | Unit tests for `enviarCotizacion()` |
| `lib/features/chat/presentation/pages/chat_screen.dart` | Quote-send call site 1/3 — switches to `enviarCotizacion()` |
| `lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart` | Quote-send call site 2/3 (switches to `enviarCotizacion()`); also fixes the broken `/reserva_detail` navigation |
| `lib/features/chat/presentation/pages/reserva_detail_screen.dart` | Quote-send call site 3/3 — switches to `enviarCotizacion()` |
| `functions/index.js` | Fixes `notifyOnNewReservation`'s missing `Timestamp.toDate()` call |
| `firestore.rules` | Fixes the `resenias` reply rule to accept taller employee sub-accounts (`actuaPorTaller`) |
| `test/firestore_rules/rules.test.js` | New `resenias` describe-block covering report + owner-reply + employee-reply cases |
| `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart` | Wraps `reportReview()` in try/catch with user-visible error feedback |
| `lib/features/admin/presentation/pages/admin_resenias_screen.dart` | Adds pull-to-refresh so newly reported reviews show without a full app restart |
| `lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart` | Adds `inputFormatters` to the "precio" field (numeric only) |
| `lib/features/mechanic/presentation/pages/workshop_settings_screen.dart` | Converts "Especialidad" from free text to a fixed dropdown |
| `lib/core/constants/especialidades_taller.dart` *(new)* | Fixed list of workshop specialty categories |
| `lib/core/utils/plate_formatter.dart` | Extended to enforce the `P` particular-vehicle prefix and El Salvador hex-plate charset |
| `test/core/utils/plate_formatter_test.dart` *(new)* | Unit tests for the extended plate formatter + validator |
| `lib/features/dashboard/presentation/widgets/add_vehicle_form.dart` | Wraps the plate field in `Form`/`TextFormField` with the new validator |

---

## Task 1: Verify and (with confirmation) deploy pending Storage/Firestore rules and Cloud Functions

**Context:** Investigation found that the code for three reported bugs — voice notes failing to upload, workshops unable to add employees, workshops unable to add catalog items — is already correct and hardened in the working tree:
- `storage.rules:127-140` already has a correct `chat_audios/{conversacionId}/{fileName}` rule matching `ChatProvider.subirAudioChat` (`lib/features/chat/presentation/providers/chat_provider.dart:307-332`), added in commit `2792905` dated 2026-08-02 — **one day before this QA pass**.
- `firestore.rules:211-221`'s `catalogo_servicios` rule already uses the role-agnostic `actuaPorTaller(tallerId)` helper (`firestore.rules:95-100`), which was explicitly "Ampliado (fix de integracion de empleados)" per the comment at `firestore.rules:213-219`.
- `functions/index.js:1104` (`crearEmpleadoTaller`) exists, is named identically to the client's `httpsCallable('crearEmpleadoTaller')` call (`lib/features/mechanic/presentation/providers/empleado_provider.dart:59`), and was hardened across two dedicated fix commits (`37b3824`, `777e37a`).

All three symptoms match "code that was fixed and committed, but the fix may not have reached the live Firebase project." This task verifies deployment state before assuming further code changes are needed.

**Files:** None modified by default — this is a verification task. `firebase.json` is read-only reference.

- [ ] **Step 1: Confirm current deploy targets**

Run:
```bash
cat firebase.json
```
Confirm `"rules": "storage.rules"` under `storage`, `"rules": "firestore.rules"` under `firestore`, and the functions source dir — note the active Firebase project alias.

- [ ] **Step 2: Check which Firebase project is active**

Run:
```bash
firebase use
```
Report the active project ID (must match the project the QA testing happened against — if unsure, ask the user which project they tested against before proceeding).

- [ ] **Step 3: Diff local rules against deployed rules**

Run the `firebase-deploy-check` skill (already installed in this project) to get a read-only comparison of pending `firestore.rules`/`storage.rules` diffs and functions status:
```
/firebase-deploy-check
```
Record its output. If it reports no pending diff, the deploy-lag hypothesis is wrong and Bug (voice notes / employees / catalog) needs re-investigation with `superpowers:systematic-debugging` against the live project's actual rules/functions (pull them with `firebase firestore:rules get` / Functions console) rather than the local working tree.

- [ ] **Step 4: STOP — get explicit user confirmation before deploying**

Do not run any `firebase deploy` command without the user explicitly confirming they want it deployed now (this touches the live production/staging environment). Present the diff from Step 3 and ask.

- [ ] **Step 5: Deploy (only after confirmation)**

```bash
firebase deploy --only firestore:rules,storage:rules,functions:crearEmpleadoTaller,functions:desactivarEmpleadoTaller
```
(Scope the `--only` list to whatever Step 3 actually showed as pending — don't deploy unrelated functions as a side effect.)

- [ ] **Step 6: Manually re-verify the three symptoms**

Ask the user (or use the `run` skill if a device/emulator is available) to retest: sending a voice note, a workshop owner adding an employee, a workshop owner adding a catalog item. Record pass/fail — if any still fails after a confirmed-clean deploy, treat as a new bug and re-run `systematic-debugging` rather than assuming Task 1 covers it.

---

## Task 2: WhatsApp-style recording overlay for voice notes

**Files:**
- Modify: `lib/features/chat/presentation/widgets/voice_record_button.dart`
- Test: `test/features/chat/presentation/widgets/voice_record_button_test.dart`

**Interfaces:**
- Consumes: nothing new (still `VoiceRecordButton({required onGrabacionCompleta})`, same public API — `chat_screen.dart:551-559` needs no changes).
- Produces: a new top-level function `String formatearDuracionGrabacion(Duration d)` in `voice_record_button.dart`, returning `mm:ss` (e.g. `Duration(seconds: 5)` → `'0:05'`, `Duration(seconds: 65)` → `'1:05'`). Used internally and unit-testable without platform channels.

- [ ] **Step 1: Write the failing test for the duration formatter**

```dart
// test/features/chat/presentation/widgets/voice_record_button_test.dart
import 'package:autodoc/features/chat/presentation/widgets/voice_record_button.dart';

// add inside main(), alongside the existing testWidgets block:
test('formatearDuracionGrabacion pads seconds under 10', () {
  expect(formatearDuracionGrabacion(const Duration(seconds: 5)), '0:05');
});

test('formatearDuracionGrabacion rolls over minutes', () {
  expect(formatearDuracionGrabacion(const Duration(seconds: 65)), '1:05');
});

test('formatearDuracionGrabacion at zero', () {
  expect(formatearDuracionGrabacion(Duration.zero), '0:00');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chat/presentation/widgets/voice_record_button_test.dart`
Expected: FAIL — `formatearDuracionGrabacion` is not defined.

- [ ] **Step 3: Implement the formatter and the recording overlay**

Replace the full contents of `lib/features/chat/presentation/widgets/voice_record_button.dart` with:

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Formatea una duración como `m:ss` (p.ej. `Duration(seconds: 65)` -> `'1:05'`).
String formatearDuracionGrabacion(Duration d) {
  final minutos = d.inMinutes;
  final segundos = d.inSeconds % 60;
  return '$minutos:${segundos.toString().padLeft(2, '0')}';
}

/// Botón de "mantener presionado para grabar" nota de voz.
///
/// Al soltar, si la grabación duró al menos 1 segundo, entrega el archivo
/// de audio grabado y su duración (en segundos) mediante [onGrabacionCompleta].
/// No sube el archivo ni crea ningún modelo: eso es responsabilidad del
/// llamador (ver `ChatProvider.subirAudioChat`).
///
/// Mientras se graba, muestra un overlay estilo WhatsApp (temporizador +
/// indicador pulsante + "Desliza para cancelar") anclado sobre el botón.
class VoiceRecordButton extends StatefulWidget {
  final void Function(File audioFile, int duracionSegundos) onGrabacionCompleta;

  const VoiceRecordButton({super.key, required this.onGrabacionCompleta});

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  // Tope de duración de una nota de voz: acota el peor caso de tamaño de
  // archivo (todo se buffera en memoria vía File.readAsBytes antes de subir,
  // ver ChatProvider.subirAudioChat) sin necesitar un rediseño a streaming.
  static const Duration _duracionMaxima = Duration(seconds: 90);

  // Distancia horizontal (hacia la izquierda) que hay que arrastrar el dedo
  // mientras se mantiene presionado para cancelar la grabación, como en
  // WhatsApp ("Desliza para cancelar").
  static const double _distanciaCancelacion = -80;

  final AudioRecorder _recorder = AudioRecorder();
  bool _grabando = false;
  bool _deberiaGrabar = false;
  DateTime? _inicio;
  Timer? _limiteDuracionTimer;
  Timer? _tickTimer;
  Duration _transcurrido = Duration.zero;
  double _arrastreX = 0;
  bool _cancelacionArmada = false;
  OverlayEntry? _overlayEntry;

  Future<void> _iniciarGrabacion() async {
    _deberiaGrabar = true;

    final permiso = await Permission.microphone.request();

    if (!_deberiaGrabar) {
      return;
    }

    if (!permiso.isGranted) {
      _deberiaGrabar = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se requiere permiso de micrófono para grabar notas de voz',
            ),
          ),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final ruta =
        '${dir.path}/nota_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: ruta);

    if (!_deberiaGrabar) {
      await _recorder.cancel();
      return;
    }

    _inicio = DateTime.now();
    _transcurrido = Duration.zero;
    _arrastreX = 0;
    _cancelacionArmada = false;
    _limiteDuracionTimer?.cancel();
    _limiteDuracionTimer = Timer(_duracionMaxima, () {
      _detenerGrabacion();
    });
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_inicio == null) return;
      _transcurrido = DateTime.now().difference(_inicio!);
      _overlayEntry?.markNeedsBuild();
    });
    if (mounted) setState(() => _grabando = true);
    _mostrarOverlay();
  }

  Future<void> _detenerGrabacion({bool cancelar = false}) async {
    _deberiaGrabar = false;
    _limiteDuracionTimer?.cancel();
    _tickTimer?.cancel();
    _quitarOverlay();
    if (!_grabando) return;

    if (cancelar) {
      if (mounted) setState(() => _grabando = false);
      await _recorder.cancel();
      return;
    }

    final ruta = await _recorder.stop();
    final duracion = _inicio == null
        ? 0
        : DateTime.now().difference(_inicio!).inSeconds;
    if (mounted) setState(() => _grabando = false);

    if (ruta != null && duracion >= 1) {
      widget.onGrabacionCompleta(File(ruta), duracion);
    }
  }

  void _mostrarOverlay() {
    _quitarOverlay();
    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final colorTexto = _cancelacionArmada ? Colors.red : Colors.white;
        return Positioned(
          right: 16,
          bottom: 90,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    formatearDuracionGrabacion(_transcurrido),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_left, color: colorTexto, size: 18),
                  Text(
                    _cancelacionArmada ? 'Suelta para cancelar' : 'Desliza para cancelar',
                    style: TextStyle(color: colorTexto, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    overlayState.insert(_overlayEntry!);
  }

  void _quitarOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _deberiaGrabar = false;
    _limiteDuracionTimer?.cancel();
    _tickTimer?.cancel();
    _quitarOverlay();
    if (_grabando) {
      _recorder.cancel();
    }
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorPrimario = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPressStart: (_) => _iniciarGrabacion(),
      onLongPressMoveUpdate: (details) {
        if (!_grabando) return;
        _arrastreX = details.offsetFromOrigin.dx;
        final armado = _arrastreX <= _distanciaCancelacion;
        if (armado != _cancelacionArmada) {
          _cancelacionArmada = armado;
          _overlayEntry?.markNeedsBuild();
        }
      },
      onLongPressEnd: (_) =>
          _detenerGrabacion(cancelar: _cancelacionArmada),
      onLongPressCancel: () => _detenerGrabacion(cancelar: true),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mantén presionado para grabar una nota de voz'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: CircleAvatar(
        backgroundColor: _grabando ? Colors.red : colorPrimario,
        child: Icon(_grabando ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/chat/presentation/widgets/voice_record_button_test.dart`
Expected: PASS (all 4 tests — the pre-existing mic-icon test plus the 3 new formatter tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/presentation/widgets/voice_record_button.dart test/features/chat/presentation/widgets/voice_record_button_test.dart
git commit -m "feat(chat): add WhatsApp-style recording overlay to voice notes"
```

---

## Task 3: Fix blank cotización messages (null-guard the send)

**Context:** `ChatProvider.crearCotizacion` (`lib/features/chat/presentation/providers/chat_provider.dart:239-247`) catches Firestore errors and returns `null`. All three send call sites (`chat_screen.dart:732-748`, `reserva_chat_card.dart:113-122`, `reserva_detail_screen.dart:176-185`) ignore that and unconditionally send a `tipo: 'cotizacion_card'` message with `metadata: {'id_cotizacion': null, ...}`. The renderer, `CotizacionChatCard` (`lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart:154-158`), returns `const SizedBox.shrink()` when `id_cotizacion` is null — this is the blank bubble.

**Files:**
- Modify: `lib/features/chat/presentation/providers/chat_provider.dart:239-247` (add `enviarCotizacion`)
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart:732-748`
- Modify: `lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart:113-122`
- Modify: `lib/features/chat/presentation/pages/reserva_detail_screen.dart:176-185`
- Test: `test/features/chat/presentation/chat_provider_test.dart`

**Interfaces:**
- Produces: `Future<bool> ChatProvider.enviarCotizacion({required CotizacionModel cotizacion, required String conversacionId, required String contenido, required String remitenteId, required String receptorId, required bool isMecanicoRemitente})` — creates the quote, and only if it got a non-null id, sends the `cotizacion_card` message; returns `true` on full success, `false` if quote creation failed (in which case **no** message is sent and `ChatProvider.error` is set to a user-facing string).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/chat/presentation/chat_provider_test.dart — add a new group()
group('ChatProvider — enviarCotizacion', () {
  test('returns false and does not send a message when crearCotizacion fails', () async {
    when(mockChatRepository.crearCotizacion(any)).thenThrow(Exception('boom'));

    final cotizacion = CotizacionModel(
      id: '',
      idPropietario: 'owner1',
      idMecanico: 'mech1',
      items: const [],
      fecha: DateTime(2026, 1, 1),
    );

    final ok = await chatProvider.enviarCotizacion(
      cotizacion: cotizacion,
      conversacionId: 'conv1',
      contenido: 'He enviado una cotización.',
      remitenteId: 'mech1',
      receptorId: 'owner1',
      isMecanicoRemitente: true,
    );

    expect(ok, isFalse);
    expect(chatProvider.error, isNotNull);
    verifyNever(mockChatRepository.enviarMensaje(
      conversacionId: anyNamed('conversacionId'),
      mensaje: anyNamed('mensaje'),
      receptorId: anyNamed('receptorId'),
      isMecanicoRemitente: anyNamed('isMecanicoRemitente'),
    ));
  });

  test('returns true and sends the message when crearCotizacion succeeds', () async {
    when(mockChatRepository.crearCotizacion(any)).thenAnswer((_) async => 'cot1');
    when(mockChatRepository.enviarMensaje(
      conversacionId: anyNamed('conversacionId'),
      mensaje: anyNamed('mensaje'),
      receptorId: anyNamed('receptorId'),
      isMecanicoRemitente: anyNamed('isMecanicoRemitente'),
    )).thenAnswer((_) async {});

    final cotizacion = CotizacionModel(
      id: '',
      idPropietario: 'owner1',
      idMecanico: 'mech1',
      items: const [],
      fecha: DateTime(2026, 1, 1),
    );

    final ok = await chatProvider.enviarCotizacion(
      cotizacion: cotizacion,
      conversacionId: 'conv1',
      contenido: 'He enviado una cotización.',
      remitenteId: 'mech1',
      receptorId: 'owner1',
      isMecanicoRemitente: true,
    );

    expect(ok, isTrue);
    final captured = verify(mockChatRepository.enviarMensaje(
      conversacionId: anyNamed('conversacionId'),
      mensaje: captureAnyNamed('mensaje'),
      receptorId: anyNamed('receptorId'),
      isMecanicoRemitente: anyNamed('isMecanicoRemitente'),
    )).captured;
    final sentMensaje = captured.single as MensajeModel;
    expect(sentMensaje.metadata?['id_cotizacion'], 'cot1');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chat/presentation/chat_provider_test.dart`
Expected: FAIL — `enviarCotizacion` is not defined on `ChatProvider`.

- [ ] **Step 3: Implement `enviarCotizacion` in `ChatProvider`**

In `lib/features/chat/presentation/providers/chat_provider.dart`, replace the existing `crearCotizacion` method (lines 239-247) with:

```dart
  Future<String?> crearCotizacion(CotizacionModel cotizacion) async {
    try {
      return await _chatRepository.crearCotizacion(cotizacion);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Crea la cotización y, solo si se creó correctamente, envía el mensaje
  /// `cotizacion_card` que la referencia. Si la creación falla, no se envía
  /// ningún mensaje (antes se enviaba igual con `id_cotizacion: null`, lo
  /// que producía una burbuja en blanco — ver CotizacionChatCard).
  Future<bool> enviarCotizacion({
    required CotizacionModel cotizacion,
    required String conversacionId,
    required String contenido,
    required String remitenteId,
    required String receptorId,
    required bool isMecanicoRemitente,
  }) async {
    final cotizacionId = await crearCotizacion(cotizacion);
    if (cotizacionId == null) {
      _error = 'No se pudo crear la cotización. Intenta de nuevo.';
      notifyListeners();
      return false;
    }

    await enviarMensaje(
      conversacionId: conversacionId,
      contenido: contenido,
      remitenteId: remitenteId,
      receptorId: receptorId,
      isMecanicoRemitente: isMecanicoRemitente,
      tipo: 'cotizacion_card',
      metadata: {'id_cotizacion': cotizacionId, 'estado': 'pendiente'},
    );
    return true;
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/chat/presentation/chat_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Update call site 1 — `chat_screen.dart:732-748`**

Replace:
```dart
                          final cotizacionId = await provider.crearCotizacion(
                            cotizacion,
                          );

                          await provider.enviarMensaje(
                            conversacionId: widget.conversacionId,
                            contenido:
                                'He creado una nueva cotización para tu vehículo.',
                            remitenteId: userId,
                            receptorId: receptorId,
                            isMecanicoRemitente: isMecanico,
                            tipo: 'cotizacion_card',
                            metadata: {
                              'id_cotizacion': cotizacionId,
                              'estado': 'pendiente',
                            },
                          );
```
with:
```dart
                          final ok = await provider.enviarCotizacion(
                            cotizacion: cotizacion,
                            conversacionId: widget.conversacionId,
                            contenido:
                                'He creado una nueva cotización para tu vehículo.',
                            remitenteId: userId,
                            receptorId: receptorId,
                            isMecanicoRemitente: isMecanico,
                          );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.error ??
                                      'No se pudo enviar la cotización.',
                                ),
                              ),
                            );
                          }
```

- [ ] **Step 6: Update call site 2 — `reserva_chat_card.dart:113-123`**

Replace:
```dart
          final cotizacionId = await chatProvider.crearCotizacion(cotizacion);

          await chatProvider.enviarMensaje(
            conversacionId: conversacionId,
            contenido: 'He enviado una cotización para tu cita solicitada.',
            remitenteId: userId,
            receptorId: receptorId,
            isMecanicoRemitente: true,
            tipo: 'cotizacion_card',
            metadata: {'id_cotizacion': cotizacionId, 'estado': 'pendiente'},
          );
```
with:
```dart
          final ok = await chatProvider.enviarCotizacion(
            cotizacion: cotizacion,
            conversacionId: conversacionId,
            contenido: 'He enviado una cotización para tu cita solicitada.',
            remitenteId: userId,
            receptorId: receptorId,
            isMecanicoRemitente: true,
          );
          if (!ok) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    chatProvider.error ?? 'No se pudo enviar la cotización.',
                  ),
                ),
              );
            }
            return;
          }
```
(the `return;` prevents the subsequent `_actualizar(context, 'cotizada', ...)` call a few lines below from running when the quote never got sent — read the surrounding 10 lines after this edit to confirm the early return lands before that call, per `reserva_chat_card.dart:125-130` from the investigation excerpt.)

- [ ] **Step 7: Update call site 3 — `reserva_detail_screen.dart:176-186`**

Replace:
```dart
          final cotizacionId = await chatProvider.crearCotizacion(cotizacion);

          await chatProvider.enviarMensaje(
            conversacionId: reserva.idConversacion,
            contenido: 'He enviado una cotización para tu cita solicitada.',
            remitenteId: userId,
            receptorId: reserva.idPropietario,
            isMecanicoRemitente: true,
            tipo: 'cotizacion_card',
            metadata: {'id_cotizacion': cotizacionId, 'estado': 'pendiente'},
          );
```
with:
```dart
          final ok = await chatProvider.enviarCotizacion(
            cotizacion: cotizacion,
            conversacionId: reserva.idConversacion,
            contenido: 'He enviado una cotización para tu cita solicitada.',
            remitenteId: userId,
            receptorId: reserva.idPropietario,
            isMecanicoRemitente: true,
          );
          if (!ok) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    chatProvider.error ?? 'No se pudo enviar la cotización.',
                  ),
                ),
              );
            }
            return;
          }
```
(same reasoning: prevent the subsequent `reservaProvider.cambiarEstadoReserva(reserva.id, 'cotizada', ...)` at `reserva_detail_screen.dart:188-192` from running on a failed send.)

- [ ] **Step 8: Run the full chat test suite**

Run: `flutter test test/features/chat/`
Expected: PASS — no regressions in the surrounding chat provider/repository tests.

- [ ] **Step 9: Commit**

```bash
git add lib/features/chat/presentation/providers/chat_provider.dart lib/features/chat/presentation/pages/chat_screen.dart lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart lib/features/chat/presentation/pages/reserva_detail_screen.dart test/features/chat/presentation/chat_provider_test.dart
git commit -m "fix(chat): guard cotización send against blank message when creation fails"
```

---

## Task 4: Fix reservation time shown to mechanic (missing `.toDate()` in push notification)

**Context:** `exports.notifyOnNewReservation` in `functions/index.js:514-533` builds its notification body from `reserva.fecha_hora_propuesta` — a raw Firestore Admin `Timestamp` object — using `new Date(reserva.fecha_hora_propuesta).toLocaleDateString()`, which does not correctly convert a `Timestamp`. Every other place in the same file does this correctly (`functions/index.js:559-560`, `:710-711`) via `.toDate()`. This is the one function that fires exactly when a reservation is sent — matching the reported "mechanic always sees the wrong time."

**Files:**
- Modify: `functions/index.js:514-533`
- Test: `functions/test/` — check for an existing test file covering `notifyOnNewReservation` before adding a new one (see Step 1).

**Interfaces:** No signature changes — internal fix only.

- [ ] **Step 1: Check for existing Cloud Functions tests**

Run:
```bash
ls functions/test/ 2>/dev/null || ls functions/*.test.js 2>/dev/null
```
If a test file already covers `notifyOnNewReservation`, add the failing case there. If none exists, skip straight to Step 3 (implementation) and note in the commit message that this fix has no automated regression test because the Cloud Functions test harness doesn't cover notification triggers yet — do not invent a new test framework for one fix.

- [ ] **Step 2 (only if a functions test harness exists): Write the failing test**

Follow whatever pattern the existing file uses to invoke `notifyOnNewReservation` with a Firestore `Timestamp`-bearing snapshot and assert the notification body contains the correctly formatted date (not `Invalid Date` / `NaN`).

- [ ] **Step 3: Fix the two `new Date(...)` calls**

In `functions/index.js`, inside `exports.notifyOnNewReservation` (around lines 514-533), replace both occurrences of:
```js
${reserva.fecha_hora_propuesta ? new Date(reserva.fecha_hora_propuesta).toLocaleDateString() : 'día propuesto'}
```
with:
```js
${reserva.fecha_hora_propuesta ? reserva.fecha_hora_propuesta.toDate().toLocaleDateString('es') : 'día propuesto'}
```
(matching the `.toDate().toLocaleDateString('es')` pattern already used at `functions/index.js:559-560`). Apply this to both the push `body` (~line 518) and the persisted notification-center `body` (~line 530).

- [ ] **Step 4: Run the fixed function through the emulator (manual smoke check, since no automated test may exist)**

```bash
cd functions && npm run build --if-present; firebase emulators:start --only functions,firestore
```
In another terminal, create a `reservas/{id}` document with a `fecha_hora_propuesta` Firestore Timestamp via the emulator UI or a small script, and confirm the emulator logs show a correctly formatted date string (not `Invalid Date`).

- [ ] **Step 5: Commit**

```bash
git add functions/index.js
git commit -m "fix(functions): convert Timestamp before formatting in notifyOnNewReservation"
```

---

## Task 5: Fix "ver detalle" navigating to a not-found page

**Context:** `reserva_chat_card.dart:360-365` calls `context.push('/reserva_detail', extra: metadata['id_reserva'] as String)`. The only registered route is `GoRoute(path: '/reserva_detail/:reservaId', ...)` (`lib/core/router/app_router.dart:563-578`), which reads the id from the path parameter, not from `extra`. `context.push('/reserva_detail')` (no id segment) matches nothing → go_router's not-found handler fires. The correct pattern is already used elsewhere in the same codebase, e.g. `functions/index.js:600` (`` `/reserva_detail/${context.params.reservaId}` ``) and the legacy-link normalizer at `lib/features/dashboard/presentation/pages/notifications_screen.dart:12-27`.

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart:357-376`
- Test: check for an existing widget test file for `reserva_chat_card.dart` before writing a new one.

**Interfaces:** No signature changes.

- [ ] **Step 1: Check for an existing test file**

```bash
find test -iname "*reserva_chat_card*"
```

- [ ] **Step 2: Write (or add to) the failing test**

If a test file exists, add this case; if not, create `test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart` following the same `MaterialApp.router` + `GoRouter` test pattern used elsewhere in this repo for route assertions (check `test/core/router/` for the established pattern first and mirror it — do not invent a different router-testing approach). The test must assert that tapping "Ver detalle" with `metadata = {'id_reserva': 'r1'}` results in navigation to a location matching `/reserva_detail/r1` (not the bare `/reserva_detail`).

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart`
Expected: FAIL — current code navigates to `/reserva_detail` with no id segment.

- [ ] **Step 4: Fix the navigation call**

In `lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart`, replace (lines 360-365):
```dart
                    onPressed: metadata['id_reserva'] == null
                        ? null
                        : () => context.push(
                            '/reserva_detail',
                            extra: metadata['id_reserva'] as String,
                          ),
```
with:
```dart
                    onPressed: metadata['id_reserva'] == null
                        ? null
                        : () => context.push(
                            '/reserva_detail/${metadata['id_reserva']}',
                          ),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart
git commit -m "fix(chat): route 'ver detalle' to /reserva_detail/:reservaId instead of a bare path"
```

---

## Task 6: Reported reviews reach the admin (error handling + live refresh)

**Context:** No permission or field-name mismatch was found — `reportReview()` writes `is_reported: true` to `resenias/{id}` (`lib/features/reviews/data/services/review_service.dart:266-269`), the admin query reads the same collection/field (`lib/features/admin/data/repositories/admin_repository.dart:106-114`, `lib/features/admin/presentation/pages/admin_resenias_screen.dart:99-101`), and `firestore.rules:390-403` already permits both the write and a fully public read. The two real gaps: (1) `reportReview()` is called with **no try/catch** at the only call site (`lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart:382-401`), so any failure — including a stale-rules failure per Task 1 — is silent, matching "as if it was never reported"; (2) the admin screen fetches once in `initState` with no live listener or refresh affordance (`admin_resenias_screen.dart:23-29`), so a report made while the admin already has the page open won't appear without a manual app restart.

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart:382-401`
- Modify: `lib/features/admin/presentation/pages/admin_resenias_screen.dart`
- Test: `test/features/mechanic/` and `test/features/admin/` — check existing patterns first.

**Interfaces:** No signature changes to `ReviewService.reportReview` or `AdminRepository.getResenias`.

- [ ] **Step 1: Fix silent failure on report**

In `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart`, replace (lines 382-401):
```dart
                                                              if (confirm ==
                                                                  true) {
                                                                await reviewService
                                                                    .reportReview(
                                                                      r.idResenia,
                                                                    );
                                                                if (context
                                                                    .mounted) {
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    const SnackBar(
                                                                      content: Text(
                                                                        'Reseña reportada para moderación.',
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                              }
```
with:
```dart
                                                              if (confirm ==
                                                                  true) {
                                                                try {
                                                                  await reviewService
                                                                      .reportReview(
                                                                        r.idResenia,
                                                                      );
                                                                  if (context
                                                                      .mounted) {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      const SnackBar(
                                                                        content: Text(
                                                                          'Reseña reportada para moderación.',
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }
                                                                } catch (e) {
                                                                  if (context
                                                                      .mounted) {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      SnackBar(
                                                                        content: Text(
                                                                          'No se pudo reportar la reseña: $e',
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }
                                                                }
                                                              }
```

- [ ] **Step 2: Add pull-to-refresh to the admin reviews screen**

Read `lib/features/admin/presentation/pages/admin_resenias_screen.dart` in full first to find the widget that wraps the review list (a `ListView`/`Column` inside the body). Wrap that list in a `RefreshIndicator`:
```dart
RefreshIndicator(
  onRefresh: () => context.read<AdminProvider>().fetchAllData(),
  child: /* existing list widget */,
)
```
Match whatever the existing list widget's exact identifier is — do not guess a variable name; use the one found while reading the file.

- [ ] **Step 3: Manual verification (no existing rules/permission bug to unit test — behavior is UI-level)**

Run the app (`run` skill or `flutter run`), report a review as a taller account, then as an admin account pull-to-refresh the reseñas screen and confirm it appears. Also verify: temporarily throw inside a debug build of `reportReview` to confirm the new catch block surfaces a SnackBar instead of failing silently — revert the temporary throw afterward.

- [ ] **Step 4: Commit**

```bash
git add lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart lib/features/admin/presentation/pages/admin_resenias_screen.dart
git commit -m "fix(reviews): surface report failures and let admin refresh reported reviews live"
```

---

## Task 7: Fix "insufficient permissions" when a workshop replies to a review

**Context:** `firestore.rules:394-396` gates the `respuesta_taller` update with a direct `resource.data.id_taller == request.auth.uid` check. Every other collection with this same owner-vs-employee shape (`reparaciones`, `catalogo_servicios`) was migrated to use the `actuaPorTaller(tallerId)` helper (`firestore.rules:95-100`), which also accepts an employee sub-account whose `usuarios/{uid}.id_taller_propietario == tallerId`. `resenias` was missed. A taller-employee account replying to a review gets `request.auth.uid` (their own uid) ≠ `resource.data.id_taller` (the owner's uid) → `PERMISSION_DENIED`, surfaced by `lib/features/reviews/data/services/review_service.dart:256-263` as "verifica que esta reseña pertenezca a tu taller."

**Files:**
- Modify: `firestore.rules:394-396`
- Test: `test/firestore_rules/rules.test.js`

**Interfaces:** No Dart-side signature changes — `ReviewService.responderResenia` already just performs the Firestore update; the rule is the only thing that changes.

- [ ] **Step 1: Write the failing rules test**

Add a new `describe` block to `test/firestore_rules/rules.test.js` (place it near other collection-specific describe blocks, following the existing `seedUser`/`getAuthedDb`/`assertFails`/`assertSucceeds` conventions already in the file):

```js
  describe('6b. Resenias — reply permissions', () => {
    async function seedResenia(id, ownerUid, tallerUid) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('resenias').doc(id).set({
          id_resenia: id,
          id_usuario: ownerUid,
          id_taller: tallerUid,
          id_servicio: 'servicio1',
          estrellas: 5,
          comentario: 'Buen trabajo',
        });
      });
    }

    it('allows the taller owner to reply', async () => {
      await seedResenia('r1', 'owner1', 'taller1');
      await seedUser('taller1', 'Taller');
      const db = getAuthedDb('taller1');
      await assertSucceeds(
        db.collection('resenias').doc('r1').update({
          respuesta_taller: { texto: 'Gracias!', fecha: new Date() },
        })
      );
    });

    it('denies a random authenticated user from replying', async () => {
      await seedResenia('r2', 'owner1', 'taller1');
      await seedUser('random1', 'Propietario');
      const db = getAuthedDb('random1');
      await assertFails(
        db.collection('resenias').doc('r2').update({
          respuesta_taller: { texto: 'Gracias!', fecha: new Date() },
        })
      );
    });

    it('allows a taller employee sub-account to reply on behalf of the owner', async () => {
      await seedResenia('r3', 'owner1', 'taller1');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('usuarios').doc('empleado1').set({
          id_usuario: 'empleado1',
          nombre_completo: 'Empleado Uno',
          correo: 'empleado1@test.com',
          rol: 'Mecanico',
          id_taller_propietario: 'taller1',
        });
      });
      const db = getAuthedDb('empleado1');
      await assertSucceeds(
        db.collection('resenias').doc('r3').update({
          respuesta_taller: { texto: 'Gracias!', fecha: new Date() },
        })
      );
    });
  });
```

- [ ] **Step 2: Run the rules test suite to verify the employee case fails**

Run:
```bash
cd test/firestore_rules && npm test
```
Expected: the "taller employee sub-account" test FAILS (`assertSucceeds` rejects a `PERMISSION_DENIED`); the owner and random-user tests PASS already.

- [ ] **Step 3: Fix the rule**

In `firestore.rules`, replace (lines 394-396):
```
        || (resource.data.id_taller == request.auth.uid
          && request.resource.data.diff(resource.data)
               .affectedKeys().hasOnly(['respuesta_taller']))
```
with:
```
        || (actuaPorTaller(resource.data.id_taller)
          && request.resource.data.diff(resource.data)
               .affectedKeys().hasOnly(['respuesta_taller']))
```

- [ ] **Step 4: Run the rules test suite to verify all three pass**

Run:
```bash
cd test/firestore_rules && npm test
```
Expected: PASS — all three new cases, and no regression in the rest of `rules.test.js`.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules test/firestore_rules/rules.test.js
git commit -m "fix(rules): let taller employee sub-accounts reply to reviews via actuaPorTaller"
```

*(Note: this rule change still needs to reach production — fold it into Task 1's deploy step, or deploy it separately with the same confirmation gate.)*

---

## Task 8: Numeric-only "precio" field in the catalog form

**Context:** `catalogo_servicios_screen.dart:105-118`'s price `TextFormField` only sets `keyboardType: TextInputType.number`, which merely changes the on-screen keyboard hint — it does not block typed characters on desktop/web or a physical keyboard, and validation only runs on submit.

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart:105-118`
- Test: check for an existing widget test covering this dialog before writing a new one.

**Interfaces:** No signature changes.

- [ ] **Step 1: Check for an existing test**

```bash
find test -iname "*catalogo_servicios_screen*"
```

- [ ] **Step 2: Write (or add to) the failing test**

If no test file exists for this screen, create `test/features/mechanic/presentation/pages/catalogo_servicios_screen_test.dart` with a minimal `testWidgets` that pumps the dialog's `TextFormField` in isolation (find it via its `key` or `labelText: 'Precio unitario'`), enters `'12a.5b'` via `tester.enterText`, and asserts the resulting field text is `'12.5'` (non-digit/non-dot characters stripped). If a test file already exists for the wider screen, add this case to it instead of creating a duplicate file.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/mechanic/presentation/pages/catalogo_servicios_screen_test.dart`
Expected: FAIL — letters currently pass through untouched.

- [ ] **Step 4: Add `inputFormatters`**

In `lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart`, replace (lines 105-118):
```dart
                    TextFormField(
                      controller: precioController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario',
                      ),
                      validator: (v) {
                        final precio = double.tryParse(v?.trim() ?? '');
                        if (precio == null || precio <= 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
```
with:
```dart
                    TextFormField(
                      controller: precioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario',
                      ),
                      validator: (v) {
                        final precio = double.tryParse(v?.trim() ?? '');
                        if (precio == null || precio <= 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
```
Add `import 'package:flutter/services.dart';` at the top of the file if it isn't already imported (check first — `TextInputFormatter`/`FilteringTextInputFormatter` live there).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/mechanic/presentation/pages/catalogo_servicios_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart test/features/mechanic/presentation/pages/catalogo_servicios_screen_test.dart
git commit -m "fix(mechanic): restrict catalog price field to numeric input"
```

---

## Task 9: Fixed "Especialidad" dropdown instead of free text

**Context:** `workshop_settings_screen.dart:356-368` uses `_buildInputField` (free-text) for "Especialidad". The same file already has `_buildDropdownField` (`workshop_settings_screen.dart:513-...`), used for "Departamento"/"Municipio" immediately below. No fixed specialty taxonomy exists anywhere in the codebase yet (only a dynamically-derived, already-inconsistent list in `admin_talleres_screen.dart:404-411`) — one needs to be defined.

**Files:**
- Create: `lib/core/constants/especialidades_taller.dart`
- Modify: `lib/features/mechanic/presentation/pages/workshop_settings_screen.dart:356-368`
- Test: `test/core/constants/especialidades_taller_test.dart`

**Interfaces:**
- Produces: `const List<String> especialidadesTaller` in the new constants file — later tasks/screens that need the same fixed list (e.g. a future filter rework of `workshop_directory_screen.dart`) should import this instead of re-deriving one.

- [ ] **Step 1: Write the failing test for the constants list**

```dart
// test/core/constants/especialidades_taller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/constants/especialidades_taller.dart';

void main() {
  test('especialidadesTaller is non-empty and has no duplicates', () {
    expect(especialidadesTaller, isNotEmpty);
    expect(especialidadesTaller.toSet().length, especialidadesTaller.length);
  });

  test('especialidadesTaller contains the expected core categories', () {
    expect(especialidadesTaller, contains('Mecánica General'));
    expect(especialidadesTaller, contains('Frenos'));
    expect(especialidadesTaller, contains('Transmisión'));
    expect(especialidadesTaller, contains('Eléctrico'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/especialidades_taller_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Create the constants file**

```dart
// lib/core/constants/especialidades_taller.dart

/// Lista fija de especialidades que un taller puede seleccionar en su
/// configuración. Reemplaza el campo de texto libre anterior para evitar
/// valores inconsistentes (mayúsculas/minúsculas, sinónimos, typos) que
/// antes hacían inútil cualquier filtro por especialidad.
const List<String> especialidadesTaller = [
  'Mecánica General',
  'Frenos',
  'Transmisión',
  'Eléctrico',
  'Suspensión y Dirección',
  'Motor',
  'Aire Acondicionado',
  'Diagnóstico Computarizado',
  'Carrocería y Pintura',
  'Llantas y Alineación',
  'Inyección Electrónica',
  'Enfriamiento',
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/especialidades_taller_test.dart`
Expected: PASS.

- [ ] **Step 5: Swap the free-text field for a dropdown**

In `lib/features/mechanic/presentation/pages/workshop_settings_screen.dart`, add the import:
```dart
import 'package:autodoc/core/constants/especialidades_taller.dart';
```
Then replace (lines 356-368):
```dart
                                    _buildInputField(
                                      label: 'Especialidad',
                                      controller: _specialtyController,
                                      icon: Icons.build_circle,
                                      hint:
                                          'Ej: Mecánica General, Frenos, Transmisión...',
                                      colors: colors,
                                      isDark: isDark,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Requerido'
                                          : null,
                                    ),
```
with:
```dart
                                    _buildDropdownField(
                                      label: 'Especialidad',
                                      value: especialidadesTaller.contains(
                                            _specialtyController.text,
                                          )
                                          ? _specialtyController.text
                                          : null,
                                      items: especialidadesTaller,
                                      icon: Icons.build_circle,
                                      colors: colors,
                                      isDark: isDark,
                                      onChanged: (val) {
                                        setState(() {
                                          _specialtyController.text = val ?? '';
                                        });
                                      },
                                    ),
```
Note `_buildDropdownField` (per its signature read at `workshop_settings_screen.dart:513-522`) doesn't take a `validator` — read the surrounding save logic (where `_specialtyController.text.trim()` is persisted, at `workshop_settings_screen.dart:177`) to confirm a required-field check still exists at save time; if the save path already validates the whole form via a `Form`/`GlobalKey<FormState>`, add an equivalent explicit null/empty check for the dropdown's selection there since `DropdownButtonFormField` validators need a `validator:` param — pass one if `_buildDropdownField` is extended to accept it, or add a manual check alongside the other manual checks already in the save handler (mirror the pattern used for "Nombre del Taller" immediately above it).

- [ ] **Step 6: Manual verification**

Run the app, open workshop settings as a taller account, confirm "Especialidad" now renders a dropdown pre-selected with the taller's current value (or blank if it doesn't match the fixed list), and that saving persists the selection.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/especialidades_taller.dart lib/features/mechanic/presentation/pages/workshop_settings_screen.dart test/core/constants/especialidades_taller_test.dart
git commit -m "feat(mechanic): replace free-text specialty field with a fixed dropdown list"
```

---

## Task 10: El Salvador license plate formatting and validation

**Context:** `add_vehicle_form.dart` has no `Form`/`validator` at all (only a manual non-empty check at line 613-620) and `PlateFormatter` (`lib/core/utils/plate_formatter.dart`) doesn't prefix "P" or restrict the character set. El Salvador private-vehicle ("particular") plates follow `P###-###` — a mandatory leading `P`, then digits/letters, with a mandatory hyphen after the 3rd character following the `P`. The user describes the alphanumeric portion as "hexadecimal" (i.e., digits `0-9` plus letters `A-F`). This task: (1) auto-prefixes `P` if the user starts typing digits/letters directly, (2) auto-inserts the hyphen after the 3rd character following `P`, (3) restricts input to the hex charset, (4) adds a `Form`+`validator` enforcing the final `P###-###` shape (hex chars only).

**Files:**
- Modify: `lib/core/utils/plate_formatter.dart`
- Modify: `lib/features/dashboard/presentation/widgets/add_vehicle_form.dart`
- Test: `test/core/utils/plate_formatter_test.dart` *(new)*

**Interfaces:**
- Produces: `RegExp placaElSalvadorPattern` (matches a complete valid plate, e.g. `P1A2-3B4`) and `String? validarPlacaElSalvador(String? value)` (a `FormFieldValidator<String>`-compatible function) in `plate_formatter.dart` — importable by any other vehicle form later.

- [ ] **Step 1: Write the failing formatter/validator tests**

```dart
// test/core/utils/plate_formatter_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/plate_formatter.dart';

TextEditingValue _apply(PlateFormatter f, String input) {
  return f.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: input, selection: TextSelection.collapsed(offset: input.length)),
  );
}

void main() {
  group('PlateFormatter', () {
    late PlateFormatter formatter;
    setUp(() => formatter = PlateFormatter());

    test('auto-prefixes P when the user types digits first', () {
      final result = _apply(formatter, '1a2');
      expect(result.text, 'P1A2');
    });

    test('does not double-prefix when the user already typed P', () {
      final result = _apply(formatter, 'p1a2');
      expect(result.text, 'P1A2');
    });

    test('inserts a hyphen after the 3rd character following P', () {
      final result = _apply(formatter, 'P1A23B4');
      expect(result.text, 'P1A-23B');
    });

    test('rejects non-hex letters (keeps only 0-9A-F)', () {
      final result = _apply(formatter, 'PZZZ111');
      expect(result.text, 'P111');
    });

    test('caps total length at P + 3 + hyphen + 3', () {
      final result = _apply(formatter, 'P1234567890');
      expect(result.text, 'P123-456');
    });
  });

  group('validarPlacaElSalvador', () {
    test('accepts a complete valid plate', () {
      expect(validarPlacaElSalvador('P1A2-3B4'), isNull);
    });

    test('rejects a plate missing the hyphen', () {
      expect(validarPlacaElSalvador('P1A23B4'), isNotNull);
    });

    test('rejects a plate without the P prefix', () {
      expect(validarPlacaElSalvador('1A2-3B4'), isNotNull);
    });

    test('rejects empty input', () {
      expect(validarPlacaElSalvador(''), isNotNull);
      expect(validarPlacaElSalvador(null), isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/utils/plate_formatter_test.dart`
Expected: FAIL — current formatter doesn't prefix `P`, doesn't restrict to hex chars, and `validarPlacaElSalvador` doesn't exist.

- [ ] **Step 3: Rewrite `plate_formatter.dart`**

```dart
import 'package:flutter/services.dart';

/// Formatea una placa de vehículo particular de El Salvador: prefijo `P`
/// obligatorio, seguido de 3 caracteres hexadecimales (0-9, A-F), un guion
/// obligatorio, y 3 caracteres hexadecimales más (p.ej. `P1A2-3B4`).
class PlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll('-', '');

    // Solo caracteres hexadecimales (0-9, A-F) y, temporalmente mientras se
    // escribe, la P inicial.
    text = text.replaceAll(RegExp(r'[^0-9A-F]'), '');

    // Prefijo P obligatorio: si el usuario empezó a escribir sin ella,
    // se antepone automáticamente.
    if (!text.startsWith('P')) {
      text = 'P$text';
    }
    // Evita una segunda P si el usuario la volvió a escribir después del
    // prefijo automático.
    if (text.length > 1) {
      text = 'P${text.substring(1).replaceAll('P', '')}';
    }

    // Tope: P + 3 + 3 = 7 caracteres útiles (el guion se agrega aparte).
    if (text.length > 7) {
      text = text.substring(0, 7);
    }

    var formatted = text;
    if (text.length > 4) {
      formatted = '${text.substring(0, 4)}-${text.substring(4)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Patrón completo de una placa válida de vehículo particular: `P` + 3
/// caracteres hexadecimales + guion + 3 caracteres hexadecimales.
final RegExp placaElSalvadorPattern = RegExp(r'^P[0-9A-F]{3}-[0-9A-F]{3}$');

/// Validador de formulario para el campo de placa. Devuelve `null` si es
/// válida, o un mensaje de error para mostrar en el `TextFormField`.
String? validarPlacaElSalvador(String? value) {
  final placa = value?.trim().toUpperCase() ?? '';
  if (placa.isEmpty) {
    return 'La placa es obligatoria';
  }
  if (!placaElSalvadorPattern.hasMatch(placa)) {
    return 'Formato inválido. Usa P123-456 (particular, El Salvador)';
  }
  return null;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/plate_formatter_test.dart`
Expected: PASS.

- [ ] **Step 5: Wrap the add-vehicle form in a `Form` and wire the validator**

Read `lib/features/dashboard/presentation/widgets/add_vehicle_form.dart` in full to find: the class's build method's top-level returned widget (to wrap in `Form`), and the `_buildTextField` helper (`add_vehicle_form.dart:791-837`) to see if it currently returns a plain `TextField` or can be switched to `TextFormField` without breaking its other callers (the form has multiple fields using this same helper — check each one to confirm none of them break if the helper starts returning a `TextFormField` instead of `TextField`, since `TextFormField` requires being inside a `Form` ancestor to validate but degrades gracefully to acting like a plain field otherwise).

Then:
1. Add `final _formKey = GlobalKey<FormState>();` as a state field.
2. Wrap the existing top-level scrollable content in `Form(key: _formKey, child: ...)`.
3. Change the `_buildTextField` helper to build a `TextFormField` instead of `TextField`, adding a `validator` parameter (`String? Function(String?)? validator`) that defaults to `null` so existing callers are unaffected, and pass it through to the underlying `TextFormField(validator: validator, ...)`.
4. Update the plate field's call site (currently `add_vehicle_form.dart:514-520`) to pass the new validator:
```dart
_buildTextField(
  context.l10n.addVehiclePlate,
  context.l10n.addVehiclePlateHint,
  _placaController,
  Icons.badge,
  formatters: [PlateFormatter()],
  validator: validarPlacaElSalvador,
),
```
(add `import 'package:autodoc/core/utils/plate_formatter.dart';` if not already present — it likely already is, given `PlateFormatter` is already used here).
5. In the save handler (`add_vehicle_form.dart:611-620` area), replace the manual empty-check for the placa with a full form validation call before the existing `anio`/`color` manual checks:
```dart
                if (!(_formKey.currentState?.validate() ?? false)) {
                  return;
                }
```
placed as the first check inside the `onPressed` callback, ahead of the `anio`/`color` checks that are staying as manual checks (do not convert those in this task — out of scope).

- [ ] **Step 6: Run the widget test suite for this form**

```bash
find test -iname "*add_vehicle_form*"
```
If a test file exists, run it and fix any regressions caused by the `Form` wrap (e.g. a test that previously entered an unformatted plate and expected the old behavior). If none exists, do a manual run: `flutter run`, open "agregar vehículo," type `123abc` into the plate field, confirm it renders as `P123-` then `P123-ABC` as more characters are typed, and confirm submitting with an incomplete plate shows the new validator error instead of silently proceeding.

- [ ] **Step 7: Commit**

```bash
git add lib/core/utils/plate_formatter.dart lib/features/dashboard/presentation/widgets/add_vehicle_form.dart test/core/utils/plate_formatter_test.dart
git commit -m "feat(vehicles): enforce El Salvador P###-### plate format with auto-prefix and validation"
```

---

## Execution Order Note

Tasks 3, 4, 5, 6, 7 (chat/reservations/reviews) are independent of each other and of Tasks 8-10 (workshop forms/vehicle form). Task 1 should run **first** since it may resolve 3 of the reported symptoms without any further code change, and Task 7's rule fix should be folded into whichever deploy happens (Task 1's or a follow-up) since a rules test passing locally does not fix production by itself.
