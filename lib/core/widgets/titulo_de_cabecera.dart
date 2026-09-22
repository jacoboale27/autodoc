import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// El titulo de una `AppBar` que **cabe entero** en un telefono.
///
/// ── Por que hace falta, con las medidas delante ──────────────────────────
///
/// Lo levanto una captura de la pantalla del asistente a 360 dp: se leia
/// «Asiste…». Medido en `titulo_de_cabecera_test.dart` sobre ese mismo ancho,
/// con flecha atras y las cuatro acciones de cabecera:
///
/// | Pieza | Ancho |
/// |---|---|
/// | Acciones de cabecera (ya apretadas) | 162 px |
/// | Hueco que le queda al titulo | **110 px** |
/// | Lo que «Asistente» necesita a 22 sp | **198 px** |
///
/// O sea que **apretar los controles no puede cerrarlo**: aunque se quitaran
/// dos, no aparecen 88 px. El titulo a 22 sp (`titleLarge`, el de Material
/// para una barra superior) simplemente no convive con cuatro acciones y una
/// flecha en 360 dp. Por eso el arreglo actua sobre el titulo y no sobre las
/// acciones — esas ya se apretaron aparte, que suma pero no basta.
///
/// **Dos capas, y las dos hacen falta.** En `compact` se baja a
/// `titleMedium` (16 sp), que es el tamaño con el que una pantalla de telefono
/// rotula de verdad; y por encima va un `FittedBox` que reduce lo que aun
/// sobresalga. Sin la primera, el escalado tendria que hacer todo el trabajo y
/// dejaria el rotulo diminuto; sin la segunda, un titulo mas largo —«Nueva
/// cotizacion», «Compartir historial»— volveria a la elipsis, que es el
/// defecto de partida.
///
/// **Escalar es mejor que recortar, y no es una preferencia.** Una elipsis
/// destruye la palabra: «Asiste…» no dice donde esta la persona. Un rotulo un
/// punto mas pequeño se lee entero. Fuera de `compact` no cambia nada: ahi
/// sobra sitio y encogerlo seria empeorar la pantalla a cambio de nada.
class TituloDeCabecera extends StatelessWidget {
  final String texto;

  const TituloDeCabecera(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final apretado = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;
    if (!apretado) return Text(texto);

    final estilo = Theme.of(context).appBarTheme.titleTextStyle;
    return FittedBox(
      fit: BoxFit.scaleDown,
      // `centerStart` y no `center`: alineado al centro, un titulo escalado se
      // despega del borde y parece descolocado respecto al resto de pantallas.
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        texto,
        maxLines: 1,
        style: (estilo ?? AppTextStyles.titleLarge).copyWith(
          fontSize: AppTextStyles.titleMedium.fontSize,
          fontWeight: AppTextStyles.titleMedium.fontWeight,
        ),
      ),
    );
  }
}
