import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/empleado_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';

/// Pantalla de gestión de sub-cuentas de empleados de un taller: lista los
/// empleados vinculados (`talleres/{idTaller}/empleados`), permite
/// desactivarlos y crear nuevos via la Cloud Function `crearEmpleadoTaller`.
///
/// Solo el dueño del taller debe llegar aquí. `MechanicSidebar` oculta el
/// link para sub-cuentas y `crearEmpleadoTaller` rechaza a un empleado que
/// invoque el callable directamente (ambos verifican
/// `id_taller_propietario`, no `rol`: un empleado también tiene
/// `rol == 'Taller'`, igual que el dueño). Pero un empleado podría llegar
/// aquí por URL directa (`context.go('/mechanic/empleados')` a mano, o un
/// deep link), así que esta pantalla repite la misma verificación
/// (defensa en profundidad, capa 3 de 3: sidebar oculto, esta pantalla,
/// Cloud Function) en vez de asumir que si llegó aquí es porque es el
/// dueño.
class EmpleadosScreen extends StatefulWidget {
  final String idTaller;

  const EmpleadosScreen({super.key, required this.idTaller});

  @override
  State<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends State<EmpleadosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idTallerPropietario = context
          .read<UserProfileProvider>()
          .userData
          ?.idTallerPropietario;
      final esSubCuentaEmpleado =
          idTallerPropietario != null && idTallerPropietario.isNotEmpty;
      // Un empleado nunca debe disparar watchTaller: firestore.rules ya lo
      // rechazaría (solo el propio tallerId puede leer su subcolección de
      // empleados), pero evitamos incluso el intento de lectura fallido.
      if (!esSubCuentaEmpleado) {
        context.read<EmpleadoProvider>().watchTaller(widget.idTaller);
      }
    });
  }

  Future<void> _confirmarDesactivar(EmpleadoModel empleado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar empleado'),
        content: Text(
          '¿Seguro que deseas desactivar a "${empleado.nombreCompleto}"? '
          'Se deshabilitará su cuenta y dejará de poder iniciar sesión '
          'en el panel del taller.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await context.read<EmpleadoProvider>().desactivar(
        widget.idTaller,
        empleado.idEmpleado,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${empleado.nombreCompleto} desactivado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _mostrarDialogoCrearEmpleado(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final correoController = TextEditingController();
    final passwordController = TextEditingController();
    final telefonoController = TextEditingController();
    final provider = context.read<EmpleadoProvider>();
    String rolSeleccionado = 'Mecanico';

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isLoading = provider.isLoading;
          return AlertDialog(
            scrollable: true,
            title: const Text('Nuevo empleado'),
            content: AppDialogContent(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'Nombre completo',
                      isRequired: true,
                      controller: nombreController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Correo',
                      isRequired: true,
                      controller: correoController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Contraseña temporal',
                      isRequired: true,
                      controller: passwordController,
                      obscureText: true,
                      helperText: 'Mínimo 6 caracteres',
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Teléfono (opcional)',
                      controller: telefonoController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: rolSeleccionado,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Mecanico',
                          child: Text('Mecánico'),
                        ),
                        DropdownMenuItem(
                          value: 'Recepcionista',
                          child: Text('Recepcionista'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => rolSeleccionado = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() {});
                        final ok = await provider.crearEmpleado(
                          correo: correoController.text.trim(),
                          password: passwordController.text,
                          nombreCompleto: nombreController.text.trim(),
                          rol: rolSeleccionado,
                          telefono: telefonoController.text.trim().isEmpty
                              ? null
                              : telefonoController.text.trim(),
                        );
                        setDialogState(() {});
                        // Cierra el teclado antes de mostrar el SnackBar
                        // (flotante en todo el tema, ver app_theme.dart): con
                        // el teclado abierto el Scaffold detras del dialogo
                        // queda tan bajo que el SnackBar flotante no cabe y
                        // dispara "Floating SnackBar presented off screen".
                        FocusManager.instance.primaryFocus?.unfocus();
                        if (ok) {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Empleado creado correctamente'),
                              ),
                            );
                          }
                        } else if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                provider.error ??
                                    'No se pudo crear el empleado.',
                              ),
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );

    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
    telefonoController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idTallerPropietario = context
        .watch<UserProfileProvider>()
        .userData
        ?.idTallerPropietario;
    final esSubCuentaEmpleado =
        idTallerPropietario != null && idTallerPropietario.isNotEmpty;

    return MechanicScaffold(
      title: 'Empleados',
      floatingActionButton: esSubCuentaEmpleado
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _mostrarDialogoCrearEmpleado(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo Empleado'),
            ),
      body: esSubCuentaEmpleado
          ? const AppEmptyState(
              title: 'Acceso restringido',
              description:
                  'Solo el dueño del taller puede gestionar cuentas de '
                  'empleados.',
              icon: Icons.lock_outline,
            )
          : Consumer<EmpleadoProvider>(
              builder: (context, provider, _) {
                final empleados = provider.empleados;
                if (empleados.isEmpty) {
                  return const AppEmptyState(
                    title: 'Aún no tienes empleados',
                    description:
                        'Crea sub-cuentas para que tu personal pueda operar '
                        'el panel del taller.',
                    icon: Icons.badge_outlined,
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppPageBody(
                    child: AppGrid(
                      compactColumns: 1,
                      mediumColumns: 2,
                      expandedColumns: 2,
                      largeColumns: 3,
                      spacing: AppSpacing.base,
                      childAspectRatio: 2.4,
                      children: [
                        for (final empleado in empleados)
                          _EmpleadoCard(
                            empleado: empleado,
                            onDesactivar: () => _confirmarDesactivar(empleado),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmpleadoCard extends StatelessWidget {
  final EmpleadoModel empleado;
  final VoidCallback onDesactivar;

  const _EmpleadoCard({required this.empleado, required this.onDesactivar});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rol = empleado.rol == 'Recepcionista' ? 'Recepcionista' : 'Mecánico';

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  empleado.nombreCompleto,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  empleado.correo,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                // El estado se comunica con texto además de con color: a un
                // usuario con daltonismo el verde y el gris le llegan igual.
                _EstadoChip(activo: empleado.activo, rol: rol),
              ],
            ),
          ),
          if (empleado.activo)
            IconButton(
              icon: Icon(Icons.person_off_outlined, color: colors.error),
              tooltip: 'Desactivar a ${empleado.nombreCompleto}',
              onPressed: onDesactivar,
            ),
        ],
      ),
    );
  }
}

/// Estado de un empleado como texto además de color: el verde y el gris
/// solos no bastan para un usuario con daltonismo.
class _EstadoChip extends StatelessWidget {
  final bool activo;
  final String rol;

  const _EstadoChip({required this.activo, required this.rol});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = activo ? colors.success : colors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        activo ? '$rol · Activo' : '$rol · Inactivo',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}
