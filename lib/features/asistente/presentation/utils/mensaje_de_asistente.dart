import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:autodoc/core/utils/mensaje_de_error.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Los cuatro motivos que el servidor publica en `details`.
///
/// Espejo de `MOTIVOS` en `functions/src/asistente.js`, que filtra contra esta
/// misma lista antes de dejar salir nada: lo que no esta ahi no llega aqui.
/// Se declaran como constantes y no como cadenas sueltas porque son un
/// contrato entre dos repositorios de codigo distintos, y una errata en una
/// cadena suelta no la ve ningun compilador — simplemente cae al caso por
/// defecto y el mensaje vuelve a ser el ambiguo de antes.
abstract final class MotivoAsistente {
  static const cupoUsuario = 'cupo_usuario';
  static const cupoGlobal = 'cupo_global';
  static const apagado = 'apagado';
  static const proveedor = 'proveedor';
}

/// IA-01 — traduce el rechazo de `asistenteAutoDoc` a algo accionable.
///
/// **El mapeo por defecto de UX-04 no vale aqui, y no por matices.** Es el
/// mismo razonamiento que obligo a escribir `mensajeDePaseHistorial` en
/// INNO-01, con otros codigos:
///
///   - `mensajeDeError` manda `unavailable` y `deadline-exceeded` a *"revisa
///     tu conexion"*. Aqui `unavailable` significa que el asistente esta
///     apagado o que el proveedor esta caido. Ninguna de las dos se arregla
///     mirando el wifi.
///   - `resource-exhausted` no es un fallo: es el cupo diario, que este
///     asistente corta a proposito para no quedarse sin cuota del proveedor a
///     media demo. Decir "algo fallo" ahi invita a reintentar lo unico que no
///     puede funcionar hoy.
///   - `permission-denied` no es "vuelve a iniciar sesion": lo lanza
///     `agenda.js` cuando un taller todavia no esta aprobado, y volver a
///     entrar no aprueba a nadie.
///
/// **Dos codigos cubren cuatro situaciones, y por eso se mira `details`.**
/// `resource-exhausted` es tu cupo o el del asistente entero; `unavailable` es
/// el interruptor o el proveedor. Las cuatro se parecen sobre el papel y no se
/// parecen en nada para quien pregunta: una es culpa suya, otra no es culpa de
/// nadie, de una se sale reintentando en un minuto y de la otra no se sale
/// hasta que alguien vuelva a encender el interruptor. Con un solo codigo por
/// par, el texto miente en la mitad de los casos y el boton de reintentar
/// sobra en la otra mitad.
///
/// Los codigos salen de la lista de `conocidos` del callable en
/// `functions/index.js`; cualquier otro cae en el mensaje generico de UX-04,
/// que ya registra el detalle tecnico en el log sin ensenarlo.
String mensajeDeAsistente(AppLocalizations l10n, Object? error) {
  final codigo = error is FirebaseFunctionsException ? error.code : null;
  final motivo = _motivo(error);

  return switch (codigo) {
    'resource-exhausted' =>
      motivo == MotivoAsistente.cupoGlobal
          ? l10n.asistenteErrorCupoGlobal
          : l10n.asistenteErrorCupo,
    // Sin motivo se cae del lado del proveedor a proposito: es el unico de los
    // dos que se arregla solo, asi que es el unico ante el que tiene sentido
    // ofrecer un reintento. Prometer que el interruptor se va a encender solo
    // seria la version que si deja a alguien esperando.
    'unavailable' =>
      motivo == MotivoAsistente.apagado
          ? l10n.asistenteErrorApagado
          : l10n.asistenteErrorProveedor,
    // Falta la clave, o el modelo configurado no existe o no esta en el free
    // tier (404 / 402 de Gemini). Es un fallo de despliegue: reintentar no lo
    // arregla nunca, y por eso este codigo no merece boton.
    'failed-precondition' => l10n.asistenteErrorNoDisponible,
    'deadline-exceeded' => l10n.asistenteErrorLento,
    // El filtro de seguridad de Google, o una respuesta vacia.
    'aborted' => l10n.asistenteErrorSinRespuesta,
    'permission-denied' => l10n.asistenteErrorTallerPendiente,
    'invalid-argument' => l10n.asistenteErrorPreguntaVacia,
    _ => mensajeDeError(l10n, error),
  };
}

/// El titular y el icono del estado de error, cuando el generico miente.
///
/// **El mensaje ya era correcto; lo que mentia era lo de encima.** El estado
/// de error comun de UX-04 corona con «No pudimos cargar esta información» y
/// una nube tachada — la estampa de «no hay internet». Sobre los cuatro
/// estados de abajo eso es falso, y ademas se contradice con el texto que
/// tiene justo debajo:
///
///   - el cupo agotado no fallo: se acabaron las consultas del dia;
///   - el interruptor apagado no fallo: alguien lo apago a proposito;
///   - un taller sin aprobar no fallo: le falta una aprobacion;
///   - una pregunta vacia no fallo: falta escribirla.
///
/// Es exactamente el defecto que [mensajeDeAsistente] corrige un piso mas
/// abajo, y por eso vive al lado: separar los dos invitaria a arreglar uno y
/// dejar el otro, que es como se llego a esto.
///
/// **Los demas codigos se quedan con el generico a proposito.** El proveedor
/// caido, la respuesta vacia o el tiempo agotado SI son un fallo de carga, y
/// para esos la nube y el titular dicen la verdad. Cambiarlos todos por
/// simetria habria sido sustituir un texto equivocado por otro.
({String titulo, IconData icono})? presentacionDeAsistente(
  AppLocalizations l10n,
  Object? error,
) {
  final codigo = error is FirebaseFunctionsException ? error.code : null;

  return switch (codigo) {
    // Los dos cupos comparten titular: para quien pregunta, la diferencia
    // entre su cupo y el global la cuenta el MENSAJE, y el titular solo tiene
    // que dejar de hablar de una carga que no ocurrio.
    'resource-exhausted' => (
      titulo: l10n.asistenteTituloCupo,
      icono: Icons.hourglass_bottom_outlined,
    ),
    // Solo el interruptor. El proveedor caido comparte codigo y se queda con
    // el generico, que para el es correcto.
    'unavailable' =>
      _motivo(error) == MotivoAsistente.apagado
          ? (
              titulo: l10n.asistenteTituloApagado,
              icono: Icons.power_settings_new_outlined,
            )
          : null,
    'permission-denied' => (
      titulo: l10n.asistenteTituloTallerPendiente,
      icono: Icons.pending_outlined,
    ),
    'invalid-argument' => (
      titulo: l10n.asistenteTituloPreguntaVacia,
      icono: Icons.edit_outlined,
    ),
    _ => null,
  };
}

/// `true` solo si volver a preguntar puede dar un resultado distinto.
///
/// Es el patron de `paseMereceReintento` (INNO-01): donde reintentar no puede
/// funcionar nunca, el boton **se retira**, no se deja gris. Un boton que
/// siempre falla es peor que no tenerlo — ensena que la app esta rota cuando
/// lo que pasa es que hoy ya no quedan consultas.
///
/// El motivo es lo que permite afinar `unavailable`: con el interruptor
/// apagado reintentar no puede funcionar hasta que alguien lo encienda, y con
/// el proveedor caido si. Antes de tener el motivo los dos compartian
/// respuesta, y habia que elegir cual de los dos errores tratar mal.
bool asistenteMereceReintento(Object? error) {
  final codigo = error is FirebaseFunctionsException ? error.code : null;

  if (codigo == 'unavailable') {
    return _motivo(error) != MotivoAsistente.apagado;
  }

  return !const {
    'resource-exhausted',
    'failed-precondition',
    'permission-denied',
    'invalid-argument',
    'unauthenticated',
  }.contains(codigo);
}

/// El motivo publicado por el servidor, o `null`.
///
/// `details` es `dynamic` y lo rellena el servidor, asi que se comprueba el
/// tipo en vez de castearlo: un `details` que no sea cadena —un mapa de otro
/// callable, un numero— no debe reventar la pantalla de error, que es
/// precisamente la pantalla que se esta pintando cuando esto se ejecuta.
String? _motivo(Object? error) {
  if (error is! FirebaseFunctionsException) return null;
  final detalles = error.details;
  return detalles is String ? detalles : null;
}
