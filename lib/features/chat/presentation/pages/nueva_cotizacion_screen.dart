import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/input_formatters.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/features/chat/data/models/vehiculo_cotizado.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_form.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';

/// Lo que el taller rellenó en [NuevaCotizacionScreen]. Cada llamador le pone
/// encima las partes (propietario, taller, cita) con [toCotizacion].
class CotizacionBorrador {
  final List<CotizacionItem> items;
  final double manoDeObra;
  final DateTime fechaPropuesta;

  /// El coche que se cotiza, para dejar su resumen en la cotización.
  final VehiculoCotizado? vehiculo;

  const CotizacionBorrador({
    required this.items,
    required this.manoDeObra,
    required this.fechaPropuesta,
    this.vehiculo,
  });

  double get total =>
      items.fold(0.0, (acc, i) => acc + i.subtotal) + manoDeObra;

  CotizacionModel toCotizacion({
    required String idPropietario,
    required String idMecanico,
    required String idTaller,
    String? idVehiculo,
    String? idReserva,
  }) {
    return CotizacionModel(
      id: '',
      idPropietario: idPropietario,
      idMecanico: idMecanico,
      // Cadena vacía -> null: `toMap()` omite la clave cuando es null pero la
      // EMITE cuando es '', y entonces la regla de `create` evalúa
      // exists(/vehiculos/$('')), una ruta inválida (ver firestore.rules).
      idVehiculo: (idVehiculo == null || idVehiculo.isEmpty)
          ? null
          : idVehiculo,
      idTaller: idTaller,
      idReserva: (idReserva == null || idReserva.isEmpty) ? null : idReserva,
      items: items,
      fechaPropuesta: fechaPropuesta,
      fecha: DateTime.now(),
      manoDeObra: manoDeObra > 0 ? manoDeObra : null,
      materiales: CotizacionModel.materialesDesdeItems(items),
      vehiculoResumen: vehiculo?.toResumen(),
    );
  }
}

/// Abre la cotización a pantalla completa. Devuelve `true` si se envió.
///
/// Es una ruta imperativa (no de go_router) a propósito: es un formulario
/// modal que no tiene sentido abrir por URL ni recargar con F5 — igual que la
/// hoja inferior a la que sustituye.
Future<bool> abrirNuevaCotizacion(
  BuildContext context, {
  required VehiculoCotizado? vehiculo,
  required Future<bool> Function(CotizacionBorrador borrador) onEnviar,
  DateTime? initialFecha,
  String? subtitle,
}) async {
  final enviado = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NuevaCotizacionScreen(
        vehiculo: vehiculo,
        onEnviar: onEnviar,
        initialFecha: initialFecha,
        subtitle: subtitle,
      ),
    ),
  );
  return enviado ?? false;
}

/// Un renglón de la cotización.
///
/// Ya no lleva «Beneficio ($) — solo tú lo ves» (observaciones del
/// 2026-09-19): hacía lo mismo que la mano de obra, que es donde el taller
/// cobra su trabajo. El renglón viaja con beneficio 0, y el documento privado
/// `privado/margen` se sigue escribiendo igual (con ceros): las reglas de
/// `/cotizaciones` exigen ese contrato para publicar la cotización.
class _FilaCotizacion {
  final item = CotizacionItemRowControllers();

  void dispose() => item.dispose();

  bool get vacia =>
      item.nombreController.text.trim().isEmpty &&
      item.costoController.text.trim().isEmpty;

  CotizacionItem toItem() => CotizacionItem(
    material: item.nombreController.text.trim(),
    cantidad: item.cantidad,
    costo: item.costo,
  );
}

/// La cotización del taller, **una sola** para todas las entradas: el chat
/// (menú de adjuntos y "Cotizar y Aceptar" sobre una cita), el detalle de la
/// cita y Buscar Vehículo.
///
/// Observaciones del 2026-09-18: la del chat era una hoja inferior vertical
/// con solo materiales, y la de Buscar Vehículo una pantalla a dos columnas
/// con materiales, catálogo, mano de obra y total. Se pidió que la del chat
/// fuera igual a la de Buscar Vehículo, **con día y hora del servicio**. Esta
/// pantalla toma el esquema de `InitiateServiceScreen` —vehículo a la
/// izquierda, importes a la derecha, en una columna en móvil— y le añade la
/// fecha y el catálogo.
class NuevaCotizacionScreen extends StatefulWidget {
  final VehiculoCotizado? vehiculo;
  final Future<bool> Function(CotizacionBorrador borrador) onEnviar;
  final DateTime? initialFecha;
  final String? subtitle;

  const NuevaCotizacionScreen({
    super.key,
    required this.vehiculo,
    required this.onEnviar,
    this.initialFecha,
    this.subtitle,
  });

  @override
  State<NuevaCotizacionScreen> createState() => _NuevaCotizacionScreenState();
}

class _NuevaCotizacionScreenState extends State<NuevaCotizacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_FilaCotizacion> _filas = [_FilaCotizacion()];
  final _manoDeObraController = TextEditingController();
  DateTime? _fecha;
  bool _fechaError = false;
  String? _errorImporte;

  /// Guard de reentrada: `onPressed: null` solo surte efecto en el frame
  /// siguiente, así que dos taps en el mismo frame pasarían los dos y
  /// crearían dos cotizaciones (ver GAPS-07 en CLAUDE.md).
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _fecha = widget.initialFecha;
    _manoDeObraController.addListener(_refrescar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idTaller = context
          .read<UserProfileProvider>()
          .userData
          ?.idTallerEfectivo;
      if (idTaller != null && idTaller.isNotEmpty) {
        _catalogo()?.watchTaller(idTaller);
      }
    });
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    _manoDeObraController.dispose();
    super.dispose();
  }

  /// El catálogo es opcional: sin su provider (p. ej. en un test que no lo
  /// monta) la pantalla funciona igual, solo sin ese atajo.
  CatalogoProvider? _catalogo() {
    try {
      return Provider.of<CatalogoProvider>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _refrescar() {
    if (!mounted) return;
    setState(() => _errorImporte = null);
  }

  double get _manoDeObra =>
      double.tryParse(_manoDeObraController.text.trim()) ?? 0;

  double get _total =>
      _filas.fold(0.0, (acc, f) => acc + f.item.subtotal) + _manoDeObra;

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final inicial = _fecha != null && _fecha!.isAfter(ahora) ? _fecha! : ahora;
    final dia = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 180)),
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: _fecha != null
          ? TimeOfDay.fromDateTime(_fecha!)
          : TimeOfDay.fromDateTime(ahora),
    );
    if (hora == null || !mounted) return;
    setState(() {
      _fecha = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
      _fechaError = false;
    });
  }

  void _agregarFila() => setState(() => _filas.add(_FilaCotizacion()));

  void _quitarFila(int index) {
    setState(() {
      _filas[index].dispose();
      _filas.removeAt(index);
    });
  }

  Future<void> _abrirCatalogo() async {
    final colors = context.appColors;
    final items = _catalogo()?.items ?? const <CatalogoItemModel>[];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxFormWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Catálogo del taller',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: Text(
                    'El catálogo del taller está vacío. Agrega ítems '
                    'desde la sección "Catálogo" del panel.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Icon(
                          Icons.build_outlined,
                          color: colors.secondary,
                        ),
                        title: Text(item.nombre),
                        trailing: Text(
                          item.rangoTexto,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        onTap: () {
                          _agregarDesdeCatalogo(item);
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _agregarDesdeCatalogo(CatalogoItemModel item) {
    setState(() {
      // Si la única fila es la vacía con la que abre la pantalla, se rellena
      // esa en vez de dejar un renglón en blanco que luego no valida.
      final _FilaCotizacion fila;
      if (_filas.length == 1 && _filas.first.vacia) {
        fila = _filas.first;
      } else {
        fila = _FilaCotizacion();
        _filas.add(fila);
      }
      // Es mano de obra (observaciones del 2026-09-19): se dice en el
      // renglón para que el cliente no lo confunda con un repuesto. Se
      // cotiza el «desde»; el taller lo ajusta si el trabajo es mayor.
      fila.item.nombreController.text = '${item.nombre} (mano de obra)';
      fila.item.costoController.text = item.precio.toStringAsFixed(2);
      _errorImporte = null;
    });
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final formularioValido = _formKey.currentState?.validate() ?? false;
    final hayFecha = _fecha != null;
    final hayImporte = _filas.isNotEmpty || _manoDeObra > 0;
    if (!formularioValido || !hayFecha || !hayImporte) {
      setState(() {
        _fechaError = !hayFecha;
        _errorImporte = hayImporte
            ? null
            : 'Agrega al menos un material o la mano de obra.';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _enviando = true);
    final borrador = CotizacionBorrador(
      items: _filas.map((f) => f.toItem()).toList(),
      manoDeObra: _manoDeObra,
      fechaPropuesta: _fecha!,
      vehiculo: widget.vehiculo,
    );
    var enviado = false;
    try {
      enviado = await widget.onEnviar(borrador);
    } catch (_) {
      // Los llamadores ya informan de sus fallos esperados y devuelven
      // `false`; esto es la red para uno inesperado, que no puede dejar la
      // pantalla bloqueada con el botón en carga para siempre.
      enviado = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la cotización.')),
        );
      }
    } finally {
      if (mounted && !enviado) setState(() => _enviando = false);
    }
    if (enviado && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.primary),
          tooltip: 'Cerrar',
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Nueva Cotización',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
        actions: const [AccionesDeCabecera()],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: AppSpacing.xl,
            bottom: AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dosColumnas = AppBreakpoints.fromWidth(
                constraints.maxWidth,
              ).isAtLeastExpanded;

              final izquierda = <Widget>[
                _TarjetaVehiculoCotizado(vehiculo: widget.vehiculo),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    widget.subtitle!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                const AppSectionHeader(
                  title: 'Día y hora del servicio',
                  uppercase: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _BotonFecha(
                  fecha: _fecha,
                  error: _fechaError,
                  onPressed: _enviando ? null : _elegirFecha,
                ),
                if (_fechaError) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Debes proponer el día y hora del servicio.',
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
                ],
              ];

              final derecha = <Widget>[
                const AppSectionHeader(
                  title: 'Materiales / repuestos',
                  uppercase: true,
                ),
                const SizedBox(height: AppSpacing.md),
                CotizacionItemsForm(
                  rows: _filas.map((f) => f.item).toList(),
                  minRows: 0,
                  showTotal: false,
                  emptyPlaceholder: Text(
                    'No hay materiales agregados.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  onAddRow: _enviando ? null : _agregarFila,
                  onRemoveRow: _quitarFila,
                  onChanged: _refrescar,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  type: AppButtonType.secondary,
                  text: 'Desde catálogo',
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: _enviando ? null : _abrirCatalogo,
                ),
                const SizedBox(height: AppSpacing.xl),
                const AppSectionHeader(title: 'Mano de obra', uppercase: true),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  key: const Key('cotizacion_mano_de_obra'),
                  label: 'Mano de obra',
                  controller: _manoDeObraController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: montoInputFormatters,
                  prefixIcon: Icon(
                    Icons.build_circle_outlined,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const AppSectionHeader(
                  title: 'Costo del servicio (total)',
                  uppercase: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _TotalCotizacion(total: _total),
                if (_errorImporte != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorImporte!,
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  text: context.l10n.chatGenerateAndSend,
                  isLoading: _enviando,
                  onPressed: _enviando ? null : _enviar,
                ),
              ];

              return AppPageBody(
                maxWidth: dosColumnas
                    ? AppBreakpoints.maxContentWidth
                    : AppBreakpoints.maxFormWidth,
                child: dosColumnas
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: izquierda,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxl),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: derecha,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...izquierda,
                          const SizedBox(height: AppSpacing.xl),
                          ...derecha,
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BotonFecha extends StatelessWidget {
  final DateTime? fecha;
  final bool error;
  final VoidCallback? onPressed;

  const _BotonFecha({
    required this.fecha,
    required this.error,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = error ? colors.error : colors.primary;
    return OutlinedButton.icon(
      key: const Key('cotizacion_fecha_servicio'),
      onPressed: onPressed,
      icon: const Icon(Icons.event),
      label: Text(
        fecha != null
            ? DateFormat('dd/MM/yyyy hh:mm a').format(fecha!)
            : 'Día y hora del servicio *',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: error ? 1.5 : 1),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
    );
  }
}

class _TotalCotizacion extends StatelessWidget {
  final double total;

  const _TotalCotizacion({required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Se calcula sumando materiales y mano de obra',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '\$${total.toStringAsFixed(2)}',
            key: const Key('cotizacion_total'),
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera del vehículo cotizado. Mismo diseño que la de
/// `InitiateServiceScreen`, para que las dos pantallas se lean como la misma.
class _TarjetaVehiculoCotizado extends StatelessWidget {
  final VehiculoCotizado? vehiculo;

  const _TarjetaVehiculoCotizado({required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final v = vehiculo;
    final nombre = v?.nombre ?? 'Vehículo del cliente';
    final detalle = [
      if (v?.placa != null) 'Placa: ${v!.placa}',
      if (v?.anio != null) '${v!.anio}',
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: colors.onPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                    if (detalle.isNotEmpty)
                      Text(
                        detalle,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.onPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (v?.kilometraje != null) ...[
            const SizedBox(height: AppSpacing.base),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.secondary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Kilometraje Actual:',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${v!.kilometraje} KM',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
