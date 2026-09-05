import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/config/secrets.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/galeria_taller.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_user_avatar.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import 'package:autodoc/features/profile/data/services/public_profile_service.dart';

/// Perfil público de "el otro" desde el chat (Tarea 10, C3).
///
/// El subconjunto de campos que se muestra depende de qué rol tiene el
/// usuario que ESTÁ MIRANDO (`context.watch<UserProfileProvider>`), no de
/// [userId] en sí — en un chat 1:1 de AutoDoc los roles son fijos: si quien
/// mira es un Propietario, [userId] SOLO puede ser el mecánico de esa
/// conversación (y viceversa). Eso evita una consulta extra para resolver
/// "¿de qué rol es este uid?" antes de decidir qué pedir.
///
/// Decisión de qué es "público" (fijada en el brief, no inventada aquí):
/// - Mecánico visto por un cliente: nombre, foto, taller, especialidad,
///   calificación, reseñas.
/// - Cliente visto por un mecánico: nombre, foto, municipio. Nunca
///   teléfono, DUI, correo ni la lista de vehículos — ver
///   `PublicProfileService` y `functions/src/obtenerPerfilPublico.js` para
///   dónde se aplica esa frontera realmente (del lado servidor, no aquí).
class PublicProfileScreen extends StatefulWidget {
  final String userId;

  /// Inyectables para pruebas de widget; por defecto usan las instancias
  /// reales (mismo patrón que `ChatScreen.firestore`).
  final FirebaseFirestore? firestore;
  final PublicProfileService? publicProfileService;

  /// Bucket de Storage para reconstruir las URLs de la galería
  /// (`GaleriaTaller.urlDe`). Por defecto `AppSecrets.firebaseStorageBucket`
  /// (un `String.fromEnvironment`, fijo en tiempo de compilación) — se
  /// inyecta aquí, no se lee la constante directamente en la sección de
  /// galería, porque un `flutter test` sin `--dart-define` no puede
  /// simular tenerlo poblado de ninguna otra forma.
  final String? storageBucket;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.firestore,
    this.publicProfileService,
    this.storageBucket,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final PublicProfileService _service;
  late final Future<_PerfilPublico> _future;

  @override
  void initState() {
    super.initState();
    _service =
        widget.publicProfileService ??
        PublicProfileService(firestore: widget.firestore);
    _future = _cargarPerfil();
  }

  Future<_PerfilPublico> _cargarPerfil() async {
    final soyMecanico = isMechanicRole(
      context.read<UserProfileProvider>().userData?.rol,
    );

    if (!soyMecanico) {
      final data = await _service.perfilMecanico(widget.userId);
      if (data == null) return const _PerfilPublico.noEncontrado();

      final firestore = widget.firestore ?? FirebaseFirestore.instance;
      List<Map<String, dynamic>> resenias = const [];
      try {
        final snap = await firestore
            .collection(FirestoreCollections.resenias)
            .where('id_taller', isEqualTo: widget.userId)
            .limit(20)
            .get();
        resenias = snap.docs.map((d) => d.data()).toList();
      } catch (_) {
        // Sin reseñas visibles no es un error de carga del perfil: el
        // nombre/foto/calificación ya se resolvieron arriba.
      }

      // Catálogo (Tarea 13, D1): subcolección PUBLICA de lectura anónima
      // (firestore.rules:340, `catalogo_servicios` -> `allow read: if
      // true`), igual que la que ya lee `catalogo_servicios_screen.dart`
      // del lado del taller. Sin cambio de reglas necesario.
      List<Map<String, dynamic>> catalogo = const [];
      try {
        final snap = await firestore
            .collection(FirestoreCollections.talleres)
            .doc(widget.userId)
            .collection('catalogo_servicios')
            .orderBy('nombre')
            .get();
        catalogo = snap.docs.map((d) => d.data()).toList();
      } catch (_) {
        // Un taller sin catálogo publicado no es un error de carga del
        // perfil.
      }

      // Empleados (Tarea 13, D1, RULING B): NUNCA una lectura directa de
      // `talleres/{uid}/empleados` (esa subcolección sigue cerrada a
      // dueño/admin en firestore.rules — trae correo/teléfono). El único
      // camino público es el callable `obtenerEmpleadosPublicos`, que
      // proyecta {nombre_completo, rol, activo} del lado servidor.
      final empleados = await _service.empleadosPublicos(widget.userId);

      return _PerfilPublico.mecanico(
        data: data,
        resenias: resenias,
        catalogo: catalogo,
        empleados: empleados,
      );
    }

    final data = await _service.perfilCliente(widget.userId);
    if (data == null) return const _PerfilPublico.noEncontrado();
    return _PerfilPublico.cliente(data);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          tooltip: 'Volver',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Perfil',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
      ),
      body: FutureBuilder<_PerfilPublico>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final perfil = snapshot.data;
          if (perfil == null || perfil.noEncontrado) {
            return const MissingArgumentScreen(
              mensaje: 'No se pudo cargar este perfil.',
              rutaVuelta: '/chat_list',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppPageBody(
              maxWidth: AppBreakpoints.maxReadingWidth,
              child: Column(
                children: [
                  AppUserAvatar(
                    urlFoto: perfil.fotoUrl,
                    nombre: perfil.nombre,
                    radius: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    perfil.nombre,
                    key: const Key('perfil_publico_nombre'),
                    style: AppTextStyles.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (perfil.esMecanico)
                    _MecanicoDetalle(
                      perfil: perfil,
                      colors: colors,
                      uid: widget.userId,
                      storageBucket:
                          widget.storageBucket ??
                          AppSecrets.firebaseStorageBucket,
                    )
                  else
                    _ClienteDetalle(perfil: perfil, colors: colors),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MecanicoDetalle extends StatelessWidget {
  final _PerfilPublico perfil;
  final AppColors colors;
  final String uid;
  final String storageBucket;

  const _MecanicoDetalle({
    required this.perfil,
    required this.colors,
    required this.uid,
    required this.storageBucket,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.build_outlined, color: colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      perfil.especialidad ?? 'General',
                      key: const Key('perfil_publico_especialidad'),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                key: const Key('perfil_publico_calificacion'),
                children: [
                  Icon(Icons.star, color: colors.warning, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    perfil.calificacionPromedio!.toStringAsFixed(1),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '(${perfil.totalResenias} reseña${perfil.totalResenias == 1 ? '' : 's'})',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (perfil.resenias!.isNotEmpty) ...[
          Text('Reseñas', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...perfil.resenias!.map(
            (r) => AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < ((r['estrellas'] as num?)?.round() ?? 0)
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: colors.warning,
                      ),
                    ),
                  ),
                  if ((r['comentario'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      r['comentario'] as String,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (perfil.direccion != null ||
            perfil.departamento != null ||
            perfil.ubicacion != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _UbicacionSection(perfil: perfil, colors: colors),
        ],
        if (perfil.galeria.archivoLogo != null ||
            perfil.galeria.archivosDelLocal.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _GaleriaSection(
            uid: uid,
            galeria: perfil.galeria,
            colors: colors,
            storageBucket: storageBucket,
          ),
        ],
        if (perfil.catalogo.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _CatalogoSection(items: perfil.catalogo, colors: colors),
        ],
        if (perfil.empleados.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _EmpleadosSection(empleados: perfil.empleados, colors: colors),
        ],
      ],
    );
  }
}

/// Ubicación del taller (Tarea 13, D1). Fuente: `direccion`, `departamento`
/// y `ubicacion` (GeoPoint) del documento `talleres/{uid}` — los tres SÍ
/// están en `CAMPOS_PUBLICOS` (`publishTallerProfile.js`). `ubicacion_municipio`
/// NO está en esa lista (verificado antes de implementar), así que
/// deliberadamente no se usa aquí: pintarlo habría sido una sección
/// permanentemente vacía en todo taller.
class _UbicacionSection extends StatelessWidget {
  final _PerfilPublico perfil;
  final AppColors colors;

  const _UbicacionSection({required this.perfil, required this.colors});

  @override
  Widget build(BuildContext context) {
    final partes = <String>[
      if ((perfil.direccion ?? '').isNotEmpty) perfil.direccion!,
      if ((perfil.departamento ?? '').isNotEmpty) perfil.departamento!,
    ];
    final texto = partes.isNotEmpty ? partes.join(', ') : null;
    final ubicacion = perfil.ubicacion;

    return AppCard(
      key: const Key('perfil_publico_ubicacion'),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  texto ?? 'Ubicación registrada',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
          if (ubicacion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: const Key('perfil_publico_abrir_mapa'),
              onPressed: () => UiUtils.openExternalUrl(
                'https://www.google.com/maps/search/?api=1&query=${ubicacion.latitude},${ubicacion.longitude}',
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Abrir en Maps'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Galería comercial (Tarea 13, D1). Fuente: `galeria` en
/// `talleres/{uid}` (nombres de archivo, nunca URLs — ver [GaleriaTaller]);
/// la ruta se reconstruye en el cliente igual que en
/// `workshop_directory_screen.dart:979`.
class _GaleriaSection extends StatelessWidget {
  final String uid;
  final GaleriaTaller galeria;
  final AppColors colors;
  final String storageBucket;

  const _GaleriaSection({
    required this.uid,
    required this.galeria,
    required this.colors,
    required this.storageBucket,
  });

  @override
  Widget build(BuildContext context) {
    final archivos = [
      if (galeria.archivoLogo != null) galeria.archivoLogo!,
      ...galeria.archivosDelLocal,
    ];
    final urls = archivos
        .map(
          (a) => GaleriaTaller.urlDe(
            bucket: storageBucket,
            idTaller: uid,
            nombreArchivo: a,
          ),
        )
        .whereType<String>()
        .toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('perfil_publico_galeria'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Galería', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (context, i) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: urls[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Catálogo de servicios/repuestos (Tarea 13, D1). Fuente:
/// `talleres/{uid}/catalogo_servicios`, subcolección ya de lectura pública
/// (`firestore.rules:340`, `allow read: if true`) — ningún cambio de reglas
/// necesario.
class _CatalogoSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final AppColors colors;

  const _CatalogoSection({required this.items, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('perfil_publico_catalogo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catálogo', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((item) {
          final nombre = (item['nombre'] as String?) ?? '';
          final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(child: Text(nombre, style: AppTextStyles.bodyMedium)),
                Text(
                  '\$${precio.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Empleados (Tarea 13, D1, RULING B). Fuente: el callable
/// `obtenerEmpleadosPublicos`, NUNCA una lectura directa de
/// `talleres/{uid}/empleados` (esa subcolección sigue cerrada a dueño/admin
/// — trae correo/teléfono del empleado). Ya llega acotado a
/// `{nombre_completo, rol, activo}` y solo activos — esta sección solo
/// pinta lo que el servidor decidió, igual que `_ClienteDetalle` con el
/// callable de Tarea 10.
class _EmpleadosSection extends StatelessWidget {
  final List<Map<String, dynamic>> empleados;
  final AppColors colors;

  const _EmpleadosSection({required this.empleados, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('perfil_publico_empleados'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equipo', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...empleados.map((e) {
          final nombre = (e['nombre_completo'] as String?) ?? 'Empleado';
          final rol = (e['rol'] as String?) ?? '';
          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: AppTextStyles.bodyMedium),
                      if (rol.isNotEmpty)
                        Text(
                          rol,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ClienteDetalle extends StatelessWidget {
  final _PerfilPublico perfil;
  final AppColors colors;

  const _ClienteDetalle({required this.perfil, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (perfil.municipio == null || perfil.municipio!.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            perfil.municipio!,
            key: const Key('perfil_publico_municipio'),
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Datos ya resueltos y listos para pintar. No es un modelo de dominio: vive
/// solo dentro de esta pantalla, con exactamente los campos que el brief
/// autorizó para cada rol (nunca más).
class _PerfilPublico {
  final bool noEncontrado;
  final bool esMecanico;
  final String nombre;
  final String? fotoUrl;

  // Solo mecánico:
  final String? especialidad;
  final double? calificacionPromedio;
  final int? totalResenias;
  final List<Map<String, dynamic>>? resenias;
  final GaleriaTaller galeria;
  final GeoPoint? ubicacion;
  final String? direccion;
  final String? departamento;
  final List<Map<String, dynamic>> catalogo;
  final List<Map<String, dynamic>> empleados;

  // Solo cliente:
  final String? municipio;

  const _PerfilPublico._({
    required this.noEncontrado,
    required this.esMecanico,
    required this.nombre,
    this.fotoUrl,
    this.especialidad,
    this.calificacionPromedio,
    this.totalResenias,
    this.resenias,
    this.galeria = const GaleriaTaller(),
    this.ubicacion,
    this.direccion,
    this.departamento,
    this.catalogo = const [],
    this.empleados = const [],
    this.municipio,
  });

  const _PerfilPublico.noEncontrado()
    : this._(noEncontrado: true, esMecanico: false, nombre: '');

  factory _PerfilPublico.mecanico({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> resenias,
    List<Map<String, dynamic>> catalogo = const [],
    List<Map<String, dynamic>> empleados = const [],
  }) {
    return _PerfilPublico._(
      noEncontrado: false,
      esMecanico: true,
      nombre: (data['nombre'] as String?) ?? 'Taller',
      fotoUrl: (data['foto_perfil_url'] ?? data['foto_url']) as String?,
      especialidad: (data['especialidad'] as String?) ?? 'General',
      calificacionPromedio:
          (data['calificacion_promedio'] as num?)?.toDouble() ?? 0,
      totalResenias: (data['total_resenias'] as num?)?.toInt() ?? 0,
      resenias: resenias,
      galeria: GaleriaTaller.fromLista(data['galeria']),
      ubicacion: data['ubicacion'] is GeoPoint
          ? data['ubicacion'] as GeoPoint
          : null,
      direccion: data['direccion'] as String?,
      departamento: data['departamento'] as String?,
      catalogo: catalogo,
      empleados: empleados,
    );
  }

  factory _PerfilPublico.cliente(Map<String, dynamic> data) {
    return _PerfilPublico._(
      noEncontrado: false,
      esMecanico: false,
      nombre: (data['nombre'] as String?) ?? 'Cliente',
      fotoUrl: data['foto_perfil_url'] as String?,
      municipio: data['municipio'] as String?,
    );
  }
}
