import 'package:cloud_functions/cloud_functions.dart';
import 'package:mockito/mockito.dart';

/// Doble de `FirebaseFunctions` que deja afirmar **qué callable** se invocó y
/// **con qué parámetros**, y decidir la respuesta desde el test.
///
/// Existe porque desde la Ronda 5 las escrituras sensibles sobre
/// `/reparaciones` viven en el servidor: el cliente ya no escribe, llama. Un
/// test que no mire el nombre del callable ni sus parámetros no distingue
/// "llamó al endpoint correcto" de "llamó a cualquier cosa".
class FakeFunctions extends Fake implements FirebaseFunctions {
  FakeFunctions({required this.alLlamar});

  final Object? Function(String nombre, dynamic parametros) alLlamar;

  /// Cada invocación registrada, en orden: `(nombre, parámetros)`.
  final List<({String nombre, dynamic parametros})> llamadas = [];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable(
        nombre: name,
        alLlamar: (nombre, parametros) {
          llamadas.add((nombre: nombre, parametros: parametros));
          return alLlamar(nombre, parametros);
        },
      );
}

class _FakeCallable extends Fake implements HttpsCallable {
  _FakeCallable({required this.nombre, required this.alLlamar});

  final String nombre;
  final Object? Function(String nombre, dynamic parametros) alLlamar;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      _FakeResult<T>(alLlamar(nombre, parameters) as T);
}

class _FakeResult<T> extends Fake implements HttpsCallableResult<T> {
  _FakeResult(this.data);

  @override
  final T data;
}
