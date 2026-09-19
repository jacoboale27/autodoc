import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/empleado_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';
import 'package:autodoc/core/models/invitacion_empleo_model.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';

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
/// Diálogo "Nuevo empleado" como StatefulWidget propio (no un
/// StatefulBuilder inline): sus TextEditingController deben liberarse en
/// `State.dispose()`, que el framework llama recién cuando el Element del
/// diálogo se desmonta de verdad (tras terminar la animación de salida).
/// Antes se llamaba `.dispose()` justo después del `await showDialog(...)`,
/// pero ese Future se completa apenas se invoca `Navigator.pop()`, ANTES de
/// que termine esa animación — el diálogo seguía reconstruyéndose con un
/// controller ya liberado, causando "A TextEditingController was used after
/// being disposed" y una cascada de errores de framework (pantalla roja).
/// El SnackBar de éxito se muestra desde `_mostrarDialogoCrearEmpleado` (con
/// el `context` de la pantalla, ya que el diálogo se cierra devolviendo
/// `true`), no desde acá.
class _NuevoEmpleadoDialog extends StatefulWidget {
  final EmpleadoProvider provider;

  const _NuevoEmpleadoDialog({required this.provider});

  @override
  State<_NuevoEmpleadoDialog> createState() => _NuevoEmpleadoDialogState();
}

class _NuevoEmpleadoDialogState extends State<_NuevoEmpleadoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  String _rolSeleccionado = 'Mecanico';

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {});
    final resultado = await widget.provider.crearEmpleado(
      correo: _correoController.text.trim(),
      password: _passwordController.text,
      nombreCompleto: _nombreController.text.trim(),
      rol: _rolSeleccionado,
      telefono: _telefonoController.text.trim().isEmpty
          ? null
          : _telefonoController.text.trim(),
    );
    if (!mounted) return;
    setState(() {});
    // Cierra el teclado antes de mostrar el SnackBar (flotante en todo el
    // tema, ver app_theme.dart): con el teclado abierto el Scaffold detras
    // del dialogo queda tan bajo que el SnackBar flotante no cabe y dispara
    // "Floating SnackBar presented off screen".
    FocusManager.instance.primaryFocus?.unfocus();
    if (resultado != null) {
      Navigator.pop(context, resultado);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.provider.error ?? 'No se pudo crear el empleado.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.provider.isLoading;
    return AlertDialog(
      scrollable: true,
      title: const Text('Nuevo empleado'),
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
                label: 'Correo',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _passwordController,
                label: 'Contraseña temporal',
                obscureText: true,
                obscureToggle: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              // Observaciones del 2026-09-19: con un correo que ya tenía
              // cuenta, el alta fallaba con «Ese dato ya existe». Ahora se le
              // invita, y conviene saberlo antes de pulsar "Crear".
              Text(
                'Si esa persona ya tiene cuenta en AutoDoc, le llegará una '
                'invitación a sus notificaciones y conservará su propia '
                'contraseña.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _telefonoController,
                label: 'Teléfono (opcional)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _rolSeleccionado,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'Mecanico', child: Text('Mecánico')),
                  DropdownMenuItem(
                    value: 'Recepcionista',
                    child: Text('Recepcionista'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _rolSeleccionado = value);
                  }
                },
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
          onPressed: isLoading ? null : () => Navigator.pop(context),
        ),
        AppButton(
          text: 'Crear',
          size: AppButtonSize.small,
          isLoading: isLoading,
          onPressed: isLoading ? null : _crear,
        ),
      ],
    );
  }
}

class EmpleadosScreen extends StatefulWidget {
  final String idTaller;

  const EmpleadosScreen({super.key, required this.idTaller});

  @override
  State<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends State<EmpleadosScreen> {
  /// idEmpleado cuya desactivación está en vuelo. `EmpleadoProvider.isLoading`
  /// no gobierna el botón de la tarjeta, que es el defecto: la protección va
  /// donde está el botón, y por empleado, no global.
  final Set<String> _desactivando = <String>{};

  /// Invitaciones cuyo retiro está en vuelo (mismo guard que [_desactivando]).
  final Set<String> _retirando = <String>{};

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
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            text: 'Desactivar',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // El diálogo se cierra al confirmar: sin esta guarda se podía reabrir y
    // confirmar otra vez mientras la primera desactivación seguía en vuelo.
    if (_desactivando.contains(empleado.idEmpleado)) return;
    setState(() => _desactivando.add(empleado.idEmpleado));

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
        ).showSnackBar(SnackBar(content: Text(mensajeSeguroDeError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _desactivando.remove(empleado.idEmpleado));
      }
    }
  }

  Future<void> _mostrarDialogoCrearEmpleado(BuildContext context) async {
    final provider = context.read<EmpleadoProvider>();
    final resultado = await showDialog<ResultadoAltaEmpleado>(
      context: context,
      builder: (dialogContext) => _NuevoEmpleadoDialog(provider: provider),
    );
    if (resultado == null || !context.mounted) return;
    final mensaje = switch (resultado) {
      ResultadoAltaEmpleado.creado => 'Empleado creado correctamente',
      ResultadoAltaEmpleado.reactivado =>
        'Ese empleado ya había trabajado en tu taller: volvió a quedar '
            'activo, con la contraseña temporal que pusiste.',
      ResultadoAltaEmpleado.reactivadoConSuContrasena =>
        'Ese empleado ya había trabajado en tu taller y volvió a quedar '
            'activo. Entra con su propia contraseña: la cuenta es suya, así '
            'que la temporal que pusiste no se usó.',
      ResultadoAltaEmpleado.invitado =>
        'Ese correo ya tiene cuenta en AutoDoc: le enviamos una invitación. '
            'Cuando la acepte desde sus notificaciones, aparecerá en tu lista.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: resultado == ResultadoAltaEmpleado.creado
            ? const Duration(seconds: 4)
            : const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _retirarInvitacion(InvitacionEmpleoModel invitacion) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar invitación'),
        content: Text(
          '¿Retirar la invitación a "${invitacion.nombreCompleto}"? Si '
          'intenta aceptarla después, le dirá que ya no está disponible.',
        ),
        actions: [
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            text: 'Retirar',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (_retirando.contains(invitacion.idInvitado)) return;
    setState(() => _retirando.add(invitacion.idInvitado));
    final provider = context.read<EmpleadoProvider>();
    final ok = await provider.retirarInvitacion(
      widget.idTaller,
      invitacion.idInvitado,
    );
    if (!mounted) return;
    setState(() => _retirando.remove(invitacion.idInvitado));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'No se pudo retirar la invitación.'),
        ),
      );
    }
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
                final ahora = DateTime.now();
                final invitaciones = provider.invitaciones
                    .where((i) => !i.caducada(ahora))
                    .toList();
                if (empleados.isEmpty && invitaciones.isEmpty) {
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (invitaciones.isNotEmpty) ...[
                          const AppSectionHeader(
                            title: 'Invitaciones pendientes',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (final invitacion in invitaciones) ...[
                            _InvitacionCard(
                              invitacion: invitacion,
                              retirando: _retirando.contains(
                                invitacion.idInvitado,
                              ),
                              onRetirar: () => _retirarInvitacion(invitacion),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        if (empleados.isNotEmpty)
                          AppGrid(
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
                                  onDesactivar: () =>
                                      _confirmarDesactivar(empleado),
                                  desactivando: _desactivando.contains(
                                    empleado.idEmpleado,
                                  ),
                                ),
                            ],
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

  /// Mientras la desactivación de este empleado sigue en vuelo el botón no
  /// acepta taps, para que no se pueda reabrir el diálogo de confirmación.
  final bool desactivando;

  const _EmpleadoCard({
    required this.empleado,
    required this.onDesactivar,
    this.desactivando = false,
  });

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
              onPressed: desactivando ? null : onDesactivar,
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

/// Una invitación enviada a alguien que ya tenía cuenta, esperando que la
/// acepte (observaciones del 2026-09-19).
class _InvitacionCard extends StatelessWidget {
  final InvitacionEmpleoModel invitacion;
  final bool retirando;
  final VoidCallback onRetirar;

  const _InvitacionCard({
    required this.invitacion,
    required this.retirando,
    required this.onRetirar,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rol = invitacion.rol == 'Recepcionista'
        ? 'Recepcionista'
        : 'Mecánico';

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.warning.withValues(alpha: 0.15),
            child: Icon(
              Icons.mark_email_unread_outlined,
              color: colors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitacion.nombreCompleto.isEmpty
                      ? invitacion.correo
                      : invitacion.nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '${invitacion.correo} · $rol · esperando que acepte',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.error),
            tooltip: 'Retirar la invitación a ${invitacion.nombreCompleto}',
            onPressed: retirando ? null : onRetirar,
          ),
        ],
      ),
    );
  }
}
