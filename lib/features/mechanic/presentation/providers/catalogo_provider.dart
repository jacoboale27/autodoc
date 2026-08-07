import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';

/// Gestiona el catálogo rápido de servicios/repuestos de un taller
/// (`talleres/{idTaller}/catalogo_servicios`), permitiendo agregarlo con un
/// clic a la lista de materiales de una factura (Task 10).
class CatalogoProvider extends ChangeNotifier {
  final CatalogoRepository _repository;
  StreamSubscription<List<CatalogoItemModel>>? _sub;
  String? _idTaller;

  CatalogoProvider({CatalogoRepository? repository})
    : _repository = repository ?? CatalogoRepository();

  List<CatalogoItemModel> _items = [];
  List<CatalogoItemModel> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void watchTaller(String idTaller) {
    if (idTaller.isEmpty) {
      _sub?.cancel();
      _sub = null;
      _idTaller = null;
      _items = [];
      notifyListeners();
      return;
    }
    if (_idTaller == idTaller && _sub != null) return;
    _idTaller = idTaller;
    _sub?.cancel();
    _sub = _repository
        .watchCatalogo(idTaller)
        .listen(
          (data) {
            _items = data;
            notifyListeners();
          },
          // Sin este onError (a diferencia de ReparacionProvider.watchTaller,
          // su hermano en el panel mecánico), una denegación de firestore.rules
          // fallaba en silencio: el stream simplemente dejaba de emitir, sin
          // registrar el error ni exponerlo via [error] para la UI.
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  Future<void> agregar(String nombre, double precio) async {
    if (_idTaller == null || _idTaller!.isEmpty) {
      _error = 'idTaller vacío: no hay taller asociado a esta cuenta';
      notifyListeners();
      throw StateError(_error!);
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.agregarItem(
        idTaller: _idTaller!,
        nombre: nombre,
        precio: precio,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> eliminar(String idItem) async {
    if (_idTaller == null || _idTaller!.isEmpty) {
      _error = 'idTaller vacío: no hay taller asociado a esta cuenta';
      notifyListeners();
      throw StateError(_error!);
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.eliminarItem(_idTaller!, idItem);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
