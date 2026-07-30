import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Se muestra cuando una ruta se abre sin el argumento que necesita —
/// por ejemplo al recargar la pagina o al compartir un enlace directo.
/// Sustituye a la pantalla en blanco que producia el cast de un `extra` nulo.
class MissingArgumentScreen extends StatelessWidget {
  final String mensaje;
  final String rutaVuelta;

  const MissingArgumentScreen({
    super.key,
    required this.mensaje,
    this.rutaVuelta = '/dashboard',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64),
              const SizedBox(height: 16),
              Text(mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(rutaVuelta),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
