import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/mechanic_profile_utils.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/features/chat/data/models/vehiculo_cotizado.dart';
import 'package:autodoc/features/chat/presentation/pages/nueva_cotizacion_screen.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/license_plate_widget.dart';
import 'package:autodoc/features/mechanic/data/repositories/trabajos_taller_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart'
    show etiquetasEstado;
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/trabajos_taller_widgets.dart';

/// El vehículo visto por el taller: a donde lleva buscar una placa (y la
/// tarjeta de vehículo del chat).
///
/// Enseña más o menos según la relación del coche con ESTE taller:
///
/// - **Ninguna** (ni cotización suya, ni cita, ni servicio): solo la ficha
///   pública —nombre, placa, kilometraje e imagen— y el aviso de que hace
///   falta una cita (A3/B2). Ni recibir, ni servicio, ni historial.
/// - **Una cita vigente** del propietario con el taller: la ficha y "Crear
///   cotización" (observaciones del 2026-09-18).
/// - **Una o más cotizaciones aceptadas, o servicios ya hechos**: el perfil
///   completo (observaciones del 2026-09-19) — los datos generales, el
///   servicio en curso con su estado y el acceso a él, las cotizaciones del
///   taller para este coche y los servicios que ya le hizo — y "Nueva
///   cotización", para mandarle al dueño una cotización extra con la misma
///   pantalla de cotizar de siempre.
///
/// Recibir el coche y registrar el servicio siguen en `InitiateServiceScreen`,
/// a la que se llega desde el servicio en curso: esta pantalla no recibe ni
/// cobra nada, así que no rebaja ninguna de las compuertas de A3/B2.
class VehiclePublicViewScreen extends StatefulWidget {
  final String vehiculoId;
  final VehicleModel? vehiculoPrecargado;

  /// Inyectables solo para pruebas.
  final FirebaseFirestore? firestore;
  final TrabajosTallerRepository? trabajos;

  const VehiclePublicViewScreen({
    super.key,
    required this.vehiculoId,
    this.vehiculoPrecargado,
    this.firestore,
    this.trabajos,
  });

  @override
  State<VehiclePublicViewScreen> createState() =>
      _VehiclePublicViewScreenState();
}

class _VehiclePublicViewScreenState extends State<VehiclePublicViewScreen> {
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  TrabajosTallerRepository get _trabajos =>
      widget.trabajos ?? TrabajosTallerRepository(firestore: _db);

  VehicleModel? _vehiculo;
  bool _cargando = false;
  bool _errorCarga = false;

  /// Todo lo que decide qué se enseña llega a la vez: hasta entonces, un
  /// indicador de carga en vez de pintar la ficha pública y cambiarla medio
  /// segundo después por el perfil.
  bool _cargandoRelacion = true;

  /// Cotizaciones de este taller para este coche, de la más nueva a la más
  /// vieja. `null` si no se pudieron leer.
  List<CotizacionModel>? _cotizaciones;
  List<ServiceRecordModel>? _servicios;
  ReparacionModel? _ticket;

  /// El último ticket cuando ya no hay ninguno vivo. Sin esto, un coche
  /// recién entregado caía en el aviso de «el ticket todavía no se ha
  /// abierto», que es lo contrario de lo que pasó (observación del
  /// 2026-09-19).
  ReparacionModel? _ticketCerrado;

  /// La cita vigente del propietario con este taller para este coche, si la
  /// hay (observaciones del 2026-09-18).
  ReservaModel? _reserva;

  /// `true` tras enviar la cotización de la cita desde aquí, para cambiar el
  /// aviso a "esperando respuesta".
  bool _cotizacionEnviada = false;

  /// Guard de reentrada del botón de cotizar (GAPS-07).
  bool _cotizando = false;

  String get _idTaller {
    final usuario = context.read<UserProfileProvider>().userData;
    return usuario?.idTallerEfectivo ?? '';
  }

  List<CotizacionModel> get _aceptadas =>
      (_cotizaciones ?? const []).where((c) => c.estado == 'aceptada').toList();

  /// ¿Tiene este coche historia con ESTE taller? Es lo que abre el perfil
  /// completo.
  bool get _conRelacion =>
      _ticket != null ||
      (_cotizaciones ?? const []).any(
        (c) => c.estado == 'aceptada' || c.estado == 'finalizada',
      ) ||
      (_servicios ?? const []).isNotEmpty;

  /// A quién va una cotización nueva: el dueño que ya aceptó una, o el de la
  /// cita. `null` si no se sabe (entonces no se ofrece cotizar).
  String? get _idPropietario {
    final deLaCita = _reserva?.idPropietario;
    if (deLaCita != null && deLaCita.isNotEmpty) return deLaCita;
    for (final c in _cotizaciones ?? const <CotizacionModel>[]) {
      if (c.idPropietario.isNotEmpty) return c.idPropietario;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _vehiculo = widget.vehiculoPrecargado;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_vehiculo == null) {
        _cargarVehiculo();
      } else {
        _cargarRelacion();
      }
    });
  }

  /// Igual que `VehicleProfileScreen`/`InitiateServiceScreen`: `extra` es
  /// solo una precarga, nunca la única fuente del dato. Sin este respaldo,
  /// un F5 sobre esta URL dejaba la vista en blanco.
  ///
  /// Primero la ficha completa (la puede leer el taller que tiene el coche);
  /// si las reglas no la dejan leer —lo normal antes de recibirlo—, la ficha
  /// pública, la misma que devuelve buscar la placa.
  Future<void> _cargarVehiculo() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    VehicleModel? vehiculo;
    try {
      final doc = await _db
          .collection(FirestoreCollections.vehiculos)
          .doc(widget.vehiculoId)
          .get();
      if (doc.exists) vehiculo = VehicleModel.fromMap(doc.data()!, doc.id);
    } catch (_) {
      // Sin acceso a la ficha completa: se intenta la pública.
    }
    if (vehiculo == null && mounted) {
      try {
        vehiculo = await context.read<VehicleProvider>().findPublicVehicleById(
          widget.vehiculoId,
        );
      } catch (e) {
        debugPrint('No se pudo leer la ficha pública del vehículo: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _vehiculo = vehiculo;
      _cargando = false;
      _errorCarga = vehiculo == null;
    });
    if (vehiculo != null) _cargarRelacion();
  }

  Future<void> _cargarRelacion() async {
    setState(() => _cargandoRelacion = true);
    try {
      // Cada carga atrapa su propio error; el tope es para que una consulta
      // que no contesta nunca no deje la pantalla girando para siempre: se
      // pinta con lo que haya llegado.
      await Future.wait([
        _cargarCotizaciones(),
        _cargarServicios(),
        _buscarTicket(),
        _buscarReserva(),
      ]).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Relación del vehículo con el taller sin cargar: $e');
    }
    if (mounted) setState(() => _cargandoRelacion = false);
  }

  /// Se filtra por `id_taller`, no por `id_mecanico == uid`: la cotización es
  /// del TALLER (en un taller con empleados, uno cotiza y otro cierra), y es
  /// además la única forma de que `firestore.rules` acepte la consulta.
  Future<void> _cargarCotizaciones() async {
    final vehiculo = _vehiculo;
    final idTaller = _idTaller;
    if (vehiculo == null || idTaller.isEmpty) return;
    try {
      final lista = await _trabajos.cotizacionesDelVehiculo(
        idVehiculo: vehiculo.idVehiculo,
        idTaller: idTaller,
      );
      if (mounted) setState(() => _cotizaciones = lista);
    } catch (e) {
      debugPrint('No se pudieron leer las cotizaciones del vehículo: $e');
      if (mounted) setState(() => _cotizaciones = null);
    }
  }

  Future<void> _cargarServicios() async {
    final vehiculo = _vehiculo;
    final idTaller = _idTaller;
    if (vehiculo == null || idTaller.isEmpty) return;
    try {
      final lista = await _trabajos.serviciosDelVehiculo(
        idVehiculo: vehiculo.idVehiculo,
        idTaller: idTaller,
      );
      if (mounted) setState(() => _servicios = lista);
    } catch (e) {
      debugPrint('No se pudieron leer los servicios del vehículo: $e');
      if (mounted) setState(() => _servicios = null);
    }
  }

  /// El ticket ya entregado cuyo servicio nadie registró, o `null`.
  ///
  /// Entregar revoca el vínculo y saca el ticket del tablero, así que hasta
  /// el 2026-09-19 el trabajo se quedaba sin factura y sin ninguna pantalla
  /// desde la que emitirla. El tablero ya avisa antes de entregar; esto es la
  /// salida para los que se entregaron antes de esa guarda.
  ///
  /// Se mide con los servicios que la pantalla YA cargó (van de más nuevo a
  /// más viejo), sin una consulta extra.
  ReparacionModel? get _ticketEntregadoSinCobro {
    final t = _ticketCerrado;
    if (t == null || t.estado != estadoReparacionEntregado) return null;
    final servicios = _servicios;
    if (servicios == null) return null;
    final ultimo = servicios.firstOrNull;
    if (ultimo != null && !ultimo.fecha.isBefore(t.fechaCreacion)) return null;
    return t;
  }

  Future<void> _buscarTicket() async {
    final vehiculo = _vehiculo;
    final idTaller = _idTaller;
    if (vehiculo == null || idTaller.isEmpty) return;
    try {
      final ticket = await context
          .read<ReparacionProvider>()
          .buscarTicketVigente(
            idVehiculo: vehiculo.idVehiculo,
            idTaller: idTaller,
          );
      if (!mounted) return;
      setState(() => _ticket = ticket);
      if (ticket != null) return;
      final ultimo = await context
          .read<ReparacionProvider>()
          .buscarUltimoTicket(
            idVehiculo: vehiculo.idVehiculo,
            idTaller: idTaller,
          );
      if (mounted) setState(() => _ticketCerrado = ultimo);
    } catch (e) {
      debugPrint('No se pudo comprobar el servicio en curso: $e');
    }
  }

  /// Un fallo aquí deja la pantalla como estaba antes: sin cita.
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
      if (mounted) setState(() => _reserva = reserva);
    } catch (e) {
      debugPrint('No se pudo comprobar la cita del vehículo: $e');
    }
  }

  /// Cotizar: la de la cita (desde la ficha) o una extra (desde el perfil).
  ///
  /// Es la misma pantalla de cotizar del chat y de la cita
  /// (`NuevaCotizacionScreen`); solo cambia a qué conversación va la tarjeta.
  Future<void> _cotizar({required bool extra}) async {
    if (_cotizando) return;
    final vehiculo = _vehiculo;
    final idPropietario = _idPropietario;
    final mecanico = context.read<UserProfileProvider>().userData;
    if (vehiculo == null || idPropietario == null || mecanico == null) return;
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
    final reserva = _reserva;
    final userId = mecanico.idUsuario;

    setState(() => _cotizando = true);
    try {
      final enviado = await abrirNuevaCotizacion(
        context,
        vehiculo: VehiculoCotizado.desdeVehiculo(vehiculo),
        initialFecha: reserva?.fechaHoraPropuesta ?? _proximaHora(),
        subtitle: extra
            ? 'Cotización adicional: le llega al propietario por el chat y, '
                  'cuando la acepte, se suma al servicio de este vehículo.'
            : 'Estás cotizando la cita que agendó el propietario.',
        onEnviar: (borrador) async {
          final conversacionId = await _conversacionCon(
            chatProvider,
            idPropietario: idPropietario,
          );
          if (conversacionId.isEmpty) {
            if (mounted) {
              UiUtils.showErrorSnackbar(
                context,
                chatProvider.error ??
                    'No se pudo abrir el chat con el propietario.',
              );
            }
            return false;
          }
          final ok = await chatProvider.enviarCotizacion(
            cotizacion: borrador.toCotizacion(
              idPropietario: idPropietario,
              idMecanico: userId,
              idVehiculo: vehiculo.idVehiculo,
              idTaller: mecanico.idTallerEfectivo,
              idReserva: reserva?.id,
            ),
            conversacionId: conversacionId,
            contenido: extra
                ? 'Te envié una cotización adicional para tu vehículo.'
                : 'He enviado una cotización para tu cita solicitada.',
            remitenteId: userId,
            receptorId: idPropietario,
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
          // Igual que "Cotizar y Aceptar" en el chat: una cita pendiente pasa
          // a cotizada. Una ya confirmada no se toca.
          if (reserva != null && reserva.estado == 'pendiente') {
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
      await _cargarCotizaciones();
    } finally {
      if (mounted) setState(() => _cotizando = false);
    }
  }

  /// La conversación con el propietario: la de la cita si la hay; si no, la
  /// que ya tengan (las cotizaciones aceptadas viajaron por una), y si no
  /// existe ninguna, una nueva.
  Future<String> _conversacionCon(
    ChatProvider chat, {
    required String idPropietario,
  }) async {
    final deLaCita = _reserva?.idConversacion ?? '';
    if (deLaCita.isNotEmpty) return deLaCita;
    final mecanico = context.read<UserProfileProvider>().userData!;
    return chat.iniciarOCrearConversacion(
      idPropietario: idPropietario,
      idMecanico: mecanico.idUsuario,
      // El taller no puede leer el perfil del cliente: el nombre real lo
      // pone la cabecera del chat, que sí lo resuelve.
      nombrePropietario: 'Propietario',
      nombreMecanico: mecanico.nombreCompleto,
      idTaller: mecanico.idTallerEfectivo,
      fotoMecanico: mecanico.fotoPerfilUrl,
    );
  }

  static DateTime _proximaHora() {
    final ahora = DateTime.now().add(const Duration(hours: 1));
    return DateTime(ahora.year, ahora.month, ahora.day, ahora.hour);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final vehiculo = _vehiculo;
    if (_errorCarga || vehiculo == null) {
      if (_cargandoRelacion && !_errorCarga) {
        // Primer frame, antes de que arranque la carga.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const MissingArgumentScreen(
        mensaje: 'No se pudo cargar el vehículo.',
        rutaVuelta: '/mechanic_search',
      );
    }

    final colors = context.appColors;
    final perfil = !_cargandoRelacion && _conRelacion;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          tooltip: 'Volver',
          onPressed: () => context.go('/mechanic_search'),
        ),
        title: Text(
          perfil ? 'Perfil del vehículo' : 'Vehículo',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
        actions: const [AccionesDeCabecera()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: _cargandoRelacion
            ? AppPageBody(
                maxWidth: AppBreakpoints.maxReadingWidth,
                child: Column(
                  children: [
                    _FichaVehiculo(vehiculo: vehiculo),
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ),
              )
            : perfil
            ? _perfil(vehiculo, colors)
            : _fichaPublica(vehiculo, colors),
      ),
    );
  }

  /// Sin relación con el taller: la ficha y lo único que se puede hacer.
  Widget _fichaPublica(VehicleModel vehiculo, AppColors colors) {
    final reserva = _reserva;
    return AppPageBody(
      maxWidth: AppBreakpoints.maxReadingWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FichaVehiculo(vehiculo: vehiculo),
          const SizedBox(height: AppSpacing.xl),
          if (reserva != null)
            _AvisoCita(
              reserva: reserva,
              cotizacionEnviada:
                  _cotizacionEnviada || reserva.estado == 'cotizada',
              enviando: _cotizando,
              onCotizar: () => _cotizar(extra: false),
            )
          else
            const _AvisoSinCita(),
        ],
      ),
    );
  }

  /// Con cotizaciones aceptadas o servicios: el perfil completo.
  Widget _perfil(VehicleModel vehiculo, AppColors colors) {
    final puedeCotizar = _idPropietario != null;

    final lateral = <Widget>[
      _FichaVehiculo(vehiculo: vehiculo),
      if (_reserva != null && _aceptadas.isEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        _AvisoCita(
          reserva: _reserva!,
          cotizacionEnviada:
              _cotizacionEnviada || _reserva!.estado == 'cotizada',
          enviando: _cotizando,
          onCotizar: () => _cotizar(extra: false),
        ),
      ],
    ];

    final principal = <Widget>[
      _ServicioEnCurso(
        ticket: _ticket,
        ticketEntregadoSinCobro: _ticketEntregadoSinCobro,
        vehiculo: vehiculo,
        hayAceptadas: _aceptadas.isNotEmpty,
      ),
      const SizedBox(height: AppSpacing.xl),
      AppSectionHeader(
        title: 'Cotizaciones',
        trailing: puedeCotizar
            ? AppButton(
                key: const Key('perfil_vehiculo_nueva_cotizacion'),
                text: 'Nueva cotización',
                size: AppButtonSize.small,
                icon: const Icon(Icons.add),
                isLoading: _cotizando,
                onPressed: _cotizando ? null : () => _cotizar(extra: true),
              )
            : null,
      ),
      const SizedBox(height: AppSpacing.md),
      ..._lista(
        datos: _cotizaciones,
        vacio: 'Todavía no le has enviado cotizaciones a este vehículo.',
        error: 'No se pudieron cargar las cotizaciones.',
        fila: (c) => CotizacionTallerTile(cotizacion: c),
      ),
      const SizedBox(height: AppSpacing.xl),
      const AppSectionHeader(title: 'Servicios realizados'),
      const SizedBox(height: AppSpacing.md),
      ..._lista(
        datos: _servicios,
        vacio: 'Tu taller todavía no le ha registrado ningún servicio.',
        error: 'No se pudieron cargar los servicios.',
        fila: (s) => ServicioRealizadoTile(servicio: s),
      ),
    ];

    return AppPageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dosColumnas = AppBreakpoints.fromWidth(
            constraints.maxWidth,
          ).isAtLeastExpanded;
          if (!dosColumnas) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...lateral,
                const SizedBox(height: AppSpacing.xl),
                ...principal,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: lateral,
                ),
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: principal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _lista<T>({
    required List<T>? datos,
    required String vacio,
    required String error,
    required Widget Function(T) fila,
  }) {
    final colors = context.appColors;
    if (datos == null) {
      return [
        Text(
          error,
          style: AppTextStyles.bodyMedium.copyWith(color: colors.error),
        ),
      ];
    }
    if (datos.isEmpty) {
      return [
        Text(
          vacio,
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
      ];
    }
    return [
      for (final d in datos) ...[
        fila(d),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }
}

/// Foto, nombre, placa y datos generales del coche.
class _FichaVehiculo extends StatelessWidget {
  final VehicleModel vehiculo;

  const _FichaVehiculo({required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final nombre = [
      vehiculo.marca,
      vehiculo.modelo,
    ].where((p) => p != null && p.isNotEmpty).join(' ');
    final km = NumberFormat.decimalPattern(
      'es',
    ).format(vehiculo.kilometrajeActual);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            // 16:9 hasta 240 px de alto: a lo ancho de una columna de
            // escritorio la foto se comía la pantalla entera.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VehicleImageWidget(
                  imageUrl: vehiculo.fotoUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        nombre.isEmpty ? 'Vehículo' : nombre,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElSalvadorLicensePlate(
                      placa: vehiculo.placa,
                      width: 112,
                      height: 60,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (vehiculo.anio != null)
                      _Dato(
                        icono: Icons.calendar_today_outlined,
                        texto: '${vehiculo.anio}',
                      ),
                    if (vehiculo.color != null && vehiculo.color!.isNotEmpty)
                      _Dato(
                        icono: Icons.palette_outlined,
                        texto: vehiculo.color!,
                      ),
                    _Dato(icono: Icons.speed, texto: '$km km'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Dato({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            texto,
            style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// El servicio de la visita actual: en qué punto está y el acceso a él.
class _ServicioEnCurso extends StatelessWidget {
  final ReparacionModel? ticket;

  /// Ver `_VehiclePublicViewScreenState._ticketEntregadoSinCobro`.
  final ReparacionModel? ticketEntregadoSinCobro;

  /// Se pasa como precarga a la pantalla del servicio, igual que hacía la
  /// búsqueda antes de llevar al perfil.
  final VehicleModel vehiculo;

  /// Hay cotizaciones aceptadas: sin ticket, eso es una anomalía que el
  /// taller tiene que poder diagnosticar (el ticket lo abre el servidor al
  /// aceptarse la cotización).
  final bool hayAceptadas;

  const _ServicioEnCurso({
    required this.ticket,
    required this.ticketEntregadoSinCobro,
    required this.vehiculo,
    required this.hayAceptadas,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = ticket;

    if (t == null) {
      // Ya se entregó y nadie registró el servicio: lo que falta no es el
      // ticket, es el cobro — y todavía se puede emitir, porque el taller
      // sigue en `talleres_conocidos` del vehículo.
      final sinCobro = ticketEntregadoSinCobro;
      if (sinCobro != null) {
        return _Aviso(
          icono: Icons.request_quote_outlined,
          texto:
              'Este vehículo se entregó sin registrar el servicio, así que no '
              'se generó el cobro. Puedes registrarlo ahora. La foto de la '
              'factura ya no se puede adjuntar: al entregar, tu taller dejó '
              'de tener acceso a la ficha del vehículo.',
          accion: TextButton.icon(
            key: const Key('perfil_vehiculo_registrar_cobro'),
            onPressed: () => context.go(
              '/initiate_service/${sinCobro.idReparacion}',
              extra: vehiculo,
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Registrar servicio y cobro'),
          ),
        );
      }
      return _Aviso(
        icono: hayAceptadas ? Icons.hourglass_empty : Icons.info_outline,
        texto: hayAceptadas
            ? 'Este vehículo tiene una cotización aceptada en tu taller, pero '
                  'el ticket todavía no se ha abierto. El ticket se abre solo '
                  'al aceptarse la cotización y aparece en Reparaciones, en '
                  '"Por recibir". Si no aparece ahí, no lo recibas desde aquí: '
                  'avisa al soporte con la placa.'
            : 'Este vehículo no tiene un servicio en curso en tu taller. Envía '
                  'una cotización nueva: cuando el propietario la acepte, '
                  'aparecerá en Reparaciones.',
        accion: hayAceptadas
            ? TextButton.icon(
                onPressed: () => context.go('/mechanic_reparaciones'),
                icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                label: const Text('Ir a Reparaciones'),
              )
            : null,
      );
    }

    final porRecibir = t.estado == 'pendiente_recepcion';
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  porRecibir ? Icons.garage_outlined : Icons.build,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Servicio en curso',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      etiquetasEstado[t.estado] ?? t.estado,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            key: const Key('perfil_vehiculo_ir_al_servicio'),
            text: porRecibir ? 'Recibir vehículo' : 'Continuar servicio',
            icon: Icon(porRecibir ? Icons.login : Icons.arrow_forward),
            onPressed: () => context.go(
              '/initiate_service/${t.idReparacion}',
              extra: vehiculo,
            ),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;

  const _Aviso({required this.icono, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
              Icon(icono, color: colors.primary),
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
          if (accion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: accion),
          ],
        ],
      ),
    );
  }
}

/// Sin relación con el taller ni cita: por qué no se ofrece nada (A3/B2).
class _AvisoSinCita extends StatelessWidget {
  const _AvisoSinCita();

  @override
  Widget build(BuildContext context) {
    return const _Aviso(
      icono: Icons.info_outline,
      texto:
          'Este vehículo todavía no tiene una cita contigo. Cuando el '
          'propietario agende una cita desde el chat y elija este vehículo, '
          'podrás enviarle tu cotización desde aquí; al aceptarla, el '
          'vehículo aparecerá en Reparaciones.',
    );
  }
}

/// Hay una cita vigente del propietario con este taller para este coche: ya
/// se puede cotizar. Recibir el coche sigue esperando a que el propietario
/// acepte la cotización.
class _AvisoCita extends StatelessWidget {
  final ReservaModel reserva;
  final bool cotizacionEnviada;
  final bool enviando;
  final VoidCallback onCotizar;

  const _AvisoCita({
    required this.reserva,
    required this.cotizacionEnviada,
    required this.enviando,
    required this.onCotizar,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
            isLoading: enviando,
            onPressed: enviando ? null : onCotizar,
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
