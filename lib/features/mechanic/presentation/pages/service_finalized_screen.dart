import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';

/// Datos que necesita [ServiceFinalizedScreen], pasados via `state.extra` de
/// go_router (no caben en la URL: son varios campos ya resueltos por
/// `InitiateServiceScreen`, y volver a leerlos de Firestore aqui solo
/// duplicaria lecturas que la pantalla anterior ya hizo).
///
/// No incluye el nombre del propietario: eso solo hace falta si se pulsa
/// "Enviar solicitud de reseña", asi que se resuelve en ese momento (ver
/// `_solicitarResenia`) en vez de bloquear la navegacion de cierre del
/// servicio con una lectura extra a `usuarios`.
class ServiceFinalizedArgs {
  final String idPropietario;
  final String idVehiculo;
  final String tallerId;
  final String tallerNombre;

  /// A donde ir al pulsar "Continuar": `/mechanic_reparaciones` si el
  /// servicio venia de un ticket Kanban, `/mechanic_dashboard` si no.
  final String rutaContinuar;

  const ServiceFinalizedArgs({
    required this.idPropietario,
    required this.idVehiculo,
    required this.tallerId,
    required this.tallerNombre,
    required this.rutaContinuar,
  });
}

/// Confirmacion tras finalizar un servicio.
///
/// Antes, `_handleFinalizeService` navegaba de inmediato con `context.go` en
/// cuanto terminaba de escribir en Firestore: solo quedaba un snackbar de
/// paso y, si la pantalla de destino tardaba un instante en montar sus
/// providers, el mecanico veia un frame en blanco entre medio. Esta pantalla
/// le da al cierre del servicio un resultado visible propio, y es el lugar
/// natural para ofrecer la accion que faltaba: pedirle al propietario que
/// reseñe el servicio (la tarjeta `review_card` del chat ya existia — ver
/// `ReviewChatCard` — pero nada la enviaba nunca).
class ServiceFinalizedScreen extends StatefulWidget {
  final ServiceFinalizedArgs args;

  const ServiceFinalizedScreen({super.key, required this.args});

  @override
  State<ServiceFinalizedScreen> createState() => _ServiceFinalizedScreenState();
}

class _ServiceFinalizedScreenState extends State<ServiceFinalizedScreen> {
  bool _enviandoResenia = false;
  bool _reseniaSolicitada = false;

  Future<void> _solicitarResenia() async {
    final userSession = context.read<UserProfileProvider>();
    final tallerUid = userSession.userData?.idUsuario;
    if (tallerUid == null) return;

    setState(() => _enviandoResenia = true);
    try {
      final chatProvider = context.read<ChatProvider>();
      final args = widget.args;

      final propietario = await UserService().getUserData(args.idPropietario);

      final conversacionId = await chatProvider.iniciarOCrearConversacion(
        idPropietario: args.idPropietario,
        idMecanico: tallerUid,
        nombrePropietario: propietario?.nombreCompleto ?? 'Propietario',
        nombreMecanico: args.tallerNombre,
        idVehiculo: args.idVehiculo,
        idTaller: args.tallerId,
      );
      if (conversacionId.isEmpty) {
        throw StateError('No se pudo abrir la conversación.');
      }

      await chatProvider.enviarMensaje(
        conversacionId: conversacionId,
        contenido: 'Servicio finalizado',
        remitenteId: tallerUid,
        receptorId: args.idPropietario,
        isMecanicoRemitente: true,
        tipo: 'review_card',
        metadata: {'tallerNombre': args.tallerNombre, 'estado': 'pendiente'},
      );

      if (!mounted) return;
      setState(() => _reseniaSolicitada = true);
      UiUtils.showSuccessSnackbar(
        context,
        'Le pedimos al propietario que reseñe el servicio.',
      );
    } catch (e) {
      if (!mounted) return;
      UiUtils.showErrorSnackbar(
        context,
        'No se pudo enviar la solicitud de reseña: $e',
      );
    } finally {
      if (mounted) setState(() => _enviandoResenia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final args = widget.args;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: AppPageBody(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: colors.success, size: 72),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Servicio finalizado',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Quedó registrado en el historial del vehículo.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_outline, color: colors.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Pídele al propietario que reseñe este servicio',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              text: _reseniaSolicitada
                                  ? 'Solicitud enviada'
                                  : 'Enviar solicitud de reseña',
                              icon: _reseniaSolicitada
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                              isLoading: _enviandoResenia,
                              onPressed: _reseniaSolicitada
                                  ? null
                                  : _solicitarResenia,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      type: AppButtonType.secondary,
                      text: 'Continuar',
                      onPressed: () => context.go(args.rutaContinuar),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
