import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/vehiculo_picker.dart';

import 'package:provider/provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_background.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/reserva_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/historial_chat_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

import 'package:image_picker/image_picker.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart';

import 'package:autodoc/features/chat/presentation/widgets/cards/review_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/imagen_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/audio_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/voice_record_button.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_picker.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/mechanic_profile_utils.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends StatefulWidget {
  final String conversacionId;

  const ChatScreen({super.key, required this.conversacionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _typingTimer;
  bool _isTyping = false;

  // Capturado una vez en initState (con el context aún activo) para poder
  // usarlo en dispose(): en ese punto el propio Element ya está desactivado,
  // así que un context.read<ChatProvider>() ahí lanza "Looking up a
  // deactivated widget's ancestor is unsafe".
  late final ChatProvider _chatProvider;

  // Si en el postFrameCallback inicial `userData` todavía es null (posible
  // en cold start, p.ej. al abrir la app desde una notificación push antes
  // de que UserProfileProvider termine de cargar el perfil), nos suscribimos
  // aquí para reintentar en cuanto el perfil llegue, en vez de no inicializar
  // nunca los mensajes ni marcarlos como leídos.
  UserProfileProvider? _userSessionPendiente;

  /// Consulta del nombre real del receptor, cacheada.
  ///
  /// Estaba construida dentro de `build()`, y como la pantalla hace
  /// `context.watch<ChatProvider>()`, cada notificación —incluido el estado
  /// "escribiendo", que cambia cada 2 s— lanzaba un `get()` nuevo a
  /// `usuarios/{receptorId}`.
  @visibleForTesting
  Future<DocumentSnapshot<Map<String, dynamic>>>? nombreReceptorFuture;
  String? _receptorIdCacheado;

  /// Devuelve el future, creándolo solo si el receptor cambió.
  Future<DocumentSnapshot<Map<String, dynamic>>>? _futureNombreReceptor(
    String receptorId,
  ) {
    if (receptorId.isEmpty) return null;
    if (_receptorIdCacheado == receptorId) return nombreReceptorFuture;
    _receptorIdCacheado = receptorId;
    nombreReceptorFuture = FirebaseFirestore.instance
        .collection(FirestoreCollections.usuarios)
        .doc(receptorId)
        .get();
    return nombreReceptorFuture;
  }

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _intentarInicializarMensajes();
    });

    _controller.addListener(() {
      final text = _controller.text;
      final userSession = context.read<UserProfileProvider>();
      final userId = userSession.userData?.idUsuario;

      if (text.isNotEmpty && !_isTyping) {
        _isTyping = true;
        context.read<ChatProvider>().setTypingStatus(
          widget.conversacionId,
          userId,
        );
      }

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTyping) {
          _isTyping = false;
          context.read<ChatProvider>().setTypingStatus(
            widget.conversacionId,
            null,
          );
        }
      });
    });
  }

  void _intentarInicializarMensajes() {
    if (!mounted) return;
    final userSession = context.read<UserProfileProvider>();
    final user = userSession.userData;
    if (user == null) {
      // Perfil aún no disponible: nos suscribimos para reintentar en cuanto
      // UserProfileProvider notifique el cambio (no llamamos a
      // marcarComoLeidos/inicializarMensajes con un userId vacío, que
      // corrompería el estado de lectura, ver ChatRepository.marcarComoLeidos).
      if (_userSessionPendiente == null) {
        _userSessionPendiente = userSession;
        _userSessionPendiente!.addListener(_onUserProfilePendienteChanged);
      }
      return;
    }
    final userId = user.idUsuario;
    final isMecanico = user.rol == 'Mecanico';
    _chatProvider.inicializarMensajes(widget.conversacionId);
    _chatProvider.marcarComoLeidos(widget.conversacionId, isMecanico, userId);
  }

  void _onUserProfilePendienteChanged() {
    if (_userSessionPendiente?.userData == null) return;
    _userSessionPendiente!.removeListener(_onUserProfilePendienteChanged);
    _userSessionPendiente = null;
    _intentarInicializarMensajes();
  }

  @override
  void dispose() {
    _userSessionPendiente?.removeListener(_onUserProfilePendienteChanged);
    _typingTimer?.cancel();
    _chatProvider.setTypingStatus(widget.conversacionId, null);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _enviarMensaje(String userId, bool isMecanico, String receptorId) {
    if (_controller.text.trim().isEmpty) return;

    context.read<ChatProvider>().enviarMensaje(
      conversacionId: widget.conversacionId,
      contenido: _controller.text.trim(),
      remitenteId: userId,
      receptorId: receptorId,
      isMecanicoRemitente: isMecanico,
      tipo: 'texto',
    );
    _controller.clear();
  }

  void _iniciarNuevaReserva({
    required String userId,
    required bool isMecanico,
    required String receptorId,
  }) {
    // El cliente debe indicar a qué vehículo de su cuenta es el servicio.
    // Usamos el context del propio State (this.context), que se mantiene
    // válido mientras la pantalla de chat siga montada — a diferencia del
    // context del sheet, que deja de servir en cuanto este se cierra.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VehiculoPicker(
        userId: userId,
        onSelected: (vehiculoData) {
          final idVehiculo = vehiculoData['vehiculo_id'] ?? '';
          // VehiculoPicker se cierra a sí mismo justo después de llamar a
          // onSelected; esperamos a que termine ese frame antes de abrir el
          // siguiente selector, para no pelear con ese cierre.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _abrirSelectorFechaReserva(
              userId: userId,
              isMecanico: isMecanico,
              receptorId: receptorId,
              idVehiculo: idVehiculo,
            );
          });
        },
      ),
    );
  }

  Future<void> _abrirSelectorFechaReserva({
    required String userId,
    required bool isMecanico,
    required String receptorId,
    required String idVehiculo,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    final fecha = DateTime(date.year, date.month, date.day);
    final hora = time.format(context);
    final fechaHora = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final provider = context.read<ChatProvider>();
    final reservaProvider = context.read<ReservaProvider>();

    final reserva = ReservaModel(
      id: '',
      idConversacion: widget.conversacionId,
      idPropietario: isMecanico ? receptorId : userId,
      idMecanico: isMecanico ? userId : receptorId,
      idVehiculo: idVehiculo,
      idTaller: isMecanico ? userId : receptorId,
      fechaHoraPropuesta: fechaHora,
      tipoServicio: 'Cita General',
      estado: 'pendiente',
      fechaCreacion: DateTime.now(),
    );

    final reservaId = await reservaProvider.solicitarReserva(reserva);

    await provider.enviarMensaje(
      conversacionId: widget.conversacionId,
      contenido:
          '📅 Propuesta de cita: \nFecha: ${fecha.day}/${fecha.month}/${fecha.year}\nHora: $hora',
      remitenteId: userId,
      receptorId: receptorId,
      isMecanicoRemitente: isMecanico,
      tipo: 'reserva_card',
      metadata: {
        'id_reserva': reservaId,
        'fecha': fecha.toIso8601String(),
        'hora': hora,
        'id_vehiculo': idVehiculo,
        'estado': 'pendiente',
      },
    );
  }

  void _showProfileIncompleteDialog(BuildContext context, UserModel? user) {
    final missing = missingMechanicProfileFields(user);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completa tu perfil de taller'),
        content: Text(
          'Para poder enviar cotizaciones, primero debes completar en tu '
          'perfil: ${missing.join(', ')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/workshop_settings');
            },
            child: const Text('Completar perfil'),
          ),
        ],
      ),
    );
  }

  void _confirmarBorrado(MensajeModel msg, bool isMe) {
    if (!isMe || msg.isDeleted) return;
    final colors = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.chatDeleteMessage),
        content: Text(context.l10n.chatConfirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.adminCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatProvider>().deleteMensaje(
                widget.conversacionId,
                msg.id,
              );
            },
            child: Text(
              context.l10n.adminDelete,
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final chatProvider = context.watch<ChatProvider>();
    final userSession = context.watch<UserProfileProvider>();
    final userId = userSession.userData?.idUsuario ?? '';
    final isMecanico = userSession.userData?.rol == 'Mecanico';

    // Necesitamos el receptorId (el ID del otro usuario). Para este demo lo hardcodearemos si no lo tenemos
    // en un caso real se obtiene del conversacion_model
    final conversacion = chatProvider.conversaciones
        .where((c) => c.id == widget.conversacionId)
        .firstOrNull;
    final receptorId = isMecanico
        ? conversacion?.idPropietario ?? ''
        : conversacion?.idMecanico ?? '';
    final targetName = conversacion != null
        ? (isMecanico
              ? conversacion.nombrePropietario
              : conversacion.nombreMecanico)
        : (isMecanico ? 'Propietario' : 'Mecánico / Taller');

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary.withValues(alpha: 0.2),
              child: Icon(Icons.person, color: colors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _futureNombreReceptor(receptorId),
              builder: (context, snapshot) {
                String finalName = targetName;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data();
                  final realName = data?['nombre_completo'];
                  if (realName?.isNotEmpty == true) {
                    finalName = realName!;
                  }
                }
                final estaEscribiendo =
                    conversacion != null && conversacion.typingId == receptorId;
                return AnimatedSize(
                  duration: AppMotion.transformDuration(
                    context,
                    AppMotion.tooltip,
                  ),
                  curve: AppMotion.easeOut,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        finalName,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (estaEscribiendo)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            'Escribiendo...',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ChatBackgroundPattern(
                    // outline (not textPrimary) is the neutral/structural
                    // token used for faint decorative tints elsewhere in
                    // this module; alpha bumped above the light-mode value
                    // because darkOutline (slate) has less luminance
                    // contrast against darkSurface than primary does.
                    color: isDark
                        ? colors.outline.withValues(alpha: 0.15)
                        : colors.primary.withValues(alpha: 0.08),
                  ),
                ),
                if (chatProvider.isLoading &&
                    chatProvider.mensajesActuales.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  AppPageBody(
                    maxWidth: AppBreakpoints.maxContentWidth,
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      itemCount: chatProvider.mensajesActuales.length,
                      itemBuilder: (context, index) {
                        final msg = chatProvider.mensajesActuales[index];
                        final isMe = msg.idRemitente == userId;
                        final nombreAutor = isMe ? 'Tú' : targetName;

                        return Align(
                          key: ValueKey(msg.id),
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _confirmarBorrado(msg, isMe),
                            child: ChatBubble(
                              isMe: isMe,
                              isDeleted: msg.isDeleted,
                              semanticLabel: '$nombreAutor: ${msg.contenido}',
                              footer: isMe
                                  ? _AcuseDeRecibo(estado: msg.estado)
                                  : null,
                              child: _buildMessageContent(
                                msg,
                                isMe,
                                colors,
                                conversacion?.idMecanico ?? '',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Input Bar
          AppPageBody(
            maxWidth: AppBreakpoints.maxContentWidth,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.outline.withValues(alpha: 0.4)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: colors.primary),
                    tooltip: 'Adjuntar',
                    onPressed: () {
                      _mostrarMenuAdjuntos(
                        context,
                        userId,
                        isMecanico,
                        receptorId,
                        colors,
                        isDark,
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.camera_alt, color: colors.primary),
                    tooltip: context.l10n.chatCamera,
                    onPressed: () => _pickAndSendImage(
                      userId,
                      isMecanico,
                      receptorId,
                      ImageSource.camera,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) =>
                            _enviarMensaje(userId, isMecanico, receptorId),
                      ),
                    ),
                  ),
                  // `record` no soporta grabación a un File real en web (stop()
                  // devuelve un blob URL, no una ruta de filesystem), y
                  // ChatProvider.subirAudioChat depende de File.readAsBytes().
                  // Ocultamos el control en vez de mostrar uno que falla en
                  // silencio (implementar grabación web queda fuera de alcance).
                  if (!kIsWeb)
                    VoiceRecordButton(
                      onGrabacionCompleta: (file, duracion) =>
                          _grabarYEnviarAudio(
                            file,
                            duracion,
                            userId,
                            isMecanico,
                            receptorId,
                          ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: colors.onPrimary, size: 20),
                      tooltip: 'Enviar',
                      onPressed: () =>
                          _enviarMensaje(userId, isMecanico, receptorId),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(
    MensajeModel msg,
    bool isMe,
    AppColors colors,
    String tallerId,
  ) {
    switch (msg.tipo) {
      case 'vehiculo_card':
        return VehiculoChatCard(metadata: msg.metadata ?? {}, isMe: isMe);
      case 'reserva_card':
        return ReservaChatCard(
          metadata: msg.metadata ?? {},
          isMe: isMe,
          mensajeId: msg.id,
          conversacionId: widget.conversacionId,
        );
      case 'cotizacion_card':
        return CotizacionChatCard(
          metadata: msg.metadata ?? {},
          isMe: isMe,
          mensajeId: msg.id,
          conversacionId: widget.conversacionId,
        );
      case 'review_card':
        return ReviewChatCard(
          metadata: msg.metadata ?? {},
          isMe: isMe,
          tallerId: tallerId,
          mensajeId: msg.id,
          conversacionId: widget.conversacionId,
        );
      case 'imagen':
        return ImagenChatCard(
          urlArchivo: msg.urlArchivo ?? '',
          isMe: isMe,
          mensajeId: msg.id,
        );
      case 'audio':
        return AudioChatCard(
          urlArchivo: msg.urlArchivo ?? '',
          duracionSegundos:
              msg.duracionSegundos ??
              (msg.metadata?['duracion_segundos'] as num?)?.toInt(),
          isMe: isMe,
        );
      case 'historial':
        return HistorialChatCard(mensaje: msg);
      case 'texto':
      default:
        return Text(
          msg.contenido,
          style: TextStyle(
            color: isMe ? colors.onPrimary : colors.textPrimary,
            fontSize: 15,
          ),
        );
    }
  }

  void _mostrarMenuAdjuntos(
    BuildContext context,
    String userId,
    bool isMecanico,
    String receptorId,
    AppColors colors,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: colors.primary),
                title: Text(context.l10n.chatCamera),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(
                    userId,
                    isMecanico,
                    receptorId,
                    ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: colors.primary),
                title: Text(context.l10n.chatGallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(
                    userId,
                    isMecanico,
                    receptorId,
                    ImageSource.gallery,
                  );
                },
              ),
              if (!isMecanico) // Solo el cliente agenda: el mecánico responde con una cotización
                ListTile(
                  leading: Icon(Icons.calendar_month, color: colors.primary),
                  title: Text(context.l10n.chatNewReservation),
                  onTap: () {
                    Navigator.pop(context);
                    _iniciarNuevaReserva(
                      userId: userId,
                      isMecanico: isMecanico,
                      receptorId: receptorId,
                    );
                  },
                ),
              if (isMecanico) ...[
                ListTile(
                  leading: Icon(Icons.request_quote, color: colors.secondary),
                  title: Text(context.l10n.chatSendQuote),
                  onTap: () {
                    Navigator.pop(context);
                    final mechanicUser = context
                        .read<UserProfileProvider>()
                        .userData;
                    if (!isMechanicProfileComplete(mechanicUser)) {
                      _showProfileIncompleteDialog(context, mechanicUser);
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => CotizacionPicker(
                        onConfirm: (items, fechaPropuesta) async {
                          final provider = context.read<ChatProvider>();

                          // Guardar cotización en la base de datos
                          final cotizacion = CotizacionModel(
                            id: '',
                            idPropietario: receptorId,
                            idMecanico: userId,
                            idVehiculo: provider.conversaciones
                                .where((c) => c.id == widget.conversacionId)
                                .firstOrNull
                                ?.idVehiculo,
                            idTaller: userId,
                            items: items,
                            fechaPropuesta: fechaPropuesta,
                            fecha: DateTime.now(),
                          );

                          final ok = await provider.enviarCotizacion(
                            cotizacion: cotizacion,
                            conversacionId: widget.conversacionId,
                            contenido:
                                'He creado una nueva cotización para tu vehículo.',
                            remitenteId: userId,
                            receptorId: receptorId,
                            isMecanicoRemitente: isMecanico,
                          );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.error ??
                                      'No se pudo enviar la cotización.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage(
    String userId,
    bool isMecanico,
    String receptorId,
    ImageSource source,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      if (!mounted) return;

      final provider = context.read<ChatProvider>();
      final url = await provider.subirImagenChat(widget.conversacionId, image);

      if (!mounted) return;

      if (url != null) {
        provider.enviarMensaje(
          conversacionId: widget.conversacionId,
          contenido: '📷 Imagen adjunta',
          remitenteId: userId,
          receptorId: receptorId,
          isMecanicoRemitente: isMecanico,
          tipo: 'imagen',
          urlArchivo: url,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatUploadImageError)),
        );
      }
    }
  }

  Future<void> _grabarYEnviarAudio(
    File audioFile,
    int duracionSegundos,
    String userId,
    bool isMecanico,
    String receptorId,
  ) async {
    final provider = context.read<ChatProvider>();
    final url = await provider.subirAudioChat(widget.conversacionId, audioFile);

    if (!mounted) return;

    if (url != null) {
      provider.enviarMensaje(
        conversacionId: widget.conversacionId,
        contenido: '🎤 Nota de voz',
        remitenteId: userId,
        receptorId: receptorId,
        isMecanicoRemitente: isMecanico,
        tipo: 'audio',
        urlArchivo: url,
        duracionSegundos: duracionSegundos,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la nota de voz')),
      );
    }
  }
}

/// Acuse de recibo del mensaje propio.
///
/// Los colores salen de la paleta y no de `Colors.white70` / `blue.shade200`:
/// sobre `colors.primary`, que en tema oscuro es #81E6D9, esos dos daban
/// 1,31:1 y 1,19:1 respectivamente.
class _AcuseDeRecibo extends StatelessWidget {
  final String estado;
  const _AcuseDeRecibo({required this.estado});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final visto = estado == 'visto';
    return Semantics(
      label: visto ? 'Visto' : 'Enviado',
      child: ExcludeSemantics(
        child: Icon(
          visto ? Icons.done_all : Icons.check,
          size: 14,
          color: colors.onPrimary.withValues(alpha: visto ? 1.0 : 0.7),
        ),
      ),
    );
  }
}
