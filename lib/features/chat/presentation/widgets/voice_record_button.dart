import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Botón de "mantener presionado para grabar" nota de voz.
///
/// Al soltar, si la grabación duró al menos 1 segundo, entrega el archivo
/// de audio grabado y su duración (en segundos) mediante [onGrabacionCompleta].
/// No sube el archivo ni crea ningún modelo: eso es responsabilidad del
/// llamador (ver `ChatProvider.subirAudioChat`).
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

  final AudioRecorder _recorder = AudioRecorder();
  bool _grabando = false;
  // Verdadero mientras el usuario sigue manteniendo el botón presionado.
  // Se usa para detectar que soltó (o se canceló el gesto) mientras aún
  // esperábamos el permiso de micrófono, y así no dejar una grabación
  // arrancando "a ciegas" sin forma de detenerla desde la UI.
  bool _deberiaGrabar = false;
  DateTime? _inicio;
  Timer? _limiteDuracionTimer;

  Future<void> _iniciarGrabacion() async {
    _deberiaGrabar = true;

    final permiso = await Permission.microphone.request();

    if (!_deberiaGrabar) {
      // El usuario ya soltó (o se canceló el gesto) mientras esperábamos
      // el permiso: no arrancar la grabación.
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
      // Se soltó/canceló mientras `start` estaba en vuelo: no dejar la
      // grabación corriendo sin control.
      await _recorder.cancel();
      return;
    }

    _inicio = DateTime.now();
    _limiteDuracionTimer?.cancel();
    _limiteDuracionTimer = Timer(_duracionMaxima, () {
      // Mismo camino que soltar el botón normalmente: detiene y entrega
      // la grabación acumulada hasta ahora.
      _detenerGrabacion();
    });
    if (mounted) setState(() => _grabando = true);
  }

  Future<void> _detenerGrabacion() async {
    _deberiaGrabar = false;
    _limiteDuracionTimer?.cancel();
    if (!_grabando) return;
    final ruta = await _recorder.stop();
    final duracion = _inicio == null
        ? 0
        : DateTime.now().difference(_inicio!).inSeconds;
    if (mounted) setState(() => _grabando = false);

    if (ruta != null && duracion >= 1) {
      widget.onGrabacionCompleta(File(ruta), duracion);
    }
  }

  @override
  void dispose() {
    _deberiaGrabar = false;
    _limiteDuracionTimer?.cancel();
    if (_grabando) {
      // Evita dejar un archivo .m4a huérfano si el widget se destruye
      // mientras hay una grabación en curso.
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
      onLongPressEnd: (_) => _detenerGrabacion(),
      onLongPressCancel: () => _detenerGrabacion(),
      child: CircleAvatar(
        backgroundColor: _grabando ? Colors.red : colorPrimario,
        child: Icon(_grabando ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
