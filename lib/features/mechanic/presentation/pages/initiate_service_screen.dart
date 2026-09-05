import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_form.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import 'package:autodoc/core/utils/input_formatters.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/features/mechanic/presentation/pages/service_finalized_screen.dart';

class InitiateServiceScreen extends StatefulWidget {
  /// Id del ticket de `reparaciones`. Desde la Tarea 5 (A3/B2) es lo que
  /// lleva la ruta (`/initiate_service/:reparacionId`), no el vehículo: esta
  /// pantalla solo es alcanzable cuando el ticket ya existe —
  /// `abrirVehiculoComoMecanico` lo resolvió antes de navegar aquí—, así que
  /// ya no necesita buscarlo por vehículo+taller.
  final String reparacionId;
  final VehicleModel? vehiculoPrecargado;

  const InitiateServiceScreen({
    super.key,
    required this.reparacionId,
    this.vehiculoPrecargado,
  });

  @override
  State<InitiateServiceScreen> createState() => _InitiateServiceScreenState();
}

class _InitiateServiceScreenState extends State<InitiateServiceScreen> {
  VehicleModel? _vehiculo;
  bool _cargando = false;
  String? _errorCarga;

  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _costoController = TextEditingController();
  final TextEditingController _manoDeObraController = TextEditingController();
  final List<CotizacionItemRowControllers> _materialRows = [];
  // Gatea Finalizar cuando no hay cotización aprobada: sin esto, una fila
  // agregada pero sin completar (nombre puesto, cantidad/costo vacíos o
  // inválidos) coercionaba en silencio a `cantidad: 1, costo: 0` en
  // `_materialesDesdeFilas()` y llegaba así al `servicios` del taller. El
  // viejo diálogo "Agregar Material" nunca dejaba agregar una fila así de
  // entrada; con las filas editables en línea (Task 7/B1) hace falta este
  // `Form` para reproducir esa misma garantía.
  final _materialesFormKey = GlobalKey<FormState>();
  final Set<String> _completedTaskIds = {};
  bool _isSaving = false;
  XFile? _invoiceImage;

  bool _hasApprovedQuote = false;
  CotizacionModel? _approvedQuote;

  /// `true` una vez que "Recibir vehículo" confirmó la transición en esta
  /// sesión de pantalla (con éxito, sea recepción nueva o no-op). Deliberado
  /// que sea independiente de `widget.reparacionId` (que la pantalla conoce
  /// desde el principio, vía la ruta, desde la Tarea 5): el banner de
  /// "recibido"/"ya estaba recibido" debe aparecer solo tras una
  /// confirmación explícita, no en cuanto se conoce el id del ticket.
  bool _recepcionConfirmada = false;

  /// `true` si esta pulsación fue la que movió el ticket a `recibido`;
  /// `false` si el ticket ya estaba recibido de antes (hallazgo 2 de la
  /// revisión de la Tarea 4). Decide qué texto muestra el banner de éxito:
  /// sin esta distinción la pantalla podía anunciar "vehículo recibido"
  /// cuando en realidad no transicionó nada.
  bool _recibidoAhora = true;

  /// Si la recepción no se pudo registrar (no hay cotización aceptada, red,
  /// permisos), se muestra un banner con reintento en vez de fallar en
  /// silencio: sin esto el mecánico podía salir de la pantalla creyendo que
  /// el vehículo quedó registrado en "Reparaciones".
  String? _reparacionError;

  /// Controla el estado de carga del botón "Recibir vehículo" (independiente
  /// de `_cargando`, que solo cubre la carga inicial del vehículo). Evita
  /// dobles envíos mientras `_recibirVehiculo` está en vuelo.
  bool _recibiendo = false;

  bool get _isInvoicePdf =>
      _invoiceImage?.name.toLowerCase().endsWith('.pdf') ?? false;

  Future<void> _pickInvoiceDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        final file = result.files.single;
        final webBytes = kIsWeb ? await file.readAsBytes() : null;
        if (!mounted) return;
        setState(() {
          if (webBytes != null) {
            _invoiceImage = XFile.fromData(webBytes, name: file.name);
          } else if (file.path != null) {
            _invoiceImage = XFile(file.path!);
          }
        });
      }
    } catch (e) {
      debugPrint("Error al seleccionar documento: $e");
    }
  }

  Future<void> _pickInvoiceCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _invoiceImage = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Error al tomar/seleccionar imagen: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _manoDeObraController.addListener(_updateTotalCost);
    _vehiculo = widget.vehiculoPrecargado;
    // La carga real (setState/notifyListeners de AlertProvider,
    // ReparacionProvider, etc.) se dispara post-frame, no aquí: si esta
    // pantalla se inserta mientras el widget padre todavía está en su
    // build (p.ej. al navegar con context.push), llamar setState o
    // notifyListeners de forma síncrona dentro de initState cae dentro del
    // "build lock" de Flutter y lanza "setState() or markNeedsBuild()
    // called during build" — justo lo que reportó el usuario al entrar
    // aquí desde "Buscar Vehículo".
    _cargando = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_vehiculo != null) {
        _onVehiculoListo();
      } else {
        _cargarVehiculo();
      }
      final tallerId = context
          .read<UserProfileProvider>()
          .userData
          ?.idTallerEfectivo;
      if (tallerId != null && tallerId.isNotEmpty) {
        context.read<CatalogoProvider>().watchTaller(tallerId);
      }
    });
  }

  /// Solo se llama cuando `vehiculoPrecargado` viene vacío (p. ej. un F5
  /// sobre esta URL, que pierde `extra`): la ruta ya no lleva el id del
  /// vehículo (Tarea 5), así que primero hay que leer el ticket por
  /// `widget.reparacionId` para saber a qué vehículo pertenece.
  Future<void> _cargarVehiculo() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final reparacionDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.reparaciones)
          .doc(widget.reparacionId)
          .get();
      if (!mounted) return;
      final idVehiculo = (reparacionDoc.data()?['id_vehiculo'] ?? '')
          .toString();
      if (!reparacionDoc.exists || idVehiculo.isEmpty) {
        setState(() {
          _cargando = false;
          _errorCarga = 'notFound';
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.vehiculos)
          .doc(idVehiculo)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _cargando = false;
          _errorCarga = 'notFound';
        });
        return;
      }
      setState(() {
        _vehiculo = VehicleModel.fromMap(doc.data()!, doc.id);
      });
      await _onVehiculoListo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'error';
      });
    }
  }

  /// El spinner de carga ('_cargando') solo cubre encontrar el vehículo:
  /// antes se quedaba activo hasta que el ticket Kanban de reparación
  /// terminara de guardarse, porque este método lo creaba automáticamente al
  /// llegar aquí. Ya no lo hace (ver comentario más abajo), así que suelta el
  /// spinner en cuanto el vehículo está listo, sin esperar a ninguna
  /// escritura en Firestore.
  Future<void> _onVehiculoListo() async {
    final vehiculo = _vehiculo!;
    _kmController.text = vehiculo.kilometrajeActual.toString();
    if (mounted) {
      context.read<AlertProvider>().fetchAlerts(vehiculo.idVehiculo, vehiculo);
    }

    FirebaseFirestore.instance
        .collection('cotizaciones')
        .where('id_vehiculo', isEqualTo: vehiculo.idVehiculo)
        .where('estado', isEqualTo: 'aceptada')
        .orderBy('fecha', descending: true)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            if (mounted) {
              setState(() {
                _hasApprovedQuote = true;
                _approvedQuote = CotizacionModel.fromMap(
                  snapshot.docs.first.data(),
                  snapshot.docs.first.id,
                );
                _costoController.text = _approvedQuote!.total.toStringAsFixed(
                  2,
                );
              });
            }
          }
        });

    // Aquí no se toca el ticket. Hasta 2026-08-28 se creaba al montar la
    // pantalla, así que teclear una placa en "Buscar Vehículo" ya metía el
    // coche en el kanban Y mandaba un push al propietario ("Tu vehículo ya
    // está en seguimiento") antes de que el taller confirmara nada. Desde
    // A4b ya no lo crea nadie desde el cliente: nace al aceptarse la
    // cotización, y el botón "Recibir vehículo" solo lo mueve a 'recibido'.
    if (mounted) {
      setState(() => _cargando = false);
    }
  }

  /// Marca la llegada del vehículo al taller. Ya **no** crea el ticket: desde
  /// A4b el ticket nace cuando el cliente acepta la cotización (Cloud
  /// Function `onCotizacionAceptada`), en `pendiente_recepcion`, y este botón
  /// solo lo mueve a `recibido`. Si no hay ticket, no hay cotización aceptada
  /// y no se recibe nada (A3/B2).
  ///
  /// Desde la Tarea 5, `widget.reparacionId` ya es el id del ticket (lo trae
  /// la ruta): a diferencia de la versión provisional de la Tarea 4, ya no
  /// hace falta buscarlo por vehículo+taller ni conocer el taller efectivo
  /// del mecánico para eso.
  Future<void> _recibirVehiculo() async {
    setState(() {
      _recibiendo = true;
      _reparacionError = null;
    });

    try {
      final reparacionProvider = context.read<ReparacionProvider>();
      final recibidoAhora = await reparacionProvider.recibirVehiculoPorId(
        widget.reparacionId,
      );
      if (!mounted) return;
      if (recibidoAhora == null) {
        setState(() {
          _reparacionError =
              reparacionProvider.error ??
              'No se pudo marcar este vehículo como recibido.';
          _recibiendo = false;
        });
        return;
      }
      setState(() {
        _recepcionConfirmada = true;
        _recibidoAhora = recibidoAhora;
        _reparacionError = null;
        _recibiendo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reparacionError = 'No se pudo marcar el vehículo como recibido: $e';
        _recibiendo = false;
      });
    }
  }

  void _updateTotalCost() {
    double totalMateriales = _materialRows.fold(
      0.0,
      (acc, r) => acc + r.subtotal,
    );
    double manoDeObra = double.tryParse(_manoDeObraController.text) ?? 0;
    double total = totalMateriales + manoDeObra;
    if (total > 0) {
      _costoController.text = total.toStringAsFixed(2);
    } else {
      _costoController.text = '';
    }
  }

  /// Convierte las filas editables de `_materialRows` al `List<Map>` que
  /// espera `AlertProvider.tallerRegistrarServicioSinTarea`/`tallerUpdateService`
  /// — la misma forma que antes producía `_showAddMaterialDialog`. Solo se
  /// llama tras `_materialesFormKey.currentState.validate()` en
  /// `_handleFinalizeService`, así que cada fila que llega aquí ya tiene
  /// nombre no vacío y cantidad/costo parseables — el filtro por nombre de
  /// abajo es una defensa adicional, no la única barrera (a diferencia de
  /// antes de la Fix 1 de la revisión, donde era la única).
  List<Map<String, dynamic>> _materialesDesdeFilas() {
    return _materialRows
        .where((r) => r.nombreController.text.trim().isNotEmpty)
        .map(
          (r) => {
            'nombre': r.nombreController.text.trim(),
            'cantidad': r.cantidad,
            'precioUnitario': r.costo,
          },
        )
        .toList();
  }

  @override
  void dispose() {
    _kmController.dispose();
    _notesController.dispose();
    _costoController.dispose();
    _manoDeObraController.dispose();
    for (final row in _materialRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _handleFinalizeService() async {
    if (_kmController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'Por favor, ingresa el kilometraje actual',
      );
      return;
    }

    final nuevoKm = int.tryParse(_kmController.text);
    if (nuevoKm == null || nuevoKm < _vehiculo!.kilometrajeActual) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'El kilometraje debe ser mayor o igual al actual',
      );
      return;
    }

    final tareasDisponibles = context
        .read<AlertProvider>()
        .maintenanceTasks
        .length;
    if (requiereTareaSeleccionada(
      tareasDisponibles: tareasDisponibles,
      tareasMarcadas: _completedTaskIds.length,
    )) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'Selecciona al menos una tarea realizada',
      );
      return;
    }

    // Sin cotización aprobada, los materiales son filas editables en línea
    // (Task 7/B1): validar aquí es lo que impide que una fila con nombre
    // pero cantidad/costo vacíos o ilegibles llegue a `servicios` coercionada
    // en silencio a `cantidad: 1, costo: 0` — la misma garantía que antes
    // daba el diálogo "Agregar Material" al no dejar agregar una fila así de
    // entrada.
    if (!_hasApprovedQuote &&
        !(_materialesFormKey.currentState?.validate() ?? true)) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'Revisa los materiales: hay renglones incompletos o inválidos.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final alertProvider = context.read<AlertProvider>();
      final userSession = context.read<UserProfileProvider>();
      // `idTallerEfectivo` (uid del dueño, no del empleado que opera), igual
      // que el resto de este archivo (líneas 142 y 235): `servicios`,
      // `mantenimientos` y `historial_mantenimientos` ya aceptan
      // `actuaPorTaller()` para sub-cuentas de empleado, así que usar aquí el
      // uid propio del empleado solo rompía el finalizar-servicio de
      // cualquier cliente que ya tuviera vínculo (`talleres_vinculados`
      // guarda el uid del dueño, nunca el del empleado).
      final tallerId =
          userSession.userData?.idTallerEfectivo ?? 'taller_anonimo';

      final costoDouble = double.tryParse(_costoController.text);
      final manoDeObraDouble = _hasApprovedQuote
          ? _approvedQuote?.manoDeObra
          : double.tryParse(_manoDeObraController.text);
      final materialesList = _hasApprovedQuote
          ? _approvedQuote?.materiales
          : _materialesDesdeFilas();

      if (_completedTaskIds.isEmpty) {
        // Sin tareas de mantenimiento configuradas, el bucle de abajo no daba
        // ni una vuelta: no se escribia NADA y aun asi la pantalla decia
        // "Servicio registrado exitosamente". No es un caso raro — es el que
        // `requiereTareaSeleccionada` deja pasar a proposito, y el que el
        // texto de la pantalla promete que "quedara registrado en el
        // historial".
        await alertProvider.tallerRegistrarServicioSinTarea(
          vehiculoId: _vehiculo!.idVehiculo,
          nuevoKilometraje: nuevoKm,
          tallerId: tallerId,
          descripcion: _notesController.text,
          costo: costoDouble,
          manoDeObra: manoDeObraDouble,
          materiales: materialesList,
          receiptImage: _invoiceImage,
        );
      } else {
        for (var taskId in _completedTaskIds) {
          await alertProvider.tallerUpdateService(
            taskId: taskId,
            nuevoKilometraje: nuevoKm,
            tallerId: tallerId,
            descripcion: _notesController.text,
            costo: costoDouble,
            manoDeObra: manoDeObraDouble,
            materiales: materialesList,
            receiptImage: _invoiceImage,
          );
        }
      }

      await alertProvider.fetchAlerts(_vehiculo!.idVehiculo, _vehiculo!);

      if (_hasApprovedQuote && _approvedQuote != null) {
        await FirebaseFirestore.instance
            .collection('cotizaciones')
            .doc(_approvedQuote!.id)
            .update({'estado': 'finalizada'});
      }

      bool kanbanUpdateFailed = false;
      // `widget.reparacionId` siempre existe desde la Tarea 5 (la ruta ya no
      // llega a esta pantalla sin un ticket): a diferencia de la versión
      // anterior, esto ya no depende de que el mecánico haya pulsado
      // "Recibir vehículo" en esta sesión (p. ej. un ticket legado que ya
      // nació en `recibido`, ver el comentario de `_recepcionConfirmada`).
      if (mounted) {
        try {
          await context.read<ReparacionProvider>().cambiarEstado(
            widget.reparacionId,
            'listo_para_entrega',
          );
        } catch (e) {
          // No bloquear el cierre del servicio si el ticket Kanban no pudo
          // actualizarse (p.ej. ya estaba en ese estado o fue eliminado),
          // pero sí avisarle al mecánico: sin esto el servicio quedaba
          // facturado y el vehículo se veía "atascado" en el tablero sin
          // ninguna pista de por qué.
          kanbanUpdateFailed = true;
          debugPrint('Error al actualizar el ticket de reparación: $e');
        }
      }

      if (mounted) {
        HapticFeedback.lightImpact();
        if (kanbanUpdateFailed) {
          UiUtils.showErrorSnackbar(
            context,
            'Servicio registrado, pero no se pudo actualizar el ticket en '
            'Reparaciones. Avánzalo manualmente desde el tablero.',
          );
        }
        // Antes, un `context.go` inmediato a /mechanic_dashboard o
        // /mechanic_reparaciones era todo lo que veía el mecánico: solo un
        // snackbar de paso, sin ninguna confirmación propia. Se llega aquí
        // con `context.go` desde el buscador de placas (reemplaza la pila:
        // `canPop()` es false), así que esta pantalla también navega con
        // `go`, nunca con `pop` — desapilar sobre una pila vacía deja el
        // `RouteMatchList` de go_router sin nada que pintar.
        final nombreTaller = userSession.userData?.nombreCompleto ?? 'Taller';
        context.go(
          '/service_finalized',
          extra: ServiceFinalizedArgs(
            idPropietario: _vehiculo!.idPropietario,
            idVehiculo: _vehiculo!.idVehiculo,
            tallerId: tallerId,
            tallerNombre: nombreTaller,
            rutaContinuar: '/mechanic_reparaciones',
          ),
        );
      }
    } on FirebaseException catch (e) {
      // `permission-denied` aqui casi siempre significa una cosa concreta y
      // accionable: el vehiculo ya esta vinculado a OTRO taller, asi que la
      // regla de `servicios` (mitigacion del hallazgo C1) no deja crear el
      // registro. Enseñar el error crudo de Firestore deja al mecanico sin
      // saber que hacer, y el fallo no es suyo.
      if (mounted) {
        HapticFeedback.heavyImpact();
        UiUtils.showErrorSnackbar(
          context,
          e.code == 'permission-denied'
              ? 'No se pudo registrar el servicio: este vehículo ya está '
                    'asignado a otro taller, o tu cuenta aún no está '
                    'aprobada. Pídele al propietario que confirme el '
                    'vínculo desde su panel.'
              : 'Error al registrar servicio: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        UiUtils.showErrorSnackbar(context, 'Error al registrar servicio: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorCarga != null || _vehiculo == null) {
      return const MissingArgumentScreen(
        mensaje: 'No se pudo cargar el vehículo del servicio.',
        rutaVuelta: '/mechanic_dashboard',
      );
    }

    final alertProvider = context.watch<AlertProvider>();
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        // `leading` explicito: se llega con `go`, que reemplaza la pila, asi
        // que no hay nada que desapilar y Flutter no pintaria flecha de
        // volver. El origen es el buscador de placas.
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          tooltip: 'Volver',
          onPressed: () => context.go('/mechanic_search'),
        ),
        title: Text(
          'Iniciar Servicio',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dosColumnas = AppBreakpoints.fromWidth(
              constraints.maxWidth,
            ).isAtLeastExpanded;

            final izquierda = <Widget>[
              _VehicleHeaderCard(vehiculo: _vehiculo!),
              const SizedBox(height: AppSpacing.base),
              _buildTicketReparacionBanner(colors),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'Kilometraje de ingreso',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _BoxedField(
                icon: Icons.speed,
                label: 'Kilometraje de ingreso',
                controller: _kmController,
                keyboardType: TextInputType.number,
                suffix: 'KM',
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'Alertas detectadas',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildAlertsList(alertProvider, colors),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'Tareas a realizar',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildMaintenanceTasks(alertProvider, colors),
            ];

            final derecha = <Widget>[
              if (_hasApprovedQuote) ...[
                _buildApprovedQuoteBanner(colors),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (!_hasApprovedQuote) ...[
                const AppSectionHeader(
                  title: 'Materiales / repuestos',
                  uppercase: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Form(
                  key: _materialesFormKey,
                  child: _buildMaterialesList(colors),
                ),
                const SizedBox(height: AppSpacing.xl),
                const AppSectionHeader(title: 'Mano de obra', uppercase: true),
                const SizedBox(height: AppSpacing.md),
                _BoxedField(
                  icon: Icons.build_circle_outlined,
                  label: 'Mano de obra',
                  controller: _manoDeObraController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: montoInputFormatters,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              const AppSectionHeader(
                title: 'Costo del servicio (total)',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _BoxedField(
                icon: Icons.attach_money,
                label: 'Costo del servicio',
                controller: _costoController,
                readOnly: true,
                helperText: 'Se calcula sumando materiales y mano de obra',
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'Observaciones técnicas',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _notesController,
                maxLines: 3,
                hintText: 'Detalles del trabajo realizado...',
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'Foto de factura / comprobante',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildInvoicePicker(colors),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: 'FINALIZAR SERVICIO',
                onPressed: _isSaving ? null : _handleFinalizeService,
                isLoading: _isSaving,
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
    );
  }

  Widget _buildApprovedQuoteBanner(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'El cliente aprobó una cotización previa por '
              '\$${_approvedQuote!.total.toStringAsFixed(2)}. El desglose '
              'ya está registrado.',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePicker(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          if (_invoiceImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: _isInvoicePdf
                  ? Container(
                      height: 200,
                      width: double.infinity,
                      color: colors.primary.withValues(alpha: 0.1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 64,
                            color: colors.error,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _invoiceImage!.name,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FutureBuilder<List<int>>(
                      future: _invoiceImage!.readAsBytes().then(
                        (b) => b.toList(),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            Uint8List.fromList(snapshot.data!),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        }
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                AppButton(
                  text: 'Tomar otra',
                  type: AppButtonType.text,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _pickInvoiceCamera,
                ),
                AppButton(
                  text: 'Archivo',
                  type: AppButtonType.text,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.folder),
                  onPressed: _pickInvoiceDocument,
                ),
                AppButton(
                  text: 'Eliminar',
                  type: AppButtonType.danger,
                  size: AppButtonSize.small,
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _invoiceImage = null),
                ),
              ],
            ),
          ] else ...[
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: colors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '¿Deseas adjuntar una foto de la factura?',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Esto le servirá al propietario como comprobante legal.',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.base),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  text: 'Cámara',
                  icon: const Icon(Icons.camera_alt),
                  size: AppButtonSize.small,
                  onPressed: () => _pickInvoiceCamera(),
                ),
                AppButton(
                  type: AppButtonType.secondary,
                  text: 'Archivo / PDF',
                  icon: const Icon(Icons.folder),
                  size: AppButtonSize.small,
                  onPressed: () => _pickInvoiceDocument(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Confirma visualmente si el ticket Kanban de "Reparaciones" quedó
  /// guardado (con acceso directo al tablero) o, si falló, ofrece
  /// reintentar sin necesidad de recargar toda la pantalla.
  Widget _buildTicketReparacionBanner(AppColors colors) {
    if (_reparacionError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _reparacionError!,
                style: AppTextStyles.bodySmall.copyWith(color: colors.error),
              ),
            ),
            AppButton(
              type: AppButtonType.text,
              size: AppButtonSize.small,
              text: 'Reintentar',
              onPressed: _recibirVehiculo,
            ),
          ],
        ),
      );
    }

    if (_recepcionConfirmada) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: colors.secondary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _recibidoAhora
                    ? 'Vehículo recibido: ya aparece en Reparaciones.'
                    : 'Este vehículo ya estaba recibido: revisa su ticket '
                          'en Reparaciones.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            AppButton(
              type: AppButtonType.text,
              size: AppButtonSize.small,
              text: 'Ver tablero',
              onPressed: () => context.go('/mechanic_reparaciones'),
            ),
          ],
        ),
      );
    }

    // El taller todavía no confirmó la recepción en esta pantalla y no hay
    // error que reintentar. Antes de este fix, llegar aquí ya implicaba que
    // el ticket estaba creado y el propietario notificado — ahora hace falta
    // este botón explícito.
    return AppButton(
      text: 'Recibir vehículo',
      type: AppButtonType.secondary,
      icon: const Icon(Icons.garage_outlined),
      isLoading: _recibiendo,
      onPressed: _recibiendo ? null : _recibirVehiculo,
    );
  }

  Widget _buildMaterialesList(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CotizacionItemsForm(
          rows: _materialRows,
          minRows: 0,
          showTotal: false,
          nombreLabel: 'Nombre o descripción',
          costoLabel: 'Precio unitario (\$)',
          emptyPlaceholder: Text(
            'No hay materiales agregados.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          onAddRow: () =>
              setState(() => _materialRows.add(CotizacionItemRowControllers())),
          onRemoveRow: (index) {
            setState(() {
              _materialRows[index].dispose();
              _materialRows.removeAt(index);
              _updateTotalCost();
            });
          },
          onChanged: () => setState(_updateTotalCost),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          type: AppButtonType.secondary,
          text: 'Desde catálogo',
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => _showCatalogoBottomSheet(colors),
        ),
      ],
    );
  }

  /// Muestra el catálogo rápido del taller (Task 9/10) en un
  /// `showModalBottomSheet`; al tocar un ítem lo agrega a `_materiales` con
  /// la misma estructura que el diálogo manual (`_showAddMaterialDialog`),
  /// sin tocar la firma de `AlertProvider.tallerUpdateService`.
  Future<void> _showCatalogoBottomSheet(AppColors colors) async {
    final items = context.read<CatalogoProvider>().items;

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxFormWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
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
                          title: Text(
                            item.nombre,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          trailing: Text(
                            '\$${item.precio.toStringAsFixed(2)}',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          onTap: () =>
                              _agregarDesdeCatalogo(item, sheetContext),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _agregarDesdeCatalogo(
    CatalogoItemModel item,
    BuildContext sheetContext,
  ) {
    setState(() {
      final row = CotizacionItemRowControllers();
      row.nombreController.text = item.nombre;
      row.costoController.text = item.precio.toStringAsFixed(2);
      _materialRows.add(row);
      _updateTotalCost();
    });
    Navigator.pop(sheetContext);
  }

  Widget _buildAlertsList(AlertProvider provider, AppColors colors) {
    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (provider.activeAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: colors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: colors.secondary),
            const SizedBox(width: AppSpacing.md),
            Text(
              'No hay alertas pendientes',
              style: AppTextStyles.bodyMedium.copyWith(color: colors.secondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: provider.activeAlerts.take(3).map((alert) {
        // `AppSeverity.forAlertPriority`: alta y media ya no comparten
        // icono. Antes ambas dibujaban `Icons.warning_amber_rounded` y solo
        // se distinguían por color, ilegible con protanopia.
        final estilo = AppSeverity.forAlertPriority(
          alert.prioridad,
          colors,
          altaLabel: 'Crítica',
          mediaLabel: 'Preventiva',
          bajaLabel: 'Informativa',
        );
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: estilo.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: estilo.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(estilo.icon, color: estilo.color, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  label: '${estilo.label}: ${alert.titulo}',
                  excludeSemantics: true,
                  child: Text(
                    alert.titulo,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: estilo.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaintenanceTasks(AlertProvider provider, AppColors colors) {
    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (provider.maintenanceTasks.isEmpty) {
      // Sin tareas que marcar, el guard de _guardarServicio ya no exige
      // ninguna: este texto deja claro que cerrar el servicio así es
      // intencional y no un callejón sin salida (ver requiereTareaSeleccionada).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este vehículo no tiene tareas de mantenimiento configuradas.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Las configura el propietario desde Alertas. Puedes cerrar el '
            'servicio igualmente: quedará registrado en el historial.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      children: provider.maintenanceTasks.map((task) {
        final isSelected = _completedTaskIds.contains(task.id);
        final status = task.getStatus(_vehiculo!.kilometrajeActual);
        final estilo = AppSeverity.forStatus(
          status,
          colors,
          optimalLabel: 'Al día',
          preventiveLabel: 'Próximo',
          criticalLabel: 'Vencido',
        );

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected
                  ? colors.secondary
                  : colors.outline.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _completedTaskIds.add(task.id);
                } else {
                  _completedTaskIds.remove(task.id);
                }
              });
            },
            activeColor: colors.secondary,
            title: Text(
              task.nombre,
              style: AppTextStyles.titleSmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Frecuencia: ${task.frecuenciaKm} km / ${task.frecuenciaMeses} meses',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            secondary: Icon(estilo.icon, color: estilo.color),
          ),
        );
      }).toList(),
    );
  }
}

/// Cabecera del vehículo en servicio: nombre, placa y kilometraje actual
/// sobre el degradado de `colors.primary`.
///
/// Extraída como su propio widget (era un método privado inline) al
/// sustituir los cuatro literales blancos por `colors.onPrimary` — mismo
/// defecto de contraste 1,47:1 en dark que Task 9 corrigió en el
/// dashboard, misma corrección.
class _VehicleHeaderCard extends StatelessWidget {
  final VehicleModel vehiculo;

  const _VehicleHeaderCard({required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
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
                      '${vehiculo.marca} ${vehiculo.modelo}',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: colors.onPrimary,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                    Text(
                      'Placa: ${vehiculo.placa}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  '${vehiculo.kilometrajeActual} KM',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
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

/// Campo con caja e icono. Era el mismo `Container` con `Row(Icon,
/// Expanded(TextField), [sufijo])` escrito tres veces (kilometraje, coste,
/// mano de obra), y los tres con `TextField` crudo e `InputBorder.none`: sin
/// etiqueta asociada al input y sin sitio donde mostrar un error.
class _BoxedField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? suffix;
  final bool readOnly;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;

  const _BoxedField({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.suffix,
    this.readOnly = false,
    this.helperText,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      suffixText: suffix,
      helperText: helperText,
      inputFormatters: inputFormatters,
      prefixIcon: Icon(icon, color: context.appColors.primary),
    );
  }
}

/// Decide si hay que exigir al mecanico marcar una tarea antes de cerrar el
/// servicio.
///
/// Hasta 2026-08-28 el guard era `_completedTaskIds.isEmpty` a secas, sin
/// mirar si habia tareas que marcar. Cuando el vehiculo no tenia ninguna
/// configurada, la pantalla pintaba "No hay tareas configuradas para este
/// vehiculo" (sin casillas) y el submit respondia "Selecciona al menos una
/// tarea realizada": un callejon sin salida con el parte entero relleno.
bool requiereTareaSeleccionada({
  required int tareasDisponibles,
  required int tareasMarcadas,
}) {
  if (tareasDisponibles == 0) return false;
  return tareasMarcadas == 0;
}
