import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';

/// Coche al que debe apuntar una cotización enviada desde el menú del chat.
///
/// Observaciones del 2026-09-18 (capturas 4 y 5): la cotización del chat
/// tomaba el coche SOLO de la conversación, que no tiene ninguno cuando el
/// cliente escribió al taller desde el directorio. El cliente ya había elegido
/// su coche al agendar la cita, pero ese dato se perdía: la cotización nacía
/// sin `id_vehiculo`, al aceptarla no se abría ticket y el taller no podía
/// recibir el coche.
///
/// Orden: el coche de la conversación si lo tiene; si no, el de la cita (o
/// tarjeta de vehículo) más reciente del hilo. [mensajesRecientesPrimero] es
/// `ChatProvider.mensajesActuales`, que ya viene del más nuevo al más viejo.
/// Devuelve `null` si en el hilo no hay ningún coche: en ese caso no se puede
/// cotizar todavía (hace falta una cita, igual que desde Buscar Vehículo).
VehiculoCotizado? vehiculoParaCotizarEnChat({
  required String? idVehiculoConversacion,
  required List<MensajeModel> mensajesRecientesPrimero,
}) {
  Map<String, dynamic>? resumenDe(MensajeModel m) {
    final meta = m.metadata ?? const <String, dynamic>{};
    if (m.tipo == 'reserva_card') {
      final v = meta['vehiculo'];
      return v is Map ? Map<String, dynamic>.from(v) : null;
    }
    // Una tarjeta de vehículo lleva los datos en la propia metadata.
    return meta;
  }

  final candidatos = mensajesRecientesPrimero.where(
    (m) =>
        !m.isDeleted &&
        (m.tipo == 'reserva_card' || m.tipo == 'vehiculo_card') &&
        ((m.metadata?['id_vehiculo'] as String?) ?? '').isNotEmpty,
  );

  final idConversacion = idVehiculoConversacion ?? '';
  if (idConversacion.isNotEmpty) {
    final mismo = candidatos
        .where((m) => m.metadata!['id_vehiculo'] == idConversacion)
        .firstOrNull;
    return VehiculoCotizado.desdeResumen(
      idConversacion,
      mismo == null ? null : resumenDe(mismo),
    );
  }

  final ultimo = candidatos.firstOrNull;
  if (ultimo == null) return null;
  return VehiculoCotizado.desdeResumen(
    ultimo.metadata!['id_vehiculo'] as String,
    resumenDe(ultimo),
  );
}

/// Lo que el taller necesita ver del coche que está cotizando: nombre, placa,
/// kilometraje y foto. Nada más.
///
/// Existe porque el taller **no puede leer** `vehiculos/{id}` hasta que recibe
/// el coche (el vínculo sigue a la posesión, ver `src/vinculoTaller.js`), y la
/// pantalla de cotización tiene que pintar la tarjeta del vehículo antes de
/// eso. Sale de tres sitios, según por dónde llegue el taller:
///
/// - Buscar Vehículo: de la ficha pública que devuelve `buscarVehiculoPorPlaca`
///   ([VehiculoCotizado.desdeVehiculo]).
/// - El chat: del resumen que el propio cliente deja en la cita al elegir su
///   coche (`reservas.vehiculo_resumen` y la metadata `vehiculo` de la tarjeta
///   de la cita), vía [VehiculoCotizado.desdeResumen].
/// - Citas anteriores a ese resumen: solo el id, y la tarjeta dice
///   «Vehículo del cliente» en vez de inventar datos.
class VehiculoCotizado {
  final String idVehiculo;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? placa;
  final int? kilometraje;
  final String? fotoUrl;

  const VehiculoCotizado({
    required this.idVehiculo,
    this.marca,
    this.modelo,
    this.anio,
    this.placa,
    this.kilometraje,
    this.fotoUrl,
  });

  factory VehiculoCotizado.desdeVehiculo(VehicleModel v) => VehiculoCotizado(
    idVehiculo: v.idVehiculo,
    marca: v.marca,
    modelo: v.modelo,
    anio: v.anio,
    placa: v.placa,
    kilometraje: v.kilometrajeActual,
    fotoUrl: v.fotoUrl,
  );

  /// Lectura tolerante: las citas y tarjetas anteriores al resumen no lo
  /// traen, y un campo con el tipo equivocado no debe tumbar la pantalla.
  factory VehiculoCotizado.desdeResumen(
    String idVehiculo,
    Map<String, dynamic>? resumen,
  ) {
    final r = resumen ?? const <String, dynamic>{};
    String? texto(String clave) {
      final valor = r[clave];
      if (valor == null) return null;
      final s = valor.toString().trim();
      return s.isEmpty ? null : s;
    }

    int? entero(String clave) {
      final valor = r[clave];
      if (valor is num) return valor.toInt();
      return int.tryParse(valor?.toString() ?? '');
    }

    return VehiculoCotizado(
      idVehiculo: idVehiculo,
      marca: texto('marca'),
      modelo: texto('modelo'),
      anio: entero('anio'),
      placa: texto('placa'),
      kilometraje: entero('kilometraje'),
      fotoUrl: texto('foto_url'),
    );
  }

  /// Resumen que se denormaliza en la cita. Solo datos que el taller ya ve en
  /// la ficha pública de Buscar Vehículo: nada del propietario.
  Map<String, dynamic> toResumen() => {
    if (marca != null) 'marca': marca,
    if (modelo != null) 'modelo': modelo,
    if (anio != null) 'anio': anio,
    if (placa != null) 'placa': placa,
    if (kilometraje != null) 'kilometraje': kilometraje,
    if (fotoUrl != null) 'foto_url': fotoUrl,
  };

  /// «Toyota Corolla» o, sin datos, un rótulo neutro.
  String get nombre {
    final partes = [
      marca,
      modelo,
    ].whereType<String>().where((p) => p.isNotEmpty).toList();
    return partes.isEmpty ? 'Vehículo del cliente' : partes.join(' ');
  }
}
