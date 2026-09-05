import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/role_utils.dart';
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

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.firestore,
    this.publicProfileService,
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

      return _PerfilPublico.mecanico(data: data, resenias: resenias);
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
                    _MecanicoDetalle(perfil: perfil, colors: colors)
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

  const _MecanicoDetalle({required this.perfil, required this.colors});

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
    this.municipio,
  });

  const _PerfilPublico.noEncontrado()
    : this._(noEncontrado: true, esMecanico: false, nombre: '');

  factory _PerfilPublico.mecanico({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> resenias,
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
