import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Redirige los SDK de Firebase a los emuladores locales.
///
/// Existe para que la suite E2E pueda ejercer la app de verdad sin tocar
/// producción. Antes de esto no había ninguna vía para apuntar la app a un
/// emulador, así que `e2e/` iniciaba sesión con cuentas fijas contra el
/// Firebase real y `registro.spec.js` creaba usuarios nuevos en producción en
/// cada corrida.
///
/// **Doble candado, a propósito.** No basta con el `--dart-define`: se exige
/// además que el build no sea de release. Un flag de compilación es una cadena
/// en una línea de comandos, y esa línea se copia entre scripts; el día que
/// alguien arrastre `USE_FIREBASE_EMULATOR=true` a un build de producción, el
/// binario publicado apuntaría a un `localhost` que en el móvil del usuario no
/// existe —o, peor, al de quien esté en la misma red—. `kReleaseMode` es una
/// constante del compilador, así que en un build de release este archivo entero
/// se elimina por tree-shaking y la conexión no puede ocurrir de ninguna forma.
const bool _flagEmuladores = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Host de los emuladores. `localhost` por defecto porque la app web servida
/// para E2E vive en la misma máquina; se puede sobreescribir para un emulador
/// en otro equipo o en Docker.
const String _hostEmuladores = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);

/// Puertos canónicos: los mismos de `firebase.json` y `test_rules/helpers.js`.
/// No se parametrizan a propósito — son compartidos, y esquivar una colisión
/// local cambiándolos aquí desincroniza la app de las suites de reglas.
const int _puertoAuth = 9099;
const int _puertoFirestore = 8080;
const int _puertoStorage = 9199;
const int _puertoFunctions = 5001;

/// `true` sólo si se pidió el modo emulador Y el build lo permite.
bool get usarEmuladoresFirebase => _flagEmuladores && !kReleaseMode;

/// Conecta Auth, Firestore, Storage y Functions a los emuladores locales.
///
/// Functions se anadio con INNO-01: el pase temporal de historial vive entero
/// en tres callables, asi que sin este cableado la demo E2E hablaria con las
/// funciones de PRODUCCION desde una suite que se cree aislada — o, con las
/// claves falsas del bundle de E2E, no hablaria con nada y el fallo se leeria
/// como un defecto de la pantalla.
///
/// Debe llamarse después de `Firebase.initializeApp()` y antes de la primera
/// operación contra cualquiera de los tres SDK.
Future<void> conectarEmuladoresFirebase() async {
  if (!usarEmuladoresFirebase) return;

  await FirebaseAuth.instance.useAuthEmulator(_hostEmuladores, _puertoAuth);
  FirebaseFirestore.instance.useFirestoreEmulator(
    _hostEmuladores,
    _puertoFirestore,
  );
  await FirebaseStorage.instance.useStorageEmulator(
    _hostEmuladores,
    _puertoStorage,
  );
  FirebaseFunctions.instance.useFunctionsEmulator(
    _hostEmuladores,
    _puertoFunctions,
  );

  debugPrint(
    '=== [AutoDoc Init] EMULADORES: Auth :$_puertoAuth, '
    'Firestore :$_puertoFirestore, Storage :$_puertoStorage, '
    'Functions :$_puertoFunctions en $_hostEmuladores '
    '— NO se esta usando produccion ===',
  );
}
