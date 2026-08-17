import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';

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
        AppSnackbar.show(
          context,
          'Se requiere permiso de micrófono para grabar notas de voz',
          type: SnackbarType.error,
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
        final colors = ctx.appColors;
        final colorTexto = _cancelacionArmada ? colors.error : Colors.white;
        final duracionTexto = formatearDuracionGrabacion(_transcurrido);
        final cancelacionTexto = _cancelacionArmada
            ? 'Suelta para cancelar'
            : 'Desliza para cancelar';
        return Positioned(
          right: 16,
          bottom: 90,
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              liveRegion: true,
              label: 'Grabando nota de voz, $duracionTexto. $cancelacionTexto.',
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: colors.error,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        duracionTexto,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.chevron_left, color: colorTexto, size: 18),
                      Text(
                        cancelacionTexto,
                        style: TextStyle(color: colorTexto, fontSize: 12),
                      ),
                    ],
                  ),
                ),
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
    final colors = context.appColors;
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
      onLongPressEnd: (_) => _detenerGrabacion(cancelar: _cancelacionArmada),
      onLongPressCancel: () => _detenerGrabacion(cancelar: true),
      onTap: () {
        AppSnackbar.show(
          context,
          'Mantén presionado para grabar una nota de voz',
        );
      },
      child: Semantics(
        label: _grabando
            ? 'Grabando nota de voz, ${formatearDuracionGrabacion(_transcurrido)}. '
                  'Suelta para enviar, desliza a la izquierda para cancelar.'
            : 'Grabar nota de voz. Mantén presionado.',
        button: true,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircleAvatar(
              backgroundColor: _grabando ? colors.error : colors.primary,
              child: Icon(
                _grabando ? Icons.stop : Icons.mic,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
