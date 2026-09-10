import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela de índices compuestos de Firestore.
///
/// **Por qué existe.** Una consulta compuesta sin índice declarado no falla en
/// los emuladores: el emulador de Firestore sirve cualquier consulta sin mirar
/// `firestore.indexes.json`. Falla en PRODUCCIÓN, con `failed-precondition`, y
/// solo cuando un usuario real la ejecuta. Ni `flutter test`, ni `test_rules/`,
/// ni Playwright pueden verlo: es la clase de defecto que solo un despliegue
/// destapa.
///
/// Se descubrió cerrando los residuales de FUNC-02, y había tres a la vez:
///
///   - `cotizaciones (id_vehiculo, estado, fecha DESC)` no existía, y la
///     consulta que lo necesita vive en un `.then(...)` sin `catchError`
///     (`initiate_service_screen.dart`): el fallo era MUDO y la pantalla
///     acababa diciendo "no hay cotización aceptada" — un mensaje que manda a
///     buscar el problema donde no está.
///   - `servicios (id_vehiculo, fecha DESC)` estaba declarado como
///     `Servicios`, **con S mayúscula**. Firestore distingue mayúsculas en el
///     nombre de la colección, así que ese índice no servía a nada y las dos
///     consultas que lo necesitaban —el historial de servicios del vehículo y
///     la tarjeta de "último taller visitado"— se quedaban sin él. Estaba
///     anotado como "índice muerto"; no lo estaba: era el índice VIVO mal
///     escrito.
///   - `reservas` no tenía ninguno, y su consulta es el `Stream` que alimenta
///     la pantalla de reservas entera.
///
/// **Cómo funciona.** No parsea Dart: mantiene un INVENTARIO explícito de las
/// consultas compuestas del repositorio y comprueba tres cosas.
///
///   1. Cada consulta del inventario tiene un índice que la sirve.
///   2. Cada índice declarado sirve a alguna consulta del inventario (un
///      índice huérfano se paga en cada escritura y no lo lee nadie).
///   3. El número de `.orderBy(` en `lib/` es el esperado. Ese es el
///      disparador: quien añada una consulta ordenada rompe este test y tiene
///      que declararla aquí, que es justo el momento de preguntarse si
///      necesita índice.
///
/// El punto 3 es lo que impide que el inventario se quede atrás. Sin él, este
/// archivo sería documentación, y la documentación no falla sola.
void main() {
  final raiz = Directory.current.path;

  test('cada consulta compuesta del inventario tiene su indice declarado', () {
    final indices = _leerIndices(raiz);
    final sinIndice = <String>[];

    for (final consulta in _inventario) {
      if (!indices.any((indice) => indice.sirve(consulta))) {
        sinIndice.add('${consulta.origen} necesita $consulta');
      }
    }

    expect(
      sinIndice,
      isEmpty,
      reason:
          'Estas consultas se ejecutan en produccion sin indice compuesto y '
          'mueren con `failed-precondition`. Los emuladores NO lo detectan: '
          'sirven cualquier consulta. Declara el indice en '
          'firestore.indexes.json.',
    );
  });

  test('no hay indices declarados que ninguna consulta use', () {
    final indices = _leerIndices(raiz);
    final huerfanos = indices
        .where((indice) => !_inventario.any(indice.sirve))
        .map((indice) => indice.toString())
        .where((nombre) => !_huerfanosConocidos.contains(nombre))
        .toList();

    expect(
      huerfanos,
      isEmpty,
      reason:
          'Un indice compuesto que nadie consulta se paga en cada escritura de '
          'la coleccion y no lo lee nunca nadie. Borralo, o —si el nombre de '
          'la coleccion esta mal escrito— corrigelo: asi se descubrio que '
          '`Servicios` era `servicios`. Si de verdad hace falta y el '
          'inventario no lo ve, apuntalo en `_huerfanosConocidos` con su '
          'razon.',
    );
  });

  test('el inventario cubre todas las consultas ordenadas de lib/', () {
    final total = _contarOcurrencias(
      Directory('$raiz/lib'),
      '.orderBy(',
      '.dart',
    );

    expect(
      total,
      _orderByEsperados,
      reason:
          'El numero de `.orderBy(` en lib/ cambio. Si añadiste una consulta '
          'ordenada, decide si es compuesta (lleva ademas un `where` sobre '
          'OTRO campo): si lo es, declara su indice en firestore.indexes.json '
          'y añadela a `_inventario`; si no lo es, el indice de un solo campo '
          'es automatico y basta con ajustar este contador. Este contador es '
          'lo unico que impide que el inventario se quede atras en silencio.',
    );
  });

  test('el inventario cubre tambien las consultas del servidor', () {
    // El disparador de arriba solo mira `lib/`, y eso dejaba ciegas a las
    // consultas de Cloud Functions — que necesitan indice exactamente igual y
    // fallan exactamente igual. Se descubrio cuando el barrido de caducidad
    // del vinculo (`caducarVinculos.js`) nacio con una igualdad mas una
    // desigualdad y sin indice declarado: el centinela lo dejo pasar porque el
    // archivo no esta en `lib/`.
    //
    // Se cuentan los `.where(` y no los `.orderBy(` porque en el servidor casi
    // ninguna consulta ordena: lo que las vuelve compuestas es acumular
    // filtros, o mezclar una igualdad con una desigualdad (que a efectos de
    // indice se comporta como un `orderBy`).
    final total =
        _contarOcurrencias(Directory('$raiz/functions/src'), '.where(', '.js') +
        _contarOcurrencias(File('$raiz/functions/index.js'), '.where(', '.js');

    expect(
      total,
      _whereServidorEsperados,
      reason:
          'El numero de `.where(` en functions/ cambio. Si añadiste una '
          'consulta con dos o mas filtros, o con una desigualdad, necesita '
          'indice compuesto: declaralo en firestore.indexes.json y añadela a '
          '`_inventario`. Los emuladores NO detectan que falte.',
    );
  });
}

/// Consultas compuestas del repositorio: las que combinan igualdades con un
/// `orderBy` sobre otro campo, o dos o más igualdades. Son las que exigen
/// índice compuesto.
///
/// Una consulta con UNA sola igualdad y sin `orderBy`, o con `orderBy` sobre
/// ese mismo campo, la sirve el índice automático de un campo: esas no van
/// aquí.
const _inventario = <_Consulta>[
  _Consulta(
    coleccion: 'reservas',
    igualdades: ['id_mecanico'],
    orden: 'fecha_hora_propuesta',
    descendente: true,
    origen: 'lib/features/chat/data/repositories/reserva_repository.dart:17',
  ),
  _Consulta(
    coleccion: 'reservas',
    igualdades: ['id_propietario'],
    orden: 'fecha_hora_propuesta',
    descendente: true,
    // La misma consulta, con el campo elegido en tiempo de ejecución según el
    // rol: `where(isMecanico ? 'id_mecanico' : 'id_propietario', ...)`. Son
    // dos índices distintos y hacen falta los dos.
    origen: 'lib/features/chat/data/repositories/reserva_repository.dart:17',
  ),
  _Consulta(
    coleccion: 'servicios',
    igualdades: ['id_vehiculo'],
    orden: 'fecha',
    descendente: true,
    origen: 'lib/features/dashboard/data/services/vehicle_service.dart:300',
  ),
  _Consulta(
    coleccion: 'servicios',
    igualdades: ['id_vehiculo'],
    orden: 'fecha',
    descendente: true,
    origen:
        'lib/features/dashboard/presentation/providers/service_history_provider.dart:43',
  ),
  _Consulta(
    coleccion: 'servicios',
    igualdades: ['id_taller'],
    orden: 'fecha',
    descendente: true,
    origen:
        'lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart:488',
  ),
  _Consulta(
    coleccion: 'servicios',
    igualdades: ['id_taller'],
    orden: 'fecha',
    descendente: true,
    origen:
        'lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart:96',
  ),
  _Consulta(
    coleccion: 'conversaciones',
    igualdades: ['id_propietario', 'id_mecanico'],
    origen: 'lib/features/chat/data/repositories/chat_repository.dart:87',
  ),
  _Consulta(
    coleccion: 'conversaciones',
    igualdades: ['id_propietario', 'id_mecanico', 'id_vehiculo'],
    // La misma consulta con el tercer `where` opcional, que `ChatProvider`
    // sí rellena (`chat_provider.dart:171`). Es un índice distinto: Firestore
    // no sirve tres igualdades con el índice de dos.
    origen: 'lib/features/chat/data/repositories/chat_repository.dart:91',
  ),
  _Consulta(
    coleccion: 'talleres',
    igualdades: ['estado'],
    orden: 'calificacion_promedio',
    descendente: true,
    // `whereIn` sobre `estado`: para el índice cuenta como igualdad.
    origen: 'lib/features/dashboard/data/services/workshop_service.dart:32',
  ),
  _Consulta(
    coleccion: 'cotizaciones',
    igualdades: ['id_vehiculo', 'estado'],
    orden: 'fecha',
    descendente: true,
    origen:
        'lib/features/mechanic/presentation/pages/initiate_service_screen.dart:269',
  ),
  _Consulta(
    coleccion: 'cotizaciones',
    igualdades: ['id_vehiculo', 'id_taller', 'estado'],
    origen:
        'lib/features/mechanic/presentation/pages/vehicle_public_view_screen.dart:98',
  ),
  _Consulta(
    coleccion: 'reparaciones',
    igualdades: ['id_vehiculo', 'id_taller'],
    origen:
        'lib/features/mechanic/data/repositories/reparacion_repository.dart:50',
  ),
  _Consulta(
    coleccion: 'reparaciones',
    igualdades: ['id_taller', 'estado'],
    orden: 'fecha_actualizacion',
    descendente: true,
    // `whereIn` sobre `estado`: el tablero Kanban y "Mis Servicios". El orden
    // es parte del tope de la consulta, no un adorno — ver
    // `watchReparacionesActivas`.
    origen:
        'lib/features/mechanic/data/repositories/reparacion_repository.dart:237',
  ),
  _Consulta(
    coleccion: 'reparaciones',
    igualdades: ['vinculo_activo'],
    orden: 'fecha_actualizacion',
    // Barrido de caducidad del vínculo: `fecha_actualizacion < corte`. Una
    // desigualdad ordena igual que un `orderBy` de cara al índice, y va
    // ascendente porque interesan los más antiguos.
    origen: 'functions/src/caducarVinculos.js:62',
  ),
  _Consulta(
    coleccion: 'reparaciones',
    igualdades: ['id_vehiculo', 'id_taller', 'estado'],
    // Dedup del servidor: `estado not-in ESTADOS_TICKET_CERRADO`. Un `not-in`
    // es una desigualdad, así que su campo va el ÚLTIMO del índice — que es
    // donde queda.
    origen: 'functions/src/aceptarCotizacion.js:247',
  ),
];

/// Índices que no sirven a ninguna consulta del inventario y aun así se
/// conservan, cada uno con su razón. Vacío a propósito: lo que entre aquí,
/// entra con su justificación escrita al lado.
const _huerfanosConocidos = <String>[];

/// Cuántos `.orderBy(` hay hoy en `lib/`. Ver el tercer test.
const _orderByEsperados = 15;

/// Cuántos `.where(` hay hoy en `functions/index.js` y `functions/src/`. Ver el
/// cuarto test.
const _whereServidorEsperados = 24;

class _Consulta {
  const _Consulta({
    required this.coleccion,
    required this.igualdades,
    required this.origen,
    this.orden,
    this.descendente = false,
  });

  final String coleccion;
  final List<String> igualdades;
  final String? orden;
  final bool descendente;
  final String origen;

  @override
  String toString() {
    final partes = [
      ...igualdades.map((campo) => '$campo =='),
      if (orden != null) '$orden ${descendente ? 'DESC' : 'ASC'}',
    ];
    return '$coleccion (${partes.join(', ')})';
  }
}

class _Indice {
  const _Indice(this.coleccion, this.campos);

  final String coleccion;

  /// `(campo, descendente)`, en el orden declarado.
  final List<(String, bool)> campos;

  /// Un índice sirve a una consulta si sus primeros campos son exactamente las
  /// igualdades (en cualquier orden entre ellas, que es como Firestore las
  /// trata) y el siguiente es el `orderBy`, con la misma dirección.
  bool sirve(_Consulta consulta) {
    if (coleccion != consulta.coleccion) return false;
    final cuantasIgualdades = consulta.igualdades.length;
    final esperados = cuantasIgualdades + (consulta.orden == null ? 0 : 1);
    if (campos.length != esperados) return false;

    final prefijo = campos.take(cuantasIgualdades).map((c) => c.$1).toSet();
    if (prefijo.length != cuantasIgualdades) return false;
    if (!prefijo.containsAll(consulta.igualdades)) return false;

    if (consulta.orden == null) return true;
    final ultimo = campos[cuantasIgualdades];
    return ultimo.$1 == consulta.orden && ultimo.$2 == consulta.descendente;
  }

  @override
  String toString() {
    final partes = campos.map((c) => '${c.$1} ${c.$2 ? 'DESC' : 'ASC'}');
    return '$coleccion (${partes.join(', ')})';
  }
}

List<_Indice> _leerIndices(String raiz) {
  final json =
      jsonDecode(File('$raiz/firestore.indexes.json').readAsStringSync())
          as Map<String, dynamic>;
  return (json['indexes'] as List)
      .cast<Map<String, dynamic>>()
      .map(
        (indice) => _Indice(
          indice['collectionGroup'] as String,
          (indice['fields'] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (campo) => (
                  campo['fieldPath'] as String,
                  campo['order'] == 'DESCENDING',
                ),
              )
              .toList(),
        ),
      )
      .toList();
}

/// Cuántas veces aparece [aguja] en los archivos con [extension] bajo
/// [origen], que puede ser un fichero suelto o un directorio.
int _contarOcurrencias(
  FileSystemEntity origen,
  String aguja,
  String extension,
) {
  final archivos = origen is Directory
      ? origen.listSync(recursive: true)
      : <FileSystemEntity>[origen];
  var total = 0;
  for (final entidad in archivos) {
    if (entidad is! File || !entidad.path.endsWith(extension)) continue;
    total += aguja.allMatches(entidad.readAsStringSync()).length;
  }
  return total;
}
