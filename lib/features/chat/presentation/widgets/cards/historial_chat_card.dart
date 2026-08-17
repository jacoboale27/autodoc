import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';

/// Tarjeta de "historial de vehículo compartido".
///
/// Hasta la Fase 6 existían **dos** clases con este nombre: una en
/// `widgets/` (la que usaba `chat_screen`) y otra en `widgets/cards/` (código
/// muerto que nadie importaba). Ésta las sustituye a las dos.
///
/// Ya no recibe `isMe` ni `colors`: la superficie y los colores los pone
/// `ChatCardShell`, y la burbuja la pone `ChatBubble`. La versión anterior
/// dibujaba su propio `Align` + `Container` coloreado **dentro** de la
/// burbuja, lo que producía una burbuja dentro de otra del mismo color y
/// estiraba el mensaje a todo el ancho de la lista.
class HistorialChatCard extends StatelessWidget {
  final MensajeModel mensaje;

  const HistorialChatCard({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return ChatCardShell(
      icon: Icons.history_edu,
      title: 'Historial de Vehículo Compartido',
      semanticLabel: 'Historial de vehículo compartido',
      child: SizedBox(
        width: double.infinity,
        child: AppButton(
          text: context.l10n.chatViewFullHistory,
          type: AppButtonType.secondary,
          onPressed: () =>
              context.push('/dashboard/history/${mensaje.contenido}'),
        ),
      ),
    );
  }
}
