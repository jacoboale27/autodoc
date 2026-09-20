import 'package:intl/intl.dart';

import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Texto visible de una alerta, localizado.
///
/// **Por qué el provider no lo arma.** `AlertProvider` no tiene
/// `BuildContext` ni locale, así que cualquier prosa que escriba ahí nace en
/// español y no hay forma de traducirla: es exactamente el origen de una parte
/// de los literales sin traducir que el proyecto arrastra. Las alertas
/// generadas viajan con su **tipo** y sus **datos** en `metadata`, y el texto
/// se arma aquí, donde sí hay `AppLocalizations`.
///
/// Ese patrón ya existía para `MantenimientoInconsistente`, duplicado a mano
/// en dos pantallas. Aquí vive una sola vez, y lo usan las tres que pintan
/// alertas — la del propietario, el panel y la del mecánico.
///
/// Las alertas **heredadas** de Firestore (las que traen su propia prosa
/// guardada) caen al `else` y se pintan tal cual: son datos, no plantillas.
class TextoDeAlerta {
  const TextoDeAlerta(this.titulo, this.descripcion);

  final String titulo;
  final String descripcion;
}

TextoDeAlerta textoDeAlerta(AppLocalizations l10n, AlertModel alerta) {
  switch (alerta.tipoAlerta) {
    case 'SOAT':
      return _documento(
        l10n,
        alerta,
        tituloPorVencer: l10n.alertsSoatExpiringTitle,
        tituloVencido: l10n.alertsSoatExpiredTitle,
      );

    case 'Tarjeta':
      return _documento(
        l10n,
        alerta,
        tituloPorVencer: l10n.alertsCardExpiringTitle,
        tituloVencido: l10n.alertsCardExpiredTitle,
      );

    case 'MantenimientoInconsistente':
      return TextoDeAlerta(
        alerta.titulo,
        l10n.alertsInconsistentMileage(
          NumberFormat('#,###').format(alerta.metadata?['ultimo_km'] ?? 0),
        ),
      );

    default:
      return TextoDeAlerta(alerta.titulo, alerta.descripcion);
  }
}

TextoDeAlerta _documento(
  AppLocalizations l10n,
  AlertModel alerta, {
  required String tituloPorVencer,
  required String tituloVencido,
}) {
  final dias = alerta.metadata?['dias_restantes'];

  // Una alerta de documento SIN sus días es una heredada de Firestore, no una
  // generada: se pinta con lo que traiga guardado en vez de inventar un «0».
  if (dias is! int) {
    return TextoDeAlerta(alerta.titulo, alerta.descripcion);
  }

  // El título tiene que concordar con el cuerpo: «por vencer» encabezando
  // «venció hace 38 días» se lee como un dato equivocado, y es justo la
  // alerta en la que la persona necesita creerle a la app.
  if (dias < 0) {
    return TextoDeAlerta(
      tituloVencido,
      l10n.alertsDocExpiredDaysAgo(dias.abs()),
    );
  }
  if (dias == 0) {
    return TextoDeAlerta(tituloPorVencer, l10n.alertsDocExpiresToday);
  }
  return TextoDeAlerta(tituloPorVencer, l10n.alertsDocExpiresInDays(dias));
}
