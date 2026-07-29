import 'package:flutter/material.dart';

/// Shown when Firebase Core cannot start, before any Firebase service is used.
class FirebaseInitializationErrorScreen extends StatelessWidget {
  const FirebaseInitializationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 56),
                SizedBox(height: 20),
                Text(
                  'No pudimos iniciar AutoDoc',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'No fue posible conectar con Firebase. Verifica tu conexión e intenta recargar la página. Si el problema continúa, contacta al administrador de la aplicación.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirebaseInitializationErrorApp extends StatelessWidget {
  const FirebaseInitializationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FirebaseInitializationErrorScreen(),
    );
  }
}
