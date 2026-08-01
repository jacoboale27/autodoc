# Panel del Mecánico/Talleres al 100% — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar el Panel del Mecánico/Taller de AutoDoc del 95.5% al 100%: estados de reparación tipo Kanban con notificación automática al dueño, gestión de sub-cuentas de empleados del taller, y catálogo rápido de servicios/repuestos reutilizable en la factura.

**Architecture:** Ninguna de las tres features existe hoy — se construyen desde cero siguiendo el patrón Clean Architecture + Provider del resto del proyecto. El estado de reparación se modela como una colección nueva `reparaciones` (documento vivo mientras el vehículo está en el taller, distinto de `servicios` que hoy solo registra el histórico de un servicio ya *terminado*). Las sub-cuentas de empleados requieren crear cuentas reales de Firebase Auth (no solo documentos de Firestore) para que cada mecánico tenga su propio login — esto exige una Cloud Function `callable` con Admin SDK, porque el SDK cliente no puede crear otro usuario de Auth sin cerrar la sesión actual. El catálogo de servicios es una subcolección simple por taller, consumida como autocompletado en el flujo de factura ya existente (`initiate_service_screen.dart`).

**Tech Stack:** Flutter, Provider, Cloud Firestore, Cloud Functions (Node.js, Admin SDK `createUser`), `firebase_auth`.

## Global Constraints

- Campos Firestore en snake_case español, modelos Dart en camelCase con `fromMap`/`toMap` manuales.
- Métodos y nombres en español, siguiendo el proyecto (`iniciarReparacion`, `cambiarEstadoReparacion`).
- Providers: patrón `_isLoading=true; notifyListeners(); try{...}catch(e){_error=e.toString(); rethrow;} finally notifyListeners()` (patrón confirmado en `AlertProvider.tallerUpdateService`).
- El envío real de push SIEMPRE ocurre en Cloud Functions vía `messaging.send()` + `writeNotification()`; el cliente solo registra el token FCM (`PushNotificationService.updateUserToken`). Ninguna nueva feature debe intentar enviar push desde el cliente.
- Nuevas colecciones deben añadirse a `lib/core/constants/firestore_collections.dart` como constantes (`FirestoreCollections.xxx`), nunca strings literales sueltos.
- Toda pantalla nueva de mecánico debe usar `MechanicSidebar` (`lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart`) para navegación consistente, y registrarse en `lib/core/router/app_router.dart`.
- No crear un modelo "Factura/Invoice" nuevo — el catálogo alimenta la lista `_materiales` (`List<Map<String, dynamic>>` con claves `nombre`, `cantidad`, `precioUnitario`) que ya consume `AlertProvider.tallerUpdateService`.

---

## File Structure

- `lib/core/models/reparacion_model.dart` — **nuevo**, ticket de reparación con estado Kanban.
- `lib/features/mechanic/data/repositories/reparacion_repository.dart` — **nuevo**, CRUD + stream de `reparaciones`.
- `lib/features/mechanic/presentation/providers/reparacion_provider.dart` — **nuevo**.
- `lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart` — **nuevo**, tablero Kanban.
- `lib/features/mechanic/presentation/widgets/reparacion_card.dart` — **nuevo**, tarjeta de vehículo en el Kanban.
- `functions/index.js` — añadir trigger `notifyOnReparacionStatusChange` y callable `crearEmpleadoTaller`.
- `firestore.rules` — reglas para `reparaciones` y subcolección `talleres/{id}/empleados`.
- `lib/core/models/empleado_model.dart` — **nuevo**.
- `lib/features/mechanic/data/repositories/empleado_repository.dart` — **nuevo**.
- `lib/features/mechanic/presentation/providers/empleado_provider.dart` — **nuevo**.
- `lib/features/mechanic/presentation/pages/empleados_screen.dart` — **nuevo**.
- `lib/core/models/catalogo_item_model.dart` — **nuevo**.
- `lib/features/mechanic/data/repositories/catalogo_repository.dart` — **nuevo**.
- `lib/features/mechanic/presentation/providers/catalogo_provider.dart` — **nuevo**.
- `lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart` — **nuevo**.
- `lib/features/mechanic/presentation/pages/initiate_service_screen.dart` — modificar para permitir agregar desde catálogo con un clic.
- `lib/core/constants/firestore_collections.dart` — añadir `reparaciones`.

---

## Parte A — Estados de Reparación Kanban

### Task 1: `ReparacionModel`

**Files:**
- Create: `lib/core/models/reparacion_model.dart`
- Test: `test/core/models/reparacion_model_test.dart`

**Interfaces:**
- Produces: `ReparacionModel` con `idReparacion, idVehiculo, idTaller, idPropietario, placa, estado (String), historialEstados (List<Map<String,dynamic>>), fechaCreacion, fechaActualizacion`.
- Produces: `const List<String> estadosReparacion = ['recibido', 'en_revision', 'esperando_repuestos', 'listo_para_entrega']` (orden fijo del Kanban).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/models/reparacion_model_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/reparacion_model.dart';

void main() {
  test('fromMap/toMap conservan estado e historial', () {
    final ahora = DateTime(2026, 7, 31, 9, 0);
    final model = ReparacionModel(
      idReparacion: 'r1',
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P123-456',
      estado: 'en_revision',
      historialEstados: [
        {'estado': 'recibido', 'timestamp': ahora},
      ],
      fechaCreacion: ahora,
      fechaActualizacion: ahora,
    );

    final map = model.toMap();
    expect(map['estado'], 'en_revision');
    expect(map['id_vehiculo'], 'v1');

    final restored = ReparacionModel.fromMap(map, 'r1');
    expect(restored.estado, 'en_revision');
    expect(restored.historialEstados.length, 1);
  });

  test('estadosReparacion define el orden fijo del Kanban', () {
    expect(estadosReparacion, [
      'recibido',
      'en_revision',
      'esperando_repuestos',
      'listo_para_entrega',
    ]);
  });
}
```

- [ ] **Step 2: Ejecutar test y verificar que falla**

Run: `flutter test test/core/models/reparacion_model_test.dart`
Expected: FAIL — `reparacion_model.dart` no existe.

- [ ] **Step 3: Implementar el modelo**

```dart
// lib/core/models/reparacion_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> estadosReparacion = [
  'recibido',
  'en_revision',
  'esperando_repuestos',
  'listo_para_entrega',
];

class ReparacionModel {
  final String idReparacion;
  final String idVehiculo;
  final String idTaller;
  final String idPropietario;
  final String placa;
  final String estado;
  final List<Map<String, dynamic>> historialEstados;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  ReparacionModel({
    required this.idReparacion,
    required this.idVehiculo,
    required this.idTaller,
    required this.idPropietario,
    required this.placa,
    this.estado = 'recibido',
    this.historialEstados = const [],
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_vehiculo': idVehiculo,
      'id_taller': idTaller,
      'id_propietario': idPropietario,
      'placa': placa,
      'estado': estado,
      'historial_estados': historialEstados
          .map((h) => {
                'estado': h['estado'],
                'timestamp': h['timestamp'] is DateTime
                    ? Timestamp.fromDate(h['timestamp'] as DateTime)
                    : h['timestamp'],
              })
          .toList(),
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'fecha_actualizacion': Timestamp.fromDate(fechaActualizacion),
    };
  }

  factory ReparacionModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

    return ReparacionModel(
      idReparacion: documentId,
      idVehiculo: (map['id_vehiculo'] ?? '').toString(),
      idTaller: (map['id_taller'] ?? '').toString(),
      idPropietario: (map['id_propietario'] ?? '').toString(),
      placa: (map['placa'] ?? '').toString(),
      estado: (map['estado'] ?? 'recibido').toString(),
      historialEstados: (map['historial_estados'] as List<dynamic>? ?? [])
          .map((h) => {
                'estado': h['estado'],
                'timestamp': h['timestamp'] is Timestamp
                    ? (h['timestamp'] as Timestamp).toDate()
                    : h['timestamp'],
              })
          .toList(),
      fechaCreacion: parseDate(map['fecha_creacion']),
      fechaActualizacion: parseDate(map['fecha_actualizacion']),
    );
  }
}
```

- [ ] **Step 4: Ejecutar test y verificar que pasa**

Run: `flutter test test/core/models/reparacion_model_test.dart`
Expected: PASS

- [ ] **Step 5: Añadir colección a `firestore_collections.dart`**

Añade `static const String reparaciones = 'reparaciones';` a `lib/core/constants/firestore_collections.dart`.

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/reparacion_model.dart lib/core/constants/firestore_collections.dart test/core/models/reparacion_model_test.dart
git commit -m "feat(mechanic): add ReparacionModel for kanban repair states"
```

---

### Task 2: `ReparacionRepository` — crear ticket y cambiar de estado

**Files:**
- Create: `lib/features/mechanic/data/repositories/reparacion_repository.dart`
- Test: `test/features/mechanic/data/repositories/reparacion_repository_test.dart`

**Interfaces:**
- Consumes: `ReparacionModel`, `estadosReparacion` (Task 1).
- Produces:
  - `Future<String> iniciarReparacion({required String idVehiculo, required String idTaller, required String idPropietario, required String placa})` → devuelve `idReparacion`.
  - `Future<void> cambiarEstado({required String idReparacion, required String nuevoEstado})` — valida que `nuevoEstado` esté en `estadosReparacion` y sea un avance válido (no permite retroceder saltando pasos hacia atrás arbitrariamente, pero sí permite avanzar directo si el mecánico se saltó un paso).
  - `Stream<List<ReparacionModel>> watchReparacionesActivas(String idTaller)` — reparaciones del taller cuyo `estado != 'entregado'` (o simplemente todas las de `estadosReparacion`, ya que `listo_para_entrega` es el último estado del Kanban definido en el spec).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/mechanic/data/repositories/reparacion_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

void main() {
  test('iniciarReparacion crea documento con estado recibido', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);

    final id = await repo.iniciarReparacion(
      idVehiculo: 'v1', idTaller: 't1', idPropietario: 'p1', placa: 'P123-456',
    );

    final doc = await firestore.collection(FirestoreCollections.reparaciones).doc(id).get();
    expect(doc.data()!['estado'], 'recibido');
  });

  test('cambiarEstado actualiza estado y agrega entrada al historial', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);
    final id = await repo.iniciarReparacion(
      idVehiculo: 'v1', idTaller: 't1', idPropietario: 'p1', placa: 'P123-456',
    );

    await repo.cambiarEstado(idReparacion: id, nuevoEstado: 'en_revision');

    final doc = await firestore.collection(FirestoreCollections.reparaciones).doc(id).get();
    expect(doc.data()!['estado'], 'en_revision');
    expect((doc.data()!['historial_estados'] as List).length, 2);
  });

  test('cambiarEstado rechaza un estado fuera de la lista permitida', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);
    final id = await repo.iniciarReparacion(
      idVehiculo: 'v1', idTaller: 't1', idPropietario: 'p1', placa: 'P123-456',
    );

    expect(
      () => repo.cambiarEstado(idReparacion: id, nuevoEstado: 'inventado'),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Ejecutar test y verificar que falla**

Run: `flutter test test/features/mechanic/data/repositories/reparacion_repository_test.dart`
Expected: FAIL — `reparacion_repository.dart` no existe.

- [ ] **Step 3: Implementar el repositorio**

```dart
// lib/features/mechanic/data/repositories/reparacion_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/reparacion_model.dart';

class ReparacionRepository {
  final FirebaseFirestore _firestore;

  ReparacionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> iniciarReparacion({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    final ahora = DateTime.now();
    final docRef = _firestore.collection(FirestoreCollections.reparaciones).doc();
    final model = ReparacionModel(
      idReparacion: docRef.id,
      idVehiculo: idVehiculo,
      idTaller: idTaller,
      idPropietario: idPropietario,
      placa: placa,
      estado: 'recibido',
      historialEstados: [
        {'estado': 'recibido', 'timestamp': ahora},
      ],
      fechaCreacion: ahora,
      fechaActualizacion: ahora,
    );
    await docRef.set(model.toMap());
    return docRef.id;
  }

  Future<void> cambiarEstado({
    required String idReparacion,
    required String nuevoEstado,
  }) async {
    if (!estadosReparacion.contains(nuevoEstado)) {
      throw ArgumentError('Estado inválido: $nuevoEstado');
    }
    final docRef = _firestore.collection(FirestoreCollections.reparaciones).doc(idReparacion);
    final ahora = DateTime.now();

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() as Map<String, dynamic>;
      final historial = List<Map<String, dynamic>>.from(
        (data['historial_estados'] as List).map((h) => Map<String, dynamic>.from(h as Map)),
      )..add({'estado': nuevoEstado, 'timestamp': Timestamp.fromDate(ahora)});

      tx.update(docRef, {
        'estado': nuevoEstado,
        'historial_estados': historial,
        'fecha_actualizacion': Timestamp.fromDate(ahora),
      });
    });
  }

  Stream<List<ReparacionModel>> watchReparacionesActivas(String idTaller) {
    return _firestore
        .collection(FirestoreCollections.reparaciones)
        .where('id_taller', isEqualTo: idTaller)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReparacionModel.fromMap(d.data(), d.id)).toList());
  }
}
```

- [ ] **Step 4: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/mechanic/data/repositories/reparacion_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/mechanic/data/repositories/reparacion_repository.dart test/features/mechanic/data/repositories/reparacion_repository_test.dart
git commit -m "feat(mechanic): add ReparacionRepository with state-machine transitions"
```

---

### Task 3: `ReparacionProvider`

**Files:**
- Create: `lib/features/mechanic/presentation/providers/reparacion_provider.dart`
- Test: `test/features/mechanic/presentation/providers/reparacion_provider_test.dart`

**Interfaces:**
- Consumes: `ReparacionRepository` (Task 2).
- Produces: `ReparacionProvider extends ChangeNotifier` con `List<ReparacionModel> reparaciones`, `bool isLoading`, `String? error`, `void watchTaller(String idTaller)`, `Future<void> iniciar(...)`, `Future<void> cambiarEstado(String idReparacion, String nuevoEstado)`.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/providers/reparacion_provider_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

void main() {
  test('watchTaller puebla reparaciones desde el repositorio', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);
    await repo.iniciarReparacion(idVehiculo: 'v1', idTaller: 't1', idPropietario: 'p1', placa: 'P1');

    final provider = ReparacionProvider(repository: repo);
    provider.watchTaller('t1');
    await Future.delayed(Duration.zero);

    expect(provider.reparaciones.length, 1);
  });

  test('cambiarEstado delega en el repositorio y no lanza si es válido', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);
    final id = await repo.iniciarReparacion(idVehiculo: 'v1', idTaller: 't1', idPropietario: 'p1', placa: 'P1');

    final provider = ReparacionProvider(repository: repo);
    await provider.cambiarEstado(id, 'en_revision');

    expect(provider.error, isNull);
  });
}
```

- [ ] **Step 2: Ejecutar test y verificar que falla**

Run: `flutter test test/features/mechanic/presentation/providers/reparacion_provider_test.dart`
Expected: FAIL — `reparacion_provider.dart` no existe.

- [ ] **Step 3: Implementar el provider**

```dart
// lib/features/mechanic/presentation/providers/reparacion_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';

class ReparacionProvider extends ChangeNotifier {
  final ReparacionRepository _repository;
  StreamSubscription<List<ReparacionModel>>? _sub;

  ReparacionProvider({ReparacionRepository? repository})
      : _repository = repository ?? ReparacionRepository();

  List<ReparacionModel> _reparaciones = [];
  List<ReparacionModel> get reparaciones => _reparaciones;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void watchTaller(String idTaller) {
    _sub?.cancel();
    _isLoading = true;
    notifyListeners();
    _sub = _repository.watchReparacionesActivas(idTaller).listen((data) {
      _reparaciones = data;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<String?> iniciar({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final id = await _repository.iniciarReparacion(
        idVehiculo: idVehiculo, idTaller: idTaller, idPropietario: idPropietario, placa: placa,
      );
      _error = null;
      return id;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cambiarEstado(String idReparacion, String nuevoEstado) async {
    try {
      await _repository.cambiarEstado(idReparacion: idReparacion, nuevoEstado: nuevoEstado);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/mechanic/presentation/providers/reparacion_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/mechanic/presentation/providers/reparacion_provider.dart test/features/mechanic/presentation/providers/reparacion_provider_test.dart
git commit -m "feat(mechanic): add ReparacionProvider"
```

---

### Task 4: Pantalla Kanban (`ReparacionesKanbanScreen`)

**Files:**
- Create: `lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart`
- Create: `lib/features/mechanic/presentation/widgets/reparacion_card.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart`
- Test: `test/features/mechanic/presentation/pages/reparaciones_kanban_screen_test.dart`

**Interfaces:**
- Consumes: `ReparacionProvider` (Task 3), `estadosReparacion` (Task 1).

- [ ] **Step 1: Leer `mechanic_dashboard_screen.dart` y `mechanic_sidebar.dart` completos**

Confirma el patrón exacto de `Provider.of`/`Consumer`, el `AppColors`/`Responsive` usados, y cómo `mechanic_sidebar.dart` registra los ítems de navegación existentes, para añadir "Reparaciones" con el mismo estilo.

- [ ] **Step 2: Escribir el test que falla (widget test básico de render con 4 columnas)**

```dart
// test/features/mechanic/presentation/pages/reparaciones_kanban_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  testWidgets('ReparacionesKanbanScreen renderiza las 4 columnas de estado', (tester) async {
    final repo = ReparacionRepository(firestore: FakeFirebaseFirestore());
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => ReparacionProvider(repository: repo))],
        child: const MaterialApp(home: ReparacionesKanbanScreen(idTaller: 't1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recibido'), findsOneWidget);
    expect(find.text('En Revisión'), findsOneWidget);
    expect(find.text('Esperando Repuestos'), findsOneWidget);
    expect(find.text('Listo para Entregar'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `flutter test test/features/mechanic/presentation/pages/reparaciones_kanban_screen_test.dart`
Expected: FAIL — `reparaciones_kanban_screen.dart` no existe.

- [ ] **Step 4: Implementar `ReparacionCard`**

```dart
// lib/features/mechanic/presentation/widgets/reparacion_card.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';

class ReparacionCard extends StatelessWidget {
  final ReparacionModel reparacion;
  final VoidCallback? onAvanzar;
  final bool esUltimoEstado;

  const ReparacionCard({
    super.key,
    required this.reparacion,
    this.onAvanzar,
    this.esUltimoEstado = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reparacion.placa, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (!esUltimoEstado)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAvanzar,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Avanzar'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implementar `ReparacionesKanbanScreen`**

```dart
// lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
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
  State<ReparacionesKanbanScreen> createState() => _ReparacionesKanbanScreenState();
}

class _ReparacionesKanbanScreenState extends State<ReparacionesKanbanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReparacionProvider>().watchTaller(widget.idTaller);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const MechanicSidebar(currentRoute: '/mechanic/reparaciones'),
          Expanded(
            child: Consumer<ReparacionProvider>(
              builder: (context, provider, _) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < estadosReparacion.length; i++)
                        _buildColumna(context, provider, estadosReparacion[i], i),
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

  Widget _buildColumna(BuildContext context, ReparacionProvider provider, String estado, int index) {
    final items = provider.reparaciones.where((r) => r.estado == estado).toList();
    final esUltimo = index == estadosReparacion.length - 1;
    final siguienteEstado = esUltimo ? null : estadosReparacion[index + 1];

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_etiquetasEstado[estado]!, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ReparacionCard(
                reparacion: r,
                esUltimoEstado: esUltimo,
                onAvanzar: siguienteEstado == null
                    ? null
                    : () => provider.cambiarEstado(r.idReparacion, siguienteEstado),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/mechanic/presentation/pages/reparaciones_kanban_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Registrar la ruta y el ítem de sidebar**

En `lib/core/router/app_router.dart`, añade `GoRoute(path: '/mechanic/reparaciones', pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: ReparacionesKanbanScreen(idTaller: state.extra as String? ?? '')))`, siguiendo el patrón de las demás rutas de mecánico. En `mechanic_sidebar.dart`, añade el ítem de navegación "Reparaciones" con un ícono (`Icons.dashboard_customize` o similar) junto a los ítems existentes.

- [ ] **Step 8: Conectar la creación del ticket al iniciar un servicio**

En `initiate_service_screen.dart`, en el método que hoy arranca el flujo de servicio (antes de que el mecánico complete tareas/materiales), añade una llamada a `context.read<ReparacionProvider>().iniciar(idVehiculo: ..., idTaller: ..., idPropietario: vehiculo.idPropietario, placa: vehiculo.placa)` para que el ticket Kanban nazca en cuanto el mecánico recibe el vehículo. Guarda el `idReparacion` devuelto en el estado de la pantalla para poder marcarlo `listo_para_entrega` automáticamente cuando el mecánico finalice el servicio (`AlertProvider.tallerUpdateService` ya existente).

- [ ] **Step 9: Verificar manualmente**

Run: `flutter run -d chrome`, entra como mecánico, inicia un servicio desde `vehicle_search_screen`, navega a "Reparaciones", confirma que el vehículo aparece en la columna "Recibido" y que "Avanzar" lo mueve de columna en tiempo real.

- [ ] **Step 10: Commit**

```bash
git add lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart lib/features/mechanic/presentation/widgets/reparacion_card.dart lib/core/router/app_router.dart lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart lib/features/mechanic/presentation/pages/initiate_service_screen.dart test/features/mechanic/presentation/pages/reparaciones_kanban_screen_test.dart
git commit -m "feat(mechanic): add repair status kanban board"
```

---

### Task 5: Notificar al dueño en cada cambio de estado (Cloud Function)

**Files:**
- Modify: `functions/index.js`
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: `writeNotification()` (ya existe en `functions/index.js`).
- Produces: `exports.notifyOnReparacionStatusChange` — trigger `firestore.document('reparaciones/{reparacionId}').onUpdate`.

- [ ] **Step 1: Leer el trigger existente `notifyOnReservationStatusChange` completo**

Es el patrón más cercano (detecta cambio de campo `estado` en un `onUpdate` y notifica al dueño) — cópialo estructuralmente.

- [ ] **Step 2: Implementar el trigger**

```js
// functions/index.js — añadir junto a notifyOnReservationStatusChange
exports.notifyOnReparacionStatusChange = functions.firestore
  .document('reparaciones/{reparacionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.estado === after.estado) return null;

    const etiquetas = {
      recibido: 'Recibido',
      en_revision: 'En Revisión',
      esperando_repuestos: 'Esperando Repuestos',
      listo_para_entrega: 'Listo para Entregar',
    };

    const propietarioId = after.id_propietario;
    const usuarioSnap = await db.collection('usuarios').doc(propietarioId).get();
    const fcmToken = usuarioSnap.exists ? usuarioSnap.data().fcmToken : null;

    const titulo = 'Actualización de tu vehículo';
    const body = `${after.placa}: ${etiquetas[after.estado] || after.estado}`;

    if (fcmToken) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: { title: titulo, body },
          data: { type: 'reparacion', reparacionId: context.params.reparacionId },
        });
      } catch (err) {
        console.error('Error enviando push de reparación:', err);
      }
    }

    await writeNotification(propietarioId, {
      tipo: 'reparacion',
      titulo,
      body,
      deepLink: `/vehicle_profile/${after.id_vehiculo}`,
      metadata: { reparacionId: context.params.reparacionId, estado: after.estado },
    });

    return null;
  });
```

- [ ] **Step 3: Añadir reglas de Firestore para `reparaciones`**

En `firestore.rules`, añade (siguiendo el estilo de la sección de `reservas`):

```
match /reparaciones/{reparacionId} {
  allow read: if isAuthenticated() &&
    (resource.data.id_propietario == request.auth.uid ||
     resource.data.id_taller == request.auth.uid || isAdmin());
  allow create: if isAuthenticated() && request.resource.data.id_taller == request.auth.uid;
  allow update: if isAuthenticated() && resource.data.id_taller == request.auth.uid;
  allow delete: if isAdmin();
}
```

- [ ] **Step 4: Desplegar y probar en el emulador**

Run: `firebase emulators:start --only functions,firestore` (si hay emuladores configurados en `firebase.json`; si no, documentar que se prueba en el siguiente despliegue). Crea un documento de prueba en `reparaciones` y actualiza `estado` manualmente desde el emulador de Firestore UI, confirma en los logs de Functions que el trigger corre sin error.

- [ ] **Step 5: Commit**

```bash
git add functions/index.js firestore.rules
git commit -m "feat(mechanic): notify owner via push on repair status change"
```

---

## Parte B — Gestión de Empleados (Sub-cuentas)

### Task 6: `EmpleadoModel` y `EmpleadoRepository`

**Files:**
- Create: `lib/core/models/empleado_model.dart`
- Create: `lib/features/mechanic/data/repositories/empleado_repository.dart`
- Test: `test/core/models/empleado_model_test.dart`
- Test: `test/features/mechanic/data/repositories/empleado_repository_test.dart`

**Interfaces:**
- Produces: `EmpleadoModel` con `idEmpleado, idTallerPropietario, nombreCompleto, correo, telefono, activo (bool), fechaCreacion`.
- Produces: `EmpleadoRepository.crearRegistroEmpleado(...)` (solo el documento Firestore; la creación de la cuenta Auth vive en la Cloud Function del Task 7), `Stream<List<EmpleadoModel>> watchEmpleados(String idTallerPropietario)`, `Future<void> desactivarEmpleado(String idTallerPropietario, String idEmpleado)`.

- [ ] **Step 1: Escribir el test del modelo que falla**

```dart
// test/core/models/empleado_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/empleado_model.dart';

void main() {
  test('fromMap/toMap conservan activo por defecto en true', () {
    final model = EmpleadoModel(
      idEmpleado: 'e1',
      idTallerPropietario: 't1',
      nombreCompleto: 'Carlos Pérez',
      correo: 'carlos@example.com',
      telefono: '70000000',
      fechaCreacion: DateTime(2026, 7, 31),
    );

    expect(model.activo, isTrue);
    expect(model.toMap()['activo'], isTrue);

    final restored = EmpleadoModel.fromMap(model.toMap(), 'e1');
    expect(restored.nombreCompleto, 'Carlos Pérez');
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/core/models/empleado_model_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementar `EmpleadoModel`**

```dart
// lib/core/models/empleado_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EmpleadoModel {
  final String idEmpleado;
  final String idTallerPropietario;
  final String nombreCompleto;
  final String correo;
  final String? telefono;
  final bool activo;
  final DateTime fechaCreacion;

  EmpleadoModel({
    required this.idEmpleado,
    required this.idTallerPropietario,
    required this.nombreCompleto,
    required this.correo,
    this.telefono,
    this.activo = true,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
        'id_taller_propietario': idTallerPropietario,
        'nombre_completo': nombreCompleto,
        'correo': correo,
        if (telefono != null) 'telefono': telefono,
        'activo': activo,
        'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      };

  factory EmpleadoModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EmpleadoModel(
      idEmpleado: documentId,
      idTallerPropietario: (map['id_taller_propietario'] ?? '').toString(),
      nombreCompleto: (map['nombre_completo'] ?? '').toString(),
      correo: (map['correo'] ?? '').toString(),
      telefono: map['telefono']?.toString(),
      activo: map['activo'] as bool? ?? true,
      fechaCreacion: (map['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/core/models/empleado_model_test.dart`
Expected: PASS

- [ ] **Step 5: Escribir el test del repositorio que falla**

```dart
// test/features/mechanic/data/repositories/empleado_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';

void main() {
  test('watchEmpleados solo devuelve empleados del taller correspondiente', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmpleadoRepository(firestore: firestore);

    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e1')
        .set({'id_taller_propietario': 't1', 'nombre_completo': 'A', 'correo': 'a@x.com', 'activo': true});
    await firestore
        .collection('talleres')
        .doc('t2')
        .collection('empleados')
        .doc('e2')
        .set({'id_taller_propietario': 't2', 'nombre_completo': 'B', 'correo': 'b@x.com', 'activo': true});

    final empleados = await repo.watchEmpleados('t1').first;

    expect(empleados.length, 1);
    expect(empleados.first.nombreCompleto, 'A');
  });

  test('desactivarEmpleado marca activo=false', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmpleadoRepository(firestore: firestore);
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e1')
        .set({'id_taller_propietario': 't1', 'nombre_completo': 'A', 'correo': 'a@x.com', 'activo': true});

    await repo.desactivarEmpleado('t1', 'e1');

    final doc = await firestore.collection('talleres').doc('t1').collection('empleados').doc('e1').get();
    expect(doc.data()!['activo'], isFalse);
  });
}
```

- [ ] **Step 6: Ejecutar y verificar que falla**

Run: `flutter test test/features/mechanic/data/repositories/empleado_repository_test.dart`
Expected: FAIL — `empleado_repository.dart` no existe.

- [ ] **Step 7: Implementar el repositorio (subcolección `talleres/{id}/empleados`)**

```dart
// lib/features/mechanic/data/repositories/empleado_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/empleado_model.dart';

class EmpleadoRepository {
  final FirebaseFirestore _firestore;

  EmpleadoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _empleadosRef(String idTallerPropietario) =>
      _firestore.collection(FirestoreCollections.talleres).doc(idTallerPropietario).collection('empleados');

  Future<void> crearRegistroEmpleado(EmpleadoModel empleado) async {
    await _empleadosRef(empleado.idTallerPropietario).doc(empleado.idEmpleado).set(empleado.toMap());
  }

  Stream<List<EmpleadoModel>> watchEmpleados(String idTallerPropietario) {
    return _empleadosRef(idTallerPropietario)
        .snapshots()
        .map((snap) => snap.docs.map((d) => EmpleadoModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> desactivarEmpleado(String idTallerPropietario, String idEmpleado) async {
    await _empleadosRef(idTallerPropietario).doc(idEmpleado).update({'activo': false});
  }
}
```

Nota: `FirestoreCollections.talleres` ya existe (`'talleres'`); no requiere añadir constante nueva porque es una subcolección anidada bajo un documento existente.

- [ ] **Step 8: Ejecutar y verificar que pasa**

Run: `flutter test test/features/mechanic/data/repositories/empleado_repository_test.dart`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/core/models/empleado_model.dart lib/features/mechanic/data/repositories/empleado_repository.dart test/core/models/empleado_model_test.dart test/features/mechanic/data/repositories/empleado_repository_test.dart
git commit -m "feat(mechanic): add EmpleadoModel and repository for workshop sub-accounts"
```

---

### Task 7: Callable Cloud Function `crearEmpleadoTaller` (crea la cuenta de Auth real)

**Files:**
- Modify: `functions/index.js`
- Modify: `firestore.rules`

**Interfaces:**
- Produces: `exports.crearEmpleadoTaller` — `https.onCall`, request `{correo: string, password: string, nombreCompleto: string, telefono?: string}`, response `{idEmpleado: string}`.

- [ ] **Step 1: Leer un callable existente completo (`buscarVehiculoPorPlaca` o similar) para copiar el patrón de validación de `context.auth`**

Confirma cómo los callables existentes verifican `context.auth.uid` y lanzan `functions.https.HttpsError` en caso de error, para mantener el mismo estilo.

- [ ] **Step 2: Implementar el callable**

```js
// functions/index.js
exports.crearEmpleadoTaller = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  const idTallerPropietario = context.auth.uid;

  const tallerDoc = await db.collection('usuarios').doc(idTallerPropietario).get();
  const rol = (tallerDoc.data() || {}).rol || '';
  if (!/taller|mecanico|mecánico/i.test(rol)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo un taller puede crear cuentas de empleados.'
    );
  }

  const { correo, password, nombreCompleto, telefono } = data;
  if (!correo || !password || !nombreCompleto) {
    throw new functions.https.HttpsError('invalid-argument', 'Correo, contraseña y nombre son requeridos.');
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError('invalid-argument', 'La contraseña debe tener al menos 6 caracteres.');
  }

  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: correo,
      password,
      displayName: nombreCompleto,
    });
  } catch (err) {
    throw new functions.https.HttpsError('already-exists', err.message);
  }

  const empleadoRef = db
    .collection('talleres')
    .doc(idTallerPropietario)
    .collection('empleados')
    .doc(userRecord.uid);

  await empleadoRef.set({
    id_taller_propietario: idTallerPropietario,
    nombre_completo: nombreCompleto,
    correo,
    telefono: telefono || null,
    activo: true,
    fecha_creacion: admin.firestore.Timestamp.now(),
  });

  // El empleado hereda rol Taller pero queda vinculado al taller dueño
  await db.collection('usuarios').doc(userRecord.uid).set({
    id_usuario: userRecord.uid,
    nombre_completo: nombreCompleto,
    correo,
    rol: 'Empleado',
    id_taller_propietario: idTallerPropietario,
    estado: 'activo',
    fecha_registro: admin.firestore.Timestamp.now(),
  });

  return { idEmpleado: userRecord.uid };
});
```

- [ ] **Step 3: Reglas: bloquear que un usuario con rol `Empleado` se auto-edite `id_taller_propietario` o `rol`**

En `firestore.rules`, sección `match /usuarios/{userId}`, añade `'id_taller_propietario'` a la lista de campos excluidos en el `update` del propio dueño (junto a `rol`, `calificacion_promedio`, `total_resenias`, `estado`), para que solo la Cloud Function (Admin SDK, que no pasa por `firestore.rules`) pueda fijarlo.

- [ ] **Step 4: Verificar con emulador o revisión manual**

Si hay emuladores configurados: `firebase emulators:start --only functions,firestore,auth`, invoca el callable desde el emulador con datos de prueba y confirma que crea tanto el usuario de Auth como los dos documentos Firestore. Si no hay emuladores, documenta la verificación pendiente para el próximo despliegue real (`firebase deploy --only functions:crearEmpleadoTaller`).

- [ ] **Step 5: Commit**

```bash
git add functions/index.js firestore.rules
git commit -m "feat(mechanic): add crearEmpleadoTaller callable to provision employee auth accounts"
```

---

### Task 8: `EmpleadoProvider` + pantalla `EmpleadosScreen`

**Files:**
- Create: `lib/features/mechanic/presentation/providers/empleado_provider.dart`
- Create: `lib/features/mechanic/presentation/pages/empleados_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart`
- Test: `test/features/mechanic/presentation/providers/empleado_provider_test.dart`

**Interfaces:**
- Consumes: `EmpleadoRepository` (Task 6), `FirebaseFunctions.instance.httpsCallable('crearEmpleadoTaller')` (Task 7).
- Produces: `EmpleadoProvider` con `List<EmpleadoModel> empleados`, `bool isLoading`, `String? error`, `void watchTaller(String id)`, `Future<bool> crearEmpleado({required String correo, required String password, required String nombreCompleto, String? telefono})`, `Future<void> desactivar(String idTaller, String idEmpleado)`.

- [ ] **Step 1: Escribir el test que falla (mock del callable)**

```dart
// test/features/mechanic/presentation/providers/empleado_provider_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';

void main() {
  test('watchTaller puebla empleados desde el repositorio', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmpleadoRepository(firestore: firestore);
    await firestore.collection('talleres').doc('t1').collection('empleados').doc('e1').set({
      'id_taller_propietario': 't1', 'nombre_completo': 'A', 'correo': 'a@x.com', 'activo': true,
    });

    final provider = EmpleadoProvider(repository: repo);
    provider.watchTaller('t1');
    await Future.delayed(Duration.zero);

    expect(provider.empleados.length, 1);
  });
}
```

Nota: `crearEmpleado` invoca una Cloud Function real (`cloud_functions` no tiene fake oficial usado en este proyecto); su prueba unitaria queda limitada a verificar que el provider maneja `isLoading`/`error` correctamente ante una implementación inyectada — se cubre con un fake simple del callable en el propio archivo de test si se requiere, o se deja como verificación manual (Step 5) dado que el proyecto no tiene mocks de `cloud_functions` establecidos (confirmar contra `test/helpers/test_helpers.mocks.dart` si ya existe `MockFirebaseFunctions`, visto en la exploración inicial del admin panel — de ser así, reutilizarlo aquí).

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/features/mechanic/presentation/providers/empleado_provider_test.dart`
Expected: FAIL — `empleado_provider.dart` no existe.

- [ ] **Step 3: Implementar el provider**

```dart
// lib/features/mechanic/presentation/providers/empleado_provider.dart
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/empleado_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';

class EmpleadoProvider extends ChangeNotifier {
  final EmpleadoRepository _repository;
  final FirebaseFunctions _functions;
  StreamSubscription<List<EmpleadoModel>>? _sub;

  EmpleadoProvider({EmpleadoRepository? repository, FirebaseFunctions? functions})
      : _repository = repository ?? EmpleadoRepository(),
        _functions = functions ?? FirebaseFunctions.instance;

  List<EmpleadoModel> _empleados = [];
  List<EmpleadoModel> get empleados => _empleados;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void watchTaller(String idTaller) {
    _sub?.cancel();
    _sub = _repository.watchEmpleados(idTaller).listen((data) {
      _empleados = data;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<bool> crearEmpleado({
    required String correo,
    required String password,
    required String nombreCompleto,
    String? telefono,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final callable = _functions.httpsCallable('crearEmpleadoTaller');
      await callable.call({
        'correo': correo,
        'password': password,
        'nombreCompleto': nombreCompleto,
        'telefono': telefono,
      });
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> desactivar(String idTaller, String idEmpleado) async {
    await _repository.desactivarEmpleado(idTaller, idEmpleado);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/features/mechanic/presentation/providers/empleado_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Implementar `EmpleadosScreen`**

Pantalla con `MechanicSidebar` + lista de `EmpleadoModel` (nombre, correo, switch activo/inactivo llamando `desactivar`) + `FloatingActionButton` que abre un `AlertDialog`/`showModalBottomSheet` con formulario (`TextFormField` para correo, contraseña temporal, nombre, teléfono) que llama `crearEmpleado`. Sigue el patrón de diálogos con `TextEditingController` + validación visto en `admin_usuarios_screen._mostrarDialogoCambiarRol`. Verifica manualmente con `flutter run -d chrome`: crea un empleado, confirma que aparece en la lista y que (con Functions desplegadas) puede iniciar sesión con las credenciales dadas.

- [ ] **Step 6: Registrar ruta y sidebar**

Añade `/mechanic/empleados` a `app_router.dart` y el ítem correspondiente en `mechanic_sidebar.dart`, visible solo si `UserModel.rol` no es `'Empleado'` (los empleados no pueden gestionar otras sub-cuentas).

- [ ] **Step 7: Commit**

```bash
git add lib/features/mechanic/presentation/providers/empleado_provider.dart lib/features/mechanic/presentation/pages/empleados_screen.dart lib/core/router/app_router.dart lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart test/features/mechanic/presentation/providers/empleado_provider_test.dart
git commit -m "feat(mechanic): add employee sub-account management screen"
```

---

## Parte C — Catálogo Rápido de Servicios/Repuestos

### Task 9: `CatalogoItemModel` + `CatalogoRepository`

**Files:**
- Create: `lib/core/models/catalogo_item_model.dart`
- Create: `lib/features/mechanic/data/repositories/catalogo_repository.dart`
- Test: `test/features/mechanic/data/repositories/catalogo_repository_test.dart`

**Interfaces:**
- Produces: `CatalogoItemModel` con `idItem, idTaller, nombre, precio (double)`.
- Produces: `CatalogoRepository.agregarItem(...)`, `Stream<List<CatalogoItemModel>> watchCatalogo(String idTaller)`, `Future<void> eliminarItem(String idTaller, String idItem)`.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/mechanic/data/repositories/catalogo_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';

void main() {
  test('agregarItem y watchCatalogo devuelven el ítem creado', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CatalogoRepository(firestore: firestore);

    await repo.agregarItem(idTaller: 't1', nombre: 'Cambio de aceite', precio: 25.0);

    final items = await repo.watchCatalogo('t1').first;
    expect(items.length, 1);
    expect(items.first.nombre, 'Cambio de aceite');
    expect(items.first.precio, 25.0);
  });

  test('eliminarItem lo remueve del catálogo', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CatalogoRepository(firestore: firestore);
    final id = await repo.agregarItem(idTaller: 't1', nombre: 'Frenos', precio: 40.0);

    await repo.eliminarItem('t1', id);

    final items = await repo.watchCatalogo('t1').first;
    expect(items, isEmpty);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/features/mechanic/data/repositories/catalogo_repository_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementar modelo y repositorio**

```dart
// lib/core/models/catalogo_item_model.dart
class CatalogoItemModel {
  final String idItem;
  final String idTaller;
  final String nombre;
  final double precio;

  CatalogoItemModel({
    required this.idItem,
    required this.idTaller,
    required this.nombre,
    required this.precio,
  });

  Map<String, dynamic> toMap() => {'id_taller': idTaller, 'nombre': nombre, 'precio': precio};

  factory CatalogoItemModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CatalogoItemModel(
      idItem: documentId,
      idTaller: (map['id_taller'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
```

```dart
// lib/features/mechanic/data/repositories/catalogo_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';

class CatalogoRepository {
  final FirebaseFirestore _firestore;

  CatalogoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _catalogoRef(String idTaller) => _firestore
      .collection(FirestoreCollections.talleres)
      .doc(idTaller)
      .collection('catalogo_servicios');

  Future<String> agregarItem({required String idTaller, required String nombre, required double precio}) async {
    final docRef = await _catalogoRef(idTaller).add(
      CatalogoItemModel(idItem: '', idTaller: idTaller, nombre: nombre, precio: precio).toMap(),
    );
    return docRef.id;
  }

  Stream<List<CatalogoItemModel>> watchCatalogo(String idTaller) {
    return _catalogoRef(idTaller)
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs.map((d) => CatalogoItemModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> eliminarItem(String idTaller, String idItem) async {
    await _catalogoRef(idTaller).doc(idItem).delete();
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/features/mechanic/data/repositories/catalogo_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Reglas de Firestore para `talleres/{id}/catalogo_servicios`**

En `firestore.rules`, dentro de `match /talleres/{tallerId}`, añade:

```
match /catalogo_servicios/{itemId} {
  allow read: if true;
  allow create, update, delete: if isAuthenticated() && request.auth.uid == tallerId;
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/catalogo_item_model.dart lib/features/mechanic/data/repositories/catalogo_repository.dart test/features/mechanic/data/repositories/catalogo_repository_test.dart firestore.rules
git commit -m "feat(mechanic): add service/parts catalog repository"
```

---

### Task 10: `CatalogoProvider` + pantalla de gestión + integración en factura

**Files:**
- Create: `lib/features/mechanic/presentation/providers/catalogo_provider.dart`
- Create: `lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart`
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart`
- Test: `test/features/mechanic/presentation/providers/catalogo_provider_test.dart`

**Interfaces:**
- Consumes: `CatalogoRepository` (Task 9).
- Produces: `CatalogoProvider` con `List<CatalogoItemModel> items`, `void watchTaller(String idTaller)`, `Future<void> agregar(String nombre, double precio)`, `Future<void> eliminar(String idTaller, String idItem)`.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/providers/catalogo_provider_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';

void main() {
  test('watchTaller puebla items desde el repositorio', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CatalogoRepository(firestore: firestore);
    await repo.agregarItem(idTaller: 't1', nombre: 'Cambio de aceite', precio: 25.0);

    final provider = CatalogoProvider(repository: repo);
    provider.watchTaller('t1');
    await Future.delayed(Duration.zero);

    expect(provider.items.length, 1);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/features/mechanic/presentation/providers/catalogo_provider_test.dart`
Expected: FAIL

- [ ] **Step 3: Implementar `CatalogoProvider`**

```dart
// lib/features/mechanic/presentation/providers/catalogo_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';

class CatalogoProvider extends ChangeNotifier {
  final CatalogoRepository _repository;
  StreamSubscription<List<CatalogoItemModel>>? _sub;
  String? _idTaller;

  CatalogoProvider({CatalogoRepository? repository}) : _repository = repository ?? CatalogoRepository();

  List<CatalogoItemModel> _items = [];
  List<CatalogoItemModel> get items => _items;

  void watchTaller(String idTaller) {
    _idTaller = idTaller;
    _sub?.cancel();
    _sub = _repository.watchCatalogo(idTaller).listen((data) {
      _items = data;
      notifyListeners();
    });
  }

  Future<void> agregar(String nombre, double precio) async {
    if (_idTaller == null) return;
    await _repository.agregarItem(idTaller: _idTaller!, nombre: nombre, precio: precio);
  }

  Future<void> eliminar(String idItem) async {
    if (_idTaller == null) return;
    await _repository.eliminarItem(_idTaller!, idItem);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/features/mechanic/presentation/providers/catalogo_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Implementar `CatalogoServiciosScreen`**

Pantalla con `MechanicSidebar` + `ListView` de `CatalogoItemModel` (nombre + precio formateado con `intl`) + botón eliminar por ítem + `FloatingActionButton` con diálogo (`TextFormField` nombre, `TextFormField` precio con `keyboardType: TextInputType.number`) que llama `provider.agregar(nombre, precio)`.

- [ ] **Step 6: Integrar "agregar con un clic" en `initiate_service_screen.dart`**

Lee primero el método existente que abre el diálogo manual de "agregar material" (`_materiales.add({...})`). Junto a ese botón, añade un segundo botón "Desde catálogo" que abre un `showModalBottomSheet` listando `context.read<CatalogoProvider>().items` (previamente cargado con `watchTaller(idTaller)` en `initState`); al tocar un ítem, ejecuta:

```dart
setState(() {
  _materiales.add({
    'nombre': item.nombre,
    'cantidad': 1,
    'precioUnitario': item.precio,
  });
});
```

Esto reutiliza exactamente la misma estructura de `_materiales` que ya consume `AlertProvider.tallerUpdateService`, sin tocar su firma.

- [ ] **Step 7: Registrar ruta y sidebar**

Añade `/mechanic/catalogo` a `app_router.dart` y el ítem "Catálogo" en `mechanic_sidebar.dart`.

- [ ] **Step 8: Verificar manualmente**

Run: `flutter run -d chrome`. Como taller, agrega 2-3 ítems al catálogo, luego inicia un servicio y confirma que "Desde catálogo" los agrega a `_materiales` con un clic, y que el total de la factura se recalcula correctamente.

- [ ] **Step 9: Commit**

```bash
git add lib/features/mechanic/presentation/providers/catalogo_provider.dart lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart lib/features/mechanic/presentation/pages/initiate_service_screen.dart lib/core/router/app_router.dart lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart test/features/mechanic/presentation/providers/catalogo_provider_test.dart
git commit -m "feat(mechanic): add quick service/parts catalog and wire it into invoicing"
```

---

## Self-Review Notes

- **Cobertura del spec**: Kanban + notificación automática (Tasks 1-5), sub-cuentas de empleados con login real (Tasks 6-8), catálogo rápido integrado a factura con un clic (Tasks 9-10). Las 3 features del spec están cubiertas.
- **Decisión documentada**: las sub-cuentas de empleados requieren una Cloud Function callable con Admin SDK (`admin.auth().createUser`) porque el SDK cliente de Firebase Auth no permite crear un usuario nuevo sin cerrar la sesión del usuario actual — un documento de Firestore por sí solo no basta para un login independiente.
- **Riesgo a vigilar en ejecución**: Task 8 Step 1 depende de si el proyecto ya tiene `MockFirebaseFunctions` en `test/helpers/test_helpers.mocks.dart` (visto en la exploración del panel admin) — verificar antes de escribir el test para no duplicar mocks.
