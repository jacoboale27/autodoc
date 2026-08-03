import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

/// Formulario modal exclusivo de Superusuario para registrar una cuenta
/// manualmente sin perder la sesión propia (ver superUserCreateAccount en
/// functions/index.js). No incluye campo de contraseña: se asigna una
/// genérica en el backend y el usuario la cambia después vía "Olvidé mi
/// contraseña".
class DialogCrearUsuario extends StatefulWidget {
  const DialogCrearUsuario({super.key});

  @override
  State<DialogCrearUsuario> createState() => _DialogCrearUsuarioState();
}

class _DialogCrearUsuarioState extends State<DialogCrearUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  String _rolSeleccionado = 'Propietario';
  bool _isSubmitting = false;

  static const _roles = ['Propietario', 'Mecanico', 'Administrador'];

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final ok = await context.read<AdminProvider>().crearUsuario(
      nombreCompleto: _nombreController.text.trim(),
      correo: _correoController.text.trim(),
      rol: _rolSeleccionado,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Usuario'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _correoController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _rolSeleccionado,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _rolSeleccionado = v!),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se asignará una contraseña temporal genérica. El usuario '
              'deberá cambiarla desde "Olvidé mi contraseña" en el login.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
