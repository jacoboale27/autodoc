import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/core/utils/mechanic_profile_utils.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_picker.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:go_router/go_router.dart';

class ReservaDetailScreen extends StatefulWidget {
  final String reservaId;

  /// Aceptado por compatibilidad con la firma que usa app_router.dart para
  /// las otras rutas con precarga (`/vehicle_profile/:id`,
  /// `/initiate_service/:id`), pero deliberadamente sin usar aquí: esta
  /// pantalla siempre carga la reserva en vivo desde Firestore por
  /// [reservaId] (ver el `StreamBuilder` en `build()`), que es justamente la
  /// corrección que reemplazó la reconstrucción de datos falsos desde los
  /// metadatos del chat (hora incorrecta, vehículo ausente).
  final ReservaModel? reservaPrecargada;

  /// Inyectable para pruebas de widget (`FakeFirebaseFirestore`); por
  /// defecto usa la instancia real. Ver Tarea 12 / C-03: esta pantalla no
  /// debe quedar en blanco si la reserva no existe, y probar eso requiere
  /// poder simular un documento ausente sin tocar Firestore real.
  final FirebaseFirestore? firestore;

  const ReservaDetailScreen({
    super.key,
    required this.reservaId,
    this.reservaPrecargada,
    this.firestore,
  });

  @override
  State<ReservaDetailScreen> createState() => _ReservaDetailScreenState();
}

class _ReservaDetailScreenState extends State<ReservaDetailScreen> {
  bool _isLoading = false;

  Future<void> _cambiarEstado(String nuevoEstado) async {
    setState(() => _isLoading = true);
    try {
      final reservaProvider = context.read<ReservaProvider>();
      await reservaProvider.cambiarEstadoReserva(
        widget.reservaId,
        nuevoEstado,
        fechaConfirmada: nuevoEstado == 'confirmada' ? DateTime.now() : null,
      );
      if (mounted) {
        UiUtils.showSuccessSnackbar(
          context,
          context.l10n.chatReservationSuccess(nuevoEstado),
        );
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showErrorSnackbar(
          context,
          context.l10n.adminError(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reprogramar(ReservaModel reserva) async {
    final date = await showDatePicker(
      context: context,
      initialDate: reserva.fechaHoraPropuesta,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(reserva.fechaHoraPropuesta),
    );
    if (time == null || !mounted) return;

    final nuevaFecha = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final reservaProvider = context.read<ReservaProvider>();
    final success = await reservaProvider.reprogramarReserva(
      reserva.id,
      nuevaFecha,
    );
    if (!mounted) return;
    if (success) {
      UiUtils.showSuccessSnackbar(context, 'Cita reprogramada.');
    } else {
      UiUtils.showErrorSnackbar(
        context,
        reservaProvider.error ?? 'No se pudo reprogramar la cita.',
      );
    }
  }

  Future<void> _cotizar(ReservaModel reserva) async {
    final mechanicUser = context.read<UserProfileProvider>().userData;
    final userId = mechanicUser?.idUsuario;
    if (userId == null) return;

    if (!isMechanicProfileComplete(mechanicUser)) {
      final missing = missingMechanicProfileFields(mechanicUser);
      if (!mounted) return;
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
    final reservaProvider = context.read<ReservaProvider>();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CotizacionPicker(
        initialFecha: reserva.fechaHoraPropuesta,
        subtitle: 'Estás cotizando la cita que propuso el cliente.',
        onConfirm: (items, fechaPropuesta) async {
          final cotizacion = CotizacionModel(
            id: '',
            idPropietario: reserva.idPropietario,
            idMecanico: userId,
            idVehiculo: reserva.idVehiculo.isNotEmpty
                ? reserva.idVehiculo
                : null,
            idTaller: userId,
            items: items,
            fechaPropuesta: fechaPropuesta,
            fecha: DateTime.now(),
          );

          final ok = await chatProvider.enviarCotizacion(
            cotizacion: cotizacion,
            conversacionId: reserva.idConversacion,
            contenido: 'He enviado una cotización para tu cita solicitada.',
            remitenteId: userId,
            receptorId: reserva.idPropietario,
            isMecanicoRemitente: true,
          );
          if (!ok) {
            if (mounted) {
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

          await reservaProvider.cambiarEstadoReserva(
            reserva.id,
            'cotizada',
            fechaConfirmada: fechaPropuesta,
          );

          if (mounted) {
            UiUtils.showSuccessSnackbar(
              context,
              'Cotización enviada. Revísala en el chat.',
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMecanico = isMechanicRole(
      context.watch<UserProfileProvider>().userData?.rol,
    );

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
      appBar: AppBar(
        title: Text(context.l10n.chatReservationDetail),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: (widget.firestore ?? FirebaseFirestore.instance)
            .collection(FirestoreCollections.reservas)
            .doc(widget.reservaId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'No se encontró esta cita.',
                style: TextStyle(color: colors.textPrimary),
              ),
            );
          }

          final reserva = ReservaModel.fromMap(
            snapshot.data!.data()!,
            snapshot.data!.id,
          );

          final estadoColor = reserva.estado == 'confirmada'
              ? Colors.green
              : (reserva.estado == 'rechazada'
                    ? Colors.red
                    : (reserva.estado == 'cotizada'
                          ? Colors.blue
                          : colors.warning));

          final estadoTexto = switch (reserva.estado) {
            'confirmada' => 'Confirmada',
            'rechazada' => 'Rechazada',
            'cotizada' => 'Cotización Enviada',
            _ => 'Pendiente de Confirmación',
          };

          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: estadoColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    estadoTexto,
                                    style: TextStyle(
                                      color: estadoColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_month,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              context.l10n.chatService,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reserva.tipoServicio.isNotEmpty
                                  ? reserva.tipoServicio
                                  : 'Mantenimiento General',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.chatDate,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'EEE, dd MMM yyyy',
                                          'es',
                                        ).format(reserva.fechaHoraPropuesta),
                                        style: AppTextStyles.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.chatTime,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'hh:mm a',
                                        ).format(reserva.fechaHoraPropuesta),
                                        style: AppTextStyles.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Text(
                              context.l10n.chatVehicleId,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reserva.idVehiculo.isNotEmpty
                                  ? reserva.idVehiculo
                                  : 'No especificado',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (reserva.estado == 'pendiente') ...[
                        const SizedBox(height: 32),
                        if (isMecanico) ...[
                          Text(
                            'Para aceptar, envía tu cotización con esta fecha.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _cotizar(reserva),
                              icon: const Icon(Icons.request_quote),
                              label: const Text(
                                'Cotizar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _cambiarEstado('confirmada'),
                              icon: const Icon(Icons.check),
                              label: Text(
                                context.l10n.chatAcceptAppointment,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => _reprogramar(reserva),
                            icon: const Icon(Icons.edit_calendar),
                            label: const Text(
                              'Reprogramar',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.primary,
                              side: BorderSide(color: colors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TextButton(
                            onPressed: () => _cambiarEstado('rechazada'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.error,
                            ),
                            child: const Text(
                              'Rechazar',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
        },
      ),
    );
  }
}
