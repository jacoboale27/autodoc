import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/widgets/aviso_lista_truncada.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/trabajos_taller_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/trabajos_taller_widgets.dart';

/// Pestañas de "Mis Servicios". [todos] junta las demás.
enum _Pestana { todos, enProceso, pendientes, finalizados, rechazados }

extension on _Pestana {
  String get etiqueta => switch (this) {
    _Pestana.todos => 'Todos',
    _Pestana.enProceso => 'En proceso',
    _Pestana.pendientes => 'Pendientes',
    _Pestana.finalizados => 'Finalizados',
    _Pestana.rechazados => 'Rechazados',
  };
}

/// "Mis Servicios": todo el trabajo del taller, por estado.
///
/// Observaciones del 2026-09-19, punto 3: la pantalla solo listaba los
/// servicios ya REGISTRADOS (`servicios`), así que las cotizaciones
/// rechazadas, las aceptadas que están en proceso y las que esperan respuesta
/// no aparecían en ninguna parte — y como cerrar un servicio fallaba por la
/// captura 7, tampoco había finalizados: la pantalla estaba siempre vacía.
///
/// Ahora junta las dos fuentes:
///
/// - **Cotizaciones del taller** (`cotizaciones`): "Pendientes" (esperando
///   respuesta del dueño), "En proceso" (aceptadas, todavía sin cobrar) y
///   "Rechazados".
/// - **Servicios registrados** (`servicios`): "Finalizados". Una cotización
///   `finalizada` no se lista aparte: su servicio registrado ES ese trabajo,
///   con el kilometraje, los materiales y la factura.
///
/// Las dos por el taller EFECTIVO (el uid del dueño): antes esta pantalla
/// consultaba por el uid de la sesión, así que a un empleado le salía vacía
/// aunque el taller tuviera servicios.
class MechanicServiceHistoryScreen extends StatefulWidget {
  /// Inyectable **solo** para tests: sin esto no se puede montar en un
  /// widget test. En producción se deja sin pasar.
  final FirebaseFirestore? firestore;

  const MechanicServiceHistoryScreen({super.key, this.firestore});

  @override
  State<MechanicServiceHistoryScreen> createState() =>
      _MechanicServiceHistoryScreenState();
}

class _MechanicServiceHistoryScreenState
    extends State<MechanicServiceHistoryScreen> {
  DateTimeRange? _dateRange;
  _Pestana _pestana = _Pestana.todos;

  /// Los dos streams se crean UNA vez por taller y se reutilizan: construidos
  /// dentro de `build`, cada `setState` (cambiar de pestaña, filtrar fechas)
  /// los recreaba y la lista volvía a "cargando" (ver GAPS-07 en CLAUDE.md).
  String? _idTallerDeLosStreams;
  Stream<List<CotizacionModel>>? _cotizaciones$;
  Stream<List<ServiceRecordModel>>? _servicios$;

  TrabajosTallerRepository get _repositorio => TrabajosTallerRepository(
    firestore: widget.firestore ?? FirebaseFirestore.instance,
  );

  void _prepararStreams(String idTaller) {
    if (_idTallerDeLosStreams == idTaller) return;
    _idTallerDeLosStreams = idTaller;
    _cotizaciones$ = _repositorio.watchCotizacionesDelTaller(idTaller);
    _servicios$ = _repositorio.watchServiciosDelTaller(idTaller);
    // Las placas de los tickets abiertos ayudan a nombrar el coche de las
    // cotizaciones anteriores al resumen del vehículo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<ReparacionProvider>().watchTaller(idTaller);
      } on ProviderNotFoundException {
        // Solo en tests que montan la pantalla sin el tablero.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserProfileProvider>().userData;
    if (userData == null || userData.idUsuario.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _prepararStreams(userData.idTallerEfectivo);

    return MechanicScaffold(
      title: 'Mis Servicios',
      body: StreamBuilder<List<CotizacionModel>>(
        stream: _cotizaciones$,
        builder: (context, cotSnap) => StreamBuilder<List<ServiceRecordModel>>(
          stream: _servicios$,
          builder: (context, servSnap) =>
              _contenido(context, cotSnap, servSnap),
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncSnapshot<List<CotizacionModel>> cotSnap,
    AsyncSnapshot<List<ServiceRecordModel>> servSnap,
  ) {
    final esperando =
        (cotSnap.connectionState == ConnectionState.waiting &&
            !cotSnap.hasData) ||
        (servSnap.connectionState == ConnectionState.waiting &&
            !servSnap.hasData);
    if (esperando) {
      return AppSkeletonLayouts.listCards(itemCount: 5, cardHeight: 96);
    }
    if (cotSnap.hasError) {
      debugPrint(
        'Mis Servicios: no se pudieron leer las cotizaciones: '
        '${cotSnap.error}',
      );
    }
    if (servSnap.hasError) {
      debugPrint(
        'Mis Servicios: no se pudieron leer los servicios: '
        '${servSnap.error}',
      );
    }
    if (cotSnap.hasError && servSnap.hasError) {
      return const AppEmptyState(
        title: 'No se pudieron cargar tus servicios',
        description: 'Revisa tu conexión e inténtalo de nuevo.',
        icon: Icons.cloud_off_outlined,
      );
    }

    final cotizaciones = (cotSnap.data ?? const <CotizacionModel>[])
        .where(_enRango)
        .where((c) => c.estado != 'finalizada')
        .toList();
    final servicios = (servSnap.data ?? const <ServiceRecordModel>[])
        .where((s) => _fechaEnRango(s.fecha))
        .toList();

    final porEstado = <_Pestana, List<CotizacionModel>>{
      _Pestana.enProceso: cotizaciones
          .where((c) => c.estado == 'aceptada')
          .toList(),
      _Pestana.pendientes: cotizaciones
          .where((c) => c.estado == 'pendiente')
          .toList(),
      _Pestana.rechazados: cotizaciones
          .where((c) => c.estado == 'rechazada')
          .toList(),
    };
    final conteos = <_Pestana, int>{
      _Pestana.enProceso: porEstado[_Pestana.enProceso]!.length,
      _Pestana.pendientes: porEstado[_Pestana.pendientes]!.length,
      _Pestana.finalizados: servicios.length,
      _Pestana.rechazados: porEstado[_Pestana.rechazados]!.length,
    };
    conteos[_Pestana.todos] = conteos.values.fold(0, (a, b) => a + b);

    final nombres = _nombresDeVehiculos(cotSnap.data ?? const []);
    final filas = <({DateTime fecha, Widget fila})>[
      if (_pestana == _Pestana.todos || _pestana == _Pestana.finalizados)
        for (final s in servicios)
          (
            fecha: s.fecha,
            fila: ServicioRealizadoTile(
              servicio: s,
              vehiculo: nombres[s.idVehiculo],
            ),
          ),
      for (final entrada in porEstado.entries)
        if (_pestana == _Pestana.todos || _pestana == entrada.key)
          for (final c in entrada.value)
            (
              fecha: c.fecha,
              fila: CotizacionTallerTile(
                cotizacion: c,
                vehiculo: vehiculoDeLaCotizacion(c) ?? nombres[c.idVehiculo],
                onTap: (c.idVehiculo ?? '').isEmpty
                    ? null
                    : () => context.go('/vehiculo_publico/${c.idVehiculo}'),
              ),
            ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));

    final truncado =
        (cotSnap.data?.length ?? 0) >= maxTrabajosTaller ||
        (servSnap.data?.length ?? 0) >= maxTrabajosTaller;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AppPageBody(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
              child: _Filtros(
                pestana: _pestana,
                conteos: conteos,
                rango: _dateRange,
                onPestana: (p) => setState(() => _pestana = p),
                onRango: (r) => setState(() => _dateRange = r),
              ),
            ),
          ),
        ),
        if (cotSnap.hasError || servSnap.hasError || truncado)
          SliverToBoxAdapter(
            child: AppPageBody(
              child: AvisoListaTruncada(
                mensaje: cotSnap.hasError || servSnap.hasError
                    ? 'Parte de tu trabajo no se pudo cargar: la lista puede '
                          'estar incompleta.'
                    : 'Se muestran los $maxTrabajosTaller trabajos más '
                          'recientes; los anteriores no aparecen aquí.',
              ),
            ),
          ),
        if (filas.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: _dateRange != null
                  ? 'No hay trabajos en este rango de fechas'
                  : _vacioTitulo(_pestana),
              description: _dateRange != null
                  ? 'Prueba a ampliar el rango o a quitar el filtro.'
                  : 'Las cotizaciones que envíes y los servicios que '
                        'registres aparecerán aquí, cada uno con su estado.',
              icon: Icons.receipt_long_outlined,
            ),
          )
        else
          SliverToBoxAdapter(
            child: AppPageBody(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: _EnColumnas(hijos: [for (final f in filas) f.fila]),
              ),
            ),
          ),
      ],
    );
  }

  static String _vacioTitulo(_Pestana p) => switch (p) {
    _Pestana.todos => 'Todavía no hay trabajos',
    _Pestana.enProceso => 'No tienes servicios en proceso',
    _Pestana.pendientes => 'No hay cotizaciones esperando respuesta',
    _Pestana.finalizados => 'No has finalizado ningún servicio aún',
    _Pestana.rechazados => 'No te han rechazado ninguna cotización',
  };

  bool _enRango(CotizacionModel c) => _fechaEnRango(c.fecha);

  bool _fechaEnRango(DateTime fecha) {
    final rango = _dateRange;
    if (rango == null) return true;
    return !fecha.isBefore(rango.start) &&
        fecha.isBefore(rango.end.add(const Duration(days: 1)));
  }

  /// «Toyota Corolla · P123-456» por id de vehículo, de lo que se sepa: el
  /// resumen que traen las cotizaciones desde el 2026-09-19, y si no, la
  /// placa de un ticket abierto.
  Map<String, String> _nombresDeVehiculos(List<CotizacionModel> todas) {
    final nombres = <String, String>{};
    try {
      for (final r in context.read<ReparacionProvider>().reparaciones) {
        if (r.placa.isNotEmpty) nombres[r.idVehiculo] = r.placa;
      }
    } on ProviderNotFoundException {
      // Solo en tests que montan la pantalla sin el tablero.
    }
    for (final c in todas) {
      final id = c.idVehiculo;
      final nombre = vehiculoDeLaCotizacion(c);
      if (id != null && nombre != null) nombres[id] = nombre;
    }
    return nombres;
  }
}

/// Pestañas por estado, con cuántos trabajos hay en cada una, y el filtro de
/// fechas.
class _Filtros extends StatelessWidget {
  final _Pestana pestana;
  final Map<_Pestana, int> conteos;
  final DateTimeRange? rango;
  final ValueChanged<_Pestana> onPestana;
  final ValueChanged<DateTimeRange?> onRango;

  const _Filtros({
    required this.pestana,
    required this.conteos,
    required this.rango,
    required this.onPestana,
    required this.onRango,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final r = rango;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final p in _Pestana.values)
              ChoiceChip(
                key: Key('mis_servicios_${p.name}'),
                label: Text('${p.etiqueta} (${conteos[p] ?? 0})'),
                selected: p == pestana,
                onSelected: (_) => onPestana(p),
                selectedColor: colors.primary.withValues(alpha: 0.15),
                labelStyle: AppTextStyles.labelLarge.copyWith(
                  color: p == pestana ? colors.primary : colors.textSecondary,
                  fontWeight: p == pestana ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Flexible(
              child: AppButton(
                type: AppButtonType.secondary,
                size: AppButtonSize.small,
                icon: const Icon(Icons.date_range, size: 18),
                text: r == null
                    ? 'Filtrar por Fechas'
                    : '${DateFormat('dd/MM/yy').format(r.start)} - '
                          '${DateFormat('dd/MM/yy').format(r.end)}',
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDateRange: r,
                  );
                  if (picked != null) onRango(picked);
                },
              ),
            ),
            if (r != null)
              IconButton(
                icon: Icon(Icons.clear, color: colors.error),
                tooltip: 'Quitar el filtro de fechas',
                onPressed: () => onRango(null),
              ),
          ],
        ),
      ],
    );
  }
}

/// Las filas en una columna en móvil y en dos a partir de `expanded`, cada
/// una con la altura de su contenido: una rejilla de proporción fija las
/// estiraba a lo alto en escritorio (observaciones del 2026-09-19, punto 6).
class _EnColumnas extends StatelessWidget {
  final List<Widget> hijos;

  const _EnColumnas({required this.hijos});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas =
            AppBreakpoints.fromWidth(constraints.maxWidth).isAtLeastExpanded
            ? 2
            : 1;
        const espacio = AppSpacing.md;
        final ancho =
            (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [for (final h in hijos) SizedBox(width: ancho, child: h)],
        );
      },
    );
  }
}
