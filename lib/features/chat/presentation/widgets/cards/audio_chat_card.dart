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

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _reproduciendo = false);
    });
  }

  Future<void> _toggle() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      if (_reproduciendo) {
        await _player.pause();
      } else {
        await _player.play(UrlSource(widget.urlArchivo));
      }
      if (mounted) setState(() => _reproduciendo = !_reproduciendo);
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

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isMe
            ? (colors?.primary ?? Theme.of(context).colorScheme.primary)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
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
