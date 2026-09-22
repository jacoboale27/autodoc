import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_error_state.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/features/dashboard/data/services/pase_historial_service.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';

/// INNO-01 — lo que ve quien escanea el pase.
///
/// Esta pantalla es alcanzable por **cualquier cuenta autenticada**: ese es el
/// sentido de la funcionalidad, y por eso su ruta no esta en ninguno de los
/// conjuntos por rol del router. Lo que acota el riesgo no es quien llama, sino
/// que el token caduca, se puede revocar, es opaco de 256 bits y la proyeccion
/// del servidor deja fuera lo economico.
class HistorialCompartidoScreen extends StatefulWidget {
  final String token;

  /// Inyectable para los tests.
  final PaseHistorialService? servicio;

  const HistorialCompartidoScreen({
    super.key,
    required this.token,
    this.servicio,
  });

  @override
  State<HistorialCompartidoScreen> createState() =>
      _HistorialCompartidoScreenState();
}

class _HistorialCompartidoScreenState extends State<HistorialCompartidoScreen> {
  late final PaseHistorialService _servicio =
      widget.servicio ?? PaseHistorialService();

  HistorialCompartido? _historial;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _canjear();
  }

  Future<void> _canjear() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final historial = await _servicio.canjear(widget.token);
      if (!mounted) return;
      setState(() {
        _historial = historial;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          context.l10n.paseLectorTitulo,
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [AccionesDeCabecera()],
      ),
      applyGutter: true,
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return AppErrorState(
        mensaje: mensajeDePaseHistorial(context.l10n, _error),
        // Reintentar solo donde puede arreglar algo. Ante un pase caducado,
        // revocado, agotado, inexistente o mal formado, el boton no puede
        // cambiar el resultado nunca: ofrecerlo seria mentir sobre lo que hace.
        onReintentar: paseMereceReintento(_error) ? _canjear : null,
      );
    }

    final historial = _historial!;
    final servicios = historial.servicios;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _cabecera(context, historial),
        const SizedBox(height: AppSpacing.md),
        _aviso(context, context.l10n.paseLectorSinImportes, Icons.lock_outline),
        const SizedBox(height: AppSpacing.lg),
        if (servicios.isEmpty)
          AppEmptyState(
            title: context.l10n.paseLectorTitulo,
            description: context.l10n.paseLectorSinServicios,
            icon: Icons.build_outlined,
          )
        else ...[
          if (servicios.any((s) => s.autoDeclarado)) ...[
            _aviso(
              context,
              context.l10n.paseLectorAvisoAutoDeclarado,
              Icons.info_outline,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final servicio in servicios) _ficha(context, servicio),
        ],
      ],
    );
  }

  Widget _cabecera(BuildContext context, HistorialCompartido h) {
    final colors = context.appColors;
    final titulo = [
      h.marca,
      h.modelo,
      h.anio?.toString(),
    ].whereType<String>().join(' ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.isEmpty ? (h.placa ?? '') : titulo,
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (h.placa != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              h.placa!,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.primary),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.paseLectorKilometraje(h.kilometrajeActual),
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          // GAPS-05, gap 5 de INNO-01: el servidor devuelve `expira_en` en el
          // canje y la pantalla lo ignoraba, asi que quien escanea no sabia si
          // le daba tiempo a repasar el historial.
          //
          // Se pinta la HORA y no una cuenta atras: un `Timer.periodic` aqui
          // obligaria a todos los tests de esta pantalla a dejar de usar
          // `pumpAndSettle` —la trampa que ya documenta la pantalla de
          // emision— y el dato que de verdad hace falta, hasta cuando puedo
          // mirar, se da igual de bien.
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.paseLectorCaduca(DateFormat.Hm().format(h.expiraEn)),
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aviso(BuildContext context, String texto, IconData icono) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              texto,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Un servicio del historial compartido.
  ///
  /// **La etiqueta de origen no es decorativa.** Un servicio auto-declarado lo
  /// escribio el propio propietario (`firestore.rules` se lo permite sobre su
  /// vehiculo, y hace bien: nadie puede prohibir el mantenimiento propio).
  /// Pintarlo igual que el de un taller convertiria este pase en la palabra del
  /// vendedor con el sello de AutoDoc encima.
  Widget _ficha(BuildContext context, ServicioCompartido s) {
    final colors = context.appColors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.tipoServicio ?? '',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (s.fecha != null)
                  Text(
                    DateFormat('dd/MM/yyyy').format(s.fecha!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
            if (s.kilometraje != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${s.kilometraje} km',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if ((s.descripcion ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.descripcion!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _sello(
              context,
              texto: s.autoDeclarado
                  ? l10n.paseLectorAutoDeclarado
                  : l10n.paseLectorPorTaller,
              icono: s.autoDeclarado
                  ? Icons.person_outline
                  : Icons.verified_outlined,
              // Color distinto y ademas icono y texto distintos: quien no
              // distingue colores tiene que poder distinguir el origen igual.
              color: s.autoDeclarado ? colors.warning : colors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sello(
    BuildContext context, {
    required String texto,
    required IconData icono,
    required Color color,
  }) {
    // `Flexible` y no un `Text` a secas: con `mainAxisSize.min` la fila pide
    // el ancho natural del rotulo y no lo deja partirse, asi que a 320 px el
    // sello desbordaba 111 px por la derecha —lo destapo el test responsive—.
    // Y el rotulo crece al traducir: «Recorded by a workshop» es mas largo que
    // su original.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            texto,
            style: AppTextStyles.bodySmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Traduce el rechazo de `leerPaseHistorial` a algo accionable.
///
/// **El mapeo por defecto de UX-04 no vale aqui, y no por matices.**
/// `mensajeDeError` manda `deadline-exceeded` al mensaje de conexion
/// ("revisa tu conexion") y `permission-denied` a "vuelve a iniciar sesion".
/// Para un pase los dos son FALSOS: el primero significa que el pase vencio y
/// el segundo que el propietario lo revoco. Los dos dejarian a la persona
/// peleandose con su wifi o con su sesion por algo que solo puede arreglar el
/// propietario emitiendo otro pase.
///
/// Los codigos salen de `functions/src/historialCompartido.js`, que es donde
/// se eligen uno a uno; cualquier otro cae en el mensaje generico de UX-04,
/// que ya registra el detalle tecnico en el log sin ensenarlo.
String mensajeDePaseHistorial(AppLocalizations l10n, Object? error) {
  final codigo = error is FirebaseFunctionsException ? error.code : null;
  return switch (codigo) {
    'deadline-exceeded' => l10n.paseLectorCaducado,
    'permission-denied' => l10n.paseLectorRevocado,
    'resource-exhausted' => l10n.paseLectorAgotado,
    'not-found' => l10n.paseLectorNoExiste,
    'invalid-argument' => l10n.paseLectorInvalido,
    _ => mensajeDeError(l10n, error),
  };
}

/// `true` solo si volver a canjear puede dar un resultado distinto.
bool paseMereceReintento(Object? error) {
  final codigo = error is FirebaseFunctionsException ? error.code : null;
  return !const {
    'deadline-exceeded',
    'permission-denied',
    'resource-exhausted',
    'not-found',
    'invalid-argument',
    'unauthenticated',
  }.contains(codigo);
}
