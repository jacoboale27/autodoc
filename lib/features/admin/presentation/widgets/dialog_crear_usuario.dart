import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';

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
    final colors = context.appColors;
    return AlertDialog(
      title: const Text('Crear Usuario'),
      content: AppDialogContent(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _nombreController,
                label: 'Nombre completo',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _correoController,
                label: 'Correo electrónico',
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _rolSeleccionado,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (v) => setState(() => _rolSeleccionado = v!),
              ),
              const SizedBox(height: 12),
              Text(
                'Se asignará una contraseña temporal genérica. El usuario '
                'deberá cambiarla desde "Olvidé mi contraseña" en el login.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          text: 'Cancelar',
          type: AppButtonType.text,
          size: AppButtonSize.small,
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        AppButton(
          text: 'Crear',
          size: AppButtonSize.small,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}
