import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_user_avatar.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/role_utils.dart';

class ConversacionesListScreen extends StatefulWidget {
  const ConversacionesListScreen({super.key});

  @override
  State<ConversacionesListScreen> createState() =>
      _ConversacionesListScreenState();
}

class _ConversacionesListScreenState extends State<ConversacionesListScreen> {
  String? _initializedUserId;
  bool? _initializedAsMecanico;

  /// Se re-evalúa en cada build (no solo en initState): si el perfil del
  /// usuario todavía no había cargado la primera vez, esto reintenta la
  /// suscripción en cuanto los datos estén disponibles, en vez de dejar la
  /// lista vacía para siempre.
  void _ensureConversacionesInitialized(String? userId, bool isMecanico) {
    if (userId == null) return;
    if (_initializedUserId == userId && _initializedAsMecanico == isMecanico) {
      return;
    }
    _initializedUserId = userId;
    _initializedAsMecanico = isMecanico;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().inicializarConversaciones(
        userId,
        isMecanico,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final chatProvider = context.watch<ChatProvider>();
    final userSession = context.watch<UserProfileProvider>();
    final authSession = context.watch<AuthSessionProvider>();
    final isMecanico = isMechanicRole(userSession.userData?.rol);

    _ensureConversacionesInitialized(authSession.user?.uid, isMecanico);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Desde `expanded` el shell ya aporta su propia barra superior
      // (Fase 2), así que un AppBar aquí sería el segundo título de la
      // pantalla. El corte pasa de 800 px (el sistema de breakpoints
      // anterior, TABLET) a 840 px (AppBreakpoints.expanded), que es el
      // del resto de la app.
      appBar: AppBreakpoints.of(context).isAtLeastExpanded
          ? null
          : AppBar(
              title: Text(
                'Mensajes',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: AppPageBody(
        maxWidth: AppBreakpoints.maxReadingWidth,
        child: chatProvider.error != null
            ? Center(
                child: Text(
                  context.l10n.adminError(chatProvider.error!),
                  style: TextStyle(color: colors.error),
                ),
              )
            : chatProvider.conversaciones.isEmpty
            ? AppEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No tienes mensajes aún',
                description: 'Contacta a un taller para iniciar un chat.',
                // El estado vacío decía qué hacer pero no ofrecía cómo.
                // Solo para propietario: /workshop_directory no le
                // corresponde al rol taller y acabaría en una redirección
                // del router.
                action: isMecanico ? null : const _BuscarTallerButton(),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: chatProvider.conversaciones.length,
                separatorBuilder: (context, index) => Divider(
                  color: colors.outline.withValues(alpha: 0.4),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final conv = chatProvider.conversaciones[index];
                  final noLeidos = isMecanico
                      ? conv.noLeidosMecanico
                      : conv.noLeidosPropietario;

                  // Por ahora usamos nombres genéricos
                  final targetName = isMecanico
                      ? conv.nombrePropietario
                      : conv.nombreMecanico;
                  // Denormalizada en el documento al crear la conversación
                  // (ChatProvider.iniciarOCrearConversacion): una lectura
                  // por fila en cada rebuild de esta lista sería un costo
                  // por conversación que no existe hoy. Nula en cualquier
                  // conversación anterior a este cambio; AppUserAvatar cae
                  // a la inicial en ese caso.
                  final targetFoto = isMecanico
                      ? conv.fotoPropietario
                      : conv.fotoMecanico;

                  return ListTile(
                    onTap: () {
                      if (noLeidos > 0) {
                        chatProvider.marcarComoLeidos(
                          conv.id,
                          isMecanico,
                          userSession.userData?.idUsuario ?? '',
                        );
                      }
                      // `go` y no `push`: con `push` se abria la conversacion
                      // pero la barra de direcciones seguia diciendo
                      // /chat_list (hallazgo §2.14; go_router
                      // match.dart:621-632 copia `matches` y conserva `uri`),
                      // asi que un F5 devolvia a la lista y la conversacion
                      // no se podia enlazar ni compartir. El boton de volver
                      // de ChatScreen navega explicitamente a /chat_list,
                      // porque `go` deja la pila sin nada que desapilar.
                      context.go('/chat/${conv.id}');
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    leading: AppUserAvatar(
                      urlFoto: targetFoto,
                      nombre: targetName,
                      radius: 28,
                    ),
                    title: Text(
                      targetName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: noLeidos > 0
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      conv.ultimoMensaje,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: noLeidos > 0
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: noLeidos > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeago.format(conv.ultimoMensajeTs, locale: 'es'),
                          style: TextStyle(
                            fontSize: 12,
                            color: noLeidos > 0
                                ? colors.primary
                                : colors.textSecondary,
                            fontWeight: noLeidos > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (noLeidos > 0)
                          Semantics(
                            container: true,
                            excludeSemantics: true,
                            label: '$noLeidos mensajes sin leer',
                            child: Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 24),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                noLeidos.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Extraído a widget propio para poder construirse `const`: `context.push`
/// necesita un `BuildContext` que el sitio de la llamada no tiene sin un
/// `Builder` intermedio.
class _BuscarTallerButton extends StatelessWidget {
  const _BuscarTallerButton();

  @override
  Widget build(BuildContext context) => AppButton(
    text: 'Buscar taller',
    icon: const Icon(Icons.search),
    onPressed: () => context.push('/workshop_directory'),
  );
}
