import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Las acciones de la barra superior, iguales en TODAS las pantallas.
///
/// Observaciones del 2026-09-19: el cambio de tema, el de idioma y la campana
/// solo estaban en el dashboard de cada rol (y el avatar solo en la barra
/// superior de escritorio del propietario), así que en cuanto el usuario
/// entraba a cualquier otra pantalla desaparecían. Se pidió que estuvieran en
/// todas: el taller con tema, idioma y campana; el propietario, además, con
/// su avatar, que lleva a su perfil.
///
/// Es la única copia de estos controles: la barra de escritorio del
/// propietario (`AppTopNavBar`) y el `MechanicScaffold` la usan tal cual, y
/// cada pantalla suelta la pone en su `AppBar`.
///
/// Si falta alguno de los providers (solo pasa en tests que montan una
/// pantalla aislada), ese control no se pinta en vez de romper la pantalla.
class AccionesDeCabecera extends StatelessWidget {
  /// La pantalla de notificaciones no necesita su propio acceso directo.
  final bool mostrarCampana;

  /// `null` = según el rol: solo el propietario lleva avatar.
  final bool? mostrarAvatar;

  const AccionesDeCabecera({
    super.key,
    this.mostrarCampana = true,
    this.mostrarAvatar,
  });

  static T? _leer<T>(BuildContext context) {
    try {
      return Provider.of<T>(context);
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = _leer<ThemeProvider>(context);
    final idioma = _leer<LanguageProvider>(context);
    final notificaciones = _leer<NotificationCenterProvider>(context);
    final usuario = _leer<UserProfileProvider>(context)?.userData;
    final esPropietario =
        usuario != null && appRoleOf(usuario.rol) == AppRole.owner;
    final conAvatar = (mostrarAvatar ?? esPropietario) && usuario != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tema != null) _BotonTema(tema: tema, discreto: esPropietario),
        if (idioma != null) ...[
          const SizedBox(width: AppSpacing.xs),
          _BotonIdioma(idioma: idioma, enCaja: esPropietario),
          const SizedBox(width: AppSpacing.xs),
        ],
        if (mostrarCampana && notificaciones != null)
          _Campana(notificaciones: notificaciones),
        if (conAvatar) ...[
          const SizedBox(width: AppSpacing.xs),
          _AvatarDePerfil(usuario: usuario),
        ],
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

/// Sol en oscuro, luna en claro.
///
/// El icono se decide con el brillo que se está PINTANDO
/// (`Theme.of(context).brightness`), no con `themeMode`: con el modo del
/// dispositivo (`ThemeMode.system`) el `themeMode` no dice qué se ve, y el
/// toque tiene que invertir justo eso. Lo que el usuario elige queda guardado
/// en `ThemeProvider`.
class _BotonTema extends StatelessWidget {
  final ThemeProvider tema;

  /// El propietario lo lleva en gris (captura en claro); el taller, en el
  /// color de la marca (captura en oscuro).
  final bool discreto;

  const _BotonTema({required this.tema, required this.discreto});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(
        oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: discreto ? colors.textSecondary : colors.primary,
      ),
      tooltip: AppLocalizations.of(context)?.topNavThemeTooltip ?? 'Tema',
      onPressed: () =>
          tema.setThemeMode(oscuro ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

class _BotonIdioma extends StatelessWidget {
  final LanguageProvider idioma;

  /// El propietario lo lleva en una caja con borde (captura en claro).
  final bool enCaja;

  const _BotonIdioma({required this.idioma, required this.enCaja});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ingles = idioma.currentLocale.languageCode == 'en';
    final color = enCaja ? colors.textSecondary : colors.primary;

    // Solo `button: true`: el `Tooltip` ya publica el nombre, y repetirlo en
    // `label` lo haría sonar dos veces (etiqueta duplicada del §2.13).
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => idioma.changeLanguage(ingles ? 'es' : 'en'),
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message:
              AppLocalizations.of(context)?.topNavLanguageTooltip ?? 'Idioma',
          child: Container(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 36),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: enCaja
                ? BoxDecoration(
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Text(
              ingles ? 'EN' : 'ES',
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Campana extends StatelessWidget {
  final NotificationCenterProvider notificaciones;

  const _Campana({required this.notificaciones});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sinLeer = notificaciones.unreadCount;
    final hay = notificaciones.hasUnread;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Sin envoltorio `Semantics`: el `IconButton` ya publica rol, acción
        // y nombre (vía `tooltip`).
        IconButton(
          icon: Icon(
            hay
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: hay ? colors.primary : colors.textSecondary,
          ),
          tooltip:
              AppLocalizations.of(context)?.notifications ?? 'Notificaciones',
          onPressed: () => context.push('/notifications'),
        ),
        if (hay)
          Positioned(
            right: 6,
            top: 6,
            child: Semantics(
              label: '$sinLeer notificaciones sin leer',
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    sinLeer > 9 ? '9+' : '$sinLeer',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.onError,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarDePerfil extends StatelessWidget {
  final UserModel usuario;

  const _AvatarDePerfil({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foto = usuario.fotoPerfilUrl;
    final nombre = usuario.nombreCompleto.trim();

    // Igual que el idioma: el `InkWell` no aporta el rol de botón y el
    // `Tooltip` ya lo nombra.
    return Semantics(
      button: true,
      child: Tooltip(
        message: AppLocalizations.of(context)?.topNavAccountTooltip ?? 'Perfil',
        child: InkWell(
          onTap: () => context.push('/user_profile'),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary,
              backgroundImage: foto != null && foto.isNotEmpty
                  ? NetworkImage(foto)
                  : null,
              child: foto == null || foto.isEmpty
                  ? Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
