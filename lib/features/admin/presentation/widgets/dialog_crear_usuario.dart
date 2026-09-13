import 'package:flutter/material.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';

/// Crea una cuenta y entrega una invitacion de primera configuracion.
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
    final enlace = await context.read<AdminProvider>().crearUsuario(
      nombreCompleto: _nombreController.text.trim(),
      correo: _correoController.text.trim(),
      rol: _rolSeleccionado,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (enlace != null) {
      final l10n = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.securityInvitationReady),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text(l10n.securityDeliverLink), SelectableText(enlace)],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.securityInvitationSent),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
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
                AppLocalizations.of(context)!.securityDeliverLink,
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
