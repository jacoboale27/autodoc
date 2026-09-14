import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart';

/// El stream que alimenta la gráfica "Tendencia de Ingresos", acotado.
///
/// Gap 4 del §5 de `GAPS-05-drenaje.md`, corregido: de los streams que la
/// anotación daba por "sin cota" en el panel del mecánico, **este es el único
/// que se puede acotar sin cambiar lo que significa**. La gráfica dibuja seis
/// meses y siempre los dibujó; lo que hacía era **descargar la historia entera
/// del taller para luego tirar en memoria todo lo que cayera fuera de la
/// ventana** (`ingresosPorMes.containsKey(key)` descarta lo viejo *después* de
/// haberlo leído). Un taller con 5000 servicios pagaba 5000 lecturas, y otras
/// tantas en cada reconexión del listener, para pintar seis barras.
///
/// Por eso el test no puede afirmar sobre los valores de la gráfica: **salen
/// iguales con cota y sin ella**, que es justo lo que hacía invisible el
/// defecto. Lo que se afirma es lo único que distingue un caso del otro: los
/// **documentos que cruzan el cable**.
///
/// La ventana es la misma que ya usaba el bucle de la gráfica —el día 1 del mes
/// que está cinco meses atrás—, así que la cota no retira ni una barra. Y el
/// índice `servicios (id_taller ASC, fecha DESC)` que el filtro de rango
/// necesita **ya existe** en `firestore.indexes.json`; no hay paso de runbook.
void main() {
  const idTaller = 't1';
  final ahora = DateTime(2026, 9, 14);

  Future<FakeFirebaseFirestore> conServicios(List<DateTime> fechas) async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < fechas.length; i += 1) {
      await db.collection('servicios').add({
        'id_taller': idTaller,
        'id_vehiculo': 'v$i',
        'costo': 100,
        'fecha': Timestamp.fromDate(fechas[i]),
      });
    }
    return db;
  }

  test('la tendencia NO descarga los servicios fuera de la ventana', () async {
    final db = await conServicios([
      ahora, // dentro
      DateTime(2026, 5, 1), // dentro: primer día del mes -5
      DateTime(2026, 3, 31), // fuera por un día: la ventana abre el 1 de abril
      DateTime(2024, 1, 15), // fuera de sobra
    ]);

    final entregados = await consultaDeTendenciaDeIngresos(
      db,
      idTaller,
      ahora,
    ).get();

    expect(
      entregados.docs,
      hasLength(2),
      reason:
          'Sin el filtro de rango llegan los cuatro, y la gráfica pinta lo '
          'mismo: el coste sólo se ve contando documentos.',
    );
  });

  test('la ventana empieza el día 1 del mes que está cinco meses atrás', () {
    // Cruza el fin de año, que es donde `month - 5` se sale del rango 1..12 y
    // donde un cálculo a mano se rompería.
    final enEnero = ventanaDeTendencia(DateTime(2026, 1, 20));
    expect(enEnero, DateTime(2025, 8, 1));

    final aMitadDeAno = ventanaDeTendencia(ahora);
    expect(aMitadDeAno, DateTime(2026, 4, 1));
  });

  test('la tendencia sigue filtrando por taller', () async {
    final db = await conServicios([ahora]);
    await db.collection('servicios').add({
      'id_taller': 'otro',
      'id_vehiculo': 'v9',
      'costo': 999,
      'fecha': Timestamp.fromDate(ahora),
    });

    final entregados = await consultaDeTendenciaDeIngresos(
      db,
      idTaller,
      ahora,
    ).get();

    expect(entregados.docs, hasLength(1));
  });
}
