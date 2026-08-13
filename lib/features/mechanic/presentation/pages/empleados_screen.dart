import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/empleado_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

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
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: correoController,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña temporal',
                      ),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefonoController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (opcional)',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
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
    final isMobile = !AppBreakpoints.of(context).isAtLeastExpanded;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final idTallerPropietario = context
        .watch<UserProfileProvider>()
        .userData
        ?.idTallerPropietario;
    final esSubCuentaEmpleado =
        idTallerPropietario != null && idTallerPropietario.isNotEmpty;

    if (esSubCuentaEmpleado) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: isMobile
            ? AppBar(
                title: const Text('Empleados'),
                iconTheme: IconThemeData(color: colors.primary),
              )
            : null,
        drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
        body: Row(
          children: [
            if (!isMobile) const MechanicSidebar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(Responsive.padding(context, 32)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: Responsive.iconSize(context, 56),
                        color: colors.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Acceso restringido',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Solo el dueño del taller puede gestionar cuentas '
                        'de empleados.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              title: Text(
                'Empleados',
                style: GoogleFonts.inter(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.primary),
            )
          : null,
      drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoCrearEmpleado(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Empleado'),
      ),
      body: Row(
        children: [
          if (!isMobile) const MechanicSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isMobile)
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 32),
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: colors.textSecondary.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Text(
                      'EMPLEADOS',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: Responsive.fontSize(context, 20),
                        color: colors.primary,
                      ),
                    ),
                  ),
                Expanded(
                  child: Consumer<EmpleadoProvider>(
                    builder: (context, provider, _) {
                      final empleados = provider.empleados;
                      if (empleados.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              Responsive.padding(context, 32),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: Responsive.iconSize(context, 56),
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aún no tienes empleados',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Crea sub-cuentas para que tu personal '
                                  'pueda operar el panel del taller.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.all(
                          Responsive.padding(context, 24),
                        ),
                        itemCount: empleados.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final empleado = empleados[index];
                          return AppCard(
                            margin: EdgeInsets.zero,
                            padding: EdgeInsets.all(
                              Responsive.padding(context, 16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: colors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        empleado.nombreCompleto,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        empleado.correo,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: Responsive.fontSize(
                                            context,
                                            13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        empleado.rol == 'Recepcionista'
                                            ? 'Recepcionista'
                                            : 'Mecánico',
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: Responsive.fontSize(
                                            context,
                                            12,
                                          ),
                                        ),
                                      ),
                                      if (empleado.telefono != null &&
                                          empleado.telefono!.isNotEmpty)
                                        Text(
                                          empleado.telefono!,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: Responsive.fontSize(
                                              context,
                                              12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Switch(
                                      value: empleado.activo,
                                      onChanged: empleado.activo
                                          ? (_) =>
                                                _confirmarDesactivar(empleado)
                                          : null,
                                    ),
                                    Text(
                                      empleado.activo ? 'Activo' : 'Inactivo',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(
                                          context,
                                          11,
                                        ),
                                        color: empleado.activo
                                            ? colors.success
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
