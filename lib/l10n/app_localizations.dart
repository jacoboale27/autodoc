import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// El nombre de la aplicación
  ///
  /// In es, this message translates to:
  /// **'AutoDoc'**
  String get appName;

  /// No description provided for @navPlatform.
  ///
  /// In es, this message translates to:
  /// **'Plataforma'**
  String get navPlatform;

  /// No description provided for @navOwners.
  ///
  /// In es, this message translates to:
  /// **'Para Dueños'**
  String get navOwners;

  /// No description provided for @navWorkshops.
  ///
  /// In es, this message translates to:
  /// **'Talleres'**
  String get navWorkshops;

  /// No description provided for @navLogin.
  ///
  /// In es, this message translates to:
  /// **'Login'**
  String get navLogin;

  /// No description provided for @navTryFree.
  ///
  /// In es, this message translates to:
  /// **'Probar Gratis'**
  String get navTryFree;

  /// No description provided for @authNoAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes una cuenta? '**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes una cuenta? '**
  String get authHaveAccount;

  /// No description provided for @authRegisterFree.
  ///
  /// In es, this message translates to:
  /// **'Regístrate gratis'**
  String get authRegisterFree;

  /// No description provided for @authLogin.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get authLogin;

  /// No description provided for @authCopilotSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tu copiloto para el control total de tu vehículo'**
  String get authCopilotSubtitle;

  /// No description provided for @authWelcomeBack.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido de nuevo'**
  String get authWelcomeBack;

  /// No description provided for @authCreateAccount.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta'**
  String get authCreateAccount;

  /// No description provided for @authEnterCredentials.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tus credenciales para acceder'**
  String get authEnterCredentials;

  /// No description provided for @authRegisterToManage.
  ///
  /// In es, this message translates to:
  /// **'Regístrate para comenzar a gestionar tus documentos'**
  String get authRegisterToManage;

  /// No description provided for @authEmailOrUserLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo o usuario'**
  String get authEmailOrUserLabel;

  /// No description provided for @authEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get authEmailLabel;

  /// No description provided for @authEmailOrUserHint.
  ///
  /// In es, this message translates to:
  /// **'nombre@ejemplo.com o usuario'**
  String get authEmailOrUserHint;

  /// No description provided for @authEmailHint.
  ///
  /// In es, this message translates to:
  /// **'nombre@ejemplo.com'**
  String get authEmailHint;

  /// No description provided for @authPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'••••••••'**
  String get authPasswordHint;

  /// No description provided for @authRememberMe.
  ///
  /// In es, this message translates to:
  /// **'Recordarme'**
  String get authRememberMe;

  /// No description provided for @authForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get authForgotPassword;

  /// No description provided for @authLoginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get authLoginButton;

  /// No description provided for @authRegisterButton.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get authRegisterButton;

  /// No description provided for @authOrContinueWith.
  ///
  /// In es, this message translates to:
  /// **'O CONTINUAR CON'**
  String get authOrContinueWith;

  /// No description provided for @authGoogleLogin.
  ///
  /// In es, this message translates to:
  /// **'Entrar con Google'**
  String get authGoogleLogin;

  /// No description provided for @authTabLogin.
  ///
  /// In es, this message translates to:
  /// **'Login'**
  String get authTabLogin;

  /// No description provided for @authTabRegister.
  ///
  /// In es, this message translates to:
  /// **'Registro'**
  String get authTabRegister;

  /// No description provided for @authTabSupport.
  ///
  /// In es, this message translates to:
  /// **'Soporte'**
  String get authTabSupport;

  /// No description provided for @authForgotPassTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar contraseña'**
  String get authForgotPassTitle;

  /// No description provided for @authForgotPassDesc.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un enlace a tu correo para restablecer la contraseña.'**
  String get authForgotPassDesc;

  /// No description provided for @authCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get authCancel;

  /// No description provided for @authSendLink.
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace'**
  String get authSendLink;

  /// No description provided for @authInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo válido.'**
  String get authInvalidEmail;

  /// No description provided for @authSendEmailError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el correo.'**
  String get authSendEmailError;

  /// No description provided for @authCheckInbox.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu bandeja de entrada en '**
  String get authCheckInbox;

  /// No description provided for @authAndSpam.
  ///
  /// In es, this message translates to:
  /// **' (y la carpeta de spam).'**
  String get authAndSpam;

  /// No description provided for @authVerifyEmailTitle.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo'**
  String get authVerifyEmailTitle;

  /// No description provided for @authSentLinkTo.
  ///
  /// In es, this message translates to:
  /// **'Enviamos un enlace de verificación a:'**
  String get authSentLinkTo;

  /// No description provided for @authAccountNotVerified.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta aún no está verificada. Revisa el correo enviado a:'**
  String get authAccountNotVerified;

  /// No description provided for @authOpenLinkThenVerify.
  ///
  /// In es, this message translates to:
  /// **'Abre el enlace del correo y luego pulsa \"Ya verifiqué\" para continuar.'**
  String get authOpenLinkThenVerify;

  /// No description provided for @authUnderstood.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get authUnderstood;

  /// No description provided for @authContinueWithoutVerify.
  ///
  /// In es, this message translates to:
  /// **'Continuar sin verificar'**
  String get authContinueWithoutVerify;

  /// No description provided for @authResendEmail.
  ///
  /// In es, this message translates to:
  /// **'Reenviar correo'**
  String get authResendEmail;

  /// No description provided for @authEmailResent.
  ///
  /// In es, this message translates to:
  /// **'Correo de verificación reenviado.'**
  String get authEmailResent;

  /// No description provided for @authResendError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reenviar.'**
  String get authResendError;

  /// No description provided for @authAlreadyVerified.
  ///
  /// In es, this message translates to:
  /// **'Ya verifiqué'**
  String get authAlreadyVerified;

  /// No description provided for @authEmailVerifiedSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Correo verificado correctamente!'**
  String get authEmailVerifiedSuccess;

  /// No description provided for @authVerificationNotDetected.
  ///
  /// In es, this message translates to:
  /// **'Aún no detectamos la verificación. Abre el enlace del correo e inténtalo de nuevo.'**
  String get authVerificationNotDetected;

  /// No description provided for @authSupportCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro de soporte'**
  String get authSupportCenter;

  /// No description provided for @authSupportDesc.
  ///
  /// In es, this message translates to:
  /// **'¿Necesitas ayuda con tu cuenta, verificación de correo o acceso?'**
  String get authSupportDesc;

  /// No description provided for @authSupportEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo de soporte'**
  String get authSupportEmail;

  /// No description provided for @authEmailCopied.
  ///
  /// In es, this message translates to:
  /// **'Correo copiado al portapapeles'**
  String get authEmailCopied;

  /// No description provided for @authEmailVerification.
  ///
  /// In es, this message translates to:
  /// **'Verificación de correo'**
  String get authEmailVerification;

  /// No description provided for @authEmailNotReceived.
  ///
  /// In es, this message translates to:
  /// **'No llegó el correo → revisa spam o reenvía desde login'**
  String get authEmailNotReceived;

  /// No description provided for @authLoginToResend.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión con tu correo para reenviar la verificación.'**
  String get authLoginToResend;

  /// No description provided for @authForgotPassTileTitle.
  ///
  /// In es, this message translates to:
  /// **'Olvidé mi contraseña'**
  String get authForgotPassTileTitle;

  /// No description provided for @authReceiveRecoveryLink.
  ///
  /// In es, this message translates to:
  /// **'Recibe un enlace de recuperación por correo'**
  String get authReceiveRecoveryLink;

  /// No description provided for @authSupportHours.
  ///
  /// In es, this message translates to:
  /// **'Horario de atención: Lun–Vie 8:00–18:00'**
  String get authSupportHours;

  /// No description provided for @heroBadge.
  ///
  /// In es, this message translates to:
  /// **'CONTROL TOTAL EN TU MANO'**
  String get heroBadge;

  /// No description provided for @heroTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Garaje Virtual,\nElevado'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Digitaliza tu vehículo hoy. Historial clínico certificado, alertas inteligentes de SOAT y mantenimientos, conectado con los mejores talleres.'**
  String get heroSubtitle;

  /// No description provided for @heroStartGarage.
  ///
  /// In es, this message translates to:
  /// **'Comenzar mi Garaje'**
  String get heroStartGarage;

  /// No description provided for @heroViewDirectory.
  ///
  /// In es, this message translates to:
  /// **'Ver Directorio'**
  String get heroViewDirectory;

  /// No description provided for @commandCenterTitle.
  ///
  /// In es, this message translates to:
  /// **'Centro de Control'**
  String get commandCenterTitle;

  /// No description provided for @commandCenterSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Todo lo que necesitas en un solo lugar'**
  String get commandCenterSubtitle;

  /// No description provided for @tabGarageTitle.
  ///
  /// In es, this message translates to:
  /// **'Garaje'**
  String get tabGarageTitle;

  /// No description provided for @tabGarageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tus vehículos'**
  String get tabGarageSubtitle;

  /// No description provided for @tabHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get tabHistoryTitle;

  /// No description provided for @tabHistorySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get tabHistorySubtitle;

  /// No description provided for @tabAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get tabAlertsTitle;

  /// No description provided for @tabAlertsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios'**
  String get tabAlertsSubtitle;

  /// No description provided for @tabSyncTitle.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar'**
  String get tabSyncTitle;

  /// No description provided for @tabSyncSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Datos'**
  String get tabSyncSubtitle;

  /// No description provided for @valuePropTitle.
  ///
  /// In es, this message translates to:
  /// **'Por qué elegir AutoDoc'**
  String get valuePropTitle;

  /// No description provided for @valuePropSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Beneficios exclusivos'**
  String get valuePropSubtitle;

  /// No description provided for @statSatisfaction.
  ///
  /// In es, this message translates to:
  /// **'99% Satisfacción'**
  String get statSatisfaction;

  /// No description provided for @statWorkshops.
  ///
  /// In es, this message translates to:
  /// **'+500 Talleres'**
  String get statWorkshops;

  /// No description provided for @footerDesc.
  ///
  /// In es, this message translates to:
  /// **'La mejor app para el cuidado de tu vehículo'**
  String get footerDesc;

  /// No description provided for @footerOwners.
  ///
  /// In es, this message translates to:
  /// **'Para Propietarios'**
  String get footerOwners;

  /// No description provided for @footerWorkshops.
  ///
  /// In es, this message translates to:
  /// **'Para Talleres'**
  String get footerWorkshops;

  /// No description provided for @footerSocial.
  ///
  /// In es, this message translates to:
  /// **'Redes Sociales'**
  String get footerSocial;

  /// No description provided for @footerCopyright.
  ///
  /// In es, this message translates to:
  /// **'© 2026 AutoDoc. Todos los derechos reservados.'**
  String get footerCopyright;

  /// No description provided for @dashHello.
  ///
  /// In es, this message translates to:
  /// **'Hola, {userName} 👋'**
  String dashHello(String userName);

  /// No description provided for @dashReadyForRoad.
  ///
  /// In es, this message translates to:
  /// **'¿Listo para la carretera hoy?'**
  String get dashReadyForRoad;

  /// No description provided for @dashMaintCritical.
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento vencido — atención inmediata'**
  String get dashMaintCritical;

  /// No description provided for @dashMaintWarning.
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento próximo — revisa las alertas'**
  String get dashMaintWarning;

  /// No description provided for @dashMaintOptimal.
  ///
  /// In es, this message translates to:
  /// **'Vehículo en buen estado'**
  String get dashMaintOptimal;

  /// No description provided for @dashMaintStatusLabel.
  ///
  /// In es, this message translates to:
  /// **'Estado de Mantenimiento'**
  String get dashMaintStatusLabel;

  /// No description provided for @dashNoVehicles.
  ///
  /// In es, this message translates to:
  /// **'No hay vehiculos registrados'**
  String get dashNoVehicles;

  /// No description provided for @dashNoVehiclesDesc.
  ///
  /// In es, this message translates to:
  /// **'Añade tu primer vehículo para empezar a controlar su mantenimiento y estado.'**
  String get dashNoVehiclesDesc;

  /// No description provided for @dashRegisterVehicle.
  ///
  /// In es, this message translates to:
  /// **'Registrar Vehículo'**
  String get dashRegisterVehicle;

  /// No description provided for @dashMainVehicle.
  ///
  /// In es, this message translates to:
  /// **'VEHICULO PRINCIPAL'**
  String get dashMainVehicle;

  /// No description provided for @dashLicensePlate.
  ///
  /// In es, this message translates to:
  /// **'Placa: {placa}'**
  String dashLicensePlate(String placa);

  /// No description provided for @dashMileage.
  ///
  /// In es, this message translates to:
  /// **'KILOMETRAJE'**
  String get dashMileage;

  /// No description provided for @dashKm.
  ///
  /// In es, this message translates to:
  /// **'km'**
  String get dashKm;

  /// No description provided for @dashViewVehicleState.
  ///
  /// In es, this message translates to:
  /// **'Ver Estado del Vehículo'**
  String get dashViewVehicleState;

  /// No description provided for @dashAddVehicleError.
  ///
  /// In es, this message translates to:
  /// **'Error al agregar vehiculo'**
  String get dashAddVehicleError;

  /// No description provided for @dashActiveAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas Activas'**
  String get dashActiveAlerts;

  /// No description provided for @dashViewAll.
  ///
  /// In es, this message translates to:
  /// **'Ver Todas'**
  String get dashViewAll;

  /// No description provided for @dashNoAlertsPending.
  ///
  /// In es, this message translates to:
  /// **'¡Excelente! No tienes alertas pendientes.'**
  String get dashNoAlertsPending;

  /// No description provided for @dashNearbyWorkshops.
  ///
  /// In es, this message translates to:
  /// **'Talleres Cercanos'**
  String get dashNearbyWorkshops;

  /// No description provided for @dashViewAllWorkshops.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get dashViewAllWorkshops;

  /// No description provided for @garageMyVehicles.
  ///
  /// In es, this message translates to:
  /// **'Mis Vehículos'**
  String get garageMyVehicles;

  /// No description provided for @garageNoVehicles.
  ///
  /// In es, this message translates to:
  /// **'No tienes vehículos en tu garaje'**
  String get garageNoVehicles;

  /// No description provided for @garageOptimal.
  ///
  /// In es, this message translates to:
  /// **'Óptimo'**
  String get garageOptimal;

  /// No description provided for @garageSuggestedReview.
  ///
  /// In es, this message translates to:
  /// **'Revisión Sugerida'**
  String get garageSuggestedReview;

  /// No description provided for @garageMakePrimary.
  ///
  /// In es, this message translates to:
  /// **'Hacer Principal'**
  String get garageMakePrimary;

  /// No description provided for @garageNowPrimary.
  ///
  /// In es, this message translates to:
  /// **'{vehicleName} es ahora tu vehículo principal'**
  String garageNowPrimary(String vehicleName);

  /// No description provided for @garageMakePrimaryError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo establecer el vehículo principal'**
  String get garageMakePrimaryError;

  /// No description provided for @garageAddVehicleError.
  ///
  /// In es, this message translates to:
  /// **'Error al agregar vehiculo'**
  String get garageAddVehicleError;

  /// No description provided for @vpProfileTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil del Vehículo'**
  String get vpProfileTitle;

  /// No description provided for @vpShareVehicle.
  ///
  /// In es, this message translates to:
  /// **'Compartir Vehículo'**
  String get vpShareVehicle;

  /// No description provided for @vpDeleteVehicle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar Vehículo'**
  String get vpDeleteVehicle;

  /// No description provided for @vpActiveStatus.
  ///
  /// In es, this message translates to:
  /// **'ACTIVO'**
  String get vpActiveStatus;

  /// No description provided for @vpOwnerPersonal.
  ///
  /// In es, this message translates to:
  /// **'Propietario: Personal'**
  String get vpOwnerPersonal;

  /// No description provided for @vpYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get vpYear;

  /// No description provided for @vpColor.
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get vpColor;

  /// No description provided for @vpMileage.
  ///
  /// In es, this message translates to:
  /// **'Kilometraje'**
  String get vpMileage;

  /// No description provided for @vpKm.
  ///
  /// In es, this message translates to:
  /// **'km'**
  String get vpKm;

  /// No description provided for @vpBrand.
  ///
  /// In es, this message translates to:
  /// **'Marca'**
  String get vpBrand;

  /// No description provided for @vpDocAndAlerts.
  ///
  /// In es, this message translates to:
  /// **'Documentación y Alertas'**
  String get vpDocAndAlerts;

  /// No description provided for @vpCirculationCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta de Circulación'**
  String get vpCirculationCard;

  /// No description provided for @vpSoatInsurance.
  ///
  /// In es, this message translates to:
  /// **'Seguro SOAT'**
  String get vpSoatInsurance;

  /// No description provided for @vpDateNotRegistered.
  ///
  /// In es, this message translates to:
  /// **'Fecha no registrada'**
  String get vpDateNotRegistered;

  /// No description provided for @vpUpdate.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get vpUpdate;

  /// No description provided for @vpExpiredOn.
  ///
  /// In es, this message translates to:
  /// **'Vencido el {date}'**
  String vpExpiredOn(String date);

  /// No description provided for @vpExpiresInDays.
  ///
  /// In es, this message translates to:
  /// **'Vence en {days} días ({date})'**
  String vpExpiresInDays(String days, String date);

  /// No description provided for @vpRenew.
  ///
  /// In es, this message translates to:
  /// **'Renovar'**
  String get vpRenew;

  /// No description provided for @vpUpdateMileage.
  ///
  /// In es, this message translates to:
  /// **'Actualizar Kilometraje'**
  String get vpUpdateMileage;

  /// No description provided for @vpEnterNewMileage.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el kilometraje actual. Debe ser mayor a {km} km.'**
  String vpEnterNewMileage(String km);

  /// No description provided for @vpNewMileageLabel.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Kilometraje'**
  String get vpNewMileageLabel;

  /// No description provided for @vpEnterValue.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un valor'**
  String get vpEnterValue;

  /// No description provided for @vpEnterValidNumber.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un número válido'**
  String get vpEnterValidNumber;

  /// No description provided for @vpMustBeGreaterThan.
  ///
  /// In es, this message translates to:
  /// **'Debe ser mayor a {km}'**
  String vpMustBeGreaterThan(String km);

  /// No description provided for @vpSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get vpSave;

  /// No description provided for @vpMileageUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Kilometraje actualizado correctamente'**
  String get vpMileageUpdatedSuccess;

  /// No description provided for @vpUpdateError.
  ///
  /// In es, this message translates to:
  /// **'Error al actualizar'**
  String get vpUpdateError;

  /// No description provided for @vpConfirmDelete.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro que deseas eliminar el {brand} {model}? Esta acción no se puede deshacer.'**
  String vpConfirmDelete(String brand, String model);

  /// No description provided for @vpEnterPassword.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get vpEnterPassword;

  /// No description provided for @vpIncorrectPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta'**
  String get vpIncorrectPassword;

  /// No description provided for @vpDeleteSuccess.
  ///
  /// In es, this message translates to:
  /// **'Vehículo eliminado correctamente'**
  String get vpDeleteSuccess;

  /// No description provided for @vpDeleteError.
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar'**
  String get vpDeleteError;

  /// No description provided for @vpQuickActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones Rápidas'**
  String get vpQuickActions;

  /// No description provided for @vpHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get vpHistory;

  /// No description provided for @vpServices.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get vpServices;

  /// No description provided for @vpPapers.
  ///
  /// In es, this message translates to:
  /// **'Papeles'**
  String get vpPapers;

  /// No description provided for @vpDateUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Fecha actualizada correctamente'**
  String get vpDateUpdatedSuccess;

  /// No description provided for @vpDateUpdateError.
  ///
  /// In es, this message translates to:
  /// **'Error al actualizar fecha'**
  String get vpDateUpdateError;

  /// No description provided for @alertsSelectVehicle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un vehículo primero'**
  String get alertsSelectVehicle;

  /// No description provided for @alertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get alertsTitle;

  /// No description provided for @alertsUpdateMileage.
  ///
  /// In es, this message translates to:
  /// **'Actualizar Kilometraje'**
  String get alertsUpdateMileage;

  /// No description provided for @alertsTabAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get alertsTabAll;

  /// No description provided for @alertsTabUrgent.
  ///
  /// In es, this message translates to:
  /// **'Urgentes'**
  String get alertsTabUrgent;

  /// No description provided for @alertsTabUpcoming.
  ///
  /// In es, this message translates to:
  /// **'Próximas'**
  String get alertsTabUpcoming;

  /// No description provided for @alertsAllGood.
  ///
  /// In es, this message translates to:
  /// **'¡Todo al día!'**
  String get alertsAllGood;

  /// No description provided for @alertsNoAlertsInCategory.
  ///
  /// In es, this message translates to:
  /// **'No hay alertas en esta categoría.'**
  String get alertsNoAlertsInCategory;

  /// No description provided for @alertsHighPriority.
  ///
  /// In es, this message translates to:
  /// **'Prioridad Alta'**
  String get alertsHighPriority;

  /// No description provided for @alertsPendingCount.
  ///
  /// In es, this message translates to:
  /// **'{count} pendientes'**
  String alertsPendingCount(String count);

  /// No description provided for @alertsUpcomingExpirations.
  ///
  /// In es, this message translates to:
  /// **'Próximos Vencimientos'**
  String get alertsUpcomingExpirations;

  /// No description provided for @alertsEventsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} eventos'**
  String alertsEventsCount(String count);

  /// No description provided for @alertsSuggestions.
  ///
  /// In es, this message translates to:
  /// **'Sugerencias'**
  String get alertsSuggestions;

  /// No description provided for @alertsCurrentMileage.
  ///
  /// In es, this message translates to:
  /// **'Kilometraje actual: '**
  String get alertsCurrentMileage;

  /// No description provided for @alertsOverdue.
  ///
  /// In es, this message translates to:
  /// **'Superado por {km} km. ¡Atención inmediata!'**
  String alertsOverdue(String km);

  /// No description provided for @alertsMissingKm.
  ///
  /// In es, this message translates to:
  /// **'Faltan {km} km para la revisión programada.'**
  String alertsMissingKm(String km);

  /// No description provided for @alertsNextServiceApprox.
  ///
  /// In es, this message translates to:
  /// **'Próximo servicio en {km} km aprox.'**
  String alertsNextServiceApprox(String km);

  /// No description provided for @alertsLastKm.
  ///
  /// In es, this message translates to:
  /// **'Último: {km} km'**
  String alertsLastKm(String km);

  /// No description provided for @alertsEveryKm.
  ///
  /// In es, this message translates to:
  /// **'Cada {km} km'**
  String alertsEveryKm(String km);

  /// No description provided for @alertsConfig.
  ///
  /// In es, this message translates to:
  /// **'Configurar'**
  String get alertsConfig;

  /// No description provided for @alertsComplete.
  ///
  /// In es, this message translates to:
  /// **'Completar'**
  String get alertsComplete;

  /// No description provided for @alertsSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get alertsSave;

  /// No description provided for @alertsCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get alertsCancel;

  /// No description provided for @alertsNewMileage.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Kilometraje'**
  String get alertsNewMileage;

  /// No description provided for @histTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de Servicios'**
  String get histTitle;

  /// No description provided for @histTabAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get histTabAll;

  /// No description provided for @histTabManual.
  ///
  /// In es, this message translates to:
  /// **'Manual'**
  String get histTabManual;

  /// No description provided for @histTabWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Taller'**
  String get histTabWorkshop;

  /// No description provided for @histNoServices.
  ///
  /// In es, this message translates to:
  /// **'No hay servicios registrados'**
  String get histNoServices;

  /// No description provided for @histNoServicesDesc.
  ///
  /// In es, this message translates to:
  /// **'Los mantenimientos aparecerán aquí'**
  String get histNoServicesDesc;

  /// No description provided for @histOwner.
  ///
  /// In es, this message translates to:
  /// **'Propietario'**
  String get histOwner;

  /// No description provided for @histWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Taller'**
  String get histWorkshop;

  /// No description provided for @histEvidence.
  ///
  /// In es, this message translates to:
  /// **'Evidencia'**
  String get histEvidence;

  /// No description provided for @histReviewWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Reseñar taller'**
  String get histReviewWorkshop;

  /// No description provided for @wdErrorLoading.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar talleres'**
  String get wdErrorLoading;

  /// No description provided for @wdNoWorkshopsFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron talleres'**
  String get wdNoWorkshopsFound;

  /// No description provided for @wdTitle.
  ///
  /// In es, this message translates to:
  /// **'Directorio de Talleres'**
  String get wdTitle;

  /// No description provided for @wdSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar mecánicos o servicios...'**
  String get wdSearchHint;

  /// No description provided for @wdFilterMunicipality.
  ///
  /// In es, this message translates to:
  /// **'Municipio'**
  String get wdFilterMunicipality;

  /// No description provided for @wdFilterSpecialty.
  ///
  /// In es, this message translates to:
  /// **'Especialidad'**
  String get wdFilterSpecialty;

  /// No description provided for @wdFilterRating.
  ///
  /// In es, this message translates to:
  /// **'Rating'**
  String get wdFilterRating;

  /// No description provided for @wdYourLocation.
  ///
  /// In es, this message translates to:
  /// **'Tu Ubicación'**
  String get wdYourLocation;

  /// No description provided for @wdWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Taller'**
  String get wdWorkshop;

  /// No description provided for @wdGeneralMechanics.
  ///
  /// In es, this message translates to:
  /// **'Mecánica General'**
  String get wdGeneralMechanics;

  /// No description provided for @wdMechanics.
  ///
  /// In es, this message translates to:
  /// **'Mecánica'**
  String get wdMechanics;

  /// No description provided for @wdDistanceKm.
  ///
  /// In es, this message translates to:
  /// **'A {km} km'**
  String wdDistanceKm(String km);

  /// No description provided for @wdWorkshopsOnMap.
  ///
  /// In es, this message translates to:
  /// **'{count} talleres en el mapa'**
  String wdWorkshopsOnMap(String count);

  /// No description provided for @wdNoLocationCount.
  ///
  /// In es, this message translates to:
  /// **'{count} sin ubicación'**
  String wdNoLocationCount(String count);

  /// No description provided for @wdNoPhoneRegistered.
  ///
  /// In es, this message translates to:
  /// **'Este taller no tiene teléfono registrado'**
  String get wdNoPhoneRegistered;

  /// No description provided for @wdContactName.
  ///
  /// In es, this message translates to:
  /// **'Contactar a {name}'**
  String wdContactName(String name);

  /// No description provided for @wdCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get wdCopy;

  /// No description provided for @wdClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get wdClose;

  /// No description provided for @wdPhoneCopied.
  ///
  /// In es, this message translates to:
  /// **'Teléfono copiado al portapapeles'**
  String get wdPhoneCopied;

  /// No description provided for @wdNamelessWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Taller Sin Nombre'**
  String get wdNamelessWorkshop;

  /// No description provided for @wdLocationNotSpecified.
  ///
  /// In es, this message translates to:
  /// **'Ubicación no especificada'**
  String get wdLocationNotSpecified;

  /// No description provided for @wdSpecialtyIs.
  ///
  /// In es, this message translates to:
  /// **'Especialidad: {specialty}'**
  String wdSpecialtyIs(String specialty);

  /// No description provided for @wdReviewsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} reseñas'**
  String wdReviewsCount(String count);

  /// No description provided for @wdReviewCount.
  ///
  /// In es, this message translates to:
  /// **'{count} reseña'**
  String wdReviewCount(String count);

  /// No description provided for @wdReview.
  ///
  /// In es, this message translates to:
  /// **'Reseñar'**
  String get wdReview;

  /// No description provided for @wdContact.
  ///
  /// In es, this message translates to:
  /// **'Contactar'**
  String get wdContact;

  /// No description provided for @upErrorUploadingImage.
  ///
  /// In es, this message translates to:
  /// **'Error uploading image: {error}'**
  String upErrorUploadingImage(String error);

  /// No description provided for @upProfileUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Perfil actualizado correctamente'**
  String get upProfileUpdatedSuccess;

  /// No description provided for @upProfileTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get upProfileTitle;

  /// No description provided for @upProfileDataNotFound.
  ///
  /// In es, this message translates to:
  /// **'Datos de perfil no encontrados'**
  String get upProfileDataNotFound;

  /// No description provided for @upPleaseCompleteSetup.
  ///
  /// In es, this message translates to:
  /// **'Por favor completa la configuración de tu perfil.'**
  String get upPleaseCompleteSetup;

  /// No description provided for @upSetupProfile.
  ///
  /// In es, this message translates to:
  /// **'Configurar Perfil'**
  String get upSetupProfile;

  /// No description provided for @upSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar Sesión'**
  String get upSignOut;

  /// No description provided for @upSaveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar Cambios'**
  String get upSaveChanges;

  /// No description provided for @upMyProfile.
  ///
  /// In es, this message translates to:
  /// **'Mi Perfil'**
  String get upMyProfile;

  /// No description provided for @upFullName.
  ///
  /// In es, this message translates to:
  /// **'Nombre Completo'**
  String get upFullName;

  /// No description provided for @upEmailAddress.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico'**
  String get upEmailAddress;

  /// No description provided for @upMemberSince.
  ///
  /// In es, this message translates to:
  /// **'Miembro desde'**
  String get upMemberSince;

  /// No description provided for @upSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get upSettings;

  /// No description provided for @upDarkMode.
  ///
  /// In es, this message translates to:
  /// **'Modo Oscuro'**
  String get upDarkMode;

  /// No description provided for @upSwitchTheme.
  ///
  /// In es, this message translates to:
  /// **'Alternar entre modo claro y oscuro'**
  String get upSwitchTheme;

  /// No description provided for @upFollowSystem.
  ///
  /// In es, this message translates to:
  /// **'Seguir el Sistema'**
  String get upFollowSystem;

  /// No description provided for @upUseSystemTheme.
  ///
  /// In es, this message translates to:
  /// **'Usar el tema predeterminado del sistema'**
  String get upUseSystemTheme;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In es, this message translates to:
  /// **'Dashboard Administrador'**
  String get adminDashboardTitle;

  /// No description provided for @adminDashboardWelcome.
  ///
  /// In es, this message translates to:
  /// **'¡Bienvenido, {name}!'**
  String adminDashboardWelcome(String name);

  /// No description provided for @adminDashboardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Panel de control administrativo'**
  String get adminDashboardSubtitle;

  /// No description provided for @adminGlobalMetricsTitle.
  ///
  /// In es, this message translates to:
  /// **'Métricas Globales'**
  String get adminGlobalMetricsTitle;

  /// No description provided for @adminMetricsUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get adminMetricsUsers;

  /// No description provided for @adminMetricsWorkshops.
  ///
  /// In es, this message translates to:
  /// **'Talleres'**
  String get adminMetricsWorkshops;

  /// No description provided for @adminMetricsVehicles.
  ///
  /// In es, this message translates to:
  /// **'Vehículos'**
  String get adminMetricsVehicles;

  /// No description provided for @adminMetricsServices.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get adminMetricsServices;

  /// No description provided for @adminMetricsAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get adminMetricsAlerts;

  /// No description provided for @adminMetricsReviews.
  ///
  /// In es, this message translates to:
  /// **'Reseñas'**
  String get adminMetricsReviews;

  /// No description provided for @adminQuickActionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Acciones Rápidas'**
  String get adminQuickActionsTitle;

  /// No description provided for @adminQuickActionManageUsers.
  ///
  /// In es, this message translates to:
  /// **'Gestionar Usuarios'**
  String get adminQuickActionManageUsers;

  /// No description provided for @adminQuickActionManageWorkshops.
  ///
  /// In es, this message translates to:
  /// **'Gestionar Talleres'**
  String get adminQuickActionManageWorkshops;

  /// No description provided for @adminQuickActionModerateReviews.
  ///
  /// In es, this message translates to:
  /// **'Moderar Reseñas'**
  String get adminQuickActionModerateReviews;

  /// No description provided for @adminQuickActionViewLogs.
  ///
  /// In es, this message translates to:
  /// **'Ver Actividad'**
  String get adminQuickActionViewLogs;

  /// No description provided for @adminRecentActivityTitle.
  ///
  /// In es, this message translates to:
  /// **'Actividad Reciente'**
  String get adminRecentActivityTitle;

  /// No description provided for @adminNoRecentActivity.
  ///
  /// In es, this message translates to:
  /// **'Sin actividad reciente'**
  String get adminNoRecentActivity;

  /// No description provided for @adminViewAllLogs.
  ///
  /// In es, this message translates to:
  /// **'Ver todo el registro'**
  String get adminViewAllLogs;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
