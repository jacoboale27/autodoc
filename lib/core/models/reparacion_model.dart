import 'package:cloud_firestore/cloud_firestore.dart';

/// Pipeline secuencial del ticket de reparación, en orden: el índice de cada
/// estado en esta lista es lo que decide qué es "avanzar" y qué "retroceder"
/// (ver [ReparacionRepository.cambiarEstado]) y en qué orden se pintan las
/// columnas del kanban (ver ReparacionesKanbanScreen).
///
/// `pendiente_recepcion` es el estado inicial desde A4b: el ticket lo abre la
/// Cloud Function `onCotizacionAceptada` en cuanto el cliente acepta la
/// cotización, con el vehículo todavía fuera del taller. "Recibir vehículo"
/// dejó de crear el ticket y es solo la transición a `recibido`.
///
/// Los tickets anteriores a A4b están ya en `recibido` o más adelante, así que
/// insertar el estado al principio no los mueve: solo desplaza los índices, y
/// la comprobación de "no retroceder" es relativa (compara dos índices de esta
/// misma lista), no absoluta.
const List<String> estadosReparacion = [
  'pendiente_recepcion',
  'recibido',
  'en_revision',
  'esperando_repuestos',
  'listo_para_entrega',
];

/// Estado terminal del ticket: el coche salió del taller por su propio pie.
///
/// Es el único estado al que se llega por un hecho FÍSICO y no por el avance
/// del trabajo, y por eso no vive en [estadosReparacion]: no es una columna
/// del tablero, es la salida del tablero. Antes de que existiera, el pipeline
/// terminaba en `listo_para_entrega` y ningún ticket salía nunca — el tablero
/// y "Mis Servicios" acumulaban la historia entera del taller.
const String estadoReparacionEntregado = 'entregado';

/// Estados en los que el ticket ya no es una visita en curso.
///
/// Es el espejo en el cliente de `ESTADOS_TICKET_CERRADO`
/// (`functions/src/aceptarCotizacion.js`): el servidor abre un ticket NUEVO
/// cuando el unico que existe para ese vehiculo+taller esta en uno de estos
/// estados. Sin compartir la definicion, el cliente y el servidor discrepaban
/// sobre cual de los dos tickets es "el de ahora" — ver
/// [ReparacionRepository.buscarReparacionActiva].
///
/// `listo_para_entrega` **ya no está aquí**. Cerraba la visita porque era el
/// último estado del pipeline, pero en ese estado el coche sigue físicamente
/// en el taller esperando a que lo recojan: darlo por cerrado hacía que una
/// cotización aceptada mientras el coche seguía en el patio abriera un
/// SEGUNDO ticket para la misma visita, y que el vínculo al vehículo se
/// revocara con el coche todavía dentro. La visita se cierra al entregar.
///
/// Ni `cancelado` ni [estadoReparacionEntregado] estan en [estadosReparacion]
/// a proposito (son terminales, fuera del pipeline secuencial), asi que esta
/// lista no es un sufijo de aquella.
const List<String> estadosReparacionCerrados = [
  'cancelado',
  estadoReparacionEntregado,
];

/// Cuántos tickets vivos se traen para el tablero Kanban y "Mis Servicios".
///
/// No es una cifra de negocio, es un techo de coste: el stream que los
/// alimenta no tenía ninguno y traía el conjunto entero en cada apertura del
/// tablero. 200 tickets ABIERTOS a la vez está muy por encima de cualquier
/// taller real —son visitas simultáneas sin cerrar—, así que en la práctica no
/// recorta nada; lo que hace es que un taller que no cierra sus tickets
/// degrade su propio tablero en vez de la factura de lecturas de todos.
///
/// Llegar al tope se anuncia ([ReparacionProvider.tableroTruncado]): un
/// recorte silencioso en un tablero es peor que un tablero lento, porque una
/// tarjeta que no está se lee como un ticket que no existe.
const int maxTicketsTablero = 200;

/// ¿Este estado deja el ticket ABIERTO (o sea, en alguna columna del tablero)?
///
/// Es la definición única del booleano `abierto` que el ticket lleva
/// denormalizado, y la razón de que exista está en el gap 9.1: el tablero
/// filtraba con un `whereIn` de cinco estados, y Firestore ejecuta un `in`
/// como **N subconsultas aplicando el límite a cada una** antes de fusionar.
/// Con `limit(200)` eso son hasta 1000 documentos leídos para devolver 200, en
/// cada `attach` del listener. El tope acotaba documentos, no lecturas.
///
/// Preguntando por una igualdad —`abierto == true`— la consulta lee
/// exactamente el tope. El precio es mantener el campo coherente con `estado`,
/// y por eso se deriva SIEMPRE de él y nunca se pasa como parámetro:
///
///   - el cliente lo escribe en `ReparacionModel.toMap` y en
///     `ReparacionRepository.cambiarEstado`;
///   - `firestore.rules` lo ata al `estado` RESULTANTE
///     (`request.resource.data`, nunca `resource.data` — mirar el documento
///     viejo es el patrón exacto que destapó los cinco huecos de QA-01);
///   - los tres escritores server-side lo escriben con su propio espejo
///     (`ticketAbierto` en `functions/src/aceptarCotizacion.js`);
///   - los tickets anteriores a este cambio no lo tienen, y **una igualdad
///     sobre un campo ausente no devuelve nada**: `backfill_entregado.js` los
///     cubre en su pasada 4, que hay que correr ANTES de desplegar la app.
bool ticketAbierto(String estado) =>
    !estadosReparacionCerrados.contains(estado);

/// Estados en los que el coche está FÍSICAMENTE en el taller.
///
/// No es ni [estadosReparacion] (que incluye `pendiente_recepcion`, cuando el
/// coche aún no ha llegado) ni el complemento de [estadosReparacionCerrados]
/// (que también incluiría `pendiente_recepcion`). Es la lista que define
/// cuándo el taller tiene derecho a ver la ficha del vehículo
/// (`vehiculos.talleres_vinculados`, ver `functions/src/vinculoTaller.js`) y
/// desde qué estados se puede entregar el coche.
const List<String> estadosVehiculoEnTaller = [
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
      'abierto': ticketAbierto(estado),
      'historial_estados': historialEstados
          .map(
            (h) => {
              'estado': h['estado'],
              'timestamp': h['timestamp'] is DateTime
                  ? Timestamp.fromDate(h['timestamp'] as DateTime)
                  : h['timestamp'],
            },
          )
          .toList(),
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'fecha_actualizacion': Timestamp.fromDate(fechaActualizacion),
    };
  }

  factory ReparacionModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();

    return ReparacionModel(
      idReparacion: documentId,
      idVehiculo: (map['id_vehiculo'] ?? '').toString(),
      idTaller: (map['id_taller'] ?? '').toString(),
      idPropietario: (map['id_propietario'] ?? '').toString(),
      placa: (map['placa'] ?? '').toString(),
      estado: (map['estado'] ?? 'recibido').toString(),
      historialEstados: (map['historial_estados'] as List<dynamic>? ?? [])
          .map(
            (h) => {
              'estado': h['estado'],
              'timestamp': h['timestamp'] is Timestamp
                  ? (h['timestamp'] as Timestamp).toDate()
                  : h['timestamp'],
            },
          )
          .toList(),
      fechaCreacion: parseDate(map['fecha_creacion']),
      fechaActualizacion: parseDate(map['fecha_actualizacion']),
    );
  }
}
