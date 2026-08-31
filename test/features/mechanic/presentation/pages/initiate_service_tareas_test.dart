import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

void main() {
  test('sin tareas configuradas el guard no exige seleccionar ninguna', () {
    expect(
      requiereTareaSeleccionada(tareasDisponibles: 0, tareasMarcadas: 0),
      isFalse,
      reason: 'no se puede exigir marcar una casilla que la pantalla no dibuja',
    );
  });

  test('con tareas disponibles sigue exigiendo al menos una', () {
    expect(
      requiereTareaSeleccionada(tareasDisponibles: 3, tareasMarcadas: 0),
      isTrue,
    );
    expect(
      requiereTareaSeleccionada(tareasDisponibles: 3, tareasMarcadas: 1),
      isFalse,
    );
  });
}
