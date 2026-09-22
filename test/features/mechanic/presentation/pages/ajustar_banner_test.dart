// Observación del 2026-09-20: «el mecánico debería poder ajustar la parte del
// banner que quiere que se vea». El banner se pinta a 3.2:1 con `BoxFit.cover`
// y casi ninguna foto lo es, así que sin esto el recorte se lo lleva siempre
// el centro.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/ajustar_banner_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

/// Doble que anota lo que se manda guardar. `FakeUserProfileProvider` del
/// harness devuelve `true` sin registrar nada, y aquí lo que importa es QUÉ
/// encuadre se guardó.
class PerfilQueAnota extends FakeUserProfileProvider {
  PerfilQueAnota(UserModel usuario) : super(user: usuario);

  final List<UserModel> guardados = [];
  bool exito = true;

  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    dynamic imageFile,
    bool isNewUser = false,
  }) async {
    guardados.add(updatedUser);
    return exito;
  }
}

Future<PerfilQueAnota> pumpAjuste(
  WidgetTester tester, {
  double? encuadreInicial,
}) async {
  final perfil = PerfilQueAnota(
    fakeTaller().copyWith(bannerEncuadre: encuadreInicial),
  );
  await pumpAtWidth(
    tester,
    ChangeNotifierProvider<UserProfileProvider>.value(
      value: perfil,
      child: const AjustarBannerScreen(urlBanner: 'https://ejemplo/banner.jpg'),
    ),
    width: 900,
  );
  await tester.pump();
  return perfil;
}

void main() {
  testWidgets('mover la barra y guardar escribe el encuadre elegido', (
    tester,
  ) async {
    final perfil = await pumpAjuste(tester);

    // Arrastrar la barra hasta el extremo derecho = enseñar la parte de
    // abajo de la foto.
    await tester.drag(
      find.byKey(const Key('ajustar_banner_slider')),
      const Offset(500, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ajustar_banner_guardar')));
    await tester.pump();
    await tester.pump();

    expect(perfil.guardados.single.bannerEncuadre, 1.0);
  });

  testWidgets('arrastrar la foto también mueve el encuadre', (tester) async {
    final perfil = await pumpAjuste(tester);

    // Hacia arriba con el dedo = bajar por la foto.
    await tester.drag(
      find.byKey(const Key('ajustar_banner_arrastre')),
      const Offset(0, -30),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ajustar_banner_guardar')));
    await tester.pump();
    await tester.pump();

    expect(perfil.guardados.single.bannerEncuadre, greaterThan(0));
  });

  testWidgets('abre por el encuadre ya guardado, no por el centro', (
    tester,
  ) async {
    final perfil = await pumpAjuste(tester, encuadreInicial: -0.5);

    await tester.tap(find.byKey(const Key('ajustar_banner_guardar')));
    await tester.pump();
    await tester.pump();

    expect(perfil.guardados.single.bannerEncuadre, -0.5);
  });
}
