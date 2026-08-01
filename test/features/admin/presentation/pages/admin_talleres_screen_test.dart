import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/workshop_model.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_talleres_screen.dart';

void main() {
  test(
    'filtrarTalleres respeta municipio, departamento y especialidad simultáneamente',
    () {
      final talleres = [
        WorkshopModel(
          idTaller: '1',
          nombre: 'A',
          ubicacionMunicipio: 'San Salvador',
          departamento: 'San Salvador',
          especialidad: 'Frenos',
          telefono: '1',
          calificacionPromedio: 4,
          estado: 'aprobado',
        ),
        WorkshopModel(
          idTaller: '2',
          nombre: 'B',
          ubicacionMunicipio: 'Santa Ana',
          departamento: 'Santa Ana',
          especialidad: 'Motor',
          telefono: '2',
          calificacionPromedio: 4,
          estado: 'aprobado',
        ),
        WorkshopModel(
          idTaller: '3',
          nombre: 'C',
          ubicacionMunicipio: 'San Salvador',
          departamento: 'San Salvador',
          especialidad: 'Motor',
          telefono: '3',
          calificacionPromedio: 4,
          estado: 'aprobado',
        ),
      ];

      final result = filtrarTalleres(
        talleres,
        municipio: 'San Salvador',
        departamento: 'San Salvador',
        especialidad: 'Motor',
      );

      expect(result.map((t) => t.idTaller), ['3']);
    },
  );

  test('filtrarTalleres combina estado, busqueda y filtros nuevos', () {
    final talleres = [
      WorkshopModel(
        idTaller: '1',
        nombre: 'Taller Alfa',
        ubicacionMunicipio: 'San Salvador',
        departamento: 'San Salvador',
        especialidad: 'Frenos',
        estado: 'pendiente',
      ),
      WorkshopModel(
        idTaller: '2',
        nombre: 'Taller Beta',
        ubicacionMunicipio: 'San Salvador',
        departamento: 'San Salvador',
        especialidad: 'Frenos',
        estado: 'aprobado',
      ),
    ];

    final result = filtrarTalleres(
      talleres,
      estado: 'aprobado',
      busqueda: 'beta',
      municipio: 'San Salvador',
      departamento: 'San Salvador',
      especialidad: 'Frenos',
    );

    expect(result.map((t) => t.idTaller), ['2']);
  });

  test('filtrarTalleres sin filtros nuevos devuelve todos los talleres', () {
    final talleres = [
      WorkshopModel(idTaller: '1', nombre: 'A', estado: 'aprobado'),
      WorkshopModel(idTaller: '2', nombre: 'B', estado: 'aprobado'),
    ];

    final result = filtrarTalleres(talleres, estado: 'todos', busqueda: '');

    expect(result.length, 2);
  });
}
