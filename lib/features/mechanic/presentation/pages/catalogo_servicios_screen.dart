import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';

/// Pantalla de gestión del catálogo rápido de servicios/repuestos de un
/// taller (`talleres/{idTaller}/catalogo_servicios`, Task 9). Permite
/// agregar y eliminar ítems reutilizables que luego se pueden añadir con un
/// clic a la lista de materiales de una factura desde
/// `InitiateServiceScreen` (Task 10).
/// Formateador de precio que, a diferencia de
/// `FilteringTextInputFormatter.allow` con un patrón anclado, no borra todo
/// el campo cuando el candidato completo no matchea (p.ej. al escribir una
/// letra en medio de un número ya válido): simplemente rechaza el cambio y
/// conserva el valor anterior.
class _PrecioInputFormatter extends TextInputFormatter {
  static final RegExp _valido = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_valido.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
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
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _mostrarDialogoAgregar(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final precioController = TextEditingController();
    final provider = context.read<CatalogoProvider>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Nuevo ítem del catálogo'),
            content: AppDialogContent(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del servicio o repuesto',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: precioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_PrecioInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario',
                      ),
                      validator: (v) {
                        final precio = double.tryParse(v?.trim() ?? '');
                        if (precio == null || precio <= 0) {
                          return 'Precio inválido';
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
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() => isLoading = true);
                        final nombre = nombreController.text.trim();
                        final precio =
                            double.tryParse(precioController.text.trim()) ?? 0;
                        try {
                          await provider.agregar(nombre, precio);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setDialogState(() => isLoading = false);
                            // Cierra el teclado antes del SnackBar (flotante
                            // en todo el tema): con el teclado abierto el
                            // Scaffold detras del dialogo queda tan bajo que
                            // dispara "Floating SnackBar presented off screen".
                            FocusManager.instance.primaryFocus?.unfocus();
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );

    nombreController.dispose();
    precioController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MechanicScaffold(
      title: 'Catálogo de Servicios',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoAgregar(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Ítem'),
      ),
      body: Consumer<CatalogoProvider>(
        builder: (context, provider, _) {
          final items = provider.items;
          if (items.isEmpty) {
            return const AppEmptyState(
              title: 'Aún no tienes ítems en tu catálogo',
              description:
                  'Agrega servicios y repuestos frecuentes para añadirlos '
                  'con un clic al facturar.',
              icon: Icons.inventory_2_outlined,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppPageBody(
              child: AppGrid(
                compactColumns: 1,
                mediumColumns: 2,
                expandedColumns: 2,
                largeColumns: 3,
                spacing: AppSpacing.base,
                // Las columnas van de 288 px (compact a 320) a ~360 px
                // (large con maxContentWidth 1200 y 3 columnas). Con 2.6 la
                // altura mínima resultante (a 320 px) es de ~111 px, por
                // encima de los ~97 que necesitan dos líneas de nombre
                // (bodyLarge) más el precio (bodyMedium) y el padding del
                // AppCard.
                childAspectRatio: 2.6,
                children: [
                  for (final item in items)
                    _CatalogoItemCard(item: item, onEliminar: _eliminar),
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

  const _CatalogoItemCard({required this.item, required this.onEliminar});

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
                  _currencyFormat.format(item.precio),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error),
            tooltip: 'Eliminar ${item.nombre} del catálogo',
            onPressed: () => onEliminar(item),
          ),
        ],
      ),
    );
  }
}
