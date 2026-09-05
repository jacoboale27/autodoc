import 'dart:async';
import 'package:autodoc/core/utils/role_utils.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
import 'package:autodoc/core/widgets/app_user_avatar.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/reserva_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/historial_chat_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
import 'package:autodoc/features/profile/data/services/public_profile_service.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends StatefulWidget {
  final String conversacionId;

  /// Inyectable para pruebas de widget (`FakeFirebaseFirestore`); por
  /// defecto usa la instancia real. Solo se propaga a `ReservaChatCard`
  /// (Tarea 8: lee `reservas/{id}` en vivo vía `StreamBuilder`), que sin
  /// esto no puede resolver su documento en un widget test sin un backend
  /// real de Firestore.
  final FirebaseFirestore? firestore;

  /// Inyectable para pruebas de widget (Tarea 10, C3): resuelve el perfil
  /// público del receptor por el mecanismo correcto según su rol —
  /// `talleres/{uid}` (lectura anónima) si es mecánico, el callable
  /// `obtenerPerfilPublico` si es cliente. Por defecto se construye a
  /// partir de [firestore], igual que el resto de la pantalla.
  final PublicProfileService? publicProfileService;

  const ChatScreen({
    super.key,
    required this.conversacionId,
    this.firestore,
    this.publicProfileService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
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

  /// Consulta del perfil público real del receptor (nombre + foto), cacheada.
  ///
  /// Estaba construida dentro de `build()`, y como la pantalla hace
  /// `context.watch<ChatProvider>()`, cada notificación —incluido el estado
  /// "escribiendo", que cambia cada 2 s— lanzaba un `get()` nuevo.
  ///
  /// Ampliada en C1 (fotos de perfil en el chat) para devolver también la
  /// foto en la misma lectura, en vez de abrir una segunda consulta: el
  /// nombre ya pagaba este `get()`, así que la foto sale gratis.
  ///
  /// HALLAZGO DE LA TAREA 9, cerrado aquí (R18): esto leía directamente
  /// `usuarios/{receptorId}`, que `firestore.rules` niega a cualquiera que
  /// no sea el propio dueño o un admin — `receptorId` es SIEMPRE la
  /// contraparte, nunca el uid de quien mira. El `get()` fallaba con
  /// permission-denied, el `FutureBuilder` caía en silencio al nombre
  /// denormalizado de la conversación, y nadie lo notó porque los tests de
  /// este archivo usan `FakeFirebaseFirestore`, que no aplica reglas. El
  /// nombre real del contacto **nunca llegó a renderizar en producción**.
  ///
  /// Se reemplaza por [PublicProfileService] (Tarea 10, C3), que resuelve el
  /// perfil por el mecanismo correcto según el rol del receptor: lectura
  /// anónima de `talleres/{uid}` si es mecánico, o el callable
  /// `obtenerPerfilPublico` (Admin SDK, verifica que exista una conversación
  /// real) si es cliente — el mismo mecanismo que usa `PublicProfileScreen`.
  @visibleForTesting
  Future<Map<String, dynamic>?>? perfilReceptorFuture;
  String? _receptorIdCacheado;

  PublicProfileService get _publicProfileService =>
      widget.publicProfileService ??
      PublicProfileService(firestore: widget.firestore);

  /// Devuelve el future, creándolo solo si el receptor cambió.
  Future<Map<String, dynamic>?>? _futurePerfilReceptor(
    String receptorId,
    bool isMecanico,
  ) {
    if (receptorId.isEmpty) return null;
    if (_receptorIdCacheado == receptorId) return perfilReceptorFuture;
    _receptorIdCacheado = receptorId;
    // El receptor es SIEMPRE del rol contrario al de quien mira: si YO soy
    // mecánico, el receptor es el cliente de esta conversación (y viceversa).
    perfilReceptorFuture = isMecanico
        ? _publicProfileService.perfilCliente(receptorId)
        : _publicProfileService.perfilMecanico(receptorId);
    return perfilReceptorFuture;
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
    final isMecanico = isMechanicRole(user.rol);
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
    _inputFocusNode.dispose();
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
    // Limpiar el texto no debe costar el foco: sin esto el teclado se cierra en
    // movil y hay que volver a tocar la barra entre mensaje y mensaje.
    _inputFocusNode.requestFocus();
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

  /// Menú contextual de mensaje (Tarea 11, C4): mantener presionado un
  /// mensaje ofrece Copiar siempre, y — solo para el mensaje propio, no
  /// borrado — Editar (solo texto) y Borrar. Reply/reenviar quedan fuera de
  /// esta ronda (11c, explícitamente pospuesto en el plan).
  void _abrirMenuMensaje(MensajeModel msg, bool isMe) {
    // R10 (revision C4b): antes se ofrecia Copiar sobre cualquier tipo de
    // mensaje. `msg.contenido` en 'imagen'/'audio' es un placeholder interno
    // ('📷 Imagen adjunta', '🎤 Nota de voz'), no texto que el usuario haya
    // escrito ni vea como tal en la burbuja (VER ImagenChatCard/AudioChatCard,
    // que ignoran `contenido`); en tarjetas (reserva/cotizacion/reseña/
    // vehiculo/historial) `contenido` tampoco se renderiza. Solo 'texto'
    // muestra `msg.contenido` como el propio texto visible de la burbuja
    // (incluido el tombstone de un mensaje borrado, que sigue siendo
    // 'texto' y sigue siendo lo que se ve en pantalla).
    final puedeCopiar = msg.tipo == 'texto';
    final puedeEditar = isMe && !msg.isDeleted && msg.tipo == 'texto';
    final puedeBorrar = isMe && !msg.isDeleted;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (puedeCopiar)
              ListTile(
                key: const Key('menu_mensaje_copiar'),
                leading: const Icon(Icons.copy),
                title: Text(context.l10n.chatCopyMessage),
                onTap: () {
                  Navigator.pop(ctx);
                  _copiarMensaje(msg);
                },
              ),
            if (puedeEditar)
              ListTile(
                key: const Key('menu_mensaje_editar'),
                leading: const Icon(Icons.edit),
                title: Text(context.l10n.chatEditMessage),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirEdicionMensaje(msg);
                },
              ),
            if (puedeBorrar)
              ListTile(
                key: const Key('menu_mensaje_borrar'),
                leading: Icon(Icons.delete, color: context.appColors.error),
                title: Text(
                  context.l10n.chatDeleteMessage,
                  style: TextStyle(color: context.appColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmarBorrado(msg, isMe);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _copiarMensaje(MensajeModel msg) {
    Clipboard.setData(ClipboardData(text: msg.contenido));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.chatMessageCopied)));
  }

  void _abrirEdicionMensaje(MensajeModel msg) {
    showDialog(
      context: context,
      builder: (ctx) => _EditarMensajeDialog(
        conversacionId: widget.conversacionId,
        mensajeId: msg.id,
        contenidoOriginal: msg.contenido,
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
            onPressed: () async {
              // Capturados antes del await: tras el pop, `ctx` ya no sirve.
              final chatProvider = context.read<ChatProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);

              final borrado = await chatProvider.deleteMensaje(
                widget.conversacionId,
                msg.id,
              );
              if (!borrado && mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('No se pudo eliminar el mensaje.'),
                    backgroundColor: colors.error,
                  ),
                );
              }
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
    final isMecanico = isMechanicRole(userSession.userData?.rol);

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
        // `leading` explicito, no el boton automatico de Flutter: se llega
        // aqui con `go`, que reemplaza la pila en vez de apilar, asi que no
        // hay nada que desapilar y Flutter no pintaria ninguna flecha de
        // volver — se saldria de la conversacion solo con el boton del
        // navegador. Volver a la lista es ademas el destino correcto.
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          tooltip: 'Volver',
          onPressed: () => context.go('/chat_list'),
        ),
        title: FutureBuilder<Map<String, dynamic>?>(
          future: _futurePerfilReceptor(receptorId, isMecanico),
          builder: (context, snapshot) {
            String finalName = targetName;
            String? fotoUrl;
            if (snapshot.hasData && snapshot.data != null) {
              final data = snapshot.data;
              final realName = data?['nombre'] as String?;
              if (realName?.isNotEmpty == true) {
                finalName = realName!;
              }
              fotoUrl =
                  (data?['foto_perfil_url'] ?? data?['foto_url']) as String?;
            }
            final estaEscribiendo =
                conversacion != null && conversacion.typingId == receptorId;
            final header = Row(
              children: [
                AppUserAvatar(urlFoto: fotoUrl, nombre: finalName, radius: 18),
                const SizedBox(width: 12),
                // `Expanded`: el nombre del taller es de longitud arbitraria y
                // aqui no tenia ninguna restriccion de ancho. Con el boton de
                // volver explicito quedan 42 px menos y desbordaba en los
                // anchos estrechos de la auditoria; sin acotarlo, cualquier
                // nombre largo lo habria desbordado igual.
                Expanded(
                  child: AnimatedSize(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  ),
                ),
              ],
            );

            // Tocable solo cuando hay a dónde ir: sin receptorId (conversación
            // aún sin resolver) no hay perfil que abrir.
            if (receptorId.isEmpty) return header;
            return InkWell(
              key: const Key('chat_header_perfil_publico'),
              onTap: () => context.push('/perfil_publico/$receptorId'),
              child: Semantics(
                button: true,
                label: 'Ver perfil de $finalName',
                excludeSemantics: true,
                child: header,
              ),
            );
          },
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
                            onLongPress: () => _abrirMenuMensaje(msg, isMe),
                            child: ChatBubble(
                              isMe: isMe,
                              isDeleted: msg.isDeleted,
                              // Solo mensajes de texto (o borrados, que se
                              // muestran como texto atenuado) pasan
                              // semanticLabel: ChatBubble usa
                              // excludeSemantics: true cuando hay label, lo
                              // que descarta todo el subárbol semántico del
                              // hijo. Las tarjetas (reserva, cotización,
                              // review, historial, audio, imagen, vehículo)
                              // tienen sus propios controles interactivos
                              // (botones Aceptar/Rechazar, play/pause, etc.)
                              // con su propia semántica: si les pasáramos
                              // este label también, esos controles
                              // quedarían inalcanzables para un lector de
                              // pantalla.
                              semanticLabel:
                                  (msg.tipo == 'texto' || msg.isDeleted)
                                  ? '$nombreAutor: ${msg.contenido}'
                                  : null,
                              footer: _footerDe(msg, isMe),
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
                        key: const Key('chat_input_field'),
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        textInputAction: TextInputAction.send,
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

  /// Footer de la burbuja: acuse de recibo (solo propio) y/o marca
  /// "(editado)" (Tarea 11b, C4) cuando `msg.editado` es true. Mensajes ya
  /// existentes en producción no traen ese campo (`MensajeModel.fromMap` lo
  /// lee `?? false`), así que renderizan igual que antes de esta tarea.
  Widget? _footerDe(MensajeModel msg, bool isMe) {
    final colors = context.appColors;
    final editadoLabel = msg.editado
        ? Text(
            context.l10n.chatMessageEditedMark,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isMe
                  ? colors.onPrimary.withValues(alpha: 0.7)
                  : colors.textSecondary,
            ),
          )
        : null;

    if (!isMe) return editadoLabel;

    if (editadoLabel == null) return _AcuseDeRecibo(estado: msg.estado);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        editadoLabel,
        const SizedBox(width: 4),
        _AcuseDeRecibo(estado: msg.estado),
      ],
    );
  }

  Widget _buildMessageContent(
    MensajeModel msg,
    bool isMe,
    AppColors colors,
    String tallerId,
  ) {
    // Antes de mirar el tipo. `deleteMensaje` es un borrado suave: marca
    // `is_deleted` y sustituye `contenido`, pero NO toca `tipo` ni
    // `url_archivo`. Sin este corte, borrar una imagen o un audio caia igual
    // en su `case` y seguia pintando la foto o el reproductor: lo unico que
    // cambiaba era el fondo de la burbuja, atenuado. De ahi la sensacion de
    // "solo se pone en gris y no se si lo borra o no" — si lo borraba, pero
    // el contenido seguia a la vista.
    if (msg.isDeleted) {
      // El mismo color en ambos lados: la burbuja borrada usa `surfaceVariant`
      // venga de quien venga (ver ChatBubble), asi que `onPrimary` no
      // contrastaria.
      final atenuado = colors.textSecondary;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.do_not_disturb_on_outlined, size: 15, color: atenuado),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              msg.contenido,
              style: TextStyle(
                color: atenuado,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    switch (msg.tipo) {
      case 'vehiculo_card':
        return VehiculoChatCard(metadata: msg.metadata ?? {}, isMe: isMe);
      case 'reserva_card':
        return ReservaChatCard(
          metadata: msg.metadata ?? {},
          isMe: isMe,
          mensajeId: msg.id,
          conversacionId: widget.conversacionId,
          firestore: widget.firestore,
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

/// Diálogo "Editar mensaje" como StatefulWidget propio (no un controller
/// creado inline en el método que abre el diálogo): su TextEditingController
/// debe liberarse en `State.dispose()`, que el framework llama recién
/// cuando el Element del diálogo se desmonta de verdad (tras terminar la
/// animación de salida). Mismo patrón y mismo motivo documentados en
/// `catalogo_servicios_screen.dart` (`_NuevoItemDialog`): llamar
/// `.dispose()` en un `.then((_) => ...)` tras `showDialog(...)` dispara "A
/// TextEditingController was used after being disposed", porque ese Future
/// se completa apenas se invoca `Navigator.pop()`, ANTES de que termine la
/// animación de salida del diálogo (revisión C4b, hallazgo R9).
class _EditarMensajeDialog extends StatefulWidget {
  final String conversacionId;
  final String mensajeId;
  final String contenidoOriginal;

  const _EditarMensajeDialog({
    required this.conversacionId,
    required this.mensajeId,
    required this.contenidoOriginal,
  });

  @override
  State<_EditarMensajeDialog> createState() => _EditarMensajeDialogState();
}

class _EditarMensajeDialogState extends State<_EditarMensajeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.contenidoOriginal);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nuevoTexto = _controller.text.trim();
    final chatProvider = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.l10n.chatEditFailed;
    Navigator.pop(context);
    if (nuevoTexto.isEmpty || nuevoTexto == widget.contenidoOriginal) return;

    final editado = await chatProvider.editarMensaje(
      widget.conversacionId,
      widget.mensajeId,
      nuevoTexto,
    );
    // `messenger` es una referencia al ScaffoldMessengerState del árbol,
    // no depende de que este diálogo (ya cerrado) siga montado.
    if (!editado) {
      messenger.showSnackBar(SnackBar(content: Text(errorText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chatEditMessage),
      content: TextField(
        key: const Key('campo_editar_mensaje'),
        controller: _controller,
        autofocus: true,
        maxLines: null,
        decoration: InputDecoration(hintText: context.l10n.chatEditMessageHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.adminCancel),
        ),
        TextButton(onPressed: _guardar, child: Text(context.l10n.chatSaveEdit)),
      ],
    );
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
