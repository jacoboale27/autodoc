import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

/// Pantalla de gestión del catálogo rápido de servicios/repuestos de un
/// taller (`talleres/{idTaller}/catalogo_servicios`, Task 9). Permite
/// agregar y eliminar ítems reutilizables que luego se pueden añadir con un
/// clic a la lista de materiales de una factura desde
/// `InitiateServiceScreen` (Task 10).
class CatalogoServiciosScreen extends StatefulWidget {
  final String idTaller;

  const CatalogoServiciosScreen({super.key, required this.idTaller});

  @override
  State<CatalogoServiciosScreen> createState() =>
      _CatalogoServiciosScreenState();
}

class _CatalogoServiciosScreenState extends State<CatalogoServiciosScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es', symbol: '\$');

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
            title: const Text('Nuevo ítem del catálogo'),
            content: SizedBox(
              width: 380,
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
                      keyboardType: TextInputType.number,
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
                        await provider.agregar(nombre, precio);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
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
    final isMobile = MediaQuery.of(context).size.width < 700;
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              title: Text(
                'Catálogo',
                style: GoogleFonts.inter(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.primary),
            )
          : null,
      drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoAgregar(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Ítem'),
      ),
      body: Row(
        children: [
          if (!isMobile) const MechanicSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isMobile)
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 32),
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: colors.textSecondary.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Text(
                      'CATÁLOGO DE SERVICIOS',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: Responsive.fontSize(context, 20),
                        color: colors.primary,
                      ),
                    ),
                  ),
                Expanded(
                  child: Consumer<CatalogoProvider>(
                    builder: (context, provider, _) {
                      final items = provider.items;
                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              Responsive.padding(context, 32),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: Responsive.iconSize(context, 56),
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aún no tienes ítems en tu catálogo',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Agrega servicios y repuestos frecuentes '
                                  'para añadirlos con un clic al facturar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.all(
                          Responsive.padding(context, 24),
                        ),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return AppCard(
                            margin: EdgeInsets.zero,
                            padding: EdgeInsets.all(
                              Responsive.padding(context, 16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: colors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Icon(
                                    Icons.build_outlined,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    item.nombre,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(item.precio),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colors.error,
                                  ),
                                  onPressed: () => _eliminar(item),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
