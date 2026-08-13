// test/support/responsive_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';

/// Anchos obligatorios de verificación del plan de refactorización UI/UX.
///
/// Los cuatro de la Pre-Delivery Checklist de ui-ux-pro-max (375/768/1024/1440)
/// más 320 (el teléfono más pequeño en uso) y los tres cortes exactos de
/// [WindowClass] (600/840/1200), que es donde el layout realmente rompe.
const List<double> kAuditWidths = [320, 375, 600, 768, 840, 1024, 1200, 1440];

/// Monta [child] dentro de un `MaterialApp` con el tema de AutoDoc y un
/// viewport de [width] × [height] píxeles lógicos.
///
/// Fija el tamaño en `tester.view` (no envolviendo en un `MediaQuery` externo,
/// que `MaterialApp` sobreescribiría al construir el suyo desde la `View`), y
/// usa el `builder` de `MaterialApp` para inyectar [disableAnimations].
Future<void> pumpAtWidth(
  WidgetTester tester,
  Widget child, {
  required double width,
  double height = 900,
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      debugShowCheckedModeBanner: false,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: inner!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// Falla si el frame actual produjo un overflow de layout.
void expectNoOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: 'el layout desbordó: $exception');
}

/// Monta [build] a cada ancho de [kAuditWidths] y ejecuta [verify].
///
/// Uso típico en una tarea de pantalla:
/// ```dart
/// await forEachAuditWidth(tester, (width) async {
///   await pumpAtWidth(tester, const MiPantalla(), width: width);
///   expectNoOverflow(tester);
/// });
/// ```
Future<void> forEachAuditWidth(
  WidgetTester tester,
  Future<void> Function(double width) verify,
) async {
  for (final width in kAuditWidths) {
    await verify(width);
  }
}
