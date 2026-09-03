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
      _error = e.toString();
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
            titulo: 'Seguro por vencer',
            descripcion: daysToExpire < 0
                ? 'Tu SOAT venció hace ${daysToExpire.abs()} días.'
                : 'Tu SOAT vence en $daysToExpire días.',
            fechaLimite: vehicle.vencimientoSoat,
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
        metadata: {'psi_recomendado': 32},
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
      _error = e.toString();
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
            .child('${DateTime.now().millisecondsSinceEpoch}$extension');
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
      _error = e.toString();
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
      _error = e.toString();
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
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> tallerUpdateService({
    required String taskId,
    required int nuevoKilometraje,
    required String tallerId,
    required String descripcion,
    double? costo,
    double? manoDeObra,
    List<Map<String, dynamic>>? materiales,
    XFile? receiptImage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();

      // 1. Actualizar la tarea de mantenimiento principal
      await _firestore
          .collection(FirestoreCollections.mantenimientos)
          .doc(taskId)
          .update({
            'ultimo_km': nuevoKilometraje,
            'fecha_ultimo_servicio': Timestamp.fromDate(now),
          });

      // 2. Obtener info de la tarea
      final taskIndex = _maintenanceTasks.indexWhere((t) => t.id == taskId);
      final task = taskIndex != -1 ? _maintenanceTasks[taskIndex] : null;
      final vehicleId = task?.vehicleId ?? 'desconocido';

      String? receiptUrl;
      if (receiptImage != null) {
        final metadataInfo = InvoiceUploadService.getFileMetadata(
          receiptImage.name,
        );
        final extension = metadataInfo['extension']!;
        final contentType = metadataInfo['contentType']!;

        final ref = _storage
            .ref()
            .child(StoragePaths.facturas)
            .child(vehicleId)
            .child('${DateTime.now().millisecondsSinceEpoch}$extension');
        final bytes = await receiptImage.readAsBytes();
        final metadata = SettableMetadata(contentType: contentType);
        await ref.putData(bytes, metadata);
        receiptUrl = await ref.getDownloadURL();
      }

      // 3. Registrar en colección servicios (tabla Servicios del esquema)
      await _firestore.collection(FirestoreCollections.servicios).add({
        'id_vehiculo': vehicleId,
        'id_taller': tallerId,
        'tipo_servicio': task?.nombre ?? 'Servicio General',
        'fecha': Timestamp.fromDate(now),
        'kilometraje_servicio': nuevoKilometraje,
        'descripcion': descripcion,
        'costo': costo,
        'mano_de_obra': manoDeObra,
        'materiales': materiales,
        'foto_factura_url': receiptUrl,
      });

      // 4. Registrar en historial_mantenimientos
      await _firestore
          .collection(FirestoreCollections.historialMantenimientos)
          .add({
            'id_taller': tallerId,
            'id_vehiculo': vehicleId,
            'id_tarea': taskId,
            'nombre_tarea': task?.nombre ?? 'Servicio General',
            'kilometraje_registro': nuevoKilometraje,
            'fecha': Timestamp.fromDate(now),
            'descripcion': descripcion,
          });

      // 5. El kilometraje del vehículo lo actualiza la Cloud Function
      // requestReviewOnServiceComplete (trigger onCreate de 'servicios'),
      // que corre con privilegios de Admin SDK justo después del paso 3.
      // Evita que el cliente necesite leer/escribir el vehículo aquí, lo
      // cual podría chocar con la propagación del vínculo taller-vehículo
      // en la primera visita de un cliente nuevo.

      // 6. Actualizar la tarea local
      if (taskIndex != -1) {
        _maintenanceTasks[taskIndex] = MaintenanceTask(
          id: task!.id,
          vehicleId: task.vehicleId,
          nombre: task.nombre,
          ultimoKm: nuevoKilometraje,
          fechaUltimoServicio: now,
          frecuenciaKm: task.frecuenciaKm,
          frecuenciaMeses: task.frecuenciaMeses,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Registra un servicio cerrado por el taller cuando el vehiculo NO tiene
  /// ninguna tarea de mantenimiento configurada.
  ///
  /// `tallerUpdateService` escribe una vez POR TAREA marcada, asi que con la
  /// lista de tareas vacia no escribia nada en absoluto: la pantalla decia
  /// "Servicio registrado exitosamente" y no quedaba rastro ni en el
  /// historial del taller (`servicios` filtrado por `id_taller`) ni en el del
  /// propietario (`servicios` filtrado por `id_vehiculo`), y el trigger
  /// `requestReviewOnServiceComplete` — que es quien actualiza el kilometraje
  /// del vehiculo y pide la resena — nunca llegaba a dispararse.
  ///
  /// No toca `mantenimientos` (no hay tarea que poner al dia) ni
  /// `historial_mantenimientos` (esa coleccion se indexa por `id_tarea` y hoy
  /// no la lee nadie en la app). El documento de `servicios` lleva los mismos
  /// campos que el de `tallerUpdateService`, para que las dos rutas produzcan
  /// registros indistinguibles al leerlos.
  Future<void> tallerRegistrarServicioSinTarea({
    required String vehiculoId,
    required int nuevoKilometraje,
    required String tallerId,
    required String descripcion,
    double? costo,
    double? manoDeObra,
    List<Map<String, dynamic>>? materiales,
    XFile? receiptImage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();

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
            .child('${DateTime.now().millisecondsSinceEpoch}$extension');
        final bytes = await receiptImage.readAsBytes();
        final metadata = SettableMetadata(contentType: contentType);
        await receiptRef.putData(bytes, metadata);
        receiptUrl = await receiptRef.getDownloadURL();
      }

      try {
        await _firestore.collection(FirestoreCollections.servicios).add({
          'id_vehiculo': vehiculoId,
          'id_taller': tallerId,
          'tipo_servicio': 'Servicio General',
          'fecha': Timestamp.fromDate(now),
          'kilometraje_servicio': nuevoKilometraje,
          'descripcion': descripcion,
          'costo': costo,
          'mano_de_obra': manoDeObra,
          'materiales': materiales,
          'foto_factura_url': receiptUrl,
        });
      } catch (e) {
        // Misma limpieza que `userCompleteTask`: la factura ya esta en
        // Storage pero el documento que la referencia no llego a existir.
        if (receiptRef != null) {
          try {
            await receiptRef.delete();
          } catch (_) {
            // Si tampoco se puede borrar, no tapamos el error original.
          }
        }
        rethrow;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
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
