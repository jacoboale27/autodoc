import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';

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

  static const List<Map<String, dynamic>> _defaultTasks = [
    {
      'nombre': 'Cambio de Aceite',
      'frecuencia_km': 5000,
      'frecuencia_meses': 6,
    },
    {
      'nombre': 'Filtro de Aire',
      'frecuencia_km': 10000,
      'frecuencia_meses': 12,
    },
    {
      'nombre': 'Filtro de Aceite',
      'frecuencia_km': 5000,
      'frecuencia_meses': 6,
    },
    {
      'nombre': 'Pastillas de Freno',
      'frecuencia_km': 20000,
      'frecuencia_meses': 24,
    },
    {
      'nombre': 'Rotación de Llantas',
      'frecuencia_km': 10000,
      'frecuencia_meses': 12,
    },
    {
      'nombre': 'Revisión de Frenos',
      'frecuencia_km': 15000,
      'frecuencia_meses': 18,
    },
    {
      'nombre': 'Cambio de Refrigerante',
      'frecuencia_km': 40000,
      'frecuencia_meses': 24,
    },
    {'nombre': 'Bujías', 'frecuencia_km': 30000, 'frecuencia_meses': 24},
  ];

  Future<void> createDefaultTasks(String vehicleId, int currentKm) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      for (var taskData in _defaultTasks) {
        final docRef = _firestore
            .collection(FirestoreCollections.mantenimientos)
            .doc();
        batch.set(docRef, {
          'id_vehiculo': vehicleId,
          'nombre': taskData['nombre'],
          'ultimo_km': currentKm,
          'fecha_ultimo_servicio': Timestamp.fromDate(now),
          'frecuencia_km': taskData['frecuencia_km'],
          'frecuencia_meses': taskData['frecuencia_meses'],
        });
      }

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
      if (task != null) {
        _maintenanceTasks[taskIndex] = MaintenanceTask(
          id: task.id,
          vehicleId: task.vehicleId,
          nombre: task.nombre,
          ultimoKm: currentKm,
          fechaUltimoServicio: now,
          frecuenciaKm: task.frecuenciaKm,
          frecuenciaMeses: task.frecuenciaMeses,
        );

        if (receiptImage != null) {
          final metadataInfo = InvoiceUploadService.getFileMetadata(
            receiptImage.name,
          );
          final extension = metadataInfo['extension']!;
          final contentType = metadataInfo['contentType']!;

          final ref = _storage
              .ref()
              .child(StoragePaths.facturas)
              .child(task.vehicleId)
              .child('${DateTime.now().millisecondsSinceEpoch}$extension');
          final bytes = await receiptImage.readAsBytes();
          final metadata = SettableMetadata(contentType: contentType);
          await ref.putData(bytes, metadata);
          receiptUrl = await ref.getDownloadURL();
        }

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

      // 5. Actualizar el kilometraje del vehículo si es mayor
      if (task != null) {
        final vehicleRef = _firestore
            .collection(FirestoreCollections.vehiculos)
            .doc(vehicleId);
        final vDoc = await vehicleRef.get();
        if (vDoc.exists) {
          int currentKm = vDoc.data()?['kilometraje_actual'] ?? 0;
          if (nuevoKilometraje > currentKm) {
            await vehicleRef.update({'kilometraje_actual': nuevoKilometraje});
          }
        }
      }

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
