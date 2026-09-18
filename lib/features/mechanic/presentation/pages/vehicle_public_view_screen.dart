import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/utils/mechanic_profile_utils.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/features/chat/data/models/vehiculo_cotizado.dart';
import 'package:autodoc/features/chat/presentation/pages/nueva_cotizacion_screen.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';

/// Ficha pública de un vehículo para un mecánico **sin** ticket de reparación
/// aceptado (A3/B2): solo nombre, placa, kilometraje e imagen. Ni "Recibir
/// vehículo", ni "Iniciar servicio", ni historial — nada de eso es posible
/// sin que el propietario haya aceptado una cotización primero.
///
/// La única acción es **cotizar**, y solo si el propietario ya agendó una cita
/// con este taller para este coche (observaciones del 2026-09-18: primero la
/// reserva, luego la cotización, y al aceptarla se desbloquea lo demás).
///
/// `abrirVehiculoComoMecanico` (`navegacion_vehiculo.dart`) es el único
/// lugar que decide traer al mecánico aquí en vez de a
/// `InitiateServiceScreen`; esta pantalla no repite esa decisión.
class VehiclePublicViewScreen extends StatefulWidget {
  final String vehiculoId;
  final VehicleModel? vehiculoPrecargado;

  const VehiclePublicViewScreen({
    super.key,
    required this.vehiculoId,
    this.vehiculoPrecargado,
  });

  @override
  State<VehiclePublicViewScreen> createState() =>
      _VehiclePublicViewScreenState();
}

class _VehiclePublicViewScreenState extends State<VehiclePublicViewScreen> {
  VehicleModel? _vehiculo;
  bool _cargando = false;
  bool _errorCarga = false;

  /// ¿Hay ya una cotización aceptada de este taller para este vehículo?
  /// `null` mientras se comprueba.
  ///
  /// Sin esta distinción, el aviso de bloqueo tenía un solo texto para dos
  /// situaciones opuestas, y eso cerraba un bucle sin salida que la revisión
  /// adversarial reprodujo entero: la tarjeta de la cotización aceptada le
  /// dice al mecánico «Recibe el vehículo desde "Buscar Vehículo"», y Buscar
  /// Vehículo le respondía «Necesitas una cotización aceptada» cuando SÍ
  /// existía una. Ni diagnóstico ni salida. Aquí se separan: "todavía no hay
  /// cotización aceptada" (y se ofrece contactar al propietario) frente a
  /// "hay una, pero el ticket aún no se ha abierto" (y se ofrece ir al
  /// tablero, donde aparecerá).
  bool? _hayCotizacionAceptada;

  /// La cita vigente del propietario con este taller para este coche, si la
  /// hay. Es lo que desbloquea cotizar desde aquí (observaciones del
  /// 2026-09-18): «si antes no recibió una reserva no debería de aparecer
  /// otra cosa que no sea el nombre del vehículo, la placa, el kilometraje y
  /// las imágenes», y con la reserva, primero se llena la cotización y luego
  /// se manda al dueño. Recibir el coche sigue exigiendo que el dueño ACEPTE
  /// esa cotización (el ticket lo abre `onCotizacionAceptada`).
  ReservaModel? _reserva;

  /// `true` tras enviar la cotización desde esta pantalla, para cambiar el
  /// aviso a "esperando respuesta" en vez de volver a ofrecer cotizar.
  bool _cotizacionEnviada = false;

  @override
  void initState() {
    super.initState();
    _vehiculo = widget.vehiculoPrecargado;
    if (_vehiculo == null) {
      _cargarVehiculo();
    } else {
      _comprobarCotizacionAceptada();
      _buscarReserva();
    }
  }

  /// Un fallo aquí deja la pantalla como estaba antes: solo la ficha pública.
  Future<void> _buscarReserva() async {
    final vehiculo = _vehiculo;
    if (vehiculo == null) return;
    final uid = context.read<UserProfileProvider>().userData?.idUsuario ?? '';
    if (uid.isEmpty) return;
    try {
      final reserva = await context
          .read<ReservaProvider>()
          .reservaVigenteParaVehiculo(
            idMecanico: uid,
            idVehiculo: vehiculo.idVehiculo,
          );
      if (!mounted) return;
      setState(() => _reserva = reserva);
    } catch (e) {
      debugPrint('No se pudo comprobar la cita del vehículo: $e');
    }
  }

  Future<void> _cotizar() async {
    final vehiculo = _vehiculo;
    final reserva = _reserva;
    if (vehiculo == null || reserva == null) return;
    final mecanico = context.read<UserProfileProvider>().userData;
    final userId = mecanico?.idUsuario;
    if (userId == null) return;
    if (!isMechanicProfileComplete(mecanico)) {
      UiUtils.showErrorSnackbar(
        context,
        'Para enviar cotizaciones primero completa en tu perfil: '
        '${missingMechanicProfileFields(mecanico).join(', ')}.',
      );
      return;
    }
    final chatProvider = context.read<ChatProvider>();
    final reservaProvider = context.read<ReservaProvider>();

    final enviado = await abrirNuevaCotizacion(
      context,
      vehiculo: VehiculoCotizado.desdeVehiculo(vehiculo),
      initialFecha: reserva.fechaHoraPropuesta,
      subtitle: 'Estás cotizando la cita que agendó el propietario.',
      onEnviar: (borrador) async {
        final ok = await chatProvider.enviarCotizacion(
          cotizacion: borrador.toCotizacion(
            idPropietario: reserva.idPropietario,
            idMecanico: userId,
            idVehiculo: vehiculo.idVehiculo,
            idTaller: mecanico?.idTallerEfectivo ?? userId,
            idReserva: reserva.id,
          ),
          conversacionId: reserva.idConversacion,
          contenido: 'He enviado una cotización para tu cita solicitada.',
          remitenteId: userId,
          receptorId: reserva.idPropietario,
          isMecanicoRemitente: true,
        );
        if (!ok) {
          if (mounted) {
            UiUtils.showErrorSnackbar(
              context,
              chatProvider.error ?? 'No se pudo enviar la cotización.',
            );
          }
          return false;
        }
        // Igual que "Cotizar y Aceptar" en el chat: una cita pendiente pasa a
        // cotizada. Una ya confirmada no se toca.
        if (reserva.estado == 'pendiente') {
          await reservaProvider.cambiarEstadoReserva(
            reserva.id,
            'cotizada',
            fechaConfirmada: borrador.fechaPropuesta,
          );
        }
        return true;
      },
    );
    if (!enviado || !mounted) return;
    setState(() => _cotizacionEnviada = true);
    UiUtils.showSuccessSnackbar(
      context,
      'Cotización enviada al propietario. Revísala en el chat.',
    );
  }

  /// Se filtra por `id_taller`, no por `id_mecanico == uid`.
  ///
  /// La pregunta que esta pantalla hace es «¿tiene MI TALLER una cotización
  /// aceptada de este vehículo?», y una cotización pertenece al taller, no al
  /// operario que la redactó. Filtrar por el uid de la sesión respondía otra
  /// pregunta: en un taller con empleados, el aviso decía «este vehículo no
  /// tiene una cotización aceptada en tu taller» a cualquiera que no fuera
  /// quien la escribió — al dueño incluida. Se filtraba así porque
  /// `firestore.rules` no admitía otra consulta de lista; la Ronda 4 añadió
  /// `actuaPorTaller(id_taller)` al `allow read` de /cotizaciones justo para
  /// esto.
  ///
  /// Un fallo aquí no rompe la pantalla: se queda en el aviso genérico, que
  /// es lo que había antes.
  Future<void> _comprobarCotizacionAceptada() async {
    final vehiculo = _vehiculo;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (vehiculo == null || uid == null) return;
    if (!mounted) return;
    // `idTallerEfectivo`: el uid del DUEÑO del taller, igual que el resto del
    // módulo (`vehicle_search_screen.dart`, `initiate_service_screen.dart`).
    final idTaller =
        context.read<UserProfileProvider>().userData?.idTallerEfectivo ?? uid;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cotizaciones')
          .where('id_vehiculo', isEqualTo: vehiculo.idVehiculo)
          .where('id_taller', isEqualTo: idTaller)
          .where('estado', isEqualTo: 'aceptada')
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() => _hayCotizacionAceptada = snap.docs.isNotEmpty);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hayCotizacionAceptada = null);
    }
  }

  /// Igual que `VehicleProfileScreen`/`InitiateServiceScreen`: `extra` es
  /// solo una precarga, nunca la única fuente del dato. Sin este respaldo,
  /// un F5 sobre esta URL (que sí puede pasar: es la primera pantalla del
  /// mecánico para un vehículo sin ticket) dejaba la vista en blanco.
  Future<void> _cargarVehiculo() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.vehiculos)
          .doc(widget.vehiculoId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _cargando = false;
          _errorCarga = true;
        });
        return;
      }
      setState(() {
        _vehiculo = VehicleModel.fromMap(doc.data()!, doc.id);
        _cargando = false;
      });
      _comprobarCotizacionAceptada();
      _buscarReserva();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final vehiculo = _vehiculo;
    if (_errorCarga || vehiculo == null) {
      return const MissingArgumentScreen(
        mensaje: 'No se pudo cargar el vehículo.',
        rutaVuelta: '/mechanic_search',
      );
    }

    final colors = context.appColors;
    final nombre = [
      vehiculo.marca,
      vehiculo.modelo,
    ].where((p) => p != null && p.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          tooltip: 'Volver',
          onPressed: () => context.go('/mechanic_search'),
        ),
        title: Text(
          'Vehículo',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: AppPageBody(
          maxWidth: AppBreakpoints.maxReadingWidth,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child:
                        vehiculo.fotoUrl != null && vehiculo.fotoUrl!.isNotEmpty
                        ? Image.network(
                            vehiculo.fotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _SinFoto(colors: colors),
                          )
                        : _SinFoto(colors: colors),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  nombre.isEmpty ? 'Vehículo' : nombre,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(vehiculo.placa, style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${vehiculo.kilometrajeActual} km',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_hayCotizacionAceptada != true && _reserva != null)
                  _AvisoCita(
                    colors: colors,
                    reserva: _reserva!,
                    cotizacionEnviada:
                        _cotizacionEnviada || _reserva!.estado == 'cotizada',
                    onCotizar: _cotizar,
                  )
                else
                  _AvisoDeBloqueo(
                    colors: colors,
                    hayCotizacionAceptada: _hayCotizacionAceptada,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El aviso que explica POR QUÉ esta pantalla no ofrece ninguna acción.
///
/// Tiene dos textos y dos salidas porque hay dos causas distintas (ver
/// `_hayCotizacionAceptada`). Mientras la comprobación está en vuelo —o si
/// falló— se mantiene el texto genérico anterior: es el peor caso, no el
/// caso por defecto.
class _AvisoDeBloqueo extends StatelessWidget {
  final AppColors colors;
  final bool? hayCotizacionAceptada;

  const _AvisoDeBloqueo({
    required this.colors,
    required this.hayCotizacionAceptada,
  });

  @override
  Widget build(BuildContext context) {
    final conCotizacion = hayCotizacionAceptada == true;
    final texto = conCotizacion
        ? 'Este vehículo ya tiene una cotización aceptada en tu taller, pero '
              'el ticket todavía no se ha abierto. El ticket se abre solo al '
              'aceptarse la cotización y aparece en Reparaciones, en '
              '"Por recibir". Si no aparece ahí, no lo recibas desde aquí: '
              'avisa al soporte con la placa.'
        : 'Este vehículo todavía no tiene una cita contigo. Cuando el '
              'propietario agende una cita desde el chat y elija este '
              'vehículo, podrás enviarle tu cotización desde aquí; al '
              'aceptarla, el vehículo aparecerá en Reparaciones.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                conCotizacion ? Icons.hourglass_empty : Icons.info_outline,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  texto,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (conCotizacion) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.go('/mechanic_reparaciones'),
                icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                label: const Text('Ir a Reparaciones'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hay una cita vigente del propietario con este taller para este coche: ya
/// se puede cotizar. Recibir el coche sigue esperando a que el propietario
/// acepte la cotización.
class _AvisoCita extends StatelessWidget {
  final AppColors colors;
  final ReservaModel reserva;
  final bool cotizacionEnviada;
  final VoidCallback onCotizar;

  const _AvisoCita({
    required this.colors,
    required this.reserva,
    required this.cotizacionEnviada,
    required this.onCotizar,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat(
      "d 'de' MMMM, h:mm a",
      'es',
    ).format(reserva.fechaHoraPropuesta);
    final texto = cotizacionEnviada
        ? 'Ya le enviaste una cotización para la cita del $fecha. Cuando el '
              'propietario la acepte, el vehículo aparecerá en Reparaciones '
              'para que lo recibas.'
        : 'El propietario agendó una cita para el $fecha. Prepara tu '
              'cotización y envíasela: cuando la acepte, el vehículo '
              'aparecerá en Reparaciones.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.event_available, color: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  texto,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            key: const Key('vehiculo_publico_crear_cotizacion'),
            text: cotizacionEnviada
                ? 'Enviar otra cotización'
                : 'Crear cotización',
            type: cotizacionEnviada
                ? AppButtonType.secondary
                : AppButtonType.primary,
            icon: const Icon(Icons.request_quote_outlined),
            onPressed: onCotizar,
          ),
          if (reserva.idConversacion.isNotEmpty)
            TextButton.icon(
              onPressed: () => context.go('/chat/${reserva.idConversacion}'),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Ir al chat con el propietario'),
            ),
        ],
      ),
    );
  }
}

class _SinFoto extends StatelessWidget {
  final AppColors colors;

  const _SinFoto({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainer,
      child: Icon(
        Icons.directions_car,
        size: 64,
        color: colors.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }
}
