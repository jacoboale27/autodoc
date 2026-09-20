import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Abre [urls] a pantalla completa, empezando por [inicial].
///
/// Observación del 2026-09-20: «todas las fotos públicas del mecánico
/// deberían poder hacerse grandes al darles click». Las miniaturas del perfil
/// miden 96 px y el banner se recorta a 3.2:1, así que no había forma de ver
/// una foto entera.
///
/// No hace nada si no hay ninguna URL: abrir un visor vacío sería peor que no
/// reaccionar al toque.
Future<void> abrirVisorDeImagenes(
  BuildContext context, {
  required List<String> urls,
  int inicial = 0,
}) {
  final limpias = urls.where((u) => u.trim().isNotEmpty).toList();
  if (limpias.isEmpty) return Future.value();
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VisorDeImagenes(
        urls: limpias,
        inicial: inicial.clamp(0, limpias.length - 1),
      ),
    ),
  );
}

/// Visor a pantalla completa: una foto por página, con zoom.
class VisorDeImagenes extends StatefulWidget {
  final List<String> urls;
  final int inicial;

  const VisorDeImagenes({super.key, required this.urls, this.inicial = 0});

  @override
  State<VisorDeImagenes> createState() => _VisorDeImagenesState();
}

class _VisorDeImagenesState extends State<VisorDeImagenes> {
  late final PageController _paginas = PageController(
    initialPage: widget.inicial,
  );
  late int _actual = widget.inicial;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final varias = widget.urls.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('visor_cerrar'),
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: varias
            ? Text(
                '${_actual + 1} / ${widget.urls.length}',
                style: const TextStyle(fontSize: 16),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _paginas,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _actual = i),
        itemBuilder: (context, i) => InteractiveViewer(
          // Con `minScale` en 1 la foto no se puede encoger por debajo de su
          // tamaño de pantalla, que es lo que se espera de un visor.
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: CachedNetworkImage(
              key: Key('visor_imagen_$i'),
              imageUrl: widget.urls[i],
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
