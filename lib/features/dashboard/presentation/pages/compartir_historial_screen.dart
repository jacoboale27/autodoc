import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_error_state.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/features/dashboard/data/services/pase_historial_service.dart';

/// INNO-01 — el propietario emite el pase temporal de su historial.
///
/// **La pantalla no decide nada.** Quien puede emitir, cuanto vive el pase y
/// que se ve al canjearlo lo resuelve `functions/src/historialCompartido.js`
/// con el reloj y el Admin SDK del servidor. Aqui solo se pide, se pinta y se
/// revoca.
///
/// **La cuenta atras es informativa y tiene que seguir siendolo.** Corre contra
/// el reloj del dispositivo, que el usuario controla; el vencimiento de verdad
/// lo vuelve a comprobar el servidor en cada canje. Adelantar el reloj del
/// telefono hace que la cuenta atras mienta, no que el pase viva mas.
///
/// Lo que si es responsabilidad de esta pantalla: **retirar el QR en cuanto el
/// pase deja de servir** —vencido o revocado—. Seguir ensenandolo manda a la
/// otra persona a escanear algo que solo puede fallar, y el fallo se leeria
/// como que la app no funciona.
class CompartirHistorialScreen extends StatefulWidget {
  final String vehiculoId;

  /// Inyectable para los tests; en la app se construye con los callables
  /// reales.
  final PaseHistorialService? servicio;

  /// Reloj de la cuenta atras. Inyectable **porque si no ningun test puede
  /// ver el vencimiento**: `tester.pump(Duration)` avanza el reloj FALSO del
  /// binding, y `DateTime.now()` lee el de verdad, asi que una pantalla que
  /// siguiera ensenando un QR muerto pasaria cualquier suite. No es un gancho
  /// de conveniencia: es la unica forma de probar la mitad de esta pantalla.
  final DateTime Function() reloj;

  const CompartirHistorialScreen({
    super.key,
    required this.vehiculoId,
    this.servicio,
    this.reloj = DateTime.now,
  });

  @override
  State<CompartirHistorialScreen> createState() =>
      _CompartirHistorialScreenState();
}

class _CompartirHistorialScreenState extends State<CompartirHistorialScreen> {
  late final PaseHistorialService _servicio =
      widget.servicio ?? PaseHistorialService();

  PaseHistorial? _pase;
  Object? _error;
  bool _cargando = true;
  bool _revocado = false;
  bool _revocando = false;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _emitir();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _emitir() async {
    _reloj?.cancel();
    setState(() {
      _cargando = true;
      _error = null;
      _pase = null;
      _revocado = false;
    });
    try {
      final pase = await _servicio.emitir(widget.vehiculoId);
      if (!mounted) return;
      setState(() {
        _pase = pase;
        _cargando = false;
      });
      // Un tick por segundo solo mientras hay un pase vivo que mostrar. El
      // temporizador se cancela al revocar, al vencer y en `dispose`.
      _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_restante <= Duration.zero) _reloj?.cancel();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  Future<void> _revocar() async {
    final pase = _pase;
    if (pase == null || _revocando) return;
    setState(() => _revocando = true);
    try {
      await _servicio.revocar(pase.token);
      if (!mounted) return;
      _reloj?.cancel();
      setState(() {
        _revocado = true;
        _revocando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _revocando = false;
      });
    }
  }

  Duration get _restante {
    final pase = _pase;
    if (pase == null) return Duration.zero;
    final falta = pase.expiraEn.difference(widget.reloj());
    return falta.isNegative ? Duration.zero : falta;
  }

  static String formatearRestante(Duration d) {
    final minutos = d.inMinutes.toString().padLeft(2, '0');
    final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppScaffold(
      useGradient: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          // Se llega aqui con `go` (para que la URL siga a la pantalla), asi
          // que puede no haber nada que desapilar: sin el `canPop` el boton de
          // volver no haria nada en el caso normal.
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/service_history/${widget.vehiculoId}'),
        ),
        title: Text(
          context.l10n.paseTitulo,
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      applyGutter: true,
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorState(
        mensaje: mensajeDeError(context.l10n, _error),
        onReintentar: _emitir,
      );
    }
    if (_revocado) {
      return _estadoTerminal(context, context.l10n.paseRevocado);
    }
    if (_restante <= Duration.zero) {
      return _estadoTerminal(context, context.l10n.paseCaducado);
    }
    return _paseVivo(context, _pase!);
  }

  /// Pase agotado (revocado o vencido): sin QR y con la unica salida que
  /// funciona.
  Widget _estadoTerminal(BuildContext context, String mensaje) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Icon(Icons.qr_code_2_outlined, size: 64, color: colors.textSecondary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(text: context.l10n.paseGenerarOtro, onPressed: _emitir),
        ],
      ),
    );
  }

  Widget _paseVivo(BuildContext context, PaseHistorial pase) {
    final colors = context.appColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.paseIntro,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                QrDelPase(payload: pase.payloadQr),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.paseCaducaEn(formatearRestante(_restante)),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.paseTokenEtiqueta,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // El codigo tambien en texto. Un QR no se puede dictar por telefono
          // ni leer con un lector de pantalla, asi que sin esto la
          // funcionalidad depende de que las dos personas esten delante la una
          // de la otra con la camara funcionando.
          //
          // **`Text` y un boton de copiar, y NO un `SelectableText`.** El
          // primer intento uso `SelectableText`, que Flutter web expone como
          // `textbox [disabled]`: un lector de pantalla lo anuncia como un
          // campo de formulario deshabilitado en vez de como texto, y el
          // snapshot de accesibilidad de Playwright lo confirmo. Copiar
          // explicitamente es mejor en los tres ejes —se anuncia bien, se
          // puede probar y en un movil seleccionar 64 caracteres a dedo es
          // peor que pulsar un boton.
          Row(
            children: [
              Expanded(
                child: Text(
                  pase.token,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_outlined, color: colors.primary),
                tooltip: context.l10n.paseCopiarCodigo,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: pase.token));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.paseCodigoCopiado)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            text: context.l10n.paseRevocar,
            type: AppButtonType.secondary,
            isLoading: _revocando,
            onPressed: _revocar,
          ),
        ],
      ),
    );
  }
}

/// El QR del pase.
///
/// **Envuelve a `QrImageView` para que un test pueda afirmar el payload.**
/// `QrImageView` guarda su contenido en un campo privado (`_data`), asi que
/// desde fuera no hay forma de comprobar QUE se codifico — solo que hay un
/// QR pintado, que es exactamente el verde que no prueba nada: un QR con la
/// placa dentro y otro con el pase se ven igual desde un test.
class QrDelPase extends StatelessWidget {
  final String payload;

  const QrDelPase({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.qrFondo,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: QrImageView(
        data: payload,
        version: QrVersions.auto,
        size: 220,
        // Fondo blanco fijo y modulos oscuros: el contraste que un lector de
        // QR necesita no es el del tema de la app. En modo oscuro, pintar el
        // QR con los colores del tema lo vuelve ilegible para la camara.
        backgroundColor: AppPalette.qrFondo,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppPalette.qrModulo,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppPalette.qrModulo,
        ),
        semanticsLabel: context.l10n.paseTitulo,
      ),
    );
  }
}
