import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_image_viewer.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_verificacion_provider.dart';
import 'package:autodoc/features/admin/presentation/widgets/admin_sidebar.dart';

/// Bandeja de verificación de talleres.
///
/// Es la pieza que faltaba para que el flujo tuviera sentido: hasta ahora el
/// administrador aprobaba o rechazaba talleres desde una tarjeta que no
/// enseñaba ni una sola imagen, así que "verificar" no verificaba nada.
class AdminVerificacionesScreen extends StatefulWidget {
  const AdminVerificacionesScreen({super.key});

  @override
  State<AdminVerificacionesScreen> createState() =>
      _AdminVerificacionesScreenState();
}

class _AdminVerificacionesScreenState extends State<AdminVerificacionesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminVerificacionProvider>().escuchar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<AdminVerificacionProvider>();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Verificación de talleres'),
        backgroundColor: colors.surface,
      ),
      // Las otras cinco pantallas de administracion montan el drawer; esta se
      // quedo sin el, y al entrar desde el sidebar no habia forma de volver a
      // ninguna otra seccion.
      drawer: const AdminSidebar(),
      body: Builder(
        builder: (context) {
          if (provider.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.bandeja.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'No hay solicitudes pendientes de revisión.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: provider.bandeja.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) =>
                _ExpedienteCard(expediente: provider.bandeja[index]),
          );
        },
      ),
    );
  }
}

class _ExpedienteCard extends StatelessWidget {
  final VerificacionTallerModel expediente;

  const _ExpedienteCard({required this.expediente});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<AdminVerificacionProvider>();
    final adminUid = context.read<AuthSessionProvider>().currentUid;
    final ocupado = provider.resolviendo == expediente.idTaller;
    final abierto = expediente.estado == EstadoVerificacion.enRevision;
    final identidad = provider.identidadDe(expediente.idTaller);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mientras no llega el perfil de `usuarios/{uid}` se usa
                    // el uid como titulo transitorio: es peor que el nombre,
                    // pero solo dura hasta la primera hidratacion, y es mejor
                    // que un hueco en blanco.
                    Text(
                      identidad?.nombreCompleto ?? expediente.idTaller,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    // Seleccionable: el administrador lo copia para escribirle
                    // al taller cuyo expediente va a rechazar. Sale de
                    // `usuarios/{uid}`, nunca de `talleres/{uid}` (lectura
                    // publica y anonima): ver el doc de `_identidades` en
                    // AdminVerificacionProvider.
                    if (identidad?.correo.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.xs),
                      SelectableText(
                        identidad!.correo,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (identidad?.especialidad != null &&
                        identidad!.especialidad!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        identidad.especialidad!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.l10n.adminVerificacionTallerId(
                        expediente.idTaller,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              _chipEstado(context, expediente.estado),
            ],
          ),
          if (expediente.fechaEnvio != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              expediente.esReRevision
                  ? 'Reabierto el ${_fecha(expediente.fechaEnvio!)}'
                  : 'Enviado el ${_fecha(expediente.fechaEnvio!)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],

          // Un expediente reabierto es un taller que YA fue aprobado y que
          // sigue operando y publicado mientras se le vuelve a mirar. Sin
          // decir que cambio, el administrador no tiene nada que contrastar
          // contra la evidencia y lo aprobaria de nuevo a ciegas.
          if (expediente.esReRevision) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.published_with_changes_outlined,
                    size: 18,
                    color: colors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Taller ya aprobado que cambió datos verificados: '
                      '${expediente.reapertura!.campos.join(', ')}. Sigue '
                      'publicado en el directorio mientras se revisa.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Evidencia. Es lo unico que justifica que esta pantalla exista.
          SizedBox(
            height: 140,
            child: expediente.documentos.isEmpty
                ? Text(
                    'Sin evidencia adjunta.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final documento in expediente.documentos.values)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: _Evidencia(
                            tallerId: expediente.idTaller,
                            documento: documento,
                          ),
                        ),
                    ],
                  ),
          ),

          if (expediente.slotsFaltantes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No adjuntó: ${expediente.slotsFaltantes.join(', ')}',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),

          if (ocupado)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (!abierto)
            // Resolver sin tomar el caso primero es lo que permite que dos
            // administradores trabajen el mismo expediente a la vez.
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                text: 'Tomar el caso',
                size: AppButtonSize.small,
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () =>
                    provider.tomarCaso(expediente.idTaller, adminUid),
              ),
            )
          else
            // Aprobar primero y con el peso visual del botón primario;
            // rechazar debajo y como acción de texto. La destructiva no
            // puede ser la más prominente de las dos: eso era lo que hacía
            // que un click apurado cayera más fácil en "Rechazar" que en
            // "Aprobar".
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppButton(
                  text: 'Aprobar',
                  size: AppButtonSize.small,
                  onPressed: () async {
                    final ok = await provider.aprobar(
                      expediente.idTaller,
                      adminUid,
                    );
                    if (context.mounted && !ok) {
                      _avisar(context, provider.error!);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Theme(
                  data: Theme.of(context).copyWith(
                    extensions: [colors.copyWith(primary: colors.error)],
                  ),
                  child: AppButton(
                    text: 'Rechazar',
                    type: AppButtonType.text,
                    size: AppButtonSize.small,
                    onPressed: () => _pedirMotivo(context, provider, adminUid),
                  ),
                ),
              ],
            ),

          if (!abierto && !ocupado) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ábrelo para poder resolverlo. Así nadie más lo revisa a la vez.',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// El motivo es obligatorio: es lo único que el taller va a leer para saber
  /// qué corregir, y un rechazo mudo solo consigue que reenvíe lo mismo.
  void _pedirMotivo(
    BuildContext context,
    AdminVerificacionProvider provider,
    String adminUid,
  ) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: AppDialogContent(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => AppTextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              label: 'Motivo del rechazo',
              hintText: 'Ej.: la foto de la fachada no deja ver el rótulo.',
              errorText: value.text.trim().isEmpty
                  ? 'Explica qué debe corregir'
                  : null,
            ),
          ),
        ),
        actions: [
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => AppButton(
              text: 'Rechazar',
              type: AppButtonType.danger,
              size: AppButtonSize.small,
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      final ok = await provider.rechazar(
                        expediente.idTaller,
                        adminUid,
                        controller.text.trim(),
                      );
                      if (dialogContext.mounted && !ok) {
                        _avisar(dialogContext, provider.error!);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  static void _avisar(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _chipEstado(BuildContext context, EstadoVerificacion estado) {
    final abierto = estado == EstadoVerificacion.enRevision;
    final colors = context.appColors;
    final color = abierto ? colors.primary : colors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        abierto ? 'EN REVISIÓN' : 'PENDIENTE',
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _fecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

/// Una pieza de evidencia. El PDF no se previsualiza: se ofrece abrirlo.
///
/// `StatefulWidget` a propósito (Ruling 8): la URL se resuelve UNA vez en
/// `initState` y se guarda en `_url`, no se reconstruye dentro de `build()`.
/// El provider dispara `notifyListeners()` seis veces distintas —incluida la
/// hidratación de identidades, que siempre llega poco después del primer
/// pintado— y cada una de esas reconstrucciones descartaba el future ya
/// resuelto y pedía otra URL nueva a Storage: miniaturas parpadeando en
/// blanco y un token de descarga nuevo por cada acción del administrador. No
/// se memoiza en el provider (la alternativa "más consistente con
/// `_identidades`"): esa cache necesitaría política de invalidación, porque
/// sobrescribir un archivo en Storage cambia el token de descarga y la URL
/// vieja deja de servir. La cache de este widget se descarta exactamente
/// cuando la tarjeta sale del árbol, y `didUpdateWidget` cubre el cambio de
/// documento en sitio.
class _Evidencia extends StatefulWidget {
  final String tallerId;
  final DocumentoEvidencia documento;

  const _Evidencia({required this.tallerId, required this.documento});

  @override
  State<_Evidencia> createState() => _EvidenciaState();
}

class _EvidenciaState extends State<_Evidencia> {
  late Future<String?> _url;

  bool get _esPdf => widget.documento.nombreArchivo.endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _resolverUrl();
  }

  @override
  void didUpdateWidget(_Evidencia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tallerId != widget.tallerId ||
        oldWidget.documento != widget.documento) {
      _resolverUrl();
    }
  }

  void _resolverUrl() {
    _url = context.read<AdminVerificacionProvider>().urlDeEvidencia(
      widget.tallerId,
      widget.documento,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          height: 110,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            // `_esPdf` se decide por encima del `FutureBuilder`: es una
            // propiedad de `widget.documento.nombreArchivo`, no de la URL, así
            // que el icono de PDF no tiene por qué esperar una resolución que
            // no necesita para saber qué pintar.
            child: _esPdf ? _tarjetaPdf(colors) : _tarjetaImagen(colors),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.documento.slot,
          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  /// El NIT es el único slot que admite PDF (`storage.rules`); no hay visor
  /// embebido a propósito (dependencia grande para algo que el navegador ya
  /// resuelve, y fuera de alcance del plan).
  ///
  /// El icono se pinta de inmediato y nunca queda mudo al tocarlo: mientras
  /// la URL sigue resolviendo, el tap la espera (`await _url`) en vez de no
  /// tener `onTap`; y si resuelve a `null`, el icono cambia a la misma señal
  /// de fallo que usa la rama de imagen (`broken_image_outlined`).
  Widget _tarjetaPdf(AppColors colors) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final resuelta = snapshot.connectionState == ConnectionState.done;
        final fallo = resuelta && snapshot.data == null;
        return InkWell(
          onTap: () => unawaited(_tocarPdf(context)),
          child: Container(
            color: colors.surface,
            child: Center(
              child: Icon(
                fallo
                    ? Icons.broken_image_outlined
                    : Icons.picture_as_pdf_outlined,
                color: colors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tarjetaImagen(AppColors colors) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(color: colors.surface);
        }
        final url = snapshot.data;
        if (url == null) {
          return Container(
            color: colors.surface,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.textSecondary,
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => AppImageViewer.open(
            context,
            imageUrl: url,
            semanticLabel: widget.documento.slot,
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => Container(
              color: colors.surface,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Espera la URL (ya en vuelo o ya resuelta gracias a `_url`) y solo
  /// entonces decide: abrir el PDF, o avisar de que no se pudo cargar. Nunca
  /// deja el tap sin efecto.
  Future<void> _tocarPdf(BuildContext context) async {
    final url = await _url;
    if (!context.mounted) return;
    if (url == null) {
      AppSnackbar.show(
        context,
        context.l10n.adminVerificacionAbrirDocumentoError,
        type: SnackbarType.error,
      );
      return;
    }
    await _abrirPdf(context, url);
  }

  /// Abre el PDF en el navegador.
  Future<void> _abrirPdf(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final abierto =
        uri != null &&
        await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      AppSnackbar.show(
        context,
        context.l10n.adminVerificacionAbrirDocumentoError,
        type: SnackbarType.error,
      );
    }
  }
}
