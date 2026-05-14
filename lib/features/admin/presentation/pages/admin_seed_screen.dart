import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pantalla que indicaba el estado de la migración de cuentas.
/// La semilla fue ejecutada con éxito y los secretos fueron eliminados por seguridad.
class AdminSeedScreen extends StatelessWidget {
  const AdminSeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Administradores'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'Migración Completada',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Las cuentas administrativas ya fueron configuradas y los secretos se eliminaron del código fuente por motivos de seguridad.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
