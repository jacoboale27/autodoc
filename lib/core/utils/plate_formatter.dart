import 'package:flutter/services.dart';

/// Tipos de placa que AutoDoc sabe registrar, con la letra que el VMT usa
/// para cada uno.
///
/// En El Salvador hay unos 19 tipos (autobús `AB`, cuerpo diplomático `CD`,
/// consular `CC`, etc.); estos cuatro son los que cubre la app.
enum TipoPlaca {
  particular('P'),
  moto('M'),
  carga('C'),
  alquiler('A');

  const TipoPlaca(this.prefijo);

  /// Letra inicial de la placa.
  final String prefijo;
}

/// Formatea una placa vehicular de El Salvador.
///
/// Reglas del VMT (ver `docs/placas-el-salvador.md` para las fuentes):
///
///  * La primera letra identifica el tipo de vehículo. La elige quien
///    registra ([tipo]), no se adivina del texto.
///  * Detrás va el correlativo, de 4 a 6 caracteres hexadecimales (`0-9` y
///    `A-F`). El esquema alfanumérico que el VMT empezó a entregar en agosto
///    de 2021, al pasar del millón de vehículos particulares, metió las
///    letras `A`-`F` en la numeración; la primera placa emitida fue
///    `P 001 00A`.
///  * El correlativo **no se rellena con ceros a la izquierda**, así que
///    circulan placas de cinco caracteres (`P12-345`) además de las de seis
///    (`P123-456`). Cubrir solo `P###-###` dejaba fuera a esos vehículos.
///
/// El guion "flota" desde la derecha mientras se escribe: siempre separa los
/// tres últimos caracteres del resto.
class PlateFormatter extends TextInputFormatter {
  const PlateFormatter({this.tipo = TipoPlaca.particular});

  /// Tipo de placa que decide el prefijo. Lo fija el selector del
  /// formulario de registro.
  final TipoPlaca tipo;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.trim().toUpperCase();

    // El prefijo se quita UNA sola vez y luego se vuelve a anteponer, de modo
    // que da igual si el usuario lo escribió o no. Ojo con hacerlo a base de
    // filtrar caracteres: `A` (alquiler) y `C` (carga) son también dígitos
    // hexadecimales válidos dentro del correlativo, así que un filtro se
    // comería la letra buena. Por eso se recorta solo el primer carácter.
    if (text.startsWith(tipo.prefijo)) {
      text = text.substring(1);
    }

    final formatted = componerPlaca(tipo, text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Máximo de caracteres del correlativo (hasta 3 + los 3 finales).
const int _maxCaracteresCorrelativo = 6;

/// Arma la placa a partir del [tipo] y un [correlativo] **sin prefijo**:
/// limpia lo que no sea hexadecimal, recorta al máximo y coloca el guion
/// delante de los tres últimos caracteres.
///
/// A diferencia de [PlateFormatter], aquí el prefijo no se adivina ni se
/// recorta: viene dado. Eso es justo lo que necesita el selector de tipo del
/// formulario, que al cambiar de tipo debe recomponer la placa sin comerse un
/// correlativo que empiece por `A` o por `C`.
String componerPlaca(TipoPlaca tipo, String correlativo) {
  var text = correlativo.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  if (text.length > _maxCaracteresCorrelativo) {
    text = text.substring(0, _maxCaracteresCorrelativo);
  }
  // Con 3 caracteres o menos aún no se sabe qué parte es el primer grupo,
  // así que no se pinta el guion todavía.
  if (text.length <= 3) {
    return '${tipo.prefijo}$text';
  }
  final corte = text.length - 3;
  return '${tipo.prefijo}${text.substring(0, corte)}-${text.substring(corte)}';
}

/// Normaliza cualquier variante de una placa (con o sin guion, minúsculas,
/// espacios, etc.) a la misma forma canónica que produce [PlateFormatter]
/// mientras el usuario escribe. Se usa para comparar/consultar placas
/// (búsqueda del mecánico, escaneo QR) contra lo que ya quedó guardado al
/// registrar el vehículo, evitando que ambos flujos diverjan.
///
/// A diferencia del formulario de registro, aquí **nadie elige el tipo**: se
/// toma de la primera letra del texto, y se asume particular si no trae una
/// conocida. `A` y `C` son ambiguas (valen como prefijo y como dígito
/// hexadecimal); se resuelven a favor del prefijo, porque quien busca teclea
/// la placa tal como está estampada, con su letra delante.
///
/// Los ceros a la izquierda se respetan tal cual: `P001-00A` y `P1-00A` son
/// placas distintas, porque en el esquema alfanumérico el correlativo se
/// imprime rellenado a tres posiciones.
String normalizarPlaca(String input) {
  final texto = input.trim().toUpperCase();
  final tipo = TipoPlaca.values.firstWhere(
    (t) => texto.startsWith(t.prefijo),
    orElse: () => TipoPlaca.particular,
  );
  return PlateFormatter(tipo: tipo)
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: texto,
          selection: TextSelection.collapsed(offset: texto.length),
        ),
      )
      .text;
}

/// Patrón completo de una placa válida: la letra del tipo, de 1 a 3
/// caracteres hexadecimales, guion, y 3 caracteres hexadecimales más.
final RegExp placaElSalvadorPattern = RegExp(
  r'^[PMCA][0-9A-F]{1,3}-[0-9A-F]{3}$',
);

/// Validador de formulario para el campo de placa. Devuelve `null` si es
/// válida, o un mensaje de error para mostrar en el `TextFormField`.
String? validarPlacaElSalvador(String? value) {
  final placa = value?.trim().toUpperCase() ?? '';
  if (placa.isEmpty) {
    return 'La placa es obligatoria';
  }
  if (!placaElSalvadorPattern.hasMatch(placa)) {
    return 'Formato inválido. Ej: P123-456 o P12-345';
  }
  return null;
}
