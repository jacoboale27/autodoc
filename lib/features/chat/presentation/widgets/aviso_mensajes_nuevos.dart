import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';

/// Mensajes sin leer del usuario en sesión, sumando todas sus conversaciones.
///
/// Tolerante a que falten los providers (algunas pruebas de widget montan la
/// navegación sin ellos): sin datos, no hay insignia.
int mensajesSinLeer(BuildContext context) {
  try {
    final chat = Provider.of<ChatProvider>(context);
    final usuario = Provider.of<UserProfileProvider>(context).userData;
    if (usuario == null) return 0;
    return isMechanicRole(usuario.rol)
        ? chat.totalNoLeidosMecanico
        : chat.totalNoLeidosPropietario;
  } on ProviderNotFoundException {
    return 0;
  }
}

/// Envuelve el icono de la entrada de Chat/Mensajes con el número de mensajes
/// sin leer. Cualquier otra ruta devuelve el icono tal cual.
class IconoConMensajesSinLeer extends StatelessWidget {
  final String route;
  final Widget icono;

  const IconoConMensajesSinLeer({
    super.key,
    required this.route,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    if (route != '/chat_list') return icono;
    final cantidad = mensajesSinLeer(context);
    if (cantidad <= 0) return icono;
    return Badge(
      label: Text(cantidad > 99 ? '99+' : '$cantidad'),
      child: icono,
    );
  }
}

/// Lo que muestra el aviso: de quién es y qué dice el último mensaje.
class _Aviso {
  final String conversacionId;
  final String remitente;
  final String texto;

  const _Aviso({
    required this.conversacionId,
    required this.remitente,
    required this.texto,
  });
}

/// Aviso en pantalla cuando llega un mensaje nuevo.
///
/// Observaciones del 2026-09-18 (Inge): «Agregar notificaciones de mensajes en
/// pantalla». Las notificaciones push de primer plano solo se pintaban en
/// Android (`NotificationService._onForegroundMessage` descarta la web), y la
/// bandeja de conversaciones solo se escuchaba con la lista de chats abierta:
/// en la web —que es donde se usa la app— un mensaje nuevo no avisaba de
/// ninguna forma mientras se estaba en otra pantalla.
///
/// Este widget vive en `MaterialApp.router(builder: ...)`, así que está en
/// todas las pantallas. Mantiene abierta la bandeja del usuario en sesión y,
/// cuando el contador de no leídos de una conversación SUBE, muestra un aviso
/// arriba con el remitente y el mensaje; tocarlo abre esa conversación. No
/// avisa de la conversación que ya se tiene abierta, ni de lo que ya estaba
/// sin leer al entrar.
///
/// Cuidado al tocarlo: está por ENCIMA del `Navigator`, así que aquí no hay
/// `Overlay` — nada de `Tooltip` (el `tooltip:` de un `IconButton` incluido).
class AvisoMensajesNuevos extends StatefulWidget {
  final Widget child;
  final void Function(String conversacionId) onAbrirConversacion;
  final Duration duracion;

  const AvisoMensajesNuevos({
    super.key,
    required this.child,
    required this.onAbrirConversacion,
    this.duracion = const Duration(seconds: 6),
  });

  @override
  State<AvisoMensajesNuevos> createState() => _AvisoMensajesNuevosState();
}

class _AvisoMensajesNuevosState extends State<AvisoMensajesNuevos> {
  ChatProvider? _chat;
  UserProfileProvider? _perfil;

  String? _uid;
  bool _esMecanico = false;

  /// No leídos por conversación en la última lectura. `null` hasta que llega
  /// la primera bandeja: lo que ya estaba sin leer al entrar no se anuncia.
  Map<String, int>? _noLeidosPrevios;

  _Aviso? _aviso;
  Timer? _temporizador;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ChatProvider chat;
    final UserProfileProvider perfil;
    try {
      chat = Provider.of<ChatProvider>(context, listen: false);
      perfil = Provider.of<UserProfileProvider>(context, listen: false);
    } on ProviderNotFoundException {
      return;
    }
    if (!identical(chat, _chat)) {
      _chat?.removeListener(_alCambiarChat);
      _chat = chat;
      chat.addListener(_alCambiarChat);
    }
    if (!identical(perfil, _perfil)) {
      _perfil?.removeListener(_alCambiarPerfil);
      _perfil = perfil;
      perfil.addListener(_alCambiarPerfil);
      _alCambiarPerfil();
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _chat?.removeListener(_alCambiarChat);
    _perfil?.removeListener(_alCambiarPerfil);
    super.dispose();
  }

  void _alCambiarPerfil() {
    final usuario = _perfil?.userData;
    final uid = usuario?.idUsuario;
    final esMecanico = isMechanicRole(usuario?.rol);
    if (uid != _uid || esMecanico != _esMecanico) {
      _uid = uid;
      _esMecanico = esMecanico;
      _noLeidosPrevios = null;
      _ocultar();
    }
    if (uid == null || uid.isEmpty) return;
    // Diferido: este listener puede dispararse durante un build (el perfil
    // se carga al arrancar), y abrir la suscripción notifica de inmediato.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _uid != uid) return;
      _chat?.inicializarConversacionesSiHaceFalta(uid, esMecanico);
    });
  }

  int _noLeidosDe(ConversacionModel c) =>
      _esMecanico ? c.noLeidosMecanico : c.noLeidosPropietario;

  void _alCambiarChat() {
    final chat = _chat;
    if (chat == null || _uid == null || !chat.conversacionesCargadas) return;

    final actuales = {
      for (final c in chat.conversaciones) c.id: _noLeidosDe(c),
    };
    final previos = _noLeidosPrevios;
    _noLeidosPrevios = actuales;
    if (previos == null) return;

    ConversacionModel? nueva;
    for (final c in chat.conversaciones) {
      final antes = previos[c.id] ?? 0;
      if (_noLeidosDe(c) <= antes) continue;
      if (c.id == chat.conversacionAbierta) continue;
      if (nueva == null || c.ultimoMensajeTs.isAfter(nueva.ultimoMensajeTs)) {
        nueva = c;
      }
    }
    if (nueva == null) return;

    final aviso = _Aviso(
      conversacionId: nueva.id,
      remitente: _esMecanico ? nueva.nombrePropietario : nueva.nombreMecanico,
      texto: nueva.ultimoMensaje,
    );
    _mostrar(aviso);
  }

  void _mostrar(_Aviso aviso) {
    void aplicar() {
      if (!mounted) return;
      setState(() => _aviso = aviso);
      HapticFeedback.lightImpact();
      _temporizador?.cancel();
      _temporizador = Timer(widget.duracion, _ocultar);
    }

    // Un `notifyListeners` puede llegar en mitad de un build; ahí `setState`
    // lanza. Fuera de él se aplica directo.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => aplicar());
    } else {
      aplicar();
    }
  }

  void _ocultar() {
    _temporizador?.cancel();
    if (!mounted || _aviso == null) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ocultar());
      return;
    }
    setState(() => _aviso = null);
  }

  void _abrir() {
    final aviso = _aviso;
    _ocultar();
    if (aviso != null) widget.onAbrirConversacion(aviso.conversacionId);
  }

  @override
  Widget build(BuildContext context) {
    final aviso = _aviso;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animacion) => FadeTransition(
                opacity: animacion,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.4),
                    end: Offset.zero,
                  ).animate(animacion),
                  child: child,
                ),
              ),
              child: aviso == null
                  ? const SizedBox.shrink()
                  : _TarjetaAviso(
                      key: ValueKey('${aviso.conversacionId}:${aviso.texto}'),
                      aviso: aviso,
                      onAbrir: _abrir,
                      onCerrar: _ocultar,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  final _Aviso aviso;
  final VoidCallback onAbrir;
  final VoidCallback onCerrar;

  const _TarjetaAviso({
    super.key,
    required this.aviso,
    required this.onAbrir,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final remitente = aviso.remitente.trim().isEmpty
        ? 'Nuevo mensaje'
        : aviso.remitente;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          // `liveRegion`: el lector de pantalla anuncia el aviso al aparecer.
          child: Semantics(
            key: const Key('aviso_mensaje_nuevo'),
            liveRegion: true,
            container: true,
            child: Material(
              color: colors.surface,
              elevation: 8,
              shadowColor: colors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onAbrir,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colors.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              remitente,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              aviso.texto,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Cerrar aviso',
                        child: IconButton(
                          key: const Key('aviso_mensaje_cerrar'),
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          onPressed: onCerrar,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
