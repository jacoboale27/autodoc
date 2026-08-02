import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/reparacion_card.dart';

const Map<String, String> _etiquetasEstado = {
  'recibido': 'Recibido',
  'en_revision': 'En Revisión',
  'esperando_repuestos': 'Esperando Repuestos',
  'listo_para_entrega': 'Listo para Entregar',
};

class ReparacionesKanbanScreen extends StatefulWidget {
  final String idTaller;

  const ReparacionesKanbanScreen({super.key, required this.idTaller});

  @override
  State<ReparacionesKanbanScreen> createState() =>
      _ReparacionesKanbanScreenState();
}

class _ReparacionesKanbanScreenState extends State<ReparacionesKanbanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReparacionProvider>().watchTaller(widget.idTaller);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              title: Text(
                'Reparaciones',
                style: GoogleFonts.inter(
                  color: colors.primary,
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.primary),
            )
          : null,
      drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) const MechanicSidebar(),
          Expanded(
            child: Consumer<ReparacionProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.reparaciones.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.all(Responsive.padding(context, 16)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < estadosReparacion.length; i++)
                        _buildColumna(
                          context,
                          colors,
                          provider,
                          estadosReparacion[i],
                          i,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumna(
    BuildContext context,
    AppColors colors,
    ReparacionProvider provider,
    String estado,
    int index,
  ) {
    final items = provider.reparaciones
        .where((r) => r.estado == estado)
        .toList();
    final esUltimo = index == estadosReparacion.length - 1;
    final siguienteEstado = esUltimo ? null : estadosReparacion[index + 1];

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _etiquetasEstado[estado] ?? estado,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 14),
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'Sin vehículos',
              style: GoogleFonts.inter(
                color: colors.textSecondary,
                fontSize: Responsive.fontSize(context, 12),
              ),
            ),
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ReparacionCard(
                reparacion: r,
                esUltimoEstado: esUltimo,
                onAvanzar: siguienteEstado == null
                    ? null
                    : () => provider.cambiarEstado(
                        r.idReparacion,
                        siguienteEstado,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
