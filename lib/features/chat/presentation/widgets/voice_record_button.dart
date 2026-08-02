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
  final AudioRecorder _recorder = AudioRecorder();
  bool _grabando = false;
  DateTime? _inicio;
  String? _rutaActual;

  Future<void> _iniciarGrabacion() async {
    final permiso = await Permission.microphone.request();
    if (!permiso.isGranted) {
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
    _rutaActual =
        '${dir.path}/nota_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: _rutaActual!);
    _inicio = DateTime.now();
    if (mounted) setState(() => _grabando = true);
  }

  Future<void> _detenerGrabacion() async {
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
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorPrimario = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPressStart: (_) => _iniciarGrabacion(),
      onLongPressEnd: (_) => _detenerGrabacion(),
      child: CircleAvatar(
        backgroundColor: _grabando ? Colors.red : colorPrimario,
        child: Icon(_grabando ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
