import 'package:autodoc/core/models/user_model.dart';

/// Estado del expediente de verificacion de un taller.
///
/// ## Por que existe un segundo eje
///
/// `usuarios/{uid}.estado` (ver [AppEstadoCuenta]) responde a UNA pregunta:
/// ¿puede este taller operar? Es el campo que leen `isMecanico()` en
/// `firestore.rules` y el guard de `resolveRedirect`, y es texto libre que ya
/// arrastra dos vocabularios ('activo' y 'aprobado') para el mismo si.
///
/// El onboarding necesita responder OTRA pregunta distinta: ¿en que punto del
/// tramite esta su expediente? Meter 'perfil_incompleto' o 'en_revision' en
/// ese mismo campo obligaria a tocar `isMecanico()` —la unica pieza que impide
/// que cualquiera se registre como taller y lea vehiculos ajenos—, asi que se
/// modela aparte, en `verificaciones/{uid}.estado_verificacion`.
///
/// ## Regla que no se negocia
///
/// **Este enum NUNCA decide el acceso.** Quien opera y quien no lo dice
/// `AppEstadoCuenta.aprobados` sobre `usuarios.estado`, y punto. Un
/// [EstadoVerificacion.aprobada] es un registro de auditoria de que la
/// revision concluyo, no una llave. Los dos vocabularios estan construidos
/// para no compartir ni un solo valor (hay un test que lo fija), justamente
/// para que un `==` contra el campo equivocado no compile un falso positivo.
enum EstadoVerificacion {
  /// Registrado, pero le faltan datos obligatorios: todavia no hay nada que
  /// un administrador pueda revisar. Estado inicial y default conservador.
  perfilIncompleto,

  /// Perfil completo y a la espera de que un administrador tome el caso.
  listoParaRevision,

  /// Un administrador lo tiene abierto. Existe como paso propio para que dos
  /// administradores no resuelvan el mismo expediente a la vez.
  enRevision,

  /// Revision concluida a favor. Registro de auditoria: el acceso real lo
  /// concede `usuarios.estado`, no este valor.
  aprobada,

  /// Denegado. El taller puede corregir y reenviar.
  rechazada,
}

/// Fuente unica de verdad sobre `verificaciones/{uid}.estado_verificacion`.
///
/// Mismo patron que [AppEstadoCuenta] para el otro eje: parseo tolerante,
/// serializacion simetrica y las transiciones legales en un solo sitio.
class AppEstadoVerificacion {
  AppEstadoVerificacion._();

  static const Map<EstadoVerificacion, String> _texto = {
    EstadoVerificacion.perfilIncompleto: 'perfil_incompleto',
    EstadoVerificacion.listoParaRevision: 'listo_para_revision',
    EstadoVerificacion.enRevision: 'en_revision',
    EstadoVerificacion.aprobada: 'aprobada',
    EstadoVerificacion.rechazada: 'rechazada',
  };

  /// Texto con el que el estado viaja a Firestore.
  static String serializar(EstadoVerificacion estado) => _texto[estado]!;

  /// Traduce el texto de Firestore a un [EstadoVerificacion].
  ///
  /// Cualquier valor desconocido —incluido ausente o vacio— cae en
  /// [EstadoVerificacion.perfilIncompleto]: el default conservador es "aun no
  /// hay expediente", nunca uno mas avanzado del real.
  static EstadoVerificacion parse(String? estado) {
    final normalizado = (estado ?? '').trim().toLowerCase();
    for (final entrada in _texto.entries) {
      if (entrada.value == normalizado) return entrada.key;
    }
    return EstadoVerificacion.perfilIncompleto;
  }

  /// Transiciones legales del expediente.
  ///
  /// - Un perfil incompleto solo puede completarse.
  /// - `listoParaRevision` no se resuelve en caliente: un administrador
  ///   primero toma el caso (`enRevision`). Tambien puede volver atras si el
  ///   taller borra un dato obligatorio de su perfil.
  /// - Solo desde `enRevision` se aprueba o se rechaza.
  /// - Un rechazo no es terminal: el taller corrige y reenvia.
  /// - Una verificacion aprobada se reabre (re-revision) cuando el taller
  ///   cambia datos publicos ya verificados. Sin esta arista, verificar seria
  ///   un sello de un solo uso: bastaria con aprobar y cambiarlo todo despues.
  ///   Vuelve a `listoParaRevision` y no a `enRevision`: un expediente
  ///   reabierto esta en la cola, todavia no lo esta mirando nadie, y saltarse
  ///   el paso de tomar el caso es lo que permitiria que dos administradores
  ///   lo resolvieran a la vez. La reapertura la escribe una Cloud Function
  ///   (`functions/src/reabrirVerificacion.js`), no el cliente: si dependiera
  ///   de la app, bastaria con escribir en Firestore por otra via para
  ///   esquivarla.
  static const Map<EstadoVerificacion, Set<EstadoVerificacion>> _transiciones =
      {
        EstadoVerificacion.perfilIncompleto: {
          EstadoVerificacion.listoParaRevision,
        },
        EstadoVerificacion.listoParaRevision: {
          EstadoVerificacion.enRevision,
          EstadoVerificacion.perfilIncompleto,
        },
        EstadoVerificacion.enRevision: {
          EstadoVerificacion.aprobada,
          EstadoVerificacion.rechazada,
        },
        EstadoVerificacion.aprobada: {EstadoVerificacion.listoParaRevision},
        EstadoVerificacion.rechazada: {
          EstadoVerificacion.listoParaRevision,
          EstadoVerificacion.perfilIncompleto,
        },
      };

  /// Estados a los que `origen` puede pasar legalmente.
  static Set<EstadoVerificacion> transicionesDesde(EstadoVerificacion origen) =>
      _transiciones[origen] ?? const {};

  /// ¿Es legal pasar de `origen` a `destino`?
  ///
  /// Quedarse en el mismo estado no es una transicion: devuelve `false` para
  /// que un re-guardado sin cambios no genere log de auditoria ni notificacion.
  static bool puedeTransicionar(
    EstadoVerificacion origen,
    EstadoVerificacion destino,
  ) => transicionesDesde(origen).contains(destino);

  /// Campos del perfil que un administrador necesita para poder verificar,
  /// en el orden en que los pide `workshop_settings_screen`.
  ///
  /// La barra es deliberadamente MAS ALTA que la del formulario de ajustes:
  /// ahi el telefono es opcional (`workshop_settings_screen.dart:538` devuelve
  /// `null` con el campo vacio) porque guardar un borrador debe ser barato.
  /// Para publicar el taller en un directorio publico no lo es: sin telefono
  /// el administrador no tiene como contrastar que el negocio existe.
  ///
  /// Devuelve etiquetas legibles y en orden estable para poder pintarlas tal
  /// cual como checklist de onboarding.
  static List<String> camposFaltantes(UserModel taller) {
    bool vacio(String? valor) => (valor ?? '').trim().isEmpty;

    return <String>[
      if (vacio(taller.nombreCompleto)) 'Nombre del taller',
      if (vacio(taller.telefono)) 'Teléfono de contacto',
      if (vacio(taller.especialidad)) 'Especialidad',
      if (vacio(taller.departamento)) 'Departamento',
      if (vacio(taller.municipio)) 'Municipio',
      // Las coordenadas son un par: media ubicacion no situa nada en el mapa,
      // asi que se reportan como un unico campo faltante.
      if (taller.latitud == null || taller.longitud == null)
        'Ubicación en el mapa',
    ];
  }

  /// ¿Tiene el perfil todo lo que exige la revision?
  static bool perfilCompleto(UserModel taller) =>
      camposFaltantes(taller).isEmpty;
}
