import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_error_state.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';
import 'package:autodoc/features/asistente/data/services/asistente_service.dart';
import 'package:autodoc/features/asistente/presentation/utils/mensaje_de_asistente.dart';

/// IA-01 — el asistente de agenda. **Un turno, sin historial y sin memoria.**
///
/// Esa forma no es una simplificacion de la pantalla: es la del producto. Un
/// asistente multiturno multiplica el cupo por conversacion y convierte cada
/// respuesta anterior en entrada del siguiente prompt, que es justo la
/// superficie que `functions/src/asistente.js` cierra por construccion. Aqui
/// se pregunta, se lee y se vuelve a empezar.
///
/// **El servicio se inyecta** (patron de VER-01 y de `HistorialCompartidoScreen`):
/// es lo unico que permite afirmar sobre los siete estados —inicial, cargando,
/// respuesta, fuera de alcance, agenda vacia, error con boton y error sin el—
/// sin un Firebase de verdad.
///
/// **Nada de lo que se pinta lo decide esta pantalla.** El texto llega ya
/// redactado y ya localizado desde el servidor, el rechazo incluido, que es
/// fijo y ni siquiera pasa por el modelo. Lo unico que decide el cliente es en
/// que idioma pedirlo, y lo lee del `Localizations` activo — la cicatriz de
/// INNO-01: la app se renderiza en el idioma del navegador, asi que adivinarlo
/// en el servidor daria respuestas en ingles a quien ve la app en espanol.
class AsistenteScreen extends StatefulWidget {
  final AsistenteService? servicio;

  const AsistenteScreen({super.key, this.servicio});

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  /// Espejo de `LARGO_MAXIMO_PREGUNTA` en `functions/src/asistente.js`. El
  /// servidor sigue siendo quien decide: esto solo evita el viaje.
  static const int _largoMaximo = 500;

  late final AsistenteService _servicio = widget.servicio ?? AsistenteService();

  final TextEditingController _controlador = TextEditingController();
  final FocusNode _foco = FocusNode();

  /// Las dos capas contra el doble envio, y hacen falta las dos (GAPS-07):
  /// `onPressed: null` solo surte efecto **en el frame siguiente**, asi que
  /// dos toques en el MISMO frame pasan los dos. Esta bandera se levanta de
  /// forma sincrona, antes del primer `await`, y es la que atrapa el segundo.
  bool _enviando = false;

  RespuestaAsistente? _respuesta;
  Object? _error;

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  /// Idioma que se le pide al servidor. Solo `es` y `en`: el servidor cae a
  /// `es` ante cualquier otro, y mandar `pt` porque el navegador lo diga
  /// seria pedir una respuesta que nadie va a poder leer en esta app.
  String get _idioma {
    final codigo = Localizations.localeOf(context).languageCode;
    return codigo == 'en' ? 'en' : 'es';
  }

  Future<void> _enviar() async {
    // Capa 2: el guard de reentrada. Antes de cualquier `await`.
    if (_enviando) return;

    final pregunta = _controlador.text.trim();
    if (pregunta.isEmpty) return;

    setState(() {
      _enviando = true;
      _error = null;
      _respuesta = null;
    });

    try {
      final r = await _servicio.preguntar(pregunta, idioma: _idioma);
      if (!mounted) return;
      setState(() => _respuesta = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _otraPregunta() {
    setState(() {
      _respuesta = null;
      _error = null;
      _controlador.clear();
    });
    _foco.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppScaffold(
      useGradient: true,
      appBar: AppBar(
        title: Text(context.l10n.asistenteTitulo),
        // Las acciones comunes (tema, idioma y campana). Lo levanto el
        // centinela `acciones_de_cabecera_test.dart` al integrar: esta
        // pantalla nacio en la rama del asistente, antes de que las
        // observaciones del 2026-09-19 hicieran de esto una convencion, asi
        // que era la unica de la app sin ellas. Es justo para lo que existe
        // ese centinela: una pantalla nueva no puede quedarse fuera en
        // silencio.
        actions: const [AccionesDeCabecera()],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: AppPageBody(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _campo(),
                const SizedBox(height: AppSpacing.md),
                _alcance(colors),
                const SizedBox(height: AppSpacing.xl),
                _resultado(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const Key('asistente-pregunta'),
          controller: _controlador,
          focusNode: _foco,
          label: context.l10n.asistenteCampoEtiqueta,
          hintText: context.l10n.asistenteCampoPista,
          maxLines: 3,
          maxLength: _largoMaximo,
          textInputAction: TextInputAction.send,
          enabled: !_enviando,
          onSubmitted: (_) => _enviar(),
        ),
        const SizedBox(height: AppSpacing.md),
        // `ValueListenableBuilder` y no `setState` en `onChanged`: lo unico
        // que depende de cada pulsacion es si el boton esta vivo, y
        // reconstruir la pantalla entera por tecla tambien reconstruiria la
        // respuesta ya pintada.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controlador,
          builder: (context, valor, _) {
            final vacia = valor.text.trim().isEmpty;
            return AppButton(
              key: const Key('asistente-enviar'),
              text: context.l10n.asistenteEnviar,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              isLoading: _enviando,
              // Capa 1: deshabilitar. Sola no basta, pero sin ella el segundo
              // toque ni siquiera llega al guard en la mayoria de los casos.
              onPressed: (_enviando || vacia) ? null : _enviar,
            );
          },
        ),
      ],
    );
  }

  Widget _alcance(AppColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            context.l10n.asistenteAlcance,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultado(AppColors colors) {
    if (_enviando) {
      return Row(
        key: const Key('asistente-cargando'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            context.l10n.asistentePensando,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return AppErrorState(
        key: const Key('asistente-error'),
        mensaje: mensajeDeAsistente(context.l10n, _error),
        // El boton se RETIRA donde reintentar no puede funcionar nunca —
        // cupo agotado, taller sin aprobar, clave sin configurar. Es el
        // patron de `paseMereceReintento` (INNO-01): un boton que siempre
        // falla ensena que la app esta rota cuando lo que pasa es otra cosa.
        onReintentar: asistenteMereceReintento(_error) ? _enviar : null,
      );
    }

    final respuesta = _respuesta;
    if (respuesta == null) {
      return Text(
        context.l10n.asistenteVacio,
        key: const Key('asistente-vacio'),
        style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
      );
    }

    return Column(
      key: const Key('asistente-respuesta'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (respuesta.fueraDeAlcance) ...[
                _distintivoFueraDeAlcance(colors),
                const SizedBox(height: AppSpacing.md),
              ],
              // `SelectableText` no: Flutter web lo expone como
              // `textbox [disabled]`, o sea que un lector de pantalla lo
              // anuncia como campo de formulario deshabilitado en vez de como
              // texto. Lo midio la demo E2E de INNO-01.
              Text(
                respuesta.texto,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: const Key('asistente-otra'),
          text: context.l10n.asistenteOtraPregunta,
          type: AppButtonType.outlined,
          onPressed: _otraPregunta,
        ),
      ],
    );
  }

  Widget _distintivoFueraDeAlcance(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        context.l10n.asistenteEtiquetaFueraDeAlcance,
        style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
