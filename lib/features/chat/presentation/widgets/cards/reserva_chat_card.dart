import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/core/utils/mechanic_profile_utils.dart';
import 'package:autodoc/core/utils/reserva_acciones.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class ReservaChatCard extends StatelessWidget {
  /// Sentinel usado solo cuando no hay documento vivo del que leer el
  /// `id_proponente` real (mensaje sin `id_reserva`, o documento
  /// borrado/no legible) y el remitente no es el usuario actual: garantiza
  /// que la comparación de proponente en `calcularAccionesReserva` no
  /// coincida por accidente con ningún uid real.
  static const String _sinProponenteEnVivo = '__sin_datos_de_reserva__';

  final Map<String, dynamic> metadata;
  final bool isMe;
  final String mensajeId;
  final String conversacionId;

  /// Inyectable para pruebas de widget (`FakeFirebaseFirestore`); por
  /// defecto usa la instancia real. Mismo precedente que
  /// `CotizacionChatCard`/`ReservaDetailScreen`: sin esto, el
  /// `StreamBuilder` de `build()` lanzaría `FirebaseException('[core/no-app]')`
  /// en un widget test sin `Firebase.initializeApp()`.
  final FirebaseFirestore? firestore;

  const ReservaChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
    required this.mensajeId,
    required this.conversacionId,
    this.firestore,
  });

  Future<void> _actualizar(
    BuildContext context,
    String estado, {
    DateTime? fechaConfirmada,
  }) async {
    final newMeta = Map<String, dynamic>.from(metadata);
    newMeta['estado'] = estado;
    final provider = context.read<ChatProvider>();
    final reservaProvider = context.read<ReservaProvider>();
    await provider.actualizarMetadatosMensaje(
      conversacionId,
      mensajeId,
      newMeta,
    );
    final reservaId = metadata['id_reserva'];
    if (reservaId != null) {
      await reservaProvider.cambiarEstadoReserva(
        reservaId,
        estado,
        fechaConfirmada: fechaConfirmada,
      );
    }
  }

  Future<void> _cotizarYAceptar(
    BuildContext context,
    String reservaId,
    DateTime fechaMetadata,
  ) async {
    final mechanicUser = context.read<UserProfileProvider>().userData;
    final userId = mechanicUser?.idUsuario;
    if (userId == null) return;

    // La 'fecha' del metadata del mensaje viene sin hora (solo se usa para
    // el texto del bubble; la hora se muestra por separado desde
    // metadata['hora']). La hora real vive en reservas/{id}.fechaHoraPropuesta,
    // así que se busca ahí para no abrir el picker de cotización siempre en
    // 12:00 AM. Si la reserva ya no existe, se usa el metadata como último
    // recurso para no bloquear el flujo.
    final reservaProvider = context.read<ReservaProvider>();
    final reserva = await reservaProvider.obtenerReserva(reservaId);
    final fecha = reserva?.fechaHoraPropuesta ?? fechaMetadata;
    if (!context.mounted) return;

    if (!isMechanicProfileComplete(mechanicUser)) {
      final missing = missingMechanicProfileFields(mechanicUser);
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
      return;
    }

    final chatProvider = context.read<ChatProvider>();
    final conversacion = chatProvider.conversaciones
        .where((c) => c.id == conversacionId)
        .firstOrNull;
    final receptorId = conversacion?.idPropietario;
    if (receptorId == null || receptorId.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CotizacionPicker(
        initialFecha: fecha,
        subtitle: 'Estás cotizando la cita que propuso el cliente.',
        onConfirm: (items, fechaPropuesta) async {
          final cotizacion = CotizacionModel(
            id: '',
            idPropietario: receptorId,
            idMecanico: userId,
            idVehiculo: conversacion?.idVehiculo,
            idTaller: userId,
            idReserva: reservaId,
            items: items,
            fechaPropuesta: fechaPropuesta,
            fecha: DateTime.now(),
          );

          final ok = await chatProvider.enviarCotizacion(
            cotizacion: cotizacion,
            conversacionId: conversacionId,
            contenido: 'He enviado una cotización para tu cita solicitada.',
            remitenteId: userId,
            receptorId: receptorId,
            isMecanicoRemitente: true,
          );
          if (!ok) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    chatProvider.error ?? 'No se pudo enviar la cotización.',
                  ),
                ),
              );
            }
            return;
          }

          if (!context.mounted) return;
          await _actualizar(
            context,
            'cotizada',
            fechaConfirmada: fechaPropuesta,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? reservaId = metadata['id_reserva'] as String?;

    // Los mensajes de reserva ya existentes en producción pueden no traer
    // `id_reserva` en su metadata: sin documento que leer, se renderiza
    // directamente desde la copia congelada del mensaje, igual que antes
    // de esta tarea.
    if (reservaId == null) {
      return _buildBody(context, estadoVivo: null, idProponenteVivo: null);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: (firestore ?? FirebaseFirestore.instance)
          .collection('reservas')
          .doc(reservaId)
          .snapshots(),
      builder: (context, snapshot) {
        // Mientras no llega la primera respuesta del documento vivo, no se
        // pinta el estado congelado de `metadata`: mostrarlo y corregirlo
        // luego sería una versión peor del bug A2 (parpadeo
        // "Pendiente" -> "Confirmada"). Se muestra un loader en su lugar.
        if (!snapshot.hasData && !snapshot.hasError) {
          return const ChatCardShell(
            icon: Icons.event,
            title: 'Reserva de Cita',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Documento borrado o sin permiso de lectura: se cae al respaldo de
        // `metadata` en vez de dejar la tarjeta atascada en el loader
        // (lectura tolerante, requerida por el proyecto para producción).
        final data = (!snapshot.hasError && snapshot.data?.exists == true)
            ? snapshot.data!.data()
            : null;

        return _buildBody(
          context,
          estadoVivo: data?['estado'] as String?,
          idProponenteVivo: data?['id_proponente'] as String?,
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required String? estadoVivo,
    required String? idProponenteVivo,
  }) {
    final colors = context.appColors;
    final currentUser = context.watch<UserProfileProvider>().userData;
    final isMecanico = isMechanicRole(currentUser?.rol);
    final currentUserId = currentUser?.idUsuario ?? '';

    final String? reservaId = metadata['id_reserva'] as String?;
    final String fechaRaw = metadata['fecha'] ?? '';
    final String hora = metadata['hora'] ?? '';
    // `metadata['estado']` es una copia congelada al enviarse el mensaje:
    // la reserva cambia de estado (aceptada/rechazada) pero el mensaje
    // nunca se reescribe (bug A2). `estadoVivo` viene de `reservas/{id}` y
    // es la fuente de verdad; `metadata` queda solo como respaldo para
    // mensajes sin `id_reserva`, o si el documento fue borrado / no se
    // pudo leer.
    final String estado =
        estadoVivo ??
        metadata['estado'] ??
        'pendiente'; // pendiente, confirmada, rechazada, cotizada

    DateTime? fecha;
    if (fechaRaw.isNotEmpty) {
      fecha = DateTime.tryParse(fechaRaw);
    }

    final severidad = AppSeverity.forReservaEstado(
      estado,
      colors,
      pendienteLabel: 'Pendiente',
      confirmadaLabel: 'Confirmada',
      rechazadaLabel: 'Rechazada',
      cotizadaLabel: 'Cotización Enviada',
      canceladaLabel: context.l10n.chatCancelledStatus,
    );

    // R4: el `id_proponente` real vive en `reservas/{id}`. Antes de leer el
    // documento vivo se aproximaba con `isMe` (quien envía el mensaje es
    // quien propuso la fecha en ese momento) — pero tras una
    // reprogramación la contraparte puede pasar a proponer mientras el
    // mensaje sigue perteneciendo al remitente original, y ahí `isMe`
    // miente. Con el documento vivo ya no hace falta adivinar; el respaldo
    // por `isMe` solo se usa cuando no hay documento que leer (mensaje sin
    // `id_reserva`, o documento borrado/no legible), igual que `estado`
    // arriba.
    final String idProponente =
        idProponenteVivo ?? (isMe ? currentUserId : _sinProponenteEnVivo);

    final acciones = calcularAccionesReserva(
      estado: estado,
      idProponente: idProponente,
      currentUserId: currentUserId,
      isMecanico: isMecanico,
    );

    return ChatCardShell(
      icon: Icons.event,
      title: 'Reserva de Cita',
      semanticLabel: 'Reserva de cita, ${severidad.label}',
      trailing: AppStatusBadge(
        text: severidad.label,
        icon: severidad.icon,
        type: _statusTypeDe(estado),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: colors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fecha != null
                      ? DateFormat('dd MMM yyyy', 'es').format(fecha)
                      : 'Fecha sin definir',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: colors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  hora.isNotEmpty ? hora : 'Hora sin definir',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // QA reportó como bug de permisos (A1) el ver los botones
          // aceptar/rechazar siendo cliente. No lo es: el mecánico también
          // propone fechas y entonces resuelve el cliente. Se hace explícito
          // para que no vuelva a leerse mal.
          if (estado == 'pendiente') ...[
            const SizedBox(height: 8),
            Text(
              // R4: se compara contra el `id_proponente` real (o su
              // respaldo), no contra `isMe` — ver el comentario junto a
              // `idProponente` más arriba.
              idProponente == currentUserId
                  ? 'Propusiste esta fecha — espera respuesta'
                  : 'Te propusieron esta fecha',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
          if (acciones.tieneAcciones) ...[
            const SizedBox(height: 12),
            if (acciones.puedeCotizarYAceptar) ...[
              // El mecánico solo puede "aceptar" enviando una cotización
              // para la misma fecha propuesta por el cliente: se deniega a
              // propósito un "aceptar sin precio" para que el cliente nunca
              // vea una cita confirmada sin costo claro.
              Text(
                'Aceptas la cita enviando tu cotización con esta fecha.',
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: context.l10n.chatReject,
                      type: AppButtonType.secondary,
                      onPressed: () => _actualizar(context, 'rechazada'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      text: 'Cotizar y Aceptar',
                      type: AppButtonType.primary,
                      onPressed: fecha == null || reservaId == null
                          ? null
                          : () => _cotizarYAceptar(context, reservaId, fecha!),
                    ),
                  ),
                ],
              ),
            ] else if (acciones.puedeAceptar || acciones.puedeRechazar) ...[
              // `tieneAcciones` también es true cuando lo único disponible
              // es `puedeCancelar` (p.ej. el propio proponente, o el estado
              // 'confirmada'), y esta tarjeta no tiene un botón de cancelar:
              // sin este guard se mostraban Aceptar/Rechazar igual, aunque
              // `calcularAccionesReserva` ya los hubiera negado — justo el
              // tipo de contradicción con el invariante que A1 casi generó.
              Row(
                children: [
                  if (acciones.puedeAceptar)
                    Expanded(
                      child: AppButton(
                        text: context.l10n.chatAccept,
                        type: AppButtonType.secondary,
                        onPressed: () => _actualizar(
                          context,
                          'confirmada',
                          fechaConfirmada: DateTime.now(),
                        ),
                      ),
                    ),
                  if (acciones.puedeAceptar && acciones.puedeRechazar)
                    const SizedBox(width: 8),
                  if (acciones.puedeRechazar)
                    Expanded(
                      child: AppButton(
                        text: context.l10n.chatReject,
                        type: AppButtonType.secondary,
                        onPressed: () => _actualizar(context, 'rechazada'),
                      ),
                    ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: context.l10n.chatViewDetail,
              type: AppButtonType.text,
              onPressed: metadata['id_reserva'] == null
                  ? null
                  : () => context.push(
                      '/reserva_detail/${metadata['id_reserva']}',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  AppStatusType _statusTypeDe(String estado) => switch (estado) {
    'confirmada' || 'aceptada' => AppStatusType.success,
    'rechazada' ||
    'cancelada' ||
    'cancelada_por_propietario' ||
    'cancelada_por_taller' => AppStatusType.error,
    'cotizada' || 'finalizada' => AppStatusType.info,
    _ => AppStatusType.warning,
  };
}
