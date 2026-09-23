/// El municipio de un taller tal y como llega en su proyeccion publica.
///
/// `UserModel` arrastra DOS nombres para el mismo dato —`ubicacion_municipio`
/// y `municipio`— y los serializa por separado. Lo que `publishTallerProfile`
/// escribe en la coleccion `talleres` es `municipio`.
///
/// Leer solo uno de los dos es un defecto medido, no teorico: el 2026-09-22
/// los DIECISEIS talleres del directorio decian «Ubicacion no especificada»
/// mientras el perfil de cada uno la mostraba bien. Vive aqui, y no junto a
/// una pantalla, porque el mismo dato lo leen el directorio y el panel de
/// administracion: duplicar la eleccion de campo es justo lo que produjo el
/// fallo.
///
/// Se mira `ubicacion_municipio` primero por retrocompatibilidad con fichas
/// antiguas que puedan traerlo; el campo canonico de la proyeccion es
/// `municipio`.
String? municipioDeTaller(Map<String, dynamic> data) {
  final preferente = data['ubicacion_municipio'];
  if (preferente is String && preferente.trim().isNotEmpty) return preferente;
  final canonico = data['municipio'];
  if (canonico is String && canonico.trim().isNotEmpty) return canonico;
  return null;
}
