import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class AccountRow extends StatelessWidget {
  final UserModel usuario;
  final VoidCallback onAprobar;
  final VoidCallback onSuspender;
  final VoidCallback onReactivar;
  final VoidCallback onCambiarRol;
  final VoidCallback onEliminar;
  final bool isCurrentAdmin;
  final bool canHardDelete;

  const AccountRow({
    super.key,
    required this.usuario,
    required this.onAprobar,
    required this.onSuspender,
    required this.onReactivar,
    required this.onCambiarRol,
    required this.onEliminar,
    required this.isCurrentAdmin,
    required this.canHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Fuente unica del semaforo: ambar pendiente, verde aprobada ('activo' Y
    // 'aprobado'), rojo suspendida/rechazada. Antes esto se decidia aqui con
    // `estado == 'activo'`, asi que una cuenta aprobada via aprobarTaller()
    // —que escribe 'aprobado'— se pintaba en rojo.
    final estadoStyle = AppEstadoCuenta.style(usuario.estado, context.appColors);

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
                  color: estadoStyle.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                // El icono acompaña al color: el estado no puede depender solo
                // de distinguir verde de rojo de ambar.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(estadoStyle.icon, size: 11, color: estadoStyle.color),
                    const SizedBox(width: 3),
                    Text(
                      estadoStyle.label.toUpperCase(),
                      style: TextStyle(
                        color: estadoStyle.color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'aprobar') onAprobar();
          if (value == 'suspender') onSuspender();
          if (value == 'reactivar') onReactivar();
          if (value == 'cambiar_rol') onCambiarRol();
          if (value == 'eliminar') onEliminar();
        },
        itemBuilder: (context) => [
          // Solo una cuenta PENDIENTE se aprueba. Antes la condicion era
          // `!= 'activo' && != 'suspendido'`, que dejaba pasar 'aprobado' y
          // por eso el menu ofrecia aprobar una cuenta ya aprobada.
          if (AppEstadoCuenta.admiteAprobacion(usuario.estado))
            PopupMenuItem(
              value: 'aprobar',
              child: Text(
                context.l10n.adminApproveAccount,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          if (AppEstadoCuenta.esAprobada(usuario.estado) && !isCurrentAdmin)
            PopupMenuItem(
              value: 'suspender',
              child: Text(
                context.l10n.adminSuspendAccount,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (AppEstadoCuenta.esSuspendida(usuario.estado))
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
          if (canHardDelete && !isCurrentAdmin && usuario.rol != 'Superusuario')
            const PopupMenuItem(
              value: 'eliminar',
              child: Text(
                'Eliminar cuenta (permanente)',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
