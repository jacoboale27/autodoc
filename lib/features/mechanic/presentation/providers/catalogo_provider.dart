import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/catalogo_item_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

/// Gestiona el catálogo de mano de obra del taller
/// (`talleres/{idTaller}/catalogo_servicios`): servicios con su precio
/// estimado, que se agregan con un clic a una cotización (ver
/// [CatalogoItemModel]).
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
            _error = mensajeSeguroDeError(e);
            notifyListeners();
          },
        );
  }

  Future<void> agregar(
    String nombre,
    double precio, {
    double? precioMax,
  }) async {
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
        precioMax: precioMax,
      );
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Añade los [serviciosComunesManoDeObra] que el taller todavía no tenga
  /// (por nombre, sin distinguir mayúsculas). Devuelve cuántos añadió.
  Future<int> cargarServiciosComunes() async {
    final idTaller = _idTaller;
    if (idTaller == null || idTaller.isEmpty) {
      _error = 'idTaller vacío: no hay taller asociado a esta cuenta';
      notifyListeners();
      throw StateError(_error!);
    }
    final existentes = _items.map((i) => i.nombre.trim().toLowerCase()).toSet();
    final nuevos = [
      for (final s in serviciosComunesManoDeObra)
        if (!existentes.contains(s.nombre.toLowerCase()))
          CatalogoItemModel(
            idItem: '',
            idTaller: idTaller,
            nombre: s.nombre,
            precio: s.desde,
            precioMax: s.hasta,
          ),
    ];
    if (nuevos.isEmpty) return 0;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.agregarVarios(idTaller, nuevos);
      return nuevos.length;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
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
      _error = mensajeSeguroDeError(e);
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
