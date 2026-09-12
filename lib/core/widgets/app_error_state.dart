import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';

/// UX-04: el estado de "no se pudo cargar" de una pantalla que consulta datos.
///
/// Se apoya en [AppEmptyState] en vez de repetir su maquetado porque el hueco
/// que dejan un error y una lista vacia es el MISMO hueco, y ya traia resueltos
/// la medida de lectura y el `Semantics` que anuncia el bloque entero.
///
/// Lo que anade —y es la mitad de esta tarea— es [onReintentar]. El sitio que
/// nombra el plan fallaba tipicamente por `unavailable`: una red que se cayo un
/// segundo dejaba la pantalla muerta hasta salir y volver a entrar. Un mensaje
/// amable sin salida sigue siendo un callejon sin salida.
class AppErrorState extends StatelessWidget {
  /// Mensaje ya traducido y ya libre de detalle tecnico. Se construye con
  /// `mensajeDeError()`, que ademas manda la excepcion al log.
  final String mensaje;

  /// Si es null no se pinta el boton: hay errores ante los que reintentar no
  /// arregla nada, y ofrecerlo seria mentir.
  final VoidCallback? onReintentar;

  const AppErrorState({super.key, required this.mensaje, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppEmptyState(
      title: context.l10n.errorDatosTitulo,
      description: mensaje,
      icon: Icons.cloud_off_outlined,
      action: onReintentar == null
          ? null
          : TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.errorReintentar),
              style: TextButton.styleFrom(foregroundColor: colors.primary),
            ),
    );
  }
}
