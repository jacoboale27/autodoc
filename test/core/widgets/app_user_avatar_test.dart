import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_user_avatar.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget avatar) async {
    await pumpAtWidth(tester, Center(child: avatar), width: 375);
  }

  testWidgets('pinta la foto cuando hay url', (tester) async {
    await pump(
      tester,
      const AppUserAvatar(urlFoto: 'https://x/f.jpg', nombre: 'Ana'),
    );
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('cae a la inicial del nombre sin url', (tester) async {
    await pump(tester, const AppUserAvatar(urlFoto: null, nombre: 'Ana'));
    expect(find.text('A'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('cae al icono si el nombre viene vacio', (tester) async {
    await pump(tester, const AppUserAvatar(urlFoto: null, nombre: ''));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets(
    'una conversacion pre-existente sin foto (url vacia) tambien cae a la '
    'inicial, no a una imagen rota',
    (tester) async {
      await pump(tester, const AppUserAvatar(urlFoto: '', nombre: 'Beto'));
      expect(find.text('B'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    },
  );
}
