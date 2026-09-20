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
      // Una consulta de SOLO igualdades no necesita índice compuesto:
      // Firestore la resuelve por *index merging* sobre los índices de un
      // solo campo, que son automáticos. Esta regla era más estricta que
      // Firestore (gap 9.4) y con ella el centinela exigía —y por tanto
      // mantenía vivos— cuatro índices que nadie necesita.
      if (!consulta.necesitaCompuesto) continue;
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
    // Un índice solo cuenta como "usado" si sirve a una consulta que de
    // verdad exige compuesto. Casar con una consulta de solo igualdades no
    // basta: esa consulta se resuelve igual sin él, así que el índice sigue
    // siendo un coste por escritura que no compra nada (gap 9.4).
    final huerfanos = indices
        .where(
          (indice) => !_inventario.any(
            (consulta) => consulta.necesitaCompuesto && indice.sirve(consulta),
          ),
        )
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
  // Las dos consultas por rol de `reservas` vivian aqui. Se fueron con
  // `streamReservasUsuario` (gap 7.2 de GAPS-02): eran las dos variantes de un
  // stream que no consumia ninguna pantalla. Con ellas se retiran sus DOS
  // indices de produccion, que es un paso de runbook.
  //
  // El TERCER indice de `reservas` se queda, y por poco: al retirar los otros
  // dos se fue tambien de un plumazo, y fue este centinela el que lo paro.
  // Lo usa el recordatorio diario de citas, que es del SERVIDOR — o sea que
  // vaciar `lib/` de consultas a una coleccion no significa que la coleccion
  // se haya quedado sin consultas.
  // (la entrada de `reservas / estado + fecha_hora_propuesta` que sirve al
  // recordatorio de citas ya estaba mas abajo, puesta por OPS-01: no se
  // duplica aqui. Lo que si queda dicho es POR QUE ese indice sobrevivio a la
  // retirada de los otros dos.)
  _Consulta(
    coleccion: 'servicios',
    igualdades: ['id_vehiculo'],
    orden: 'fecha',
    descendente: true,
    origen: 'lib/features/dashboard/data/services/vehicle_service.dart:300',
  ),
  // Gap 7.4 de GAPS-02: antes no llevaba `id_taller` ni orden ni tope, asi
  // que leia el historial COMPLETO del propietario para devolver un id.
  _Consulta(
    coleccion: 'servicios',
    igualdades: ['id_vehiculo', 'id_taller'],
    orden: 'fecha',
    descendente: true,
    origen: 'lib/features/reviews/data/services/review_service.dart:160',
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
    coleccion: 'conversaciones',
    igualdades: ['id_propietario'],
    orden: 'ultimo_mensaje_ts',
    descendente: true,
    // La bandeja de chat, acotada (gap 9.2). El campo del `where` lo elige el
    // rol en tiempo de ejecución, así que son dos índices distintos y hacen
    // falta los dos — igual que en `reservas`.
    //
    // Los dos se habían retirado por huérfanos al cerrar los residuales de
    // FUNC-02: estaban huérfanos precisamente PORQUE el orden se hacía en
    // memoria. Acotar la consulta es lo que vuelve a necesitarlos.
    origen: 'lib/features/chat/data/repositories/chat_repository.dart:52',
  ),
  _Consulta(
    coleccion: 'conversaciones',
    igualdades: ['id_mecanico'],
    orden: 'ultimo_mensaje_ts',
    descendente: true,
    origen: 'lib/features/chat/data/repositories/chat_repository.dart:52',
  ),
  _Consulta(
    coleccion: 'mensajes',
    igualdades: ['id_remitente'],
    orden: 'estado',
    // `marcarComoLeidos`, acotada (gap 7.1): `estado != 'visto'`. Una
    // desigualdad cuenta como el `orderBy` de cara al indice, asi que su campo
    // va el ULTIMO. Es una subcoleccion, pero la consulta NO es de grupo de
    // coleccion: el indice va con queryScope COLLECTION igual que los demas.
    origen: 'lib/features/chat/data/repositories/chat_repository.dart:205',
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
    igualdades: ['id_taller', 'abierto'],
    orden: 'fecha_actualizacion',
    descendente: true,
    // El tablero Kanban y "Mis Servicios". Fue un `whereIn` sobre `estado`
    // hasta el gap 9.1: ahora es la igualdad sobre el booleano denormalizado,
    // que es lo que hace que el `limit` acote lecturas y no solo documentos.
    // El orden es parte del tope, no un adorno — ver
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
    igualdades: ['id_vehiculo', 'id_taller'],
    orden: 'estado',
    // Dedup del servidor: `estado not-in ESTADOS_TICKET_CERRADO`. Un `not-in`
    // es una desigualdad, así que su campo va el ÚLTIMO del índice — que es
    // donde queda.
    //
    // Va en `orden` y no en `igualdades` justamente porque NO es una
    // igualdad: desde el gap 9.4, las consultas de solo igualdades ya no
    // exigen compuesto, y declararla como tal habría hecho que el centinela
    // dejara de pedir el índice que esta consulta sí necesita.
    origen: 'functions/src/aceptarCotizacion.js:247',
  ),
  _Consulta(
    coleccion: 'reservas',
    igualdades: ['estado'],
    orden: 'fecha_hora_propuesta',
    // OPS-01: recordatorio diario de citas. La desigualdad es doble
    // (`>= inicio` y `< fin` de la ventana de mañana), lo que a efectos de
    // índice se comporta como un `orderBy` ascendente sobre ese campo.
    //
    // Antes de OPS-01 esta consulta era de solo igualdades —`estado ==
    // 'confirmada'`— y por eso no aparecía aquí: barría la colección entera y
    // descartaba en memoria. Acotarla en el servidor es lo que la vuelve
    // compuesta, y este índice es el precio de no leer cada reserva que haya
    // existido jamás, todos los días.
    origen: 'functions/src/recordatoriosReserva.js:86',
  ),
  _Consulta(
    coleccion: 'servicios',
    igualdades: ['id_vehiculo'],
    orden: 'fecha',
    descendente: true,
    // INNO-01: el pase temporal de historial por QR. Reutiliza el MISMO indice
    // que el historial del propietario, asi que no crea ninguno.
    //
    // Entra igualmente al inventario, y la razon es el escarmiento de GAPS-04:
    // al retirar `streamReservasUsuario` el centinela se llevaba de paso un
    // tercer indice de `reservas` que usa el recordatorio de citas, o sea el
    // SERVIDOR. Si manana alguien retira las consultas de historial de `lib/`,
    // sin esta entrada este indice se marcaria huerfano y se borraria — y el
    // canje del pase moriria en produccion con `failed-precondition`, que es
    // justo el fallo que los emuladores no pueden ver.
    origen: 'functions/src/historialCompartido.js:160',
  ),
  // Asistente de agenda (plan 2026-09-19). Las DOS consultas de citas, una por
  // rol, y las dos son nuevas: hasta hoy el unico indice de `reservas` era el
  // del barrido global de recordatorios, que filtra solo por `estado` y no
  // sirve a ninguna de estas dos.
  //
  // La del taller es ademas la primera consulta a `reservas` que existe para
  // ese rol en todo el repositorio: `grep -rn "reservas" lib/features/mechanic/`
  // no devuelve nada, o sea que el taller no tiene hoy ninguna vista de sus
  // citas proximas pese a que el dato lleva ahi desde siempre.
  _Consulta(
    coleccion: 'reservas',
    igualdades: ['id_propietario', 'estado'],
    orden: 'fecha_hora_propuesta',
    origen: 'functions/src/agenda.js (leerCitas, rol propietario)',
  ),
  _Consulta(
    coleccion: 'reservas',
    igualdades: ['id_taller', 'estado'],
    orden: 'fecha_hora_propuesta',
    origen: 'functions/src/agenda.js (leerCitas, rol taller)',
  ),
];

/// Índices que no sirven a ninguna consulta del inventario y aun así se
/// conservan, cada uno con su razón. Vacío a propósito: lo que entre aquí,
/// entra con su justificación escrita al lado.
const _huerfanosConocidos = <String>[];

/// Cuántos `.orderBy(` hay hoy en `lib/`. Ver el tercer test.
/// 16: sube a 17 con el `orderBy` que `findReviewableServiceId` baja al
/// servidor (gap 7.4) y vuelve a 16 al retirarse `streamReservasUsuario`
/// (gap 7.2). Ambos de GAPS-02.
/// 17 desde GAPS-08: `VehiclePhotoService.deletePhoto` busca la foto más
/// reciente que queda para ascenderla a portada. NO necesita índice
/// declarado —es un `orderBy` de un solo campo sin `where`, y ésos Firestore
/// los tiene automáticos—, así que solo ajusta el contador.
const _orderByEsperados = 17;

/// Cuántos `.where(` hay hoy en `functions/index.js` y `functions/src/`. Ver el
/// cuarto test.
/// 27 desde que `caducarVinculosInactivos` consulta tambien por
/// `vinculo_revocacion_pendiente` (gap 9.6). Es una **sola igualdad**, asi que
/// el indice automatico la sirve y no anade compuesto; por eso sube el contador
/// y no el inventario.
/// 28 desde INNO-01: `leerHistorialPorToken` consulta `servicios` por
/// `id_vehiculo` con `orderBy('fecha','desc')`. El indice compuesto que
/// necesita YA existe —es el mismo que sirve al historial del propietario— asi
/// que aqui no nace ninguno; pero la consulta si entra al inventario, para que
/// ese indice no se marque huerfano el dia que alguien retire las consultas de
/// historial de `lib/`. Ese fallo exacto ya paso una vez con `reservas` en
/// GAPS-04: vaciar `lib/` de consultas a una coleccion no significa que la
/// coleccion se quede sin consultas.
/// 31 desde GAPS-05: `crearTokenHistorial` busca un pase vivo antes de acunar
/// otro (gaps 1 y 2 de INNO-01) con tres igualdades — `id_vehiculo`,
/// `id_propietario` y `revocado`. **No anaden inventario y no crean indice**, y
/// esa es justo la razon de escribir la consulta asi: Firestore sirve las
/// consultas de igualdades puras con los indices automaticos, y por eso el
/// vencimiento y el cupo se filtran en codigo en vez de con un rango. Mismo
/// criterio que la consulta de `vinculo_revocacion_pendiente` anotada arriba.
// GAPS-05: 31 -> 32. El barrido de alertas (`alertasVencidas.js`) gana un
// segundo filtro, `avisos_pendientes == true`, que es la denormalizacion que
// le impide releer cada dia lo que ya aviso.
//
// **No necesita indice compuesto, y por eso no se declara ninguno.** Son DOS
// IGUALDADES mas `orderBy('__name__')`: Firestore las resuelve con merge join
// de los indices de campo unico, que ya ordenan por `__name__` como segundo
// termino. Lo que obliga a declarar indice es acumular un `orderBy` sobre otro
// campo, o mezclar una igualdad con una DESIGUALDAD — que es justo el caso que
// se le escapo a este centinela con `caducarVinculos.js` y por el que existe
// este segundo test.
const _whereServidorEsperados = 39;

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

  /// Solo las consultas que **ordenan** (o que llevan una desigualdad, que
  /// para el índice se comporta igual) exigen un índice compuesto. Las de
  /// solo igualdades las resuelve el *index merging* sobre los índices
  /// automáticos de un campo.
  bool get necesitaCompuesto => orden != null;

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
