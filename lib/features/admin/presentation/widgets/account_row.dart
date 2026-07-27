import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class AccountRow extends StatelessWidget {
  final UserModel usuario;
  final VoidCallback onSuspender;
  final VoidCallback onReactivar;
  final VoidCallback onCambiarRol;
  final bool isCurrentAdmin;

  const AccountRow({
    super.key,
    required this.usuario,
    required this.onSuspender,
    required this.onReactivar,
    required this.onCambiarRol,
    required this.isCurrentAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        child: Text(
          usuario.nombreCompleto.isNotEmpty
              ? usuario.nombreCompleto[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(usuario.nombreCompleto),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(usuario.correo),
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4, right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  usuario.rol.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: usuario.estado == 'activo'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  usuario.estado.toUpperCase(),
                  style: TextStyle(
                    color: usuario.estado == 'activo'
                        ? Colors.green[800]
                        : Colors.red[800],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'suspender') onSuspender();
          if (value == 'reactivar') onReactivar();
          if (value == 'rol') onCambiarRol();
        },
        itemBuilder: (context) => [
          if (usuario.estado == 'activo' && !isCurrentAdmin)
            PopupMenuItem(
              value: 'suspender',
              child: Text(
                context.l10n.adminSuspendAccount,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (usuario.estado == 'suspendido')
            PopupMenuItem(
              value: 'reactivar',
              child: Text(
                context.l10n.adminReactivateAccount,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          if (!isCurrentAdmin)
            PopupMenuItem(
              value: 'cambiar_rol',
              child: Text(context.l10n.adminChangeUserRole),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
