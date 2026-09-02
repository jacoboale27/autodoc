import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_image_viewer.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/features/mechanic/presentation/providers/verificacion_provider.dart';

/// Firma del selector de archivo, con origen y opciones ya fijadas.
///
/// Costura inyectable, mismo motivo que `SubidorDeEvidencia` en
/// `VerificacionService`: no hay forma barata de simular el canal de
/// plataforma de `image_picker` en un widget test, así que se saca la
/// llamada a un campo que un test puede sustituir por un valor fijo.
typedef SelectorDeArchivo = Future<XFile?> Function();

/// Un archivo recién elegido, todavía sin subir.
///
/// Guarda los bytes ya leídos (no el `XFile`) para poder previsualizarlo con
/// `Image.memory` sin volver a tocar disco/red en cada rebuild, y para poder
/// mandarlos tal cual a `VerificacionProvider.subirEvidencia` al confirmar.
class _ArchivoPendiente {
  const _ArchivoPendiente({required this.bytes, required this.nombre});

  final Uint8List bytes;
  final String nombre;

  bool get esPdf => nombre.toLowerCase().endsWith('.pdf');

  String get tamanoEnMB =>
      (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
}

/// Etiquetas de cada slot de evidencia, en el orden en que se piden.
const _etiquetas = <String, ({String titulo, String ayuda, bool obligatorio})>{
  'fachada': (
    titulo: 'Foto de la fachada',
    ayuda:
        'La entrada del local, de día y desde la calle. Es la única '
        'obligatoria: es lo que permite comprobar que el taller existe.',
    obligatorio: true,
  ),
  'rotulo': (
    titulo: 'Foto del rótulo',
    ayuda: 'El letrero con el nombre del taller, legible.',
    obligatorio: false,
  ),
  'nit': (
    titulo: 'NIT o registro fiscal',
    ayuda: 'Foto o PDF del documento. Acelera la revisión.',
    obligatorio: false,
  ),
};

/// Expediente de verificación del taller: qué falta y qué hay que subir.
///
/// Es la pantalla que convierte la espera en algo accionable. Antes un taller
/// recién registrado solo veía «espera 1-2 días hábiles» sin nada que hacer y
/// sin que el administrador tuviera con qué verificarlo.
class WorkshopVerificationScreen extends StatefulWidget {
  const WorkshopVerificationScreen({super.key, this.selectorDeArchivo});

  /// Sustituye al `ImagePicker()` real. Solo lo usan los tests: en
  /// producción siempre es `null` y se cae al selector de galería de abajo.
  final SelectorDeArchivo? selectorDeArchivo;

  @override
  State<WorkshopVerificationScreen> createState() =>
      _WorkshopVerificationScreenState();
}

class _WorkshopVerificationScreenState
    extends State<WorkshopVerificationScreen> {
  /// Archivo elegido pero todavía no confirmado, por slot.
  ///
  /// Vive aquí y no en `VerificacionProvider` porque es puramente
  /// transitorio a esta pantalla: nunca sale de aquí (ni se persiste, ni lo
  /// necesita nadie más), y desaparece en cuanto se confirma la subida o se
  /// navega fuera. Mismo criterio que `_imageFile` en
  /// `ProfileSetupScreen._pickPhoto`.
  final Map<String, _ArchivoPendiente> _pendientes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthSessionProvider>().currentUid;
      if (uid.isNotEmpty) context.read<VerificacionProvider>().cargar(uid);
    });
  }

  Future<XFile?> _seleccionarArchivo() {
    if (widget.selectorDeArchivo != null) return widget.selectorDeArchivo!();
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Un taller no aprobado puede subir 3 archivos de hasta 5 MB (el tope de
      // storage.rules). Reducir aqui evita rebotar contra ese limite con una
      // foto de camara moderna, y una fachada no necesita mas resolucion.
      maxWidth: 1600,
      imageQuality: 85,
    );
  }

  /// Abre el selector y deja el resultado en `_pendientes`, SIN subir nada
  /// todavía. Cancelar el selector no toca el estado previo del slot: si ya
  /// había una previsualización o un archivo subido, siguen ahí.
  Future<void> _elegirArchivo(String slot) async {
    final archivo = await _seleccionarArchivo();
    if (archivo == null || !mounted) return;

    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendientes[slot] = _ArchivoPendiente(bytes: bytes, nombre: archivo.name);
    });
  }

  /// Sube el archivo previsualizado. Es la única función de esta pantalla
  /// que escribe en Storage: seleccionar (`_elegirArchivo`) nunca lo hace.
  Future<void> _confirmarYSubir(String slot) async {
    final pendiente = _pendientes[slot];
    if (pendiente == null) return;

    final provider = context.read<VerificacionProvider>();
    final uid = context.read<AuthSessionProvider>().currentUid;
    if (uid.isEmpty) return;

    final ok = await provider.subirEvidencia(
      tallerId: uid,
      slot: slot,
      nombreOriginal: pendiente.nombre,
      bytes: pendiente.bytes,
    );

    if (!mounted) return;
    // Solo se limpia la previsualización si la subida salió bien: si falló,
    // el taller no debe tener que volver a elegir el archivo para
    // reintentar, solo volver a pulsar "Confirmar y subir".
    if (ok) setState(() => _pendientes.remove(slot));
    _avisar(
      ok ? '${_etiquetas[slot]!.titulo} subida.' : provider.error!,
      error: !ok,
    );
  }

  /// Abre en grande un documento ya subido: el visor de A1 para imágenes, el
  /// navegador (vía `url_launcher`) para PDF. La URL se resuelve en el
  /// momento del tap y no antes, por el mismo motivo que en la bandeja del
  /// administrador: lleva un token de Storage que no conviene pedir de más.
  Future<void> _verEvidencia(
    DocumentoEvidencia documento,
    String titulo,
  ) async {
    final provider = context.read<VerificacionProvider>();
    final uid = context.read<AuthSessionProvider>().currentUid;
    if (uid.isEmpty) return;

    final url = await provider.urlDeEvidencia(uid, documento);
    if (!mounted) return;
    if (url == null) {
      _avisar(context.l10n.adminVerificacionAbrirDocumentoError, error: true);
      return;
    }

    if (documento.nombreArchivo.endsWith('.pdf')) {
      final uri = Uri.parse(url);
      final abierto =
          await canLaunchUrl(uri) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abierto && mounted) {
        _avisar(context.l10n.adminVerificacionAbrirDocumentoError, error: true);
      }
      return;
    }

    if (!mounted) return;
    await AppImageViewer.open(context, imageUrl: url, semanticLabel: titulo);
  }

  Future<void> _enviar(UserModel perfil) async {
    final provider = context.read<VerificacionProvider>();
    final uid = context.read<AuthSessionProvider>().currentUid;
    if (uid.isEmpty) return;

    final ok = await provider.enviarARevision(tallerId: uid, perfil: perfil);
    if (!mounted) return;
    _avisar(
      ok ? 'Solicitud enviada. Un administrador la revisará.' : provider.error!,
      error: !ok,
    );
  }

  void _avisar(String mensaje, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<VerificacionProvider>();
    final perfil = context.watch<UserProfileProvider>().userData;
    final expediente = provider.expediente;
    final faltantes = provider.camposFaltantes(perfil);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        // `leading` explicito, no el boton automatico de Flutter: se llega
        // aqui con `go`, que reemplaza la pila en vez de apilar, asi que no
        // hay nada que desapilar y Flutter no pintaria ningun boton de
        // volver — el taller se quedaria atrapado en la pantalla. Navegar al
        // origen es ademas lo correcto: la verificacion se abre desde
        // /mechanic_pending y es a donde se vuelve.
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          tooltip: 'Volver',
          onPressed: () => context.go('/mechanic_pending'),
        ),
        title: const Text('Verificación del taller'),
        backgroundColor: colors.surface,
      ),
      body: provider.cargando && expediente == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppPageBody(
                maxWidth: AppBreakpoints.maxFormWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _banner(colors, provider.estado, expediente),
                    const SizedBox(height: AppSpacing.xxl),

                    _tituloSeccion(colors, '1. Completa tu perfil'),
                    const SizedBox(height: AppSpacing.md),
                    _checklistPerfil(colors, faltantes),
                    const SizedBox(height: AppSpacing.xxl),

                    _tituloSeccion(colors, '2. Sube la evidencia'),
                    const SizedBox(height: AppSpacing.md),
                    for (final slot in _etiquetas.keys) ...[
                      _tarjetaSlot(colors, provider, slot, expediente),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const SizedBox(height: AppSpacing.xl),

                    _botonEnviar(provider, perfil, faltantes, expediente),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }

  /// «a», «a y b», «a, b y c». Las etiquetas vienen de la Cloud Function ya
  /// en minuscula inicial salvo la primera palabra, asi que se enumeran tal
  /// cual.
  static String _enumerar(List<String> partes) {
    if (partes.length == 1) return partes.first.toLowerCase();
    final minusculas = partes.map((parte) => parte.toLowerCase()).toList();
    final ultima = minusculas.removeLast();
    return '${minusculas.join(', ')} y $ultima';
  }

  Widget _tituloSeccion(AppColors colors, String texto) => Text(
    texto,
    style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
  );

  /// Estado del expediente, en una frase y con el motivo del rechazo si lo hay.
  Widget _banner(
    AppColors colors,
    EstadoVerificacion estado,
    VerificacionTallerModel? expediente,
  ) {
    final (
      IconData icono,
      Color color,
      String titulo,
      String detalle,
    ) = switch (estado) {
      EstadoVerificacion.perfilIncompleto => (
        Icons.assignment_outlined,
        colors.primary,
        'Prepara tu solicitud',
        'Completa los datos de tu taller y sube al menos la foto de la '
            'fachada. Después podrás enviarla a revisión.',
      ),
      // Un expediente reabierto tambien esta en 'listo_para_revision', pero
      // decirle "solicitud enviada" a un taller que lleva meses verificado y
      // solo corrigio su telefono es incomprensible. La distincion la marca
      // `reapertura`, que escribe la Cloud Function.
      EstadoVerificacion.listoParaRevision
          when expediente?.esReRevision == true =>
        (
          Icons.published_with_changes_outlined,
          colors.warning,
          'Cambios en revisión',
          'Cambiaste ${_enumerar(expediente!.reapertura!.campos)}, así que un '
              'administrador volverá a revisar tu taller. Mientras tanto '
              'sigues operando con normalidad.',
        ),
      EstadoVerificacion.listoParaRevision => (
        Icons.schedule_rounded,
        colors.warning,
        'Solicitud enviada',
        'Un administrador la revisará. Te avisaremos en cuanto haya '
            'respuesta.',
      ),
      EstadoVerificacion.enRevision => (
        Icons.visibility_outlined,
        colors.warning,
        'En revisión',
        'Un administrador está revisando tu solicitud ahora mismo.',
      ),
      EstadoVerificacion.aprobada => (
        Icons.verified_outlined,
        colors.success,
        'Taller verificado',
        'Tu solicitud fue aprobada.',
      ),
      EstadoVerificacion.rechazada => (
        Icons.error_outline,
        Theme.of(context).colorScheme.error,
        'Solicitud rechazada',
        expediente?.motivoRechazo ?? 'Corrige lo indicado y vuelve a enviarla.',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTextStyles.titleSmall.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detalle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistPerfil(AppColors colors, List<String> faltantes) {
    if (faltantes.isEmpty) {
      return _fila(
        colors,
        Icons.check_circle,
        colors.success,
        'Tu perfil está completo.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final campo in faltantes) ...[
          _fila(
            colors,
            Icons.radio_button_unchecked,
            colors.textSecondary,
            campo,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          text: 'Editar perfil del taller',
          type: AppButtonType.secondary,
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: () => context.push('/workshop_settings'),
        ),
      ],
    );
  }

  Widget _fila(AppColors colors, IconData icono, Color color, String texto) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              texto,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      );

  Widget _tarjetaSlot(
    AppColors colors,
    VerificacionProvider provider,
    String slot,
    VerificacionTallerModel? expediente,
  ) {
    final etiqueta = _etiquetas[slot]!;
    final subido = expediente?.documentos[slot];
    final pendiente = _pendientes[slot];
    final enCurso = provider.slotEnCurso == slot;
    // Una vez enviado, el expediente esta en manos del administrador: dejar
    // cambiar la evidencia bajo sus pies significa que revisa una foto y
    // aprueba otra distinta.
    final bloqueado =
        provider.estado == EstadoVerificacion.listoParaRevision ||
        provider.estado == EstadoVerificacion.enRevision;
    // Ver ya subido no es "cambiar": no hay razón para bloquearlo aunque el
    // expediente esté en revisión.
    final puedeVer = subido != null && pendiente == null && !enCurso;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _miniaturaSlot(colors, etiqueta, subido, pendiente),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: InkWell(
                  onTap: puedeVer
                      ? () => _verEvidencia(subido, etiqueta.titulo)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              etiqueta.titulo,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (!etiqueta.obligatorio) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'opcional',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _descripcionSlot(context, etiqueta, subido, pendiente),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (enCurso)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (pendiente == null)
                TextButton(
                  onPressed: bloqueado ? null : () => _elegirArchivo(slot),
                  child: Text(
                    subido != null ? context.l10n.tallerVerifCambiar : 'Subir',
                  ),
                ),
            ],
          ),
          if (pendiente != null && !enCurso) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: bloqueado ? null : () => _elegirArchivo(slot),
                  child: Text(context.l10n.tallerVerifCambiar),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  text: context.l10n.tallerVerifConfirmarYSubir,
                  size: AppButtonSize.small,
                  onPressed: bloqueado ? null : () => _confirmarYSubir(slot),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Cuadro de la izquierda de la tarjeta: la previsualización local si hay
  /// un archivo pendiente, si no el icono de estado de siempre.
  Widget _miniaturaSlot(
    AppColors colors,
    ({String titulo, String ayuda, bool obligatorio}) etiqueta,
    DocumentoEvidencia? subido,
    _ArchivoPendiente? pendiente,
  ) {
    if (pendiente != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 48,
          height: 48,
          child: pendiente.esPdf
              ? Container(
                  color: colors.surface,
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: colors.textSecondary,
                  ),
                )
              : Image.memory(pendiente.bytes, fit: BoxFit.cover),
        ),
      );
    }

    return Icon(
      subido != null
          ? Icons.check_circle
          : etiqueta.obligatorio
          ? Icons.error_outline
          : Icons.add_photo_alternate_outlined,
      color: subido != null
          ? colors.success
          : etiqueta.obligatorio
          ? colors.warning
          : colors.textSecondary,
    );
  }

  /// Texto bajo el título: ayuda del slot vacío, aviso de pendiente de
  /// confirmar (con nombre y peso si es PDF), o confirmación de que ya se
  /// subió.
  String _descripcionSlot(
    BuildContext context,
    ({String titulo, String ayuda, bool obligatorio}) etiqueta,
    DocumentoEvidencia? subido,
    _ArchivoPendiente? pendiente,
  ) {
    if (pendiente != null) {
      return pendiente.esPdf
          ? context.l10n.tallerVerifArchivoPendientePdf(
              pendiente.nombre,
              pendiente.tamanoEnMB,
            )
          : context.l10n.tallerVerifArchivoPendiente;
    }
    if (subido != null) return context.l10n.tallerVerifArchivoSubido;
    return etiqueta.ayuda;
  }

  Widget _botonEnviar(
    VerificacionProvider provider,
    UserModel? perfil,
    List<String> faltantes,
    VerificacionTallerModel? expediente,
  ) {
    final puede = provider.puedeEnviar(perfil);

    // El boton deshabilitado dice POR QUE lo esta. Un boton gris y mudo obliga
    // a adivinar, que es la version mala de esta misma pantalla.
    String? impedimento;
    if (!puede) {
      if (expediente == null) {
        // Sin esta rama el boton salia deshabilitado y MUDO mientras el
        // expediente cargaba o si su lectura fallaba: no hay nada mas
        // parecido a "el boton no funciona" que un boton gris sin motivo.
        impedimento = provider.error ?? 'Cargando tu expediente…';
      } else if (faltantes.isNotEmpty) {
        impedimento = 'Faltan datos del perfil: ${faltantes.join(', ')}.';
      } else if (!expediente.tieneEvidenciaMinima) {
        impedimento = 'Falta la foto de la fachada.';
      } else {
        // Ya esta enviado o en revision: `puedeTransicionar` lo bloquea y
        // hasta ahora eso tampoco se explicaba.
        impedimento =
            'Tu solicitud ya está enviada. Un administrador la revisará.';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: provider.estado == EstadoVerificacion.rechazada
                ? 'Volver a enviar'
                : 'Enviar a revisión',
            isLoading: provider.enviando,
            onPressed: puede && perfil != null && !provider.enviando
                ? () => _enviar(perfil)
                : null,
          ),
        ),
        if (impedimento != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            impedimento,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
