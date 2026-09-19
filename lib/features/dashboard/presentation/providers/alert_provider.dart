import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';

import 'package:autodoc/core/constants/maintenance_defaults.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/constants/storage_paths.dart';
import 'package:autodoc/features/dashboard/data/services/invoice_upload_service.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

class AlertProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AlertProvider({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  List<AlertModel> _alerts = [];
  List<MaintenanceTask> _maintenanceTasks = [];
  bool _isLoading = false;
  String? _error;

  List<AlertModel> get alerts => _alerts;
  List<AlertModel> get activeAlerts =>
      _alerts.where((a) => a.estado == 'Pendiente').toList();
  List<MaintenanceTask> get maintenanceTasks => _maintenanceTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Vacia el estado por usuario. Se llama al cerrar sesion: sin esto, el
  /// siguiente usuario que entre sin recargar la pagina ve las alertas del
  /// anterior.
  void clear() {
    _alerts = [];
    _maintenanceTasks = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAlerts(String vehicleId, VehicleModel vehicle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Obtener alertas manuales de Firestore
      final snapshot = await _firestore
          .collection(FirestoreCollections.alertas)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();

      _alerts = snapshot.docs
          .map((doc) => AlertModel.fromMap(doc.data(), doc.id))
          .toList();

      // 2. Obtener tareas de mantenimiento robustas
      final mSnapshot = await _firestore
          .collection(FirestoreCollections.mantenimientos)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();

      _maintenanceTasks = mSnapshot.docs
          .map((doc) => MaintenanceTask.fromMap(doc.data(), doc.id))
          .toList();

      if (_maintenanceTasks.isEmpty) {
        await createDefaultTasks(vehicleId, vehicle.kilometrajeActual);
        final mSnapshot2 = await _firestore
            .collection(FirestoreCollections.mantenimientos)
            .where('id_vehiculo', isEqualTo: vehicleId)
            .get();
        _maintenanceTasks = mSnapshot2.docs
            .map((doc) => MaintenanceTask.fromMap(doc.data(), doc.id))
            .toList();
      }

      // 3. Generar alertas automáticas basadas en lógica
      await _generateSmartAlerts(vehicle);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches and merges alerts across all [vehicles], instead of replacing
  /// them per-call like [fetchAlerts] does. Used by the dashboard so owners
  /// with multiple vehicles see alerts for every vehicle they own, not just
  /// the currently selected one.
  ///
  /// [maintenanceTasks] se fusiona igual que las alertas: si solo quedaran
  /// las del ultimo vehiculo procesado, el vehiculo seleccionado (el
  /// primario, que casi nunca es el ultimo del bucle) no tendria ninguna y
  /// las pantallas que las pintan se quedarian en blanco.
  ///
  /// Los consumidores (`dashboard_screen.dart`, `alerts_screen.dart`)
  /// filtran la lista por `task.vehicleId` antes de graduarla contra el
  /// odometro del vehiculo seleccionado; ese filtro es lo que hace segura
  /// esta fusion. No lo quites.
  Future<void> fetchAlertsForVehicles(List<VehicleModel> vehicles) async {
    if (vehicles.isEmpty) {
      _alerts = [];
      _maintenanceTasks = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final mergedAlerts = <AlertModel>[];
    final mergedTasks = <MaintenanceTask>[];
    String? lastError;

    for (final vehicle in vehicles) {
      // fetchAlerts catches its own exceptions internally (it never
      // rethrows — see its own try/catch below) and signals failure only
      // via `_error`. When a vehicle's fetch throws, it does so before
      // reassigning `_alerts`/`_maintenanceTasks`, so esos campos siguen
      // teniendo los datos de la iteracion *anterior*. Only merge when
      // `_error` is still null after the call, otherwise we'd silently
      // re-add the previous vehicle's data a second time.
      await fetchAlerts(vehicle.idVehiculo, vehicle);
      if (_error == null) {
        mergedAlerts.addAll(_alerts);
        mergedTasks.addAll(_maintenanceTasks);
      } else {
        lastError = _error;
      }
    }

    _alerts = mergedAlerts;
    _maintenanceTasks = mergedTasks;
    _error = lastError;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _generateSmartAlerts(VehicleModel vehicle) async {
    final now = DateTime.now();

    // --- 1. Alerta de Seguro (SOAT) ---
    if (vehicle.vencimientoSoat != null) {
      final daysToExpire = vehicle.vencimientoSoat!.difference(now).inDays;
      if (daysToExpire <= 15) {
        _addOrUpdateLocalAlert(
          AlertModel(
            idAlerta: 'soat_${vehicle.idVehiculo}',
            idVehiculo: vehicle.idVehiculo,
            tipoAlerta: 'SOAT',
            // El título tiene que concordar con el cuerpo: "Seguro por
            // vencer" encabezando "Tu SOAT venció hace 38 días" se lee como
            // un dato equivocado, y es justo la alerta en la que el usuario
            // necesita creerle a la app.
            titulo: daysToExpire < 0 ? 'Seguro vencido' : 'Seguro por vencer',
            descripcion: daysToExpire < 0
                ? 'Tu SOAT venció hace ${daysToExpire.abs()} días.'
                : 'Tu SOAT vence en $daysToExpire días.',
            fechaLimite: vehicle.vencimientoSoat,
            metadata: {'placa': vehicle.placa},
            prioridad: daysToExpire < 0
                ? AlertPriority.high
                : AlertPriority.medium,
          ),
        );
      }
    }

    // Nota: La alerta de Aceite se ha migrado a MaintenanceTasks
    // para permitir umbrales configurables por el usuario.

    // --- 3. Presión de Llantas (Semanal) ---
    _addOrUpdateLocalAlert(
      AlertModel(
        idAlerta: 'llantas_${vehicle.idVehiculo}',
        idVehiculo: vehicle.idVehiculo,
        tipoAlerta: 'Llantas',
        titulo: 'Presión de Llantas',
        descripcion:
            'Revisión semanal recomendada para mantener el consumo óptimo.',
        prioridad: AlertPriority.low,
        // La placa viaja en la metadata de TODAS las alertas generadas por
        // vehículo. Estas tres (llantas, fluidos, luces) son recordatorios
        // fijos que se emiten una vez por coche, así que en un garaje con
        // varios vehículos el panel repetía la misma terna, palabra por
        // palabra, tantas veces como coches — sin nada que dijera a cuál
        // pertenecía cada tarjeta.
        metadata: {'psi_recomendado': 32, 'placa': vehicle.placa},
      ),
    );

    // --- 4. Chequeos Rápidos (Fluidos, Batería, Luces) ---
    _addOrUpdateLocalAlert(
      AlertModel(
        idAlerta: 'fluidos_${vehicle.idVehiculo}',
        idVehiculo: vehicle.idVehiculo,
        tipoAlerta: 'Fluidos',
        titulo: 'Niveles de Fluidos',
        descripcion:
            'Revisa refrigerante, líquido de frenos y limpiaparabrisas.',
        prioridad: AlertPriority.low,
        metadata: {'placa': vehicle.placa},
      ),
    );
    _addOrUpdateLocalAlert(
      AlertModel(
        idAlerta: 'luces_${vehicle.idVehiculo}',
        idVehiculo: vehicle.idVehiculo,
        tipoAlerta: 'Luces',
        titulo: 'Inspección de Luces',
        descripcion:
            'Asegúrate de que todas las luces externas funcionen correctamente.',
        prioridad: AlertPriority.low,
        metadata: {'placa': vehicle.placa},
      ),
    );

    // --- 5. Integración con MaintenanceTasks Robustas ---
    for (var task in _maintenanceTasks) {
      // Un odómetro por debajo del último servicio registrado es un dato
      // inconsistente, no una tarea con "kilometraje restante" enorme:
      // getStatus() resta un negativo y cree que faltan decenas de miles
      // de km, marcando la tarea ÓPTIMA y ocultando el problema real (ver
      // hallazgo QA §16). No es un fallo de carga (`_error`): es un dato
      // de ESTA tarea, así que se representa como su propia alerta.
      if (vehicle.kilometrajeActual < task.ultimoKm) {
        _addOrUpdateLocalAlert(
          AlertModel(
            idAlerta: 'task_inconsistente_${task.id}',
            idVehiculo: vehicle.idVehiculo,
            tipoAlerta: 'MantenimientoInconsistente',
            titulo: task.nombre,
            // El texto visible se arma en la pantalla que la muestra
            // (l10n): el provider no tiene BuildContext/locale.
            descripcion: '',
            prioridad: AlertPriority.high,
            metadata: {'ultimo_km': task.ultimoKm},
          ),
        );
        continue;
      }

      final status = task.getStatus(vehicle.kilometrajeActual);
      if (status != MaintenanceStatus.optimal) {
        _addOrUpdateLocalAlert(
          AlertModel(
            idAlerta: 'task_${task.id}',
            idVehiculo: vehicle.idVehiculo,
            tipoAlerta: 'Mantenimiento',
            titulo: task.nombre,
            descripcion: status == MaintenanceStatus.critical
                ? '¡CRÍTICO! Límite de ${task.nombre} superado.'
                : 'Mantenimiento preventivo de ${task.nombre} próximo.',
            prioridad: status == MaintenanceStatus.critical
                ? AlertPriority.high
                : AlertPriority.medium,
            fechaLimite: DateTime.now().add(
              const Duration(days: 15),
            ), // Aproximado para la UI
          ),
        );
      }
    }
  }

  void _addOrUpdateLocalAlert(AlertModel alert) {
    final index = _alerts.indexWhere(
      (AlertModel a) => a.idAlerta == alert.idAlerta,
    );
    if (index != -1) {
      _alerts[index] = alert;
    } else {
      _alerts.add(alert);
    }
  }

  Future<void> completeAlert(String alertId) async {
    try {
      // Si la alerta existe en Firestore, la marcamos como completada
      final index = _alerts.indexWhere((AlertModel a) => a.idAlerta == alertId);
      if (index != -1) {
        final alert = _alerts[index];

        if (![
          'soat_',
          'aceite_',
          'llantas_',
          'fluidos_',
          'luces_',
          'task_',
        ].any((p) => alertId.startsWith(p))) {
          await _firestore
              .collection(FirestoreCollections.alertas)
              .doc(alertId)
              .update({'estado': 'Completada'});
        }

        _alerts[index] = alert.copyWith(estado: 'Completada');
        notifyListeners();
      }
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
    }
  }

  // --- LÓGICA DE CREACIÓN DE TAREAS PREDETERMINADAS ---

  /// Ver `kTareasMantenimientoPorDefecto`. La tabla salio de aqui para que
  /// el script de backfill (`functions/seed_tareas_mantenimiento.js`) pueda
  /// citarla como fuente unica en vez de reinventar los valores.
  static const List<Map<String, dynamic>> _defaultTasks =
      kTareasMantenimientoPorDefecto;

  /// Siembra el plan por defecto en [vehicleId]. Es **idempotente**: se puede
  /// llamar tantas veces como haga falta sin duplicar nada.
  ///
  /// Antes no lo era, y por eso los vehiculos aparecian con el plan repetido
  /// x2, x3 o x6: cada tarea se escribia con `collection().doc()` (id
  /// aleatorio), asi que dos llamadas cualesquiera creaban dos juegos
  /// completos de ocho. Y llamadas repetidas son lo normal, no la excepcion —
  /// se llama al anadir el vehiculo (dashboard/garage) y otra vez desde
  /// `fetchAlerts` cada vez que la lista sale vacia, que es justo lo que
  /// ocurre mientras la escritura anterior todavia no es visible.
  ///
  /// Dos defensas, no una:
  ///  - El id lo fija `idTareaMantenimiento`, asi que dos llamadas a la vez
  ///    escriben el MISMO documento en lugar de dos.
  ///  - Se saltan las tareas cuyo nombre ya existe, para no pisar con `set`
  ///    el `ultimo_km` de una tarea que el propietario ya llevaba al dia.
  Future<void> createDefaultTasks(String vehicleId, int currentKm) async {
    try {
      final existentes = await _firestore
          .collection(FirestoreCollections.mantenimientos)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();
      final nombresExistentes = existentes.docs
          .map((doc) => doc.data()['nombre'])
          .toSet();

      final now = DateTime.now();
      final batch = _firestore.batch();
      var pendientes = 0;

      for (var taskData in _defaultTasks) {
        if (nombresExistentes.contains(taskData['nombre'])) continue;
        final docRef = _firestore
            .collection(FirestoreCollections.mantenimientos)
            .doc(idTareaMantenimiento(vehicleId, taskData['nombre'] as String));
        batch.set(docRef, {
          'id_vehiculo': vehicleId,
          'nombre': taskData['nombre'],
          'ultimo_km': currentKm,
          'fecha_ultimo_servicio': Timestamp.fromDate(now),
          'frecuencia_km': taskData['frecuencia_km'],
          'frecuencia_meses': taskData['frecuencia_meses'],
        });
        pendientes++;
      }

      if (pendientes == 0) return;
      await batch.commit();
    } catch (e) {
      debugPrint('Error al crear tareas predeterminadas: $e');
    }
  }

  // --- LÓGICA DE USUARIO PARA TAREAS ---

  Future<void> userCompleteTask({
    required String taskId,
    required int currentKm,
    required double cost,
    required String notes,
    double? manoDeObra,
    List<Map<String, dynamic>>? materiales,
    XFile? receiptImage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      String? receiptUrl;

      // Actualizar la tarea
      await _firestore
          .collection(FirestoreCollections.mantenimientos)
          .doc(taskId)
          .update({
            'ultimo_km': currentKm,
            'fecha_ultimo_servicio': Timestamp.fromDate(now),
          });

      // Actualizar localmente
      final taskIndex = _maintenanceTasks.indexWhere((t) => t.id == taskId);
      final task = taskIndex != -1 ? _maintenanceTasks[taskIndex] : null;
      if (task == null) {
        // Antes todo el registro del servicio colgaba de este `if (task != null)`,
        // asi que si la tarea no estaba en la lista en memoria el historial no
        // se escribia en absoluto y la UI mostraba igualmente "Servicio validado
        // y registrado en historial". Fallar en voz alta es preferible a mentir.
        throw StateError(
          'La tarea $taskId no esta cargada; recarga el mantenimiento e intentalo de nuevo.',
        );
      }

      _maintenanceTasks[taskIndex] = MaintenanceTask(
        id: task.id,
        vehicleId: task.vehicleId,
        nombre: task.nombre,
        ultimoKm: currentKm,
        fechaUltimoServicio: now,
        frecuenciaKm: task.frecuenciaKm,
        frecuenciaMeses: task.frecuenciaMeses,
      );

      Reference? receiptRef;
      if (receiptImage != null) {
        final metadataInfo = InvoiceUploadService.getFileMetadata(
          receiptImage.name,
        );
        final extension = metadataInfo['extension']!;
        final contentType = metadataInfo['contentType']!;

        receiptRef = _storage
            .ref()
            .child(StoragePaths.facturas)
            .child(task.vehicleId)
            .child(InvoiceUploadService.nombreDeArchivo(extension));
        final bytes = await receiptImage.readAsBytes();
        final metadata = SettableMetadata(contentType: contentType);
        await receiptRef.putData(bytes, metadata);
        receiptUrl = await receiptRef.getDownloadURL();
      }

      try {
        // Registrar como un servicio hecho manualmente
        await _firestore.collection(FirestoreCollections.servicios).add({
          'id_vehiculo': task.vehicleId,
          'id_taller': 'Manual (Propietario)',
          'tipo_servicio': task.nombre,
          'fecha': Timestamp.fromDate(now),
          'kilometraje_servicio': currentKm,
          'descripcion': notes.isNotEmpty
              ? notes
              : 'Mantenimiento registrado manualmente por el propietario',
          'costo': cost,
          'mano_de_obra': manoDeObra,
          'materiales': materiales,
          'foto_factura_url': receiptUrl,
        });
      } catch (e) {
        // La factura ya esta en Storage pero el documento que la referencia no
        // llego a existir: sin esta limpieza el archivo queda huerfano en el
        // bucket para siempre, sin ninguna forma de encontrarlo desde la app.
        //
        // ⚠️ ESTA LIMPIEZA NO PUEDE FUNCIONAR, y conviene saberlo antes de
        // confiar en ella: `storage.rules` deja el `delete` de `facturas/`
        // SOLO a un admin —«las facturas son el rastro documental del
        // producto»— asi que este `delete()` siempre se deniega y el `catch`
        // de abajo se lo traga. Tampoco funcionaba antes de GAPS-05: el viejo
        // `allow write` incluia `esFacturaValida()`, que dereferencia
        // `request.resource`, y en un delete eso es null.
        //
        // O sea que cada `servicios.add()` fallido deja una factura huerfana e
        // imborrable desde el cliente. Se deja el intento porque no cuesta
        // nada y documenta la intencion, pero el arreglo de verdad es del
        // servidor —un trigger con Admin SDK, hermano de
        // `borrarFotosAlEliminarResenia` (GAPS-04)—. Lo levanto el gate de
        // revision de GAPS-05 y queda anotado como gap.
        if (receiptRef != null) {
          try {
            await receiptRef.delete();
          } catch (_) {
            // Si tampoco se puede borrar, no tapamos el error original.
          }
        }
        rethrow;
      }

      // Limpiar también cualquier alerta activa relacionada a este task
      final alertIndex = _alerts.indexWhere(
        (a) => a.idAlerta == 'task_$taskId',
      );
      if (alertIndex != -1) {
        _alerts.removeAt(alertIndex);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> userUpdateTask(String taskId, int newFrecuenciaKm) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore
          .collection(FirestoreCollections.mantenimientos)
          .doc(taskId)
          .update({'frecuencia_km': newFrecuenciaKm});

      final taskIndex = _maintenanceTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        final task = _maintenanceTasks[taskIndex];
        _maintenanceTasks[taskIndex] = MaintenanceTask(
          id: task.id,
          vehicleId: task.vehicleId,
          nombre: task.nombre,
          ultimoKm: task.ultimoKm,
          fechaUltimoServicio: task.fechaUltimoServicio,
          frecuenciaKm: newFrecuenciaKm,
          frecuenciaMeses: task.frecuenciaMeses,
        );
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> userUpdateTaskFull(
    String taskId,
    int newFrecuenciaKm,
    int newFrecuenciaMeses,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore
          .collection(FirestoreCollections.mantenimientos)
          .doc(taskId)
          .update({
            'frecuencia_km': newFrecuenciaKm,
            'frecuencia_meses': newFrecuenciaMeses,
          });

      final taskIndex = _maintenanceTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        final task = _maintenanceTasks[taskIndex];
        _maintenanceTasks[taskIndex] = MaintenanceTask(
          id: task.id,
          vehicleId: task.vehicleId,
          nombre: task.nombre,
          ultimoKm: task.ultimoKm,
          fechaUltimoServicio: task.fechaUltimoServicio,
          frecuenciaKm: newFrecuenciaKm,
          frecuenciaMeses: newFrecuenciaMeses,
        );
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Cierra un servicio del taller: escribe **un solo** documento en
  /// `servicios`, marque las tareas de mantenimiento que marque.
  ///
  /// Observaciones del 2026-09-19. Antes había dos caminos:
  /// `tallerUpdateService`, que se llamaba UNA VEZ POR TAREA marcada y
  /// escribía un `servicios` completo en cada vuelta —tres tareas en un
  /// servicio de $588 salían en el historial como tres servicios de $588, con
  /// tres reseñas posibles y tres avisos del trigger—, y
  /// `tallerRegistrarServicioSinTarea` para cuando no había tareas. Además la
  /// pantalla exigía marcar al menos una, cuando lo que se cobra es lo de la
  /// cotización.
  ///
  /// Las [tareasRealizadas] ya no son el servicio: solo ponen al día el
  /// calendario de mantenimiento del cliente (`mantenimientos` y
  /// `historial_mantenimientos`). Si alguna no se puede poner al día, el
  /// servicio YA quedó registrado y no se deshace ni se repite: se devuelve
  /// cuántas fallaron para que la pantalla lo avise. Repetir el cierre por un
  /// fallo aquí duplicaría el servicio.
  ///
  /// [tipoServicio] es el título con que sale en el historial; sin él, los
  /// nombres de las tareas marcadas, y sin tareas, «Servicio General».
  Future<int> tallerCerrarServicio({
    required String vehiculoId,
    required int nuevoKilometraje,
    required String tallerId,
    required String descripcion,
    double? costo,
    double? manoDeObra,
    List<Map<String, dynamic>>? materiales,
    XFile? receiptImage,
    Iterable<String> tareasRealizadas = const [],
    String? tipoServicio,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final tareas = tareasRealizadas
          .map((id) => maintenanceTasks.where((t) => t.id == id).firstOrNull)
          .whereType<MaintenanceTask>()
          .toList();
      final titulo = (tipoServicio != null && tipoServicio.trim().isNotEmpty)
          ? tipoServicio.trim()
          : tareas.isNotEmpty
          ? tareas.map((t) => t.nombre).join(', ')
          : 'Servicio General';

      Reference? receiptRef;
      String? receiptUrl;
      if (receiptImage != null) {
        final metadataInfo = InvoiceUploadService.getFileMetadata(
          receiptImage.name,
        );
        final extension = metadataInfo['extension']!;
        final contentType = metadataInfo['contentType']!;

        receiptRef = _storage
            .ref()
            .child(StoragePaths.facturas)
            .child(vehiculoId)
            .child(InvoiceUploadService.nombreDeArchivo(extension));
        final bytes = await receiptImage.readAsBytes();
        final metadata = SettableMetadata(contentType: contentType);
        await receiptRef.putData(bytes, metadata);
        receiptUrl = await receiptRef.getDownloadURL();
      }

      try {
        // El kilometraje del vehículo lo pone al día el trigger
        // `requestReviewOnServiceComplete` (onCreate de `servicios`), con
        // Admin SDK: el taller puede no tener permiso para escribir el coche.
        await _firestore.collection(FirestoreCollections.servicios).add({
          'id_vehiculo': vehiculoId,
          'id_taller': tallerId,
          'tipo_servicio': titulo,
          'fecha': Timestamp.fromDate(now),
          'kilometraje_servicio': nuevoKilometraje,
          'descripcion': descripcion,
          'costo': costo,
          'mano_de_obra': manoDeObra,
          'materiales': materiales,
          'foto_factura_url': receiptUrl,
        });
      } catch (e) {
        // La factura ya está en Storage pero el documento que la referencia
        // no llegó a existir.
        if (receiptRef != null) {
          try {
            await receiptRef.delete();
          } catch (_) {
            // Si tampoco se puede borrar, no tapamos el error original.
          }
        }
        rethrow;
      }

      var fallidas = 0;
      for (final tarea in tareas) {
        try {
          await _firestore
              .collection(FirestoreCollections.mantenimientos)
              .doc(tarea.id)
              .update({
                'ultimo_km': nuevoKilometraje,
                'fecha_ultimo_servicio': Timestamp.fromDate(now),
              });
          await _firestore
              .collection(FirestoreCollections.historialMantenimientos)
              .add({
                'id_taller': tallerId,
                'id_vehiculo': vehiculoId,
                'id_tarea': tarea.id,
                'nombre_tarea': tarea.nombre,
                'kilometraje_registro': nuevoKilometraje,
                'fecha': Timestamp.fromDate(now),
                'descripcion': descripcion,
              });
          final i = _maintenanceTasks.indexWhere((t) => t.id == tarea.id);
          if (i != -1) {
            _maintenanceTasks[i] = MaintenanceTask(
              id: tarea.id,
              vehicleId: tarea.vehicleId,
              nombre: tarea.nombre,
              ultimoKm: nuevoKilometraje,
              fechaUltimoServicio: now,
              frecuenciaKm: tarea.frecuenciaKm,
              frecuenciaMeses: tarea.frecuenciaMeses,
            );
          }
        } catch (e) {
          fallidas++;
          debugPrint('No se pudo poner al día la tarea ${tarea.id}: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
      return fallidas;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<MaintenanceStatus> getVehicleOverallStatus(
    VehicleModel vehicle,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.mantenimientos)
          .where('id_vehiculo', isEqualTo: vehicle.idVehiculo)
          .get();

      final tasks = snapshot.docs
          .map((doc) => MaintenanceTask.fromMap(doc.data(), doc.id))
          .toList();

      if (tasks.isEmpty) return MaintenanceStatus.optimal;

      MaintenanceStatus worstStatus = MaintenanceStatus.optimal;
      for (final task in tasks) {
        final s = task.getStatus(vehicle.kilometrajeActual);
        if (s == MaintenanceStatus.critical) {
          worstStatus = MaintenanceStatus.critical;
          break;
        } else if (s == MaintenanceStatus.preventive) {
          worstStatus = MaintenanceStatus.preventive;
        }
      }
      return worstStatus;
    } catch (e) {
      return MaintenanceStatus.optimal;
    }
  }
}
