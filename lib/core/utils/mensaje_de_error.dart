import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';

import 'package:autodoc/l10n/app_localizations.dart';

/// UX-04: traduce un error a algo que una persona pueda leer y usar.
///
/// El enunciado del plan nombra UN sitio —el `'Error: ${snapshot.error}'` de
/// `service_history_screen.dart`— pero al inventariar salieron unos cuarenta, y
/// el grupo que mas asusta no es el que se ve crudo a simple vista: es el de
/// las cadenas que YA estan traducidas y aun asi meten la excepcion dentro
/// (`adminError` = "Error: {error}", `upErrorUploadingImage`). Tener la frase
/// en espanol no sirve de nada si el hueco lo rellena un `FirebaseException`
/// con su plugin, su codigo y, en el caso de `failed-precondition`, la consulta
/// entera y un enlace a la consola de Firebase del proyecto.
///
/// Dos decisiones que parecen detalles y no lo son:
///
///   - **Se distingue red de permisos.** Colapsar todo en "algo fallo" deja a
///     la persona sin saber si reintentar sirve de algo. Reintentar arregla un
///     `unavailable`; ante un `permission-denied` no va a arreglar nada nunca.
///   - **El detalle tecnico no se pierde, se MUEVE.** Va a `developer.log`, que
///     es donde puede verlo quien depura sin que lo vea quien usa la app. Un
///     error que no se muestra pero tampoco se registra es peor que el defecto
///     original: deja de haber pista alguna.
String mensajeDeError(AppLocalizations l10n, Object? error) {
  developer.log(
    'Error mostrado al usuario',
    name: 'autodoc.error',
    error: error,
  );

  if (error is FirebaseException) {
    return switch (error.code) {
      // Storage dice 'unauthorized'; Firestore, 'permission-denied'.
      'permission-denied' || 'unauthorized' => l10n.errorDatosPermiso,
      'unavailable' ||
      'deadline-exceeded' ||
      'retry-limit-exceeded' ||
      'network-request-failed' => l10n.errorDatosConexion,
      // Estos tres estaban SOLO en `mensajeSeguroDeError`, la version en
      // espanol para providers, asi que quien tenia la app en ingles recibia
      // menos informacion que quien la tenia en espanol: leia «algo salio
      // mal, intentalo mas tarde» —que ademas invita a reintentar algo que no
      // va a funcionar— en vez de «no encontramos ese dato». Lo vigila el
      // centinela de paridad de `test/core/mensaje_de_error_test.dart`.
      'not-found' => l10n.errorDatosNoEncontrado,
      'already-exists' => l10n.errorDatosYaExiste,
      'canceled' => l10n.errorDatosCancelado,
      // `failed-precondition` cae aqui a proposito y NO tiene mensaje propio:
      // en esta app significa casi siempre una consulta sin indice compuesto,
      // o sea un fallo nuestro que la persona no puede resolver ni entender.
      // Lo unico honesto que se le puede decir es que lo intente mas tarde.
      _ => l10n.errorDatosGenerico,
    };
  }

  return l10n.errorDatosGenerico;
}

/// Version sin `BuildContext` de [mensajeDeError], para los providers y para
/// las pantallas que avisan con un SnackBar.
///
/// Existe porque el problema de UX-04 no estaba solo en la pantalla que nombra
/// el plan. Al inventariarlo aparecio el patron de verdad: **quince providers
/// guardaban `_error = e.toString()`** —setenta y siete sitios— y las pantallas
/// pintan ese campo tal cual (`UiUtils.showErrorSnackbar(context,
/// provider.error!)`, `Text(provider.error!)`). Por eso seguian filtrando hasta
/// los mensajes que YA estaban traducidos: la frase venia del ARB, pero el
/// hueco lo rellenaba un `FirebaseException` con su plugin y su codigo dentro.
/// Y donde la pantalla hacia `provider.error ?? context.l10n.loQueSea`, la
/// traduccion no llegaba a verse NUNCA — el error crudo no es null cuando algo
/// falla, asi que el `??` jamas caia del lado traducido.
///
/// [accion] conserva lo que la pantalla ya sabia decir ("No se pudo subir la
/// foto") y solo sustituye el detalle tecnico por el motivo. Juntas dicen mas
/// que cualquiera de las dos por separado: que fallo, y si reintentar sirve.
///
/// El texto va en espanol y sin pasar por el ARB, que es exactamente lo que ya
/// hacian los dos providers que si trataban esto bien (`galeria_provider`,
/// `verificacion_provider`). Un provider no tiene `BuildContext`, y darle uno
/// para esto seria peor que el problema. Cuando la pantalla SI puede traducir
/// —porque tiene contexto y esta pintando un estado, no un aviso— usa
/// [mensajeDeError]; eso es lo que hace el historial de servicios.
String mensajeSeguroDeError(Object? error, {String? accion}) {
  developer.log(
    accion ?? 'Error mostrado al usuario',
    name: 'autodoc.error',
    error: error,
  );

  return '${accion ?? 'No se pudo completar la operacion'}. ${_motivo(error)}';
}

String _motivo(Object? error) {
  if (error is! FirebaseException) {
    return 'Intentalo de nuevo en un momento.';
  }
  return switch (error.code) {
    // Storage dice 'unauthorized'; Firestore, 'permission-denied'.
    'permission-denied' || 'unauthorized' =>
      'No tienes permiso. Si crees que deberias tenerlo, vuelve a iniciar '
          'sesion.',
    'unavailable' ||
    'deadline-exceeded' ||
    'retry-limit-exceeded' ||
    'network-request-failed' => 'Revisa tu conexion e intentalo de nuevo.',
    'not-found' => 'No encontramos ese dato.',
    'already-exists' => 'Ese dato ya existe.',
    'canceled' => 'La operacion se cancelo.',
    // Codigos de Auth. Estos NO pueden caer en el generico: son los unicos
    // errores de toda la app que la persona si puede resolver por si misma, y
    // decirle "intentalo de nuevo en un momento" cuando lo que pasa es que la
    // contrasena esta mal la deja dando vueltas. Antes se veian, pero crudos y
    // en ingles: `[firebase_auth/email-already-in-use] The email address is
    // already in use by another account.`
    'email-already-in-use' =>
      'Ese correo ya tiene una cuenta. Inicia sesion o recupera tu contrasena.',
    'invalid-email' => 'Ese correo no parece valido.',
    'weak-password' => 'La contrasena es demasiado debil. Usa una mas larga.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'El correo o la contrasena no coinciden.',
    'user-disabled' => 'Esta cuenta esta deshabilitada.',
    'too-many-requests' =>
      'Demasiados intentos seguidos. Espera un momento y vuelve a probar.',
    'requires-recent-login' =>
      'Por seguridad, vuelve a iniciar sesion antes de hacer este cambio.',
    'account-exists-with-different-credential' =>
      'Ese correo ya tiene una cuenta creada con otro metodo de acceso.',
    'operation-not-allowed' => 'Ese metodo de acceso no esta habilitado.',
    _ => 'Intentalo de nuevo en un momento.',
  };
}

/// Para los sitios donde ESTE codigo lanza `StateError` a proposito con un
/// texto ya escrito para una persona ("Ya dejaste una resena para este
/// servicio", "Este servicio no corresponde a este taller" — hay ocho asi en
/// `ReviewService`).
///
/// Se separa de [mensajeSeguroDeError] en vez de meter el caso dentro porque
/// la diferencia importa: ahi el `StateError` es un mensaje redactado; en
/// cualquier otro sitio un `StateError` es un fallo de programacion ("Bad
/// state: No element") y ensenarlo seria exactamente el defecto que cierra
/// UX-04. Solo se usa donde consta que el que lanza es nuestro.
///
/// Lo que habia antes era `e.toString().replaceFirst('StateError: ', '')`: se
/// leia como si distinguiera, y no distinguia nada — a un `FirebaseException`
/// le dejaba pasar el `[cloud_firestore/...]` entero.
String mensajeDeReglaDeNegocio(Object? error, {String? accion}) {
  if (error is StateError) return error.message;
  return mensajeSeguroDeError(error, accion: accion);
}
