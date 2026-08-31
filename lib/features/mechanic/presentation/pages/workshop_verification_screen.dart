import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/features/mechanic/presentation/providers/verificacion_provider.dart';

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
  const WorkshopVerificationScreen({super.key});

  @override
  State<WorkshopVerificationScreen> createState() =>
      _WorkshopVerificationScreenState();
}

class _WorkshopVerificationScreenState
    extends State<WorkshopVerificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthSessionProvider>().currentUid;
      if (uid.isNotEmpty) context.read<VerificacionProvider>().cargar(uid);
    });
  }

  Future<void> _elegirYSubir(String slot) async {
    final provider = context.read<VerificacionProvider>();
    final uid = context.read<AuthSessionProvider>().currentUid;
    if (uid.isEmpty) return;

    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Un taller no aprobado puede subir 3 archivos de hasta 5 MB (el tope de
      // storage.rules). Reducir aqui evita rebotar contra ese limite con una
      // foto de camara moderna, y una fachada no necesita mas resolucion.
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    final ok = await provider.subirEvidencia(
      tallerId: uid,
      slot: slot,
      nombreOriginal: archivo.name,
      bytes: bytes,
    );

    if (!mounted) return;
    _avisar(
      ok ? '${_etiquetas[slot]!.titulo} subida.' : provider.error!,
      error: !ok,
    );
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
    final enCurso = provider.slotEnCurso == slot;
    // Una vez enviado, el expediente esta en manos del administrador: dejar
    // cambiar la evidencia bajo sus pies significa que revisa una foto y
    // aprueba otra distinta.
    final bloqueado =
        provider.estado == EstadoVerificacion.listoParaRevision ||
        provider.estado == EstadoVerificacion.enRevision;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
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
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
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
                  subido != null ? 'Archivo subido.' : etiqueta.ayuda,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (enCurso)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: bloqueado ? null : () => _elegirYSubir(slot),
              child: Text(subido != null ? 'Cambiar' : 'Subir'),
            ),
        ],
      ),
    );
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
