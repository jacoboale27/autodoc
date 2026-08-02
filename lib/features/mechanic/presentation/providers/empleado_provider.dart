import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/empleado_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';

class EmpleadoProvider extends ChangeNotifier {
  final EmpleadoRepository _repository;
  final FirebaseFunctions? _injectedFunctions;
  StreamSubscription<List<EmpleadoModel>>? _sub;

  EmpleadoProvider({
    EmpleadoRepository? repository,
    FirebaseFunctions? functions,
  }) : _repository = repository ?? EmpleadoRepository(),
       _injectedFunctions = functions;

  // Resuelto de forma perezosa (no en el constructor): `FirebaseFunctions.instance`
  // exige `Firebase.initializeApp()`, y `watchTaller`/tests que no llaman
  // `crearEmpleado` no deberian requerirlo.
  FirebaseFunctions get _functions =>
      _injectedFunctions ?? FirebaseFunctions.instance;

  List<EmpleadoModel> _empleados = [];
  List<EmpleadoModel> get empleados => _empleados;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void watchTaller(String idTaller) {
    _sub?.cancel();
    _sub = _repository
        .watchEmpleados(idTaller)
        .listen(
          (data) {
            _empleados = data;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  Future<bool> crearEmpleado({
    required String correo,
    required String password,
    required String nombreCompleto,
    String? telefono,
  }) async {
    _isLoading = true;
    _error = null;
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
