import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/config/secrets.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/core/models/galeria_taller.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_user_avatar.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import 'package:autodoc/features/profile/data/services/public_profile_service.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';

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
        actions: const [AccionesDeCabecera()],
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
          final bucket =
              widget.storageBucket ?? AppSecrets.firebaseStorageBucket;
          // Observaciones del 2026-09-18 (captura 3): el taller se representa
          // con su LOGO, no con la inicial de su nombre. Antes el logo solo
          // salía abajo, en la galería, y el avatar decía "L".
          final logo = perfil.esMecanico ? perfil.galeria.archivoLogo : null;
          final urlAvatar =
              (logo == null
                  ? null
                  : GaleriaTaller.urlDe(
                      bucket: bucket,
                      idTaller: widget.userId,
                      nombreArchivo: logo,
                    )) ??
              perfil.fotoUrl;
          if (perfil.esMecanico) {
            final banner = perfil.galeria.archivoBanner;
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: AppPageBody(
                maxWidth: 1000,
                child: _PerfilEmpresa(
                  perfil: perfil,
                  colors: colors,
                  uid: widget.userId,
                  storageBucket: bucket,
                  urlLogo: urlAvatar,
                  urlBanner: banner == null
                      ? null
                      : GaleriaTaller.urlDe(
                          bucket: bucket,
                          idTaller: widget.userId,
                          nombreArchivo: banner,
                        ),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppPageBody(
              maxWidth: AppBreakpoints.maxReadingWidth,
              child: Column(
                children: [
                  AppUserAvatar(
                    key: const Key('perfil_publico_avatar'),
                    urlFoto: urlAvatar,
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

/// El perfil del taller como página de empresa (observaciones del
/// 2026-09-19): «quiero que en el perfil que el usuario puede ver del mecánico
/// aparezca siempre toda la información pública» y «que el mecánico pueda
/// poner un banner ... quiero que parezca que tiene un perfil empresarial».
///
/// Es la misma pantalla desde el directorio y desde el chat. Todas las
/// secciones se pintan SIEMPRE: una sección vacía dice que está vacía en vez
/// de desaparecer, que era por lo que el perfil parecía incompleto.
class _PerfilEmpresa extends StatelessWidget {
  final _PerfilPublico perfil;
  final AppColors colors;
  final String uid;
  final String storageBucket;
  final String? urlLogo;
  final String? urlBanner;

  const _PerfilEmpresa({
    required this.perfil,
    required this.colors,
    required this.uid,
    required this.storageBucket,
    required this.urlLogo,
    required this.urlBanner,
  });

  @override
  Widget build(BuildContext context) {
    final contacto = _Seccion(
      titulo: 'Contacto y ubicación',
      claveContenido: const Key('perfil_publico_contacto'),
      child: _ContactoSection(perfil: perfil, colors: colors),
    );
    final fotos = _Seccion(
      titulo: 'Fotos del local',
      child: _GaleriaSection(
        uid: uid,
        galeria: perfil.galeria,
        colors: colors,
        storageBucket: storageBucket,
      ),
    );
    final catalogo = _Seccion(
      titulo: 'Servicios y precios estimados',
      child: _CatalogoSection(items: perfil.catalogo, colors: colors),
    );
    final equipo = _Seccion(
      titulo: 'Equipo',
      child: _EmpleadosSection(empleados: perfil.empleados, colors: colors),
    );
    final resenias = _Seccion(
      titulo: 'Reseñas',
      child: _ReseniasSection(resenias: perfil.resenias ?? const []),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Portada(
          colors: colors,
          urlBanner: urlBanner,
          urlLogo: urlLogo,
          nombre: perfil.nombre,
        ),
        const SizedBox(height: AppSpacing.md),
        _Encabezado(perfil: perfil, colors: colors),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [contacto, fotos, catalogo, equipo, resenias],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [contacto, equipo],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [fotos, catalogo, resenias],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Banner de portada con el logo encima, como la cabecera de una página de
/// empresa. Sin banner, un degradado de la marca ocupa su sitio.
class _Portada extends StatelessWidget {
  final AppColors colors;
  final String? urlBanner;
  final String? urlLogo;
  final String nombre;

  const _Portada({
    required this.colors,
    required this.urlBanner,
    required this.urlLogo,
    required this.nombre,
  });

  static const double _radioLogo = 48;

  @override
  Widget build(BuildContext context) {
    final degradado = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
    final url = urlBanner;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _radioLogo),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.lg),
            ),
            child: AspectRatio(
              key: const Key('perfil_publico_banner'),
              aspectRatio: 3.2,
              child: url == null
                  ? degradado
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => degradado,
                      errorWidget: (_, _, _) => degradado,
                    ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: AppUserAvatar(
              key: const Key('perfil_publico_avatar'),
              urlFoto: urlLogo,
              nombre: nombre,
              radius: _radioLogo,
            ),
          ),
        ),
      ],
    );
  }
}

/// Nombre, especialidad, calificación, municipio y las dos acciones.
class _Encabezado extends StatelessWidget {
  final _PerfilPublico perfil;
  final AppColors colors;

  const _Encabezado({required this.perfil, required this.colors});

  @override
  Widget build(BuildContext context) {
    final lugar = [
      if ((perfil.municipioTaller ?? '').isNotEmpty) perfil.municipioTaller!,
      if ((perfil.departamento ?? '').isNotEmpty) perfil.departamento!,
    ].join(', ');
    final telefono = perfil.telefono;
    final ubicacion = perfil.ubicacion;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            perfil.nombre,
            key: const Key('perfil_publico_nombre'),
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_outlined, color: colors.primary, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      perfil.especialidad ?? 'General',
                      key: const Key('perfil_publico_especialidad'),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
              Row(
                key: const Key('perfil_publico_calificacion'),
                mainAxisSize: MainAxisSize.min,
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
              if (lugar.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        lugar,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (telefono != null || ubicacion != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (telefono != null)
                  FilledButton.icon(
                    key: const Key('perfil_publico_llamar'),
                    onPressed: () => UiUtils.openExternalUrl(
                      'tel:${telefono.replaceAll(RegExp(r'[^0-9+]'), '')}',
                    ),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Llamar'),
                  ),
                if (ubicacion != null)
                  OutlinedButton.icon(
                    key: const Key('perfil_publico_como_llegar'),
                    onPressed: () => UiUtils.openExternalUrl(
                      'https://www.google.com/maps/dir/?api=1&destination='
                      '${ubicacion.latitude},${ubicacion.longitude}',
                    ),
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: const Text('Cómo llegar'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Una sección con su título, siempre presente.
class _Seccion extends StatelessWidget {
  final String titulo;
  final Widget child;
  final Key? claveContenido;

  const _Seccion({
    required this.titulo,
    required this.child,
    this.claveContenido,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        key: claveContenido,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Lo que se dice cuando una sección no tiene nada.
class _Vacio extends StatelessWidget {
  final String texto;

  const _Vacio(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: AppTextStyles.bodyMedium.copyWith(
        color: context.appColors.textSecondary,
      ),
    );
  }
}

class _ContactoSection extends StatelessWidget {
  final _PerfilPublico perfil;
  final AppColors colors;

  const _ContactoSection({required this.perfil, required this.colors});

  @override
  Widget build(BuildContext context) {
    final telefono = perfil.telefono;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_outlined, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  telefono ?? 'Sin teléfono publicado',
                  key: const Key('perfil_publico_telefono'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: telefono == null
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _UbicacionSection(perfil: perfil, colors: colors),
        ],
      ),
    );
  }
}

class _ReseniasSection extends StatelessWidget {
  final List<Map<String, dynamic>> resenias;

  const _ReseniasSection({required this.resenias});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (resenias.isEmpty) {
      return const _Vacio('Este taller aún no tiene reseñas.');
    }
    return Column(
      key: const Key('perfil_publico_resenias'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in resenias)
          AppCard(
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

    if (texto == null && ubicacion == null) {
      return const _Vacio('Sin dirección registrada');
    }
    return Column(
      key: const Key('perfil_publico_ubicacion'),
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
    final archivos = galeria.archivosDelLocal;
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
    if (urls.isEmpty) {
      return const _Vacio('Este taller aún no ha subido fotos del local.');
    }

    return Column(
      key: const Key('perfil_publico_galeria'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (context, i) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // Mismo contrato que la tarjeta del directorio
              // (`workshop_directory_screen.dart`): esqueleto mientras carga
              // y un icono de reemplazo si falla. Un taller cuyo `galeria`
              // sigue listando un archivo que ya no esta en Storage pintaba
              // un hueco de 96x96 sin nada, ni durante la carga ni tras el
              // fallo.
              child: CachedNetworkImage(
                imageUrl: urls[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                // Placeholder estatico y no `AppSkeleton`: el esqueleto usa
                // `Shimmer`, que anima sin fin, y una animacion perpetua deja
                // el arbol sin asentar — cualquier test que llegue aqui con
                // `pumpAndSettle` se cuelga hasta el timeout. Para una
                // miniatura de 96 no aporta nada frente a un bloque de color.
                placeholder: (ctx, url) => Container(
                  width: 96,
                  height: 96,
                  color: colors.surfaceContainer,
                ),
                errorWidget: (ctx, url, err) => Container(
                  width: 96,
                  height: 96,
                  color: colors.surfaceContainer,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.textSecondary,
                  ),
                ),
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
    if (items.isEmpty) {
      return const _Vacio('Este taller aún no ha publicado sus servicios.');
    }
    return Column(
      key: const Key('perfil_publico_catalogo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mano de obra estimada, para cualquier vehículo. Los repuestos se '
          'cotizan aparte.',
          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((item) {
          // `.toString()` y no un cast duro: `CatalogoItemModel.fromMap`
          // ya tolera un `nombre` numerico (escrito por el Admin SDK o por
          // una importacion), y un cast aqui reventaria dentro de `build`,
          // tumbando la pantalla entera del perfil.
          final modelo = CatalogoItemModel.fromMap(item, '');
          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(modelo.nombre, style: AppTextStyles.bodyMedium),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  modelo.rangoTexto,
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
    if (empleados.isEmpty) {
      return const _Vacio('Sin personal publicado.');
    }
    return Column(
      key: const Key('perfil_publico_empleados'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
  final String? telefono;
  final String? municipioTaller;

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
    this.telefono,
    this.municipioTaller,
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
      telefono: _textoONulo(data['telefono']),
      municipioTaller: _textoONulo(data['municipio']),
    );
  }

  static String? _textoONulo(Object? valor) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
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
