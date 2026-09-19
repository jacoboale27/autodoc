import 'package:flutter/material.dart';

import 'package:autodoc/core/utils/plate_formatter.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Clase de vehículo que se registra (observaciones del 2026-09-19: «solo
/// podemos tener vehículos tipo sedan, camioneta y de esos tipos ligeros pero
/// no tenemos para moto, camiones, microbuses»).
///
/// Decide tres cosas del registro: qué marcas se ofrecen primero, qué
/// modelos se piden a NHTSA ([tipoNhtsa]; `null` = todos los de la marca) y
/// el tipo de placa por defecto, que la persona puede cambiar.
///
/// Se guarda en `vehiculos.tipo_vehiculo` con su [id]. Los vehículos
/// registrados antes no lo tienen y se tratan como [automovil].
enum TipoVehiculo {
  automovil(
    id: 'automovil',
    icono: Icons.directions_car_filled_rounded,
    placaPorDefecto: TipoPlaca.particular,
    tipoNhtsa: null,
    marcas: [
      'Toyota',
      'Nissan',
      'Honda',
      'Hyundai',
      'Kia',
      'Chevrolet',
      'Mazda',
      'Volkswagen',
      'Ford',
      'Mitsubishi',
      'Suzuki',
      'Renault',
      'Peugeot',
      'Subaru',
      'BMW',
      'Mercedes-Benz',
      'Audi',
      'Chery',
      'MG',
      'JAC',
      'Changan',
      'Geely',
      'BYD',
      'Fiat',
      'Dodge',
      'Lexus',
      'Volvo',
      'Mini',
      'Seat',
      'Citroen',
      'Tesla',
    ],
  ),
  camioneta(
    id: 'camioneta',
    icono: Icons.airport_shuttle_rounded,
    placaPorDefecto: TipoPlaca.particular,
    tipoNhtsa: null,
    marcas: [
      'Toyota',
      'Nissan',
      'Mitsubishi',
      'Isuzu',
      'Ford',
      'Chevrolet',
      'Mazda',
      'Hyundai',
      'Kia',
      'Honda',
      'Jeep',
      'Suzuki',
      'Great Wall',
      'JAC',
      'Ram',
      'Volkswagen',
      'Dodge',
      'GMC',
      'Haval',
      'Land Rover',
      'Subaru',
    ],
  ),
  motocicleta(
    id: 'motocicleta',
    icono: Icons.two_wheeler_rounded,
    placaPorDefecto: TipoPlaca.moto,
    tipoNhtsa: 'motorcycle',
    marcas: [
      'Honda',
      'Yamaha',
      'Suzuki',
      'Kawasaki',
      'Bajaj',
      'TVS',
      'Italika',
      'Hero',
      'KTM',
      'Serpento',
      'Freedom',
      'UM',
      'Haojue',
      'Vento',
      'Harley-Davidson',
      'BMW',
      'Ducati',
      'Royal Enfield',
      'Kymco',
      'Benelli',
    ],
  ),
  camion(
    id: 'camion',
    icono: Icons.local_shipping_rounded,
    placaPorDefecto: TipoPlaca.carga,
    tipoNhtsa: 'truck',
    marcas: [
      'Hino',
      'Isuzu',
      'Mitsubishi Fuso',
      'Freightliner',
      'International',
      'Kenworth',
      'Mack',
      'Volvo',
      'Mercedes-Benz',
      'Hyundai',
      'JAC',
      'Foton',
      'Dongfeng',
      'Nissan',
      'UD Trucks',
      'Scania',
      'Sinotruk',
      'Toyota',
    ],
  ),
  microbus(
    id: 'microbus',
    icono: Icons.airport_shuttle_outlined,
    placaPorDefecto: TipoPlaca.microbus,
    tipoNhtsa: 'bus',
    marcas: [
      'Toyota',
      'Nissan',
      'Hyundai',
      'Mitsubishi',
      'JAC',
      'JMC',
      'King Long',
      'Golden Dragon',
      'Foton',
      'Mercedes-Benz',
      'Kia',
      'Isuzu',
      'Yutong',
    ],
  ),
  autobus(
    id: 'autobus',
    icono: Icons.directions_bus_filled_rounded,
    placaPorDefecto: TipoPlaca.autobus,
    tipoNhtsa: 'bus',
    marcas: [
      'Blue Bird',
      'International',
      'Freightliner',
      'Mercedes-Benz',
      'Hino',
      'Isuzu',
      'Yutong',
      'King Long',
      'Volvo',
      'Scania',
      'Thomas Built Buses',
      'Golden Dragon',
      'Higer',
      'Zhongtong',
    ],
  );

  const TipoVehiculo({
    required this.id,
    required this.icono,
    required this.placaPorDefecto,
    required this.tipoNhtsa,
    required this.marcas,
  });

  /// Valor que se guarda en `vehiculos.tipo_vehiculo`.
  final String id;
  final IconData icono;
  final TipoPlaca placaPorDefecto;

  /// `vehicletype` de la API de NHTSA para filtrar modelos, o `null` para
  /// pedir todos los de la marca (turismos y camionetas se mezclan allí).
  final String? tipoNhtsa;

  /// Marcas frecuentes en El Salvador, en el orden en que se ofrecen.
  final List<String> marcas;

  static TipoVehiculo desdeId(String? id) => TipoVehiculo.values.firstWhere(
    (t) => t.id == id,
    orElse: () => TipoVehiculo.automovil,
  );

  String etiqueta(AppLocalizations l10n) => switch (this) {
    TipoVehiculo.automovil => l10n.tipoVehiculoAutomovil,
    TipoVehiculo.camioneta => l10n.tipoVehiculoCamioneta,
    TipoVehiculo.motocicleta => l10n.tipoVehiculoMotocicleta,
    TipoVehiculo.camion => l10n.tipoVehiculoCamion,
    TipoVehiculo.microbus => l10n.tipoVehiculoMicrobus,
    TipoVehiculo.autobus => l10n.tipoVehiculoAutobus,
  };
}
