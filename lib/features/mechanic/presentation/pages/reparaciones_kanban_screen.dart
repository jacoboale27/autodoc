import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/reparacion_card.dart';

/// Etiquetas visibles de los estados del tablero, en el mismo orden que
/// `estadosReparacion`. Pública porque los tests y `ReparacionCard`
/// necesitan el nombre del estado siguiente.
const Map<String, String> etiquetasEstado = {
  'pendiente_recepcion': 'Por recibir',
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
    return MechanicScaffold(
      title: 'Reparaciones',
      body: Consumer<ReparacionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.reparaciones.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: context.appColors.primary,
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final windowClass = AppBreakpoints.fromWidth(
                constraints.maxWidth,
              );
              return windowClass.isAtLeastExpanded
                  ? _ColumnsBoard(
                      provider: provider,
                      available: constraints.maxWidth,
                    )
                  : _TabsBoard(provider: provider);
            },
          );
        },
      ),
    );
  }
}

/// Ancho mínimo de una columna del tablero. Por debajo de esto una placa
/// más el botón "Avanzar a Esperando Repuestos" ya no caben en dos líneas.
const double _anchoColumna = 240;

class _ColumnsBoard extends StatelessWidget {
  final ReparacionProvider provider;
  final double available;

  const _ColumnsBoard({required this.provider, required this.available});

  @override
  Widget build(BuildContext context) {
    final gutter = AppBreakpoints.gutter(AppBreakpoints.fromWidth(available));
    final n = estadosReparacion.length;
    final cabenTodas =
        available >= n * _anchoColumna + (n - 1) * AppSpacing.md + gutter * 2;

    final columnas = [
      for (var i = 0; i < n; i++) _EstadoColumn(provider: provider, index: i),
    ];

    if (cabenTodas) {
      return Padding(
        padding: EdgeInsets.all(gutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: columnas[i]),
            ],
          ],
        ),
      );
    }

    // Physics por defecto: en iOS conserva el rebote y el momentum nativos.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.all(gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            SizedBox(width: _anchoColumna, child: columnas[i]),
          ],
        ],
      ),
    );
  }
}

class _TabsBoard extends StatelessWidget {
  final ReparacionProvider provider;

  const _TabsBoard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DefaultTabController(
      length: estadosReparacion.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.primary,
            tabs: [
              for (final estado in estadosReparacion)
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(etiquetasEstado[estado] ?? estado),
                      const SizedBox(width: AppSpacing.sm),
                      _ContadorBadge(
                        count: provider.reparaciones
                            .where((r) => r.estado == estado)
                            .length,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (var i = 0; i < estadosReparacion.length; i++)
                  _EstadoColumn(
                    provider: provider,
                    index: i,
                    mostrarEncabezado: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una columna del tablero: encabezado (solo en el layout de columnas) y la
/// lista de tarjetas con **su propio scroll vertical**. Ese scroll es la
/// corrección del desbordamiento: antes era un `Column` dentro de un scroll
/// horizontal, que recibe altura acotada y no puede crecer.
class _EstadoColumn extends StatelessWidget {
  final ReparacionProvider provider;
  final int index;
  final bool mostrarEncabezado;

  const _EstadoColumn({
    required this.provider,
    required this.index,
    this.mostrarEncabezado = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final estado = estadosReparacion[index];
    final esUltimo = index == estadosReparacion.length - 1;
    final siguienteEstado = esUltimo ? null : estadosReparacion[index + 1];
    final items = provider.reparaciones
        .where((r) => r.estado == estado)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarEncabezado) ...[
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    etiquetasEstado[estado] ?? estado,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _ContadorBadge(count: items.length),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Expanded(
          // Siempre un ListView, incluso vacío: la columna vecina puede
          // tener más tarjetas de las que caben en el viewport, y si esta
          // columna fuera un widget distinto (el AppEmptyState suelto de
          // antes) dejaría de ser una lista con scroll vertical propio —
          // justo el contrato que corrige el desbordamiento original.
          child: items.isEmpty
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    AppEmptyState(
                      title: 'Sin vehículos',
                      description: 'Ningún vehículo está en este estado.',
                      icon: Icons.directions_car_outlined,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => ReparacionCard(
                    reparacion: items[i],
                    esUltimoEstado: esUltimo,
                    siguienteEstadoLabel: siguienteEstado == null
                        ? null
                        : etiquetasEstado[siguienteEstado],
                    onAvanzar: siguienteEstado == null
                        ? null
                        : () => provider.cambiarEstado(
                            items[i].idReparacion,
                            siguienteEstado,
                          ),
                    onCancelar: () => provider.cancelar(items[i].idReparacion),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ContadorBadge extends StatelessWidget {
  final int count;

  const _ContadorBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: '$count ${count == 1 ? 'vehículo' : 'vehículos'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(color: colors.primary),
          ),
        ),
      ),
    );
  }
}
