import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';

class AlertProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<AlertModel> _alerts = [];
  List<MaintenanceTask> _maintenanceTasks = [];
  bool _isLoading = false;
  String? _error;

  List<AlertModel> get alerts => _alerts;
  List<AlertModel> get activeAlerts => _alerts.where((a) => a.estado == 'Pendiente').toList();
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
          .collection('alertas')
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();

      _alerts = snapshot.docs
          .map((doc) => AlertModel.fromMap(doc.data(), doc.id))
          .toList();

      // 2. Obtener tareas de mantenimiento robustas
      final mSnapshot = await _firestore
          .collection('mantenimientos')
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();
      
      _maintenanceTasks = mSnapshot.docs
          .map((doc) => MaintenanceTask.fromMap(doc.data(), doc.id))
          .toList();

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
        _addOrUpdateLocalAlert(AlertModel(
          idAlerta: 'soat_${vehicle.idVehiculo}',
          idVehiculo: vehicle.idVehiculo,
          tipoAlerta: 'SOAT',
          titulo: 'Seguro por vencer',
          descripcion: daysToExpire < 0 
              ? 'Tu SOAT venció hace ${daysToExpire.abs()} días.'
              : 'Tu SOAT vence en $daysToExpire días.',
          fechaLimite: vehicle.vencimientoSoat,
          prioridad: daysToExpire < 0 ? AlertPriority.high : AlertPriority.medium,
        ));
      }
    }

    // --- 2. Alerta de Aceite ---
    // Buscamos el último registro de servicio de aceite
    final serviceSnapshot = await _firestore
        .collection('servicios')
        .where('id_vehiculo', isEqualTo: vehicle.idVehiculo)
        .where('tipo_servicio', isEqualTo: 'Cambio de Aceite')
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();

    int ultimoKm = 0;
    if (serviceSnapshot.docs.isNotEmpty) {
      final lastService = ServiceRecordModel.fromMap(
        serviceSnapshot.docs.first.data(), 
        serviceSnapshot.docs.first.id
      );
      ultimoKm = lastService.kilometrajeServicio ?? 0;
    }

    // Si han pasado más de 5000km (o lo configurado)
    final kmDiff = vehicle.kilometrajeActual - ultimoKm;
    if (kmDiff >= 4500) {
      _addOrUpdateLocalAlert(AlertModel(
        idAlerta: 'aceite_${vehicle.idVehiculo}',
        idVehiculo: vehicle.idVehiculo,
        tipoAlerta: 'Aceite',
        titulo: 'Cambio de Aceite',
        descripcion: 'Has recorrido $kmDiff km desde tu último cambio. Se recomienda realizarlo cada 5000 km.',
        prioridad: kmDiff >= 5000 ? AlertPriority.high : AlertPriority.medium,
        kilometrajeObjetivo: ultimoKm + 5000,
      ));
    }

    // --- 3. Presión de Llantas (Semanal) ---
    _addOrUpdateLocalAlert(AlertModel(
      idAlerta: 'llantas_${vehicle.idVehiculo}',
      idVehiculo: vehicle.idVehiculo,
      tipoAlerta: 'Llantas',
      titulo: 'Presión de Llantas',
      descripcion: 'Revisión semanal recomendada para mantener el consumo óptimo.',
      prioridad: AlertPriority.low,
      metadata: {'psi_recomendado': 32},
    ));

    // --- 4. Chequeos Rápidos (Fluidos, Batería, Luces) ---
    _addOrUpdateLocalAlert(AlertModel(
      idAlerta: 'fluidos_${vehicle.idVehiculo}',
      idVehiculo: vehicle.idVehiculo,
      tipoAlerta: 'Fluidos',
      titulo: 'Niveles de Fluidos',
      descripcion: 'Revisa refrigerante, líquido de frenos y limpiaparabrisas.',
      prioridad: AlertPriority.low,
    ));
        _addOrUpdateLocalAlert(AlertModel(
        idAlerta: 'luces_${vehicle.idVehiculo}',
        idVehiculo: vehicle.idVehiculo,
        tipoAlerta: 'Luces',
        titulo: 'Inspección de Luces',
        descripcion: 'Asegúrate de que todas las luces externas funcionen correctamente.',
        prioridad: AlertPriority.low,
      ));

      // --- 5. Integración con MaintenanceTasks Robustas ---
      for (var task in _maintenanceTasks) {
        final status = task.getStatus(vehicle.kilometrajeActual);
        if (status != MaintenanceStatus.optimal) {
          _addOrUpdateLocalAlert(AlertModel(
            idAlerta: 'task_${task.id}',
            idVehiculo: vehicle.idVehiculo,
            tipoAlerta: 'Mantenimiento',
            titulo: task.nombre,
            descripcion: status == MaintenanceStatus.critical 
                ? '¡CRÍTICO! Límite de ${task.nombre} superado.'
                : 'Mantenimiento preventivo de ${task.nombre} próximo.',
            prioridad: status == MaintenanceStatus.critical ? AlertPriority.high : AlertPriority.medium,
            fechaLimite: DateTime.now().add(const Duration(days: 15)), // Aproximado para la UI
          ));
        }
      }
    }

  void _addOrUpdateLocalAlert(AlertModel alert) {
    final index = _alerts.indexWhere((AlertModel a) => a.idAlerta == alert.idAlerta);
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
        
        if (!['soat_', 'aceite_', 'llantas_', 'fluidos_', 'luces_', 'task_'].any((p) => alertId.startsWith(p))) {
          await _firestore.collection('alertas').doc(alertId).update({'estado': 'Completada'});
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
    {'nombre': 'Cambio de Aceite', 'frecuencia_km': 5000, 'frecuencia_meses': 6},
    {'nombre': 'Filtro de Aire', 'frecuencia_km': 10000, 'frecuencia_meses': 12},
    {'nombre': 'Filtro de Aceite', 'frecuencia_km': 5000, 'frecuencia_meses': 6},
    {'nombre': 'Pastillas de Freno', 'frecuencia_km': 20000, 'frecuencia_meses': 24},
    {'nombre': 'Rotación de Llantas', 'frecuencia_km': 10000, 'frecuencia_meses': 12},
    {'nombre': 'Revisión de Frenos', 'frecuencia_km': 15000, 'frecuencia_meses': 18},
    {'nombre': 'Cambio de Refrigerante', 'frecuencia_km': 40000, 'frecuencia_meses': 24},
    {'nombre': 'Bujías', 'frecuencia_km': 30000, 'frecuencia_meses': 24},
  ];

  Future<void> createDefaultTasks(String vehicleId, int currentKm) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      for (var taskData in _defaultTasks) {
        final docRef = _firestore.collection('mantenimientos').doc();
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

  // --- LÓGICA DE TALLER ---
  
  Future<void> tallerUpdateService({
    required String taskId,
    required int nuevoKilometraje,
    required String tallerId,
    required String descripcion,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      
      // 1. Actualizar la tarea de mantenimiento principal
      await _firestore.collection('mantenimientos').doc(taskId).update({
        'ultimo_km': nuevoKilometraje,
        'fecha_ultimo_servicio': Timestamp.fromDate(now),
      });

      // 2. Obtener info de la tarea
      final taskIndex = _maintenanceTasks.indexWhere((t) => t.id == taskId);
      final task = taskIndex != -1 ? _maintenanceTasks[taskIndex] : null;
      final vehicleId = task?.vehicleId ?? 'desconocido';

      // 3. Registrar en colección servicios (tabla Servicios del esquema)
      await _firestore.collection('servicios').add({
        'id_vehiculo': vehicleId,
        'id_taller': tallerId,
        'tipo_servicio': task?.nombre ?? 'Servicio General',
        'fecha': Timestamp.fromDate(now),
        'kilometraje_servicio': nuevoKilometraje,
        'descripcion': descripcion,
        'costo': null,
        'foto_factura_url': null,
      });

      // 4. Registrar en historial_mantenimientos
      await _firestore.collection('historial_mantenimientos').add({
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
        final vehicleRef = _firestore.collection('vehiculos').doc(vehicleId);
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
}
