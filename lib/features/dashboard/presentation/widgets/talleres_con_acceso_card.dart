import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/profile/data/services/public_profile_service.dart';

/// «Talleres con acceso»: la mitad que le faltaba al consentimiento.
///
/// `vehiculos.talleres_vinculados` es lo que autoriza a un taller a leer la
/// ficha del coche, su galería, sus alertas, sus mantenimientos y el historial
/// que escribieron otros talleres. Desde la ronda 5 ese array significa «este
/// taller tiene el coche AHORA MISMO» y se otorga al recibir el vehículo y se
/// revoca al entregarlo.
///
/// Lo que no existía era la vista del titular. La revisión adversarial de la
/// ronda 6 lo resumió así: el permiso más sensible del sistema no aparecía en
/// ninguna pantalla del propietario, que solo podía CONCEDERLO desde el banner
/// de `taller_pendiente_confirmacion` y nunca verlo ni retirarlo. Un permiso
/// que el sujeto no puede inspeccionar ni revocar no es consentimiento; es una
/// concesión de un solo sentido.
///
/// La lista se resuelve contra `talleres/{uid}` (lectura pública del
/// directorio) para enseñar nombres y no uids. Si un taller no está publicado
/// en el directorio, se enseña igual con una etiqueta genérica: **nunca** se
/// oculta una entrada por no poder resolver su nombre, porque lo que importa
/// aquí es que el acceso existe.
class TalleresConAccesoCard extends StatefulWidget {
  final VehicleModel vehicle;

  /// Inyectable en tests para no depender de Firestore. Devuelve el documento
  /// público del taller, o `null` si no se pudo resolver.
  final Future<Map<String, dynamic>?> Function(String uid)? resolverTaller;

  const TalleresConAccesoCard({
    super.key,
    required this.vehicle,
    this.resolverTaller,
  });

  @override
  State<TalleresConAccesoCard> createState() => _TalleresConAccesoCardState();
}

class _TalleresConAccesoCardState extends State<TalleresConAccesoCard> {
  /// uid -> nombre ya resuelto. Se cachea en el State y no se vuelve a pedir
  /// en cada rebuild: el widget se reconstruye cada vez que el provider
  /// notifica (p. ej. al revocar), y sin esto cada revocación dispararía una
  /// lectura por cada taller restante.
  final Map<String, String> _nombres = {};
  bool _resolviendo = false;

  @override
  void initState() {
    super.initState();
    _resolverNombres();
  }

  @override
  void didUpdateWidget(TalleresConAccesoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolverNombres();
  }

  Future<void> _resolverNombres() async {
    final pendientes = widget.vehicle.talleresVinculados
        .where((uid) => !_nombres.containsKey(uid))
        .toList();
    if (pendientes.isEmpty || _resolviendo) return;
    _resolviendo = true;
    final resolver =
        widget.resolverTaller ?? PublicProfileService().perfilMecanico;
    for (final uid in pendientes) {
      String? nombre;
      try {
        final datos = await resolver(uid);
        final crudo = datos?['nombre_taller'] ?? datos?['nombre_completo'];
        if (crudo is String && crudo.trim().isNotEmpty) nombre = crudo.trim();
      } catch (_) {
        // Un taller sin ficha pública, o una lectura que falla, no puede
        // esconder el hecho de que tiene acceso: se cae al nombre genérico.
        nombre = null;
      }
      _nombres[uid] = nombre ?? 'Taller sin perfil público';
    }
    _resolviendo = false;
    if (mounted) setState(() {});
  }

  Future<void> _confirmarRevocar(String uid, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar acceso'),
        content: AppDialogContent(
          child: Text(
            '¿Retirar el acceso de "$nombre" a la ficha de '
            '${widget.vehicle.placa}?\n\n'
            'Dejará de ver los datos, las fotos, las alertas y el historial '
            'de mantenimiento de este vehículo. Si el coche está en ese '
            'taller ahora mismo, puede que no pueda seguir registrando el '
            'servicio en curso.',
          ),
        ),
        actions: [
          AppButton(
            text: 'Volver',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            // No repite el título del diálogo a propósito: el botón nombra la
            // decisión ("sí, hazlo"), no la pantalla.
            text: 'Sí, retirar',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final provider = context.read<VehicleProvider>();
    final ok = await provider.revocarAccesoTaller(
      widget.vehicle.idVehiculo,
      uid,
    );
    if (!mounted) return;
    if (ok) {
      UiUtils.showSuccessSnackbar(context, 'Acceso retirado a $nombre.');
    } else {
      UiUtils.showErrorSnackbar(
        context,
        provider.error ?? 'No se pudo retirar el acceso.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final talleres = widget.vehicle.talleresVinculados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Talleres con acceso',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          talleres.isEmpty
              ? 'Ningún taller puede ver la ficha de este vehículo.'
              : 'Estos talleres pueden ver los datos, las fotos y el '
                    'historial de este vehículo mientras dure su visita.',
          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(AppSpacing.base),
          child: talleres.isEmpty
              ? Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Sin accesos activos',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (var i = 0; i < talleres.length; i++) ...[
                      if (i > 0) const Divider(height: AppSpacing.lg),
                      _FilaTaller(
                        nombre: _nombres[talleres[i]] ?? 'Cargando…',
                        onRetirar: () => _confirmarRevocar(
                          talleres[i],
                          _nombres[talleres[i]] ?? 'este taller',
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _FilaTaller extends StatelessWidget {
  final String nombre;
  final VoidCallback onRetirar;

  const _FilaTaller({required this.nombre, required this.onRetirar});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(Icons.storefront_outlined, size: 20, color: colors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            nombre,
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppButton(
          text: 'Retirar',
          type: AppButtonType.text,
          size: AppButtonSize.small,
          onPressed: onRetirar,
          child: Text(
            'Retirar',
            style: AppTextStyles.labelMedium.copyWith(color: colors.error),
          ),
        ),
      ],
    );
  }
}
