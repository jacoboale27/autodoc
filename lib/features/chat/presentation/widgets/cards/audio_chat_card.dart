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
  bool _isToggling = false;
  // audioplayers v6: play(Source) siempre arranca desde el principio, incluso
  // si el player estaba en pausa. Para reanudar de verdad hace falta llamar
  // a resume(). Este flag distingue "primera reproducción / pista terminada"
  // (usa play()) de "reanudar tras pausa" (usa resume()).
  bool _hasStartedOnce = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _reproduciendo = false;
          _hasStartedOnce = false;
        });
      }
    });
  }

  Future<void> _toggle() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      if (_reproduciendo) {
        await _player.pause();
      } else if (_hasStartedOnce) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.urlArchivo));
        _hasStartedOnce = true;
      }
      if (mounted) setState(() => _reproduciendo = !_reproduciendo);
    } catch (e) {
      if (mounted) {
        setState(() => _reproduciendo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir la nota de voz')),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
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
    final colors = Theme.of(context).extension<AppColors>();
    final contentColor = widget.isMe
        ? Colors.white
        : (colors?.textPrimary ?? Colors.black87);

    // Sin fondo/borde propios: el burbujeo de color ya lo aporta el
    // Container en ChatScreen._buildMessageContent (igual que para los
    // mensajes de texto). Tener aquí una segunda burbuja duplicada además
    // dejaba el fondo fijo en gris claro, ilegible en modo oscuro.
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _reproduciendo ? Icons.pause : Icons.play_arrow,
              color: contentColor,
            ),
            onPressed: _isToggling ? null : _toggle,
          ),
          Text(_duracionFormateada, style: TextStyle(color: contentColor)),
        ],
      ),
    );
  }
}
