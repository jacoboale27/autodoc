import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/vehicle_gallery_widget.dart';

import '../widgets/expense_summary_card.dart';
import '../../data/services/vehicle_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/license_plate_widget.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import '../widgets/share_vehicle_sheet.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/talleres_con_acceso_card.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';
import '../../data/services/vehicle_photo_service.dart';

class VehicleProfileScreen extends StatefulWidget {
  final String vehiculoId;
  final VehicleModel? vehiculoPrecargado;

  /// Inyectable para pruebas de widget. `VehicleService()` toca
  /// `FirebaseFirestore.instance` en su propio inicializador de campo, y esta
  /// pantalla lo instancia en tres sitios (el resumen de gastos lo hace en cada
  /// build), asi que sin esto no se puede montar sin `Firebase.initializeApp()`.
  /// Mismo precedente que el `firestore` de ReservaDetailScreen y el
  /// `selectorDeImagen` de ChatScreen.
  final VehicleService? vehicleService;

  /// Stream de fotos para la galeria; mismo motivo.
  final Stream<List<VehiclePhotoModel>>? galleryPhotos;

  /// Elige y sube la foto principal, y devuelve su URL (o `null` si la
  /// persona canceló). Inyectable por lo mismo que los dos de arriba:
  /// `VehiclePhotoService` toca `FirebaseStorage.instance` y el picker no
  /// tiene plataforma en un widget test.
  final Future<String?> Function(VehicleModel vehiculo)? elegirFotoPrincipal;

  /// Servicio de fotos y selector de imagen, inyectables por el mismo motivo:
  /// los dos tocan plataforma (Firebase y el picker nativo) y sin ellos no se
  /// puede probar el camino de "añadir la primera foto".
  final VehiclePhotoService? photoService;
  final Future<XFile?> Function()? seleccionarFoto;

  const VehicleProfileScreen({
    super.key,
    required this.vehiculoId,
    this.vehiculoPrecargado,
    this.vehicleService,
    this.galleryPhotos,
    this.elegirFotoPrincipal,
    this.photoService,
    this.seleccionarFoto,
  });

  @override
  State<VehicleProfileScreen> createState() => _VehicleProfileScreenState();
}

class _VehicleProfileScreenState extends State<VehicleProfileScreen> {
  VehicleService get _vehicleService =>
      widget.vehicleService ?? VehicleService();

  /// Bloquea el botón mientras la foto viaja: subir dos veces deja un objeto
  /// huérfano y dos escrituras del vehículo (patrón de GAPS-07).
  bool _cambiandoFoto = false;

  Future<String?> _elegirFoto(VehicleModel vehiculo) async {
    final elegir = widget.elegirFotoPrincipal;
    if (elegir != null) return elegir(vehiculo);
    final imagen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (imagen == null) return null;
    return VehiclePhotoService().setMainPhoto(
      vehiculo.idVehiculo,
      imagen,
      urlAnterior: vehiculo.fotoUrl,
    );
  }

  /// Observación del 2026-09-20: «el propietario debe poder poner la imagen
  /// que quiera como foto principal de su vehículo».
  Future<void> _cambiarFotoPrincipal(VehicleModel vehiculo) async {
    if (_cambiandoFoto) return;
    setState(() => _cambiandoFoto = true);
    final provider = context.read<VehicleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await _elegirFoto(vehiculo);
      if (url == null) return;
      final ok = await provider.updateVehicle(vehiculo.copyWith(fotoUrl: url));
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? 'No se pudo guardar la foto del vehículo.',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mensajeSeguroDeError(e, accion: 'No se pudo cambiar la foto'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _cambiandoFoto = false);
    }
  }

  /// Bandera de envio del kilometraje, de la nota nueva y de cada una de las
  /// dos fechas. Las fechas van por clave porque actualizar el SOAT no tiene
  /// por que bloquear la tarjeta de propiedad.
  final Set<String> _fechasEnCurso = <String>{};

  /// El FutureBuilder del resumen creaba un Future NUEVO en cada build, asi que
  /// cada setState relanzaba la consulta. Con banderas de envio hay mas builds.
  Future<Map<String, dynamic>>? _resumenDeGastos;

  VehicleModel? _currentVehicle;
  bool _cargando = false;
  String? _errorCarga;

  /// Notas que ya se descartaron con el gesto pero cuyo borrado en Firestore
  /// sigue en vuelo. Ver el comentario en [_buildNotaCard]: sin este filtro,
  /// el rebuild que dispara `fetchVehicles` al empezar remonta la nota
  /// descartada y `Dismissible` lanza.
  final Set<String> _notasEliminandose = <String>{};

  @override
  void initState() {
    super.initState();
    _currentVehicle = widget.vehiculoPrecargado;
    if (_currentVehicle == null) _cargarVehiculo();
  }

  Future<void> _cargarVehiculo() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
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
          _errorCarga = 'notFound';
        });
        return;
      }
      setState(() {
        _currentVehicle = VehicleModel.fromMap(doc.data()!, doc.id);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorCarga != null || _currentVehicle == null) {
      return const MissingArgumentScreen(
        mensaje: 'No se pudo cargar este vehículo.',
        rutaVuelta: '/garage',
      );
    }

    final colors = context.appColors;

    final vehicleProvider = context.watch<VehicleProvider>();
    final vehicle = vehicleProvider.vehicles.firstWhere(
      (v) => v.idVehiculo == _currentVehicle!.idVehiculo,
      orElse: () => _currentVehicle!,
    );

    return AppScaffold(
      useGradient: true,
      body: Column(
        children: [
          _buildHeader(context, colors, vehicle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
              child: AppPageBody(
                // Se decide por el ancho del contenido y no por `MediaQuery`,
                // igual que `AppGrid`: es lo que de verdad cabe.
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      AppBreakpoints.fromWidth(
                        constraints.maxWidth,
                      ).isAtLeastExpanded
                      ? _buildLayoutAncho(vehicle, colors)
                      : _buildLayoutCompacto(vehicle, colors),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Teléfono y tablet en vertical: una sola columna.
  Widget _buildLayoutCompacto(VehicleModel vehicle, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroImage(vehicle, colors),
        const SizedBox(height: AppSpacing.base),
        _buildVehicleIdentity(vehicle, colors),
        const SizedBox(height: AppSpacing.base),
        _buildExpenseSummary(vehicle, colors),
        const SizedBox(height: AppSpacing.base),
        _buildTechnicalDetails(vehicle, colors),
        const SizedBox(height: AppSpacing.xxl),
        _buildNotesSection(vehicle, colors),
        const SizedBox(height: AppSpacing.xxl),
        _buildGallery(vehicle, colors),
        const SizedBox(height: AppSpacing.xxl),
        _buildDocumentationStatus(vehicle, colors),
        const SizedBox(height: AppSpacing.xxl),
        // Quién puede ver esta ficha, y el botón para retirarlo. Va aquí,
        // junto a la documentación y antes de las acciones rápidas, porque es
        // información sobre el vehículo y no una acción sobre él.
        TalleresConAccesoCard(vehicle: vehicle),
        const SizedBox(height: AppSpacing.xxl),
        _buildQuickActions(vehicle, colors),
      ],
    );
  }

  /// Escritorio (observaciones del 2026-09-19: «en computadora las tarjetas
  /// del carro se ven deformes, todo grande»).
  ///
  /// Apilado a lo ancho, la foto en 16:9 ocupaba más de 600 px de alto y cada
  /// dato (año, color…) una tarjeta de 250 px casi vacía, así que el perfil
  /// eran tres pantallas de scroll. Aquí la foto y la ficha van lado a lado,
  /// y lo que es estado del vehículo (documentos y talleres con acceso) se
  /// reparte en dos columnas.
  Widget _buildLayoutAncho(VehicleModel vehicle, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const Key('perfil_vehiculo_cabecera_ancha'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _buildHeroImage(vehicle, colors, aspectRatio: 3 / 2),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVehicleIdentity(vehicle, colors),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTechnicalDetails(vehicle, colors),
                  const SizedBox(height: AppSpacing.xl),
                  _buildQuickActions(vehicle, colors),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildExpenseSummary(vehicle, colors),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDocumentationStatus(vehicle, colors)),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: TalleresConAccesoCard(vehicle: vehicle)),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        _buildNotesSection(vehicle, colors),
        const SizedBox(height: AppSpacing.xxl),
        _buildGallery(vehicle, colors),
      ],
    );
  }

  Widget _buildGallery(VehicleModel vehicle, AppColors colors) {
    return VehicleGalleryWidget(
      vehicleId: vehicle.idVehiculo,
      colors: colors,
      photos: widget.galleryPhotos,
      // Los dos de GAPS-08. Sin ellos la galeria compila igual y la portada
      // deja de poder cambiarse desde aqui: el layout responsive de las
      // observaciones se quedo con la version anterior de esta llamada.
      fotoPrincipal: vehicle.fotoUrl,
      onPortadaCambiada: _refrescarVehiculos,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppColors colors,
    VehicleModel vehicle,
  ) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainer.withValues(alpha: 0.8),
          border: Border(
            bottom: BorderSide(color: colors.primary.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: colors.primary,
                size: 20,
              ),
            ),
            // Con tema, idioma, campana y avatar a la derecha (observaciones
            // del 2026-09-19) el título no cabe en un teléfono: ahí se omite,
            // porque la ficha ya abre con la marca y el modelo del coche.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 160
                    ? const SizedBox.shrink()
                    : Text(
                        context.l10n.vpProfileTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
              ),
            ),
            const AccionesDeCabecera(),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: colors.primary, size: 24),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmationDialog(context, vehicle, colors);
                } else if (value == 'share') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ShareVehicleSheet(
                      vehicle: vehicle,
                      onUpdated: (updated) {
                        setState(() => _currentVehicle = updated);
                      },
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(context.l10n.vpShareVehicle),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: colors.error, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.vpDeleteVehicle,
                        style: TextStyle(color: colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Bloquea el segundo tap mientras el selector o la subida siguen en vuelo.
  /// Mismo guard que la galeria: `onTap: null` solo surte efecto en el frame
  /// siguiente, asi que dos taps en el MISMO frame pasan los dos.
  bool _subiendoPortada = false;

  VehiclePhotoService? _photoServiceCache;
  VehiclePhotoService get _photoService =>
      widget.photoService ?? (_photoServiceCache ??= VehiclePhotoService());

  /// Sube una foto desde el hueco de la ficha y la deja como portada.
  ///
  /// Es el mismo `addPhoto` de la galeria —la foto acaba tambien alli, que es
  /// lo correcto: son la misma coleccion—, y asciende sola porque el vehiculo
  /// no tenia ninguna. Este atajo existe solo cuando no hay foto.
  Future<void> _subirFotoDePortada(String vehiculoId) async {
    if (_subiendoPortada) return;
    setState(() => _subiendoPortada = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final elegida = widget.seleccionarFoto != null
          ? await widget.seleccionarFoto!()
          : await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
            );
      if (elegida == null) return;
      messenger.showSnackBar(const SnackBar(content: Text('Subiendo foto...')));
      await _photoService.addPhoto(vehiculoId, elegida);
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      _refrescarVehiculos();
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mensajeSeguroDeError(e, accion: 'No se pudo subir la foto'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _subiendoPortada = false);
    }
  }

  /// Relee el garaje tras cambiar la foto del vehiculo.
  ///
  /// Hace falta porque `foto_url` no llega por el stream de la galeria: vive
  /// en el documento del vehiculo, y quien lo tiene en memoria es
  /// `VehicleProvider`. Sin esto, la portada cambiaba en Firestore y la ficha
  /// seguia enseñando la anterior hasta el siguiente arranque.
  void _refrescarVehiculos() {
    final uid = context.read<AuthSessionProvider>().user?.uid;
    if (uid == null) return;
    context.read<VehicleProvider>().fetchVehicles(uid);
  }

  Widget _buildHeroImage(
    VehicleModel vehicle,
    AppColors colors, {
    double aspectRatio = 16 / 9,
  }) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'vehicle_image_${vehicle.idVehiculo}',
                child: VehicleImageWidget(
                  imageUrl: vehicle.fotoUrl,
                  tipoVehiculo: vehicle.tipoVehiculo,
                  fit: BoxFit.cover,
                ),
              ),
              // Sin foto, la silueta no dice que se pueda hacer algo al
              // respecto. La galeria esta mas abajo, fuera de pantalla en un
              // telefono, asi que el sitio donde se nota el hueco es tambien
              // donde tiene que estar la invitacion a llenarlo.
              if (!VehiclePhotoService.tieneFoto(vehicle.fotoUrl))
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _subiendoPortada
                          ? null
                          : () => _subirFotoDePortada(vehicle.idVehiculo),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: colors.primary,
                              size: 32,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Añade una foto de tu vehículo',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Material(
                  // `scrim`/`onScrim` y no negro y blanco a pelo: es el par
                  // de tokens que existe justo para dibujar encima de una
                  // foto, y el centinela de este fichero prohíbe literales.
                  color: colors.scrim,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const Key('perfil_vehiculo_cambiar_foto'),
                    tooltip: 'Cambiar foto',
                    icon: _cambiandoFoto
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onScrim,
                            ),
                          )
                        : Icon(
                            Icons.photo_camera_outlined,
                            color: colors.onScrim,
                            size: 20,
                          ),
                    onPressed: _cambiandoFoto
                        ? null
                        : () => _cambiarFotoPrincipal(vehicle),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        // Degradado de legibilidad sobre foto: no es un
                        // color de marca. textPrimary en light ya es casi
                        // negro; en dark, la superficie oscura de la propia
                        // app cumple el mismo papel.
                        colors.textPrimary.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondary,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          context.l10n.vpActiveStatus,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colors.onSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleIdentity(VehicleModel vehicle, AppColors colors) {
    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${vehicle.marca} ${vehicle.modelo}',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            Text(
              context.l10n.vpOwnerPersonal,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140, maxHeight: 80),
          child: AspectRatio(
            aspectRatio: 140 / 80,
            child: ElSalvadorLicensePlate(
              placa: vehicle.placa,
              width: 140,
              height: 80,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseSummary(VehicleModel vehicle, AppColors colors) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _resumenDeGastos ??= _vehicleService.getExpenseSummary(
        vehicle.idVehiculo,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return ExpenseSummaryCard(summary: snapshot.data!);
      },
    );
  }

  Widget _buildTechnicalDetails(VehicleModel vehicle, AppColors colors) {
    // Alto fijo y no proporción: el contenido de cada tarjeta (icono, rótulo
    // y valor) no crece con el ancho, y con `childAspectRatio` cada una
    // medía 250 px de alto en escritorio.
    return AppGrid(
      key: const Key('perfil_vehiculo_datos'),
      compactColumns: 2,
      mediumColumns: 4,
      expandedColumns: 4,
      largeColumns: 4,
      spacing: AppSpacing.md,
      mainAxisExtent: 72,
      children: [
        _buildDetailItem(
          Icons.calendar_today,
          context.l10n.vpYear,
          vehicle.anio?.toString() ?? 'N/A',
          colors,
        ),
        _buildDetailItem(
          Icons.palette,
          context.l10n.vpColor,
          vehicle.color ?? 'N/A',
          colors,
        ),
        _buildDetailItem(
          Icons.speed,
          context.l10n.vpMileage,
          '${vehicle.kilometrajeActual} ${context.l10n.vpKm}',
          colors,
          onTap: () => _showEditMileageDialog(context, vehicle, colors),
        ),
        _buildDetailItem(
          Icons.directions_car,
          context.l10n.vpBrand,
          vehicle.marca ?? 'N/A',
          colors,
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value,
    AppColors colors, {
    VoidCallback? onTap,
  }) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: onTap,
      semanticLabel: onTap == null ? null : '$label: $value',
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.edit,
              color: colors.primary.withValues(alpha: 0.5),
              size: 16,
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(VehicleModel vehicle, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.vpQuickNotes,
          trailing: IconButton(
            icon: Icon(Icons.add, color: colors.primary),
            onPressed: () {
              // El estado de envio vive en el StatefulBuilder porque el
              // dialogo no pertenece al arbol de esta pantalla.
              var guardandoNota = false;
              showDialog(
                context: context,
                builder: (ctx) {
                  final controller = TextEditingController();
                  return StatefulBuilder(
                    builder: (ctx, setDialogState) => AlertDialog(
                      title: const Text('Nueva Nota'),
                      content: AppTextField(
                        controller: controller,
                        label: 'Nota',
                        hintText: 'Escribe tu nota aquí...',
                        maxLines: 3,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: guardandoNota
                              ? null
                              : () async {
                                  if (guardandoNota) return;
                                  final text = controller.text.trim();
                                  if (text.isNotEmpty) {
                                    final uid = context
                                        .read<AuthSessionProvider>()
                                        .user
                                        ?.uid;
                                    final provider = context
                                        .read<VehicleProvider>();
                                    setDialogState(() => guardandoNota = true);
                                    await _vehicleService.addNote(
                                      vehicle.idVehiculo,
                                      text,
                                    );
                                    if (uid != null) {
                                      provider.fetchVehicles(uid);
                                    }
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                },
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (vehicle.notas.isEmpty)
          Text(
            'No hay notas registradas.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          )
        else
          // Rejilla en vez de una columna: una nota suele ser media linea de
          // texto, y apilarlas a ancho completo estiraba la seccion varias
          // pantallas hacia abajo en cuanto habia unas pocas.
          //
          // Wrap y no AppGrid a proposito: AppGrid es un GridView.count con
          // childAspectRatio fijo, asi que impone la MISMA altura a todas las
          // celdas —la nota de una palabra deja un hueco enorme y la larga
          // desborda—. Wrap deja que cada tarjeta se mida por su texto.
          LayoutBuilder(
            builder: (context, constraints) {
              final notas = _notasVisibles(vehicle);
              final columnas = _columnasDeNotas(constraints.maxWidth);
              final ancho =
                  (constraints.maxWidth - AppSpacing.sm * (columnas - 1)) /
                  columnas;
              return Wrap(
                key: const Key('vehicle-notes-grid'),
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final nota in notas)
                    SizedBox(
                      width: ancho,
                      child: _buildNotaCard(vehicle, nota, colors),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  /// Columnas de la rejilla de notas para el ancho **disponible**.
  ///
  /// Se decide por `constraints.maxWidth` y no por `MediaQuery`: esta seccion
  /// puede vivir dentro de un panel mas estrecho que la ventana.
  static int _columnasDeNotas(double ancho) =>
      switch (AppBreakpoints.fromWidth(ancho)) {
        WindowClass.compact => 1,
        WindowClass.medium => 2,
        WindowClass.expanded => 2,
        WindowClass.large => 3,
      };

  /// Notas del vehiculo menos las que estan en vuelo hacia el borrado.
  List<String> _notasVisibles(VehicleModel vehicle) => vehicle.notas
      .where((nota) => !_notasEliminandose.contains(nota))
      .toList();

  Widget _buildNotaCard(VehicleModel vehicle, String nota, AppColors colors) {
    return Dismissible(
      // `addNote` escribe con arrayUnion, que no admite duplicados, asi que el
      // propio texto es una clave unica.
      key: Key(nota),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        final uid = context.read<AuthSessionProvider>().user?.uid;
        final provider = context.read<VehicleProvider>();
        final messenger = ScaffoldMessenger.of(context);

        // Fuera de la lista ya mismo. `Dismissible` exige que su elemento
        // desaparezca del arbol en cuanto dispara onDismissed, y esperar al
        // round-trip de Firestore no vale: `fetchVehicles` empieza con
        // _setLoading(true) -> notifyListeners(), y ese rebuild intermedio
        // vuelve a montar la nota ya descartada. Al reconstruirse despues de
        // completar su animacion, Dismissible lanza "A dismissed Dismissible
        // widget is still part of the tree".
        setState(() => _notasEliminandose.add(nota));
        try {
          await _vehicleService.removeNote(vehicle.idVehiculo, nota);
          if (uid != null) await provider.fetchVehicles(uid);
          if (mounted) setState(() => _notasEliminandose.remove(nota));
        } catch (e) {
          if (!mounted) return;
          // Se queda sin borrar: devolverla a la lista es mas honesto que
          // dejarla oculta y que reaparezca al siguiente refresco.
          setState(() => _notasEliminandose.remove(nota));
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                mensajeSeguroDeError(e, accion: 'No se pudo eliminar la nota'),
              ),
              backgroundColor: colors.error,
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.base),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.delete, color: colors.onPrimary),
      ),
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sticky_note_2, color: colors.primary, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                nota,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentationStatus(VehicleModel vehicle, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.vpDocAndAlerts,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDocumentationStatusItem(
          context.l10n.vpCirculationCard,
          vehicle.vencimientoTarjeta,
          colors,
          _fechasEnCurso.contains('tarjeta')
              ? null
              : () => _showUpdateDateDialog(context, vehicle, true),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDocumentationStatusItem(
          context.l10n.vpSoatInsurance,
          vehicle.vencimientoSoat,
          colors,
          _fechasEnCurso.contains('soat')
              ? null
              : () => _showUpdateDateDialog(context, vehicle, false),
        ),
      ],
    );
  }

  Widget _buildDocumentationStatusItem(
    String title,
    DateTime? expiryDate,
    AppColors colors,
    // Nullable: con la actualizacion de esa fecha en vuelo el boton se
    // deshabilita, y `AppButton.onPressed` ya acepta null.
    VoidCallback? onUpdate,
  ) {
    if (expiryDate == null) {
      return _buildStatusAlert(
        icon: Icons.help_outline,
        title: title,
        subtitle: context.l10n.vpDateNotRegistered,
        color: colors.textSecondary,
        colors: colors,
        actionLabel: context.l10n.vpUpdate,
        onActionPressed: onUpdate,
      );
    }

    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    final formattedDate = DateFormat('dd MMM yyyy').format(expiryDate);

    final severity = AppSeverity.forExpiry(
      difference,
      colors,
      expiredLabel: context.l10n.vpExpiredOn(formattedDate),
      soonLabel: context.l10n.vpExpiresInDays(
        difference.toString(),
        formattedDate,
      ),
      okLabel: context.l10n.vpExpiresInDays(
        difference.toString(),
        formattedDate,
      ),
    );

    return _buildStatusAlert(
      icon: severity.icon,
      title: title,
      subtitle: severity.label,
      color: severity.color,
      colors: colors,
      isVerified: difference >= 30,
      actionLabel: difference < 30 ? context.l10n.vpRenew : null,
      onActionPressed: onUpdate,
    );
  }

  Widget _buildStatusAlert({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required AppColors colors,
    bool isVerified = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            Flexible(
              // Tope de ancho: AppButton ocupa todo el que le den, y en
              // escritorio el botón se estiraba a media tarjeta.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: AppButton(
                  text: actionLabel,
                  size: AppButtonSize.small,
                  onPressed: onActionPressed,
                  type: AppButtonType.primary,
                ),
              ),
            )
          else if (isVerified)
            Icon(Icons.check_circle, color: color, size: 20),
        ],
      ),
    );
  }

  Future<void> _showUpdateDateDialog(
    BuildContext context,
    VehicleModel vehicle,
    bool isTarjeta,
  ) async {
    // Guard de reentrada: entre el tap y la escritura media un date picker, asi
    // que deshabilitar el boton no llega a tiempo para dos taps seguidos.
    final clave = isTarjeta ? 'tarjeta' : 'soat';
    if (_fechasEnCurso.contains(clave)) return;
    final vehicleProvider = context.read<VehicleProvider>();
    final l10n = context.l10n;

    // Sin builder: el ThemeData de la app ya define el colorScheme correcto
    // para cada modo. El builder anterior lo pisaba con una versión clara
    // fija, así que el selector salía en claro incluso en dark mode.
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate != null && context.mounted) {
      final updatedVehicle = isTarjeta
          ? vehicle.copyWith(vencimientoTarjeta: pickedDate)
          : vehicle.copyWith(vencimientoSoat: pickedDate);

      setState(() => _fechasEnCurso.add(clave));
      final bool success;
      try {
        success = await vehicleProvider.updateVehicle(updatedVehicle);
      } finally {
        if (mounted) setState(() => _fechasEnCurso.remove(clave));
      }

      if (!context.mounted) return;
      if (success) {
        UiUtils.showSuccessSnackbar(context, l10n.vpDateUpdatedSuccess);
      } else {
        UiUtils.showErrorSnackbar(
          context,
          vehicleProvider.error ?? l10n.vpDateUpdateError,
        );
      }
    }
  }

  Widget _buildQuickActions(VehicleModel vehicle, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.vpQuickActions,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            _buildActionButton(
              Icons.history,
              context.l10n.vpHistory,
              colors.primary,
              colors,
              onTap: () {
                context.push('/service_history/${vehicle.idVehiculo}');
              },
            ),
            const SizedBox(width: AppSpacing.md),
            _buildActionButton(
              Icons.build,
              context.l10n.vpServices,
              colors.secondary,
              colors,
              onTap: () {
                // '/workshop_directory' vive dentro del ShellRoute
                // principal; empujarlo con push() desde una pantalla
                // fuera del shell (como esta) crea una segunda instancia
                // del shell con el mismo GlobalKey de Navigator interno,
                // lo que dispara el assert de key duplicada en
                // HeroControllerScope. go() reemplaza la ubicación en
                // vez de apilar una segunda instancia del shell.
                context.go('/workshop_directory');
              },
            ),
            const SizedBox(width: AppSpacing.md),
            _buildActionButton(
              Icons.description,
              context.l10n.vpPapers,
              colors.warning,
              colors,
              onTap: () {
                context.push('/alerts');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    AppColors colors, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: AppCard(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        onTap: onTap,
        semanticLabel: onTap == null ? null : label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMileageDialog(
    BuildContext context,
    VehicleModel vehicle,
    AppColors colors,
  ) {
    final controller = TextEditingController(
      text: vehicle.kilometrajeActual.toString(),
    );
    final formKey = GlobalKey<FormState>();

    // El estado de envio vive en el StatefulBuilder: el dialogo no pertenece al
    // arbol de esta pantalla.
    var guardandoKm = false;

    // El provider se resuelve AQUI y no dentro del builder: el contexto de un
    // dialogo cuelga del Navigator, que puede estar por encima del
    // MultiProvider, y entonces `read` dentro del dialogo no lo encuentra.
    final vehicleProvider = context.read<VehicleProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            context.l10n.vpUpdateMileage,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.vpEnterNewMileage(
                    vehicle.kilometrajeActual.toString(),
                  ),
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.vpNewMileageLabel,
                    labelStyle: TextStyle(color: colors.textSecondary),
                    suffixText: context.l10n.vpKm,
                    suffixStyle: TextStyle(color: colors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.speed, color: colors.primary),
                  ),
                  style: TextStyle(color: colors.textPrimary),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.vpEnterValue;
                    }
                    final newMileage = int.tryParse(value);
                    if (newMileage == null) {
                      return context.l10n.vpEnterValidNumber;
                    }
                    if (newMileage <= vehicle.kilometrajeActual) {
                      return context.l10n.vpMustBeGreaterThan(
                        vehicle.kilometrajeActual.toString(),
                      );
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(context.l10n.alertsCancel),
            ),
            AppButton(
              text: context.l10n.vpSave,
              isLoading: guardandoKm,
              onPressed: () async {
                if (guardandoKm) return;
                if (formKey.currentState!.validate()) {
                  final newMileage = int.parse(controller.text);
                  final updatedVehicle = vehicle.copyWith(
                    kilometrajeActual: newMileage,
                  );

                  setDialogState(() => guardandoKm = true);
                  final success = await vehicleProvider.updateVehicle(
                    updatedVehicle,
                  );
                  if (context.mounted) {
                    setDialogState(() => guardandoKm = false);
                  }

                  if (context.mounted) {
                    if (success) {
                      context.pop();
                      UiUtils.showSuccessSnackbar(
                        context,
                        context.l10n.vpMileageUpdatedSuccess,
                      );
                    } else {
                      UiUtils.showErrorSnackbar(
                        context,
                        vehicleProvider.error ?? context.l10n.vpUpdateError,
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    VehicleModel vehicle,
    AppColors colors,
  ) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;
    final isEmailUser = context.read<AuthProvider>().isEmailPasswordUser;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            context.l10n.vpDeleteVehicle,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.error,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.vpConfirmDelete(
                    vehicle.marca ?? '',
                    vehicle.modelo ?? '',
                  ),
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                ),
                if (isEmailUser) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.vpEnterPassword,
                      labelStyle: TextStyle(color: colors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.lock, color: colors.primary),
                    ),
                    style: TextStyle(color: colors.textPrimary),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.l10n.vpEnterPassword;
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => context.pop(),
              child: Text(context.l10n.alertsCancel),
            ),
            AppButton(
              text: context.l10n.vpDeleteVehicle,
              isLoading: isVerifying,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isVerifying = true);

                  final vehicleProvider = context.read<VehicleProvider>();

                  if (isEmailUser) {
                    final isValid = await context
                        .read<AuthProvider>()
                        .verifyPassword(passwordController.text);

                    if (context.mounted) {
                      if (!isValid) {
                        setState(() => isVerifying = false);
                        UiUtils.showErrorSnackbar(
                          context,
                          context.l10n.vpIncorrectPassword,
                        );
                        return;
                      }
                    }
                  }

                  final success = await vehicleProvider.deleteVehicle(
                    vehicle.idVehiculo,
                    vehicle.idPropietario,
                  );

                  if (context.mounted) {
                    setState(() => isVerifying = false);
                    if (success) {
                      context.pop(); // Close dialog
                      // El segundo pop asume que esta pantalla se llego con
                      // `push` (hay algo debajo que desapilar). No es asi si
                      // se entro con la pila de un solo elemento -recarga en
                      // web sobre /vehicle_profile/:id, o un deep link-, y
                      // ahi revienta con "GoError: There is nothing to pop".
                      if (context.mounted) {
                        if (context.canPop()) {
                          context.pop(); // Go back to previous screen
                        } else {
                          context.go('/garage');
                        }
                      }
                      UiUtils.showSuccessSnackbar(
                        context,
                        context.l10n.vpDeleteSuccess,
                      );
                    } else {
                      UiUtils.showErrorSnackbar(
                        context,
                        vehicleProvider.error ?? context.l10n.vpDeleteError,
                      );
                    }
                  }
                }
              },
              // type: AppButtonType.primary, // Default is primary
            ),
          ],
        ),
      ),
    );
  }
}
