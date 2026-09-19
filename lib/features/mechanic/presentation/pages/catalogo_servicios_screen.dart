import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/core/utils/input_formatters.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

/// Pantalla de gestión del catálogo rápido de servicios/repuestos de un
/// taller (`talleres/{idTaller}/catalogo_servicios`, Task 9). Permite
/// agregar y eliminar ítems reutilizables que luego se pueden añadir con un
/// clic a la lista de materiales de una factura desde
/// `InitiateServiceScreen` (Task 10).
/// Diálogo "Nuevo ítem del catálogo" como StatefulWidget propio (no un
/// StatefulBuilder inline): sus TextEditingController deben liberarse en
/// `State.dispose()`, que el framework llama recién cuando el Element del
/// diálogo se desmonta de verdad (tras terminar la animación de salida).
/// Antes se llamaba `.dispose()` justo después del `await showDialog(...)`,
/// pero ese Future se completa apenas se invoca `Navigator.pop()`, ANTES de
/// que termine esa animación — el diálogo seguía reconstruyéndose con un
/// controller ya liberado, causando "A TextEditingController was used after
/// being disposed" y una cascada de errores de framework (pantalla roja).
class _NuevoItemDialog extends StatefulWidget {
  final CatalogoProvider provider;

  const _NuevoItemDialog({required this.provider});

  @override
  State<_NuevoItemDialog> createState() => _NuevoItemDialogState();
}

class _NuevoItemDialogState extends State<_NuevoItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _precioMaxController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _precioMaxController.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isLoading = true);
    final nombre = _nombreController.text.trim();
    final precio = double.tryParse(_precioController.text.trim()) ?? 0;
    final precioMax = double.tryParse(_precioMaxController.text.trim());
    try {
      await widget.provider.agregar(nombre, precio, precioMax: precioMax);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Cierra el teclado antes del SnackBar (flotante en todo el tema):
        // con el teclado abierto el Scaffold detras del dialogo queda tan
        // bajo que dispara "Floating SnackBar presented off screen".
        FocusManager.instance.primaryFocus?.unfocus();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeSeguroDeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Nuevo servicio'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Servicio (mano de obra)',
                  hintText: 'Ej.: Cambio de pastillas de freno',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precioController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: montoInputFormatters,
                decoration: const InputDecoration(
                  labelText: 'Desde (USD)',
                  helperText:
                      'Lo que cuesta la mano de obra en lo más sencillo',
                ),
                validator: (v) {
                  final precio = double.tryParse(v?.trim() ?? '');
                  if (precio == null || precio <= 0) {
                    return 'Precio inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('catalogo_precio_max'),
                controller: _precioMaxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: montoInputFormatters,
                decoration: const InputDecoration(
                  labelText: 'Hasta (USD, opcional)',
                  helperText: 'Para un vehículo grande o un trabajo complicado',
                ),
                validator: (v) {
                  final texto = v?.trim() ?? '';
                  if (texto.isEmpty) return null;
                  final hasta = double.tryParse(texto);
                  final desde = double.tryParse(_precioController.text.trim());
                  if (hasta == null || (desde != null && hasta < desde)) {
                    return 'Debe ser mayor o igual que «Desde»';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _agregar,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Agregar'),
        ),
      ],
    );
  }
}

class CatalogoServiciosScreen extends StatefulWidget {
  final String idTaller;

  const CatalogoServiciosScreen({super.key, required this.idTaller});

  @override
  State<CatalogoServiciosScreen> createState() =>
      _CatalogoServiciosScreenState();
}

class _CatalogoServiciosScreenState extends State<CatalogoServiciosScreen> {
  /// idItem cuya eliminación está en vuelo. `CatalogoProvider.isLoading` no
  /// gobierna el botón de la tarjeta, que es justo el defecto: la protección
  /// tiene que vivir donde está el botón, y por ítem, no global.
  final Set<String> _eliminando = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogoProvider>().watchTaller(widget.idTaller);
    });
  }

  Future<void> _eliminar(CatalogoItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ítem'),
        content: Text('¿Eliminar "${item.nombre}" del catálogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // El diálogo se cierra al confirmar: sin esta guarda se podía reabrir y
    // confirmar otra vez mientras la primera eliminación seguía en vuelo.
    if (_eliminando.contains(item.idItem)) return;
    setState(() => _eliminando.add(item.idItem));

    try {
      await context.read<CatalogoProvider>().eliminar(item.idItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.nombre} eliminado del catálogo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeSeguroDeError(e))));
      }
    } finally {
      if (mounted) setState(() => _eliminando.remove(item.idItem));
    }
  }

  bool _cargandoComunes = false;

  Future<void> _cargarComunes() async {
    if (_cargandoComunes) return;
    setState(() => _cargandoComunes = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await context.read<CatalogoProvider>().cargarServiciosComunes();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'Ya tienes todos los servicios comunes.'
                : 'Se agregaron $n servicios con precios estimados. '
                      'Ajústalos a tu taller.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensajeSeguroDeError(e))));
    } finally {
      if (mounted) setState(() => _cargandoComunes = false);
    }
  }

  Future<void> _mostrarDialogoAgregar(BuildContext context) async {
    final provider = context.read<CatalogoProvider>();
    await showDialog(
      context: context,
      builder: (dialogContext) => _NuevoItemDialog(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MechanicScaffold(
      title: 'Catálogo de mano de obra',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoAgregar(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo servicio'),
      ),
      body: Consumer<CatalogoProvider>(
        builder: (context, provider, _) {
          final items = provider.items;
          final cargarComunes = OutlinedButton.icon(
            key: const Key('catalogo_cargar_comunes'),
            onPressed: _cargandoComunes ? null : _cargarComunes,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Agregar servicios comunes'),
          );
          if (items.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(
                  child: AppEmptyState(
                    title: 'Aún no tienes servicios en tu catálogo',
                    description:
                        'Pon el precio estimado de la mano de obra de lo que '
                        'haces más seguido. Los repuestos van aparte en cada '
                        'cotización.',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                cargarComunes,
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Precios estimados de mano de obra, para cualquier '
                    'vehículo. Al cotizar se agregan con un clic y los '
                    'repuestos van aparte. Los clientes los ven en tu perfil.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  cargarComunes,
                  const SizedBox(height: AppSpacing.lg),
                  AppGrid(
                    compactColumns: 1,
                    mediumColumns: 2,
                    expandedColumns: 2,
                    largeColumns: 3,
                    spacing: AppSpacing.base,
                    // Cada tarjeta a su alto (observaciones del 2026-09-19).
                    sizeToContent: true,
                    children: [
                      for (final item in items)
                        _CatalogoItemCard(
                          item: item,
                          onEliminar: _eliminar,
                          eliminando: _eliminando.contains(item.idItem),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CatalogoItemCard extends StatelessWidget {
  final CatalogoItemModel item;
  final Future<void> Function(CatalogoItemModel) onEliminar;

  /// Mientras la eliminación de este ítem sigue en vuelo el botón no acepta
  /// taps, para que no se pueda reabrir el diálogo de confirmación.
  final bool eliminando;

  const _CatalogoItemCard({
    required this.item,
    required this.onEliminar,
    this.eliminando = false,
  });

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es',
    symbol: '\$',
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Icon(Icons.build_outlined, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.nombre,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.precioMax != null && item.precioMax! > item.precio
                      ? '${_currencyFormat.format(item.precio)} – '
                            '${_currencyFormat.format(item.precioMax)}'
                      : _currencyFormat.format(item.precio),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                Text(
                  'Mano de obra estimada',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error),
            tooltip: 'Eliminar ${item.nombre} del catálogo',
            onPressed: eliminando ? null : () => onEliminar(item),
          ),
        ],
      ),
    );
  }
}
