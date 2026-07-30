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

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'AutoDoc'**
  String get appName;

  /// No description provided for @navPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get navPlatform;

  /// No description provided for @navOwners.
  ///
  /// In en, this message translates to:
  /// **'For Owners'**
  String get navOwners;

  /// No description provided for @navWorkshops.
  ///
  /// In en, this message translates to:
  /// **'Workshops'**
  String get navWorkshops;

  /// No description provided for @navLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get navLogin;

  /// No description provided for @navTryFree.
  ///
  /// In en, this message translates to:
  /// **'Try for Free'**
  String get navTryFree;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authRegisterFree.
  ///
  /// In en, this message translates to:
  /// **'Sign up for free'**
  String get authRegisterFree;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogin;

  /// No description provided for @authCopilotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your copilot for total vehicle control'**
  String get authCopilotSubtitle;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateAccount;

  /// No description provided for @authEnterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to access'**
  String get authEnterCredentials;

  /// No description provided for @authRegisterToManage.
  ///
  /// In en, this message translates to:
  /// **'Sign up to start managing your documents'**
  String get authRegisterToManage;

  /// No description provided for @authEmailOrUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Email or Username'**
  String get authEmailOrUserLabel;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authEmailOrUserHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com or username'**
  String get authEmailOrUserHint;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get authEmailHint;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get authPasswordHint;

  /// No description provided for @authRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get authRememberMe;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get authForgotPassword;

  /// No description provided for @authLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLoginButton;

  /// No description provided for @authRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authRegisterButton;

  /// No description provided for @authOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'OR CONTINUE WITH'**
  String get authOrContinueWith;

  /// No description provided for @authGoogleLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in with Google'**
  String get authGoogleLogin;

  /// No description provided for @authTabLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authTabLogin;

  /// No description provided for @authTabRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authTabRegister;

  /// No description provided for @authTabSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get authTabSupport;

  /// No description provided for @authForgotPassTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover Password'**
  String get authForgotPassTitle;

  /// No description provided for @authForgotPassDesc.
  ///
  /// In en, this message translates to:
  /// **'We will send a link to your email to reset your password.'**
  String get authForgotPassDesc;

  /// No description provided for @authCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancel;

  /// No description provided for @authSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get authSendLink;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email.'**
  String get authInvalidEmail;

  /// No description provided for @authSendEmailError.
  ///
  /// In en, this message translates to:
  /// **'Could not send the email.'**
  String get authSendEmailError;

  /// No description provided for @authCheckInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox at '**
  String get authCheckInbox;

  /// No description provided for @authAndSpam.
  ///
  /// In en, this message translates to:
  /// **' (and the spam folder).'**
  String get authAndSpam;

  /// No description provided for @authVerifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authVerifyEmailTitle;

  /// No description provided for @authSentLinkTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to:'**
  String get authSentLinkTo;

  /// No description provided for @authAccountNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Your account is not verified yet. Check the email sent to:'**
  String get authAccountNotVerified;

  /// No description provided for @authOpenLinkThenVerify.
  ///
  /// In en, this message translates to:
  /// **'Open the link in the email and then press \"I already verified\" to continue.'**
  String get authOpenLinkThenVerify;

  /// No description provided for @authUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get authUnderstood;

  /// No description provided for @authContinueWithoutVerify.
  ///
  /// In en, this message translates to:
  /// **'Continue without verifying'**
  String get authContinueWithoutVerify;

  /// No description provided for @authResendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get authResendEmail;

  /// No description provided for @authEmailResent.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent.'**
  String get authEmailResent;

  /// No description provided for @authResendError.
  ///
  /// In en, this message translates to:
  /// **'Could not resend.'**
  String get authResendError;

  /// No description provided for @authAlreadyVerified.
  ///
  /// In en, this message translates to:
  /// **'I already verified'**
  String get authAlreadyVerified;

  /// No description provided for @authEmailVerifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully!'**
  String get authEmailVerifiedSuccess;

  /// No description provided for @authVerificationNotDetected.
  ///
  /// In en, this message translates to:
  /// **'We still don\'t detect the verification. Open the link in the email and try again.'**
  String get authVerificationNotDetected;

  /// No description provided for @authSupportCenter.
  ///
  /// In en, this message translates to:
  /// **'Support Center'**
  String get authSupportCenter;

  /// No description provided for @authSupportDesc.
  ///
  /// In en, this message translates to:
  /// **'Need help with your account, email verification, or access?'**
  String get authSupportDesc;

  /// No description provided for @authSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support email'**
  String get authSupportEmail;

  /// No description provided for @authEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard'**
  String get authEmailCopied;

  /// No description provided for @authEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Email verification'**
  String get authEmailVerification;

  /// No description provided for @authEmailNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Email didn\'t arrive → check spam or resend from login'**
  String get authEmailNotReceived;

  /// No description provided for @authLoginToResend.
  ///
  /// In en, this message translates to:
  /// **'Log in with your email to resend verification.'**
  String get authLoginToResend;

  /// No description provided for @authForgotPassTileTitle.
  ///
  /// In en, this message translates to:
  /// **'I forgot my password'**
  String get authForgotPassTileTitle;

  /// No description provided for @authReceiveRecoveryLink.
  ///
  /// In en, this message translates to:
  /// **'Receive a recovery link by email'**
  String get authReceiveRecoveryLink;

  /// No description provided for @authSupportHours.
  ///
  /// In en, this message translates to:
  /// **'Support hours: Mon–Fri 8:00–18:00'**
  String get authSupportHours;

  /// No description provided for @heroBadge.
  ///
  /// In en, this message translates to:
  /// **'TOTAL CONTROL IN YOUR HANDS'**
  String get heroBadge;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Virtual Garage,\nElevated'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Digitize your vehicle today. Certified clinical history, smart SOAT and maintenance alerts, connected with the best workshops.'**
  String get heroSubtitle;

  /// No description provided for @heroStartGarage.
  ///
  /// In en, this message translates to:
  /// **'Start my Garage'**
  String get heroStartGarage;

  /// No description provided for @heroViewDirectory.
  ///
  /// In en, this message translates to:
  /// **'View Directory'**
  String get heroViewDirectory;

  /// No description provided for @commandCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Command Center'**
  String get commandCenterTitle;

  /// No description provided for @commandCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you need in one place'**
  String get commandCenterSubtitle;

  /// No description provided for @tabGarageTitle.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get tabGarageTitle;

  /// No description provided for @tabGarageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your vehicles'**
  String get tabGarageSubtitle;

  /// No description provided for @tabHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistoryTitle;

  /// No description provided for @tabHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get tabHistorySubtitle;

  /// No description provided for @tabAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabAlertsTitle;

  /// No description provided for @tabAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get tabAlertsSubtitle;

  /// No description provided for @tabSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get tabSyncTitle;

  /// No description provided for @tabSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get tabSyncSubtitle;

  /// No description provided for @valuePropTitle.
  ///
  /// In en, this message translates to:
  /// **'Why choose AutoDoc'**
  String get valuePropTitle;

  /// No description provided for @valuePropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exclusive benefits'**
  String get valuePropSubtitle;

  /// No description provided for @statSatisfaction.
  ///
  /// In en, this message translates to:
  /// **'99% Satisfaction'**
  String get statSatisfaction;

  /// No description provided for @statWorkshops.
  ///
  /// In en, this message translates to:
  /// **'+500 Workshops'**
  String get statWorkshops;

  /// No description provided for @footerDesc.
  ///
  /// In en, this message translates to:
  /// **'The best app for your vehicle care'**
  String get footerDesc;

  /// No description provided for @footerOwners.
  ///
  /// In en, this message translates to:
  /// **'For Owners'**
  String get footerOwners;

  /// No description provided for @footerWorkshops.
  ///
  /// In en, this message translates to:
  /// **'For Workshops'**
  String get footerWorkshops;

  /// No description provided for @footerSocial.
  ///
  /// In en, this message translates to:
  /// **'Social Media'**
  String get footerSocial;

  /// No description provided for @footerCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 AutoDoc. All rights reserved.'**
  String get footerCopyright;

  /// No description provided for @dashHello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {userName} 👋'**
  String dashHello(String userName);

  /// No description provided for @dashReadyForRoad.
  ///
  /// In en, this message translates to:
  /// **'Ready for the road today?'**
  String get dashReadyForRoad;

  /// No description provided for @dashMaintCritical.
  ///
  /// In en, this message translates to:
  /// **'Maintenance overdue — immediate attention'**
  String get dashMaintCritical;

  /// No description provided for @dashMaintWarning.
  ///
  /// In en, this message translates to:
  /// **'Upcoming maintenance — check alerts'**
  String get dashMaintWarning;

  /// No description provided for @dashMaintOptimal.
  ///
  /// In en, this message translates to:
  /// **'Vehicle in good condition'**
  String get dashMaintOptimal;

  /// No description provided for @dashMaintStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Status'**
  String get dashMaintStatusLabel;

  /// No description provided for @dashNoVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles registered'**
  String get dashNoVehicles;

  /// No description provided for @dashNoVehiclesDesc.
  ///
  /// In en, this message translates to:
  /// **'Add your first vehicle to start tracking its maintenance and status.'**
  String get dashNoVehiclesDesc;

  /// No description provided for @dashRegisterVehicle.
  ///
  /// In en, this message translates to:
  /// **'Register Vehicle'**
  String get dashRegisterVehicle;

  /// No description provided for @dashMainVehicle.
  ///
  /// In en, this message translates to:
  /// **'MAIN VEHICLE'**
  String get dashMainVehicle;

  /// No description provided for @dashLicensePlate.
  ///
  /// In en, this message translates to:
  /// **'License plate: {placa}'**
  String dashLicensePlate(String placa);

  /// No description provided for @dashMileage.
  ///
  /// In en, this message translates to:
  /// **'MILEAGE'**
  String get dashMileage;

  /// No description provided for @dashKm.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get dashKm;

  /// No description provided for @dashViewVehicleState.
  ///
  /// In en, this message translates to:
  /// **'View Vehicle Status'**
  String get dashViewVehicleState;

  /// No description provided for @dashAddVehicleError.
  ///
  /// In en, this message translates to:
  /// **'Error adding vehicle'**
  String get dashAddVehicleError;

  /// No description provided for @dashActiveAlerts.
  ///
  /// In en, this message translates to:
  /// **'Active Alerts'**
  String get dashActiveAlerts;

  /// No description provided for @dashViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get dashViewAll;

  /// No description provided for @dashNoAlertsPending.
  ///
  /// In en, this message translates to:
  /// **'Excellent! You have no pending alerts.'**
  String get dashNoAlertsPending;

  /// No description provided for @dashNearbyWorkshops.
  ///
  /// In en, this message translates to:
  /// **'Nearby Workshops'**
  String get dashNearbyWorkshops;

  /// No description provided for @dashViewAllWorkshops.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashViewAllWorkshops;

  /// No description provided for @dashTallerPendienteTitulo.
  ///
  /// In en, this message translates to:
  /// **'A new workshop wants access to the history'**
  String get dashTallerPendienteTitulo;

  /// No description provided for @dashTallerPendienteSolicitante.
  ///
  /// In en, this message translates to:
  /// **'Requested by: {tallerName}'**
  String dashTallerPendienteSolicitante(String tallerName);

  /// No description provided for @dashTallerPendienteNombreDesconocido.
  ///
  /// In en, this message translates to:
  /// **'A workshop'**
  String get dashTallerPendienteNombreDesconocido;

  /// No description provided for @dashTallerPendienteDesc.
  ///
  /// In en, this message translates to:
  /// **'This workshop is requesting permanent access to this vehicle\'s maintenance history. Confirm only if you recognize this visit.'**
  String get dashTallerPendienteDesc;

  /// No description provided for @dashTallerPendienteConfirmError.
  ///
  /// In en, this message translates to:
  /// **'Error confirming the workshop'**
  String get dashTallerPendienteConfirmError;

  /// No description provided for @dashTallerPendienteRechazarError.
  ///
  /// In en, this message translates to:
  /// **'Error rejecting the workshop'**
  String get dashTallerPendienteRechazarError;

  /// No description provided for @garageMyVehicles.
  ///
  /// In en, this message translates to:
  /// **'My Vehicles'**
  String get garageMyVehicles;

  /// No description provided for @garageNoVehicles.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have vehicles in your garage'**
  String get garageNoVehicles;

  /// No description provided for @garageOptimal.
  ///
  /// In en, this message translates to:
  /// **'Optimal'**
  String get garageOptimal;

  /// No description provided for @garageSuggestedReview.
  ///
  /// In en, this message translates to:
  /// **'Suggested Review'**
  String get garageSuggestedReview;

  /// No description provided for @garageMakePrimary.
  ///
  /// In en, this message translates to:
  /// **'Make Primary'**
  String get garageMakePrimary;

  /// No description provided for @garageNowPrimary.
  ///
  /// In en, this message translates to:
  /// **'{vehicleName} is now your primary vehicle'**
  String garageNowPrimary(String vehicleName);

  /// No description provided for @garageMakePrimaryError.
  ///
  /// In en, this message translates to:
  /// **'Could not set primary vehicle'**
  String get garageMakePrimaryError;

  /// No description provided for @garageAddVehicleError.
  ///
  /// In en, this message translates to:
  /// **'Error adding vehicle'**
  String get garageAddVehicleError;

  /// No description provided for @vpProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Profile'**
  String get vpProfileTitle;

  /// No description provided for @vpShareVehicle.
  ///
  /// In en, this message translates to:
  /// **'Share Vehicle'**
  String get vpShareVehicle;

  /// No description provided for @vpDeleteVehicle.
  ///
  /// In en, this message translates to:
  /// **'Delete Vehicle'**
  String get vpDeleteVehicle;

  /// No description provided for @vpActiveStatus.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get vpActiveStatus;

  /// No description provided for @vpOwnerPersonal.
  ///
  /// In en, this message translates to:
  /// **'Owner: Personal'**
  String get vpOwnerPersonal;

  /// No description provided for @vpYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get vpYear;

  /// No description provided for @vpColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get vpColor;

  /// No description provided for @vpMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get vpMileage;

  /// No description provided for @vpKm.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get vpKm;

  /// No description provided for @vpBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get vpBrand;

  /// No description provided for @vpDocAndAlerts.
  ///
  /// In en, this message translates to:
  /// **'Documentation and Alerts'**
  String get vpDocAndAlerts;

  /// No description provided for @vpCirculationCard.
  ///
  /// In en, this message translates to:
  /// **'Circulation Card'**
  String get vpCirculationCard;

  /// No description provided for @vpSoatInsurance.
  ///
  /// In en, this message translates to:
  /// **'SOAT Insurance'**
  String get vpSoatInsurance;

  /// No description provided for @vpDateNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Date not registered'**
  String get vpDateNotRegistered;

  /// No description provided for @vpUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get vpUpdate;

  /// No description provided for @vpExpiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired on {date}'**
  String vpExpiredOn(String date);

  /// No description provided for @vpExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days} days ({date})'**
  String vpExpiresInDays(String days, String date);

  /// No description provided for @vpRenew.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get vpRenew;

  /// No description provided for @vpUpdateMileage.
  ///
  /// In en, this message translates to:
  /// **'Update Mileage'**
  String get vpUpdateMileage;

  /// No description provided for @vpEnterNewMileage.
  ///
  /// In en, this message translates to:
  /// **'Enter the current mileage. It must be greater than {km} km.'**
  String vpEnterNewMileage(String km);

  /// No description provided for @vpNewMileageLabel.
  ///
  /// In en, this message translates to:
  /// **'New Mileage'**
  String get vpNewMileageLabel;

  /// No description provided for @vpEnterValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get vpEnterValue;

  /// No description provided for @vpEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get vpEnterValidNumber;

  /// No description provided for @vpMustBeGreaterThan.
  ///
  /// In en, this message translates to:
  /// **'Must be greater than {km}'**
  String vpMustBeGreaterThan(String km);

  /// No description provided for @vpSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vpSave;

  /// No description provided for @vpMileageUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Mileage updated successfully'**
  String get vpMileageUpdatedSuccess;

  /// No description provided for @vpUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Update error'**
  String get vpUpdateError;

  /// No description provided for @vpConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the {brand} {model}? This action cannot be undone.'**
  String vpConfirmDelete(String brand, String model);

  /// No description provided for @vpEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get vpEnterPassword;

  /// No description provided for @vpIncorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get vpIncorrectPassword;

  /// No description provided for @vpDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Vehicle deleted successfully'**
  String get vpDeleteSuccess;

  /// No description provided for @vpDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting vehicle'**
  String get vpDeleteError;

  /// No description provided for @vpQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get vpQuickActions;

  /// No description provided for @vpHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get vpHistory;

  /// No description provided for @vpServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get vpServices;

  /// No description provided for @vpPapers.
  ///
  /// In en, this message translates to:
  /// **'Papers'**
  String get vpPapers;

  /// No description provided for @vpDateUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Date updated successfully'**
  String get vpDateUpdatedSuccess;

  /// No description provided for @vpDateUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Error updating date'**
  String get vpDateUpdateError;

  /// No description provided for @alertsSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select a vehicle first'**
  String get alertsSelectVehicle;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsUpdateMileage.
  ///
  /// In en, this message translates to:
  /// **'Update Mileage'**
  String get alertsUpdateMileage;

  /// No description provided for @alertsTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get alertsTabAll;

  /// No description provided for @alertsTabUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get alertsTabUrgent;

  /// No description provided for @alertsTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get alertsTabUpcoming;

  /// No description provided for @alertsAllGood.
  ///
  /// In en, this message translates to:
  /// **'All up to date!'**
  String get alertsAllGood;

  /// No description provided for @alertsNoAlertsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No alerts in this category.'**
  String get alertsNoAlertsInCategory;

  /// No description provided for @alertsHighPriority.
  ///
  /// In en, this message translates to:
  /// **'High Priority'**
  String get alertsHighPriority;

  /// No description provided for @alertsPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String alertsPendingCount(String count);

  /// No description provided for @alertsUpcomingExpirations.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Expirations'**
  String get alertsUpcomingExpirations;

  /// No description provided for @alertsEventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String alertsEventsCount(String count);

  /// No description provided for @alertsSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get alertsSuggestions;

  /// No description provided for @alertsCurrentMileage.
  ///
  /// In en, this message translates to:
  /// **'Current mileage: '**
  String get alertsCurrentMileage;

  /// No description provided for @alertsOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {km} km. Immediate attention!'**
  String alertsOverdue(String km);

  /// No description provided for @alertsMissingKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km left for scheduled review.'**
  String alertsMissingKm(String km);

  /// No description provided for @alertsNextServiceApprox.
  ///
  /// In en, this message translates to:
  /// **'Next service in approx {km} km.'**
  String alertsNextServiceApprox(String km);

  /// No description provided for @alertsLastKm.
  ///
  /// In en, this message translates to:
  /// **'Last: {km} km'**
  String alertsLastKm(String km);

  /// No description provided for @alertsEveryKm.
  ///
  /// In en, this message translates to:
  /// **'Every {km} km'**
  String alertsEveryKm(String km);

  /// No description provided for @alertsConfig.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get alertsConfig;

  /// No description provided for @alertsComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get alertsComplete;

  /// No description provided for @alertsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get alertsSave;

  /// No description provided for @alertsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get alertsCancel;

  /// No description provided for @alertsNewMileage.
  ///
  /// In en, this message translates to:
  /// **'New Mileage'**
  String get alertsNewMileage;

  /// No description provided for @histTitle.
  ///
  /// In en, this message translates to:
  /// **'Service History'**
  String get histTitle;

  /// No description provided for @histTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get histTabAll;

  /// No description provided for @histTabManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get histTabManual;

  /// No description provided for @histTabWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get histTabWorkshop;

  /// No description provided for @histNoServices.
  ///
  /// In en, this message translates to:
  /// **'No services registered'**
  String get histNoServices;

  /// No description provided for @histNoServicesDesc.
  ///
  /// In en, this message translates to:
  /// **'Maintenances will appear here'**
  String get histNoServicesDesc;

  /// No description provided for @histOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get histOwner;

  /// No description provided for @histWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get histWorkshop;

  /// No description provided for @histEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get histEvidence;

  /// No description provided for @histReviewWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Review workshop'**
  String get histReviewWorkshop;

  /// No description provided for @wdErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading workshops'**
  String get wdErrorLoading;

  /// No description provided for @wdNoWorkshopsFound.
  ///
  /// In en, this message translates to:
  /// **'No workshops found'**
  String get wdNoWorkshopsFound;

  /// No description provided for @wdTitle.
  ///
  /// In en, this message translates to:
  /// **'Workshop Directory'**
  String get wdTitle;

  /// No description provided for @wdSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search mechanics or services...'**
  String get wdSearchHint;

  /// No description provided for @wdFilterMunicipality.
  ///
  /// In en, this message translates to:
  /// **'Municipality'**
  String get wdFilterMunicipality;

  /// No description provided for @wdFilterSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get wdFilterSpecialty;

  /// No description provided for @wdFilterRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get wdFilterRating;

  /// No description provided for @wdYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your Location'**
  String get wdYourLocation;

  /// No description provided for @wdWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get wdWorkshop;

  /// No description provided for @wdGeneralMechanics.
  ///
  /// In en, this message translates to:
  /// **'General Mechanics'**
  String get wdGeneralMechanics;

  /// No description provided for @wdMechanics.
  ///
  /// In en, this message translates to:
  /// **'Mechanics'**
  String get wdMechanics;

  /// No description provided for @wdDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String wdDistanceKm(String km);

  /// No description provided for @wdWorkshopsOnMap.
  ///
  /// In en, this message translates to:
  /// **'{count} workshops on map'**
  String wdWorkshopsOnMap(String count);

  /// No description provided for @wdNoLocationCount.
  ///
  /// In en, this message translates to:
  /// **'{count} without location'**
  String wdNoLocationCount(String count);

  /// No description provided for @wdNoPhoneRegistered.
  ///
  /// In en, this message translates to:
  /// **'This workshop has no registered phone'**
  String get wdNoPhoneRegistered;

  /// No description provided for @wdContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact {name}'**
  String wdContactName(String name);

  /// No description provided for @wdCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get wdCopy;

  /// No description provided for @wdClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get wdClose;

  /// No description provided for @wdPhoneCopied.
  ///
  /// In en, this message translates to:
  /// **'Phone copied to clipboard'**
  String get wdPhoneCopied;

  /// No description provided for @wdNamelessWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Nameless Workshop'**
  String get wdNamelessWorkshop;

  /// No description provided for @wdLocationNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Location not specified'**
  String get wdLocationNotSpecified;

  /// No description provided for @wdSpecialtyIs.
  ///
  /// In en, this message translates to:
  /// **'Specialty: {specialty}'**
  String wdSpecialtyIs(String specialty);

  /// No description provided for @wdReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String wdReviewsCount(String count);

  /// No description provided for @wdReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count} review'**
  String wdReviewCount(String count);

  /// No description provided for @wdReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get wdReview;

  /// No description provided for @wdContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get wdContact;

  /// No description provided for @upErrorUploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Error uploading image: {error}'**
  String upErrorUploadingImage(String error);

  /// No description provided for @upProfileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get upProfileUpdatedSuccess;

  /// No description provided for @upProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get upProfileTitle;

  /// No description provided for @upProfileDataNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile data not found'**
  String get upProfileDataNotFound;

  /// No description provided for @upPleaseCompleteSetup.
  ///
  /// In en, this message translates to:
  /// **'Please complete your profile setup.'**
  String get upPleaseCompleteSetup;

  /// No description provided for @upSetupProfile.
  ///
  /// In en, this message translates to:
  /// **'Setup Profile'**
  String get upSetupProfile;

  /// No description provided for @upSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get upSignOut;

  /// No description provided for @upSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get upSaveChanges;

  /// No description provided for @upMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get upMyProfile;

  /// No description provided for @upFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get upFullName;

  /// No description provided for @upEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get upEmailAddress;

  /// No description provided for @upMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Member Since'**
  String get upMemberSince;

  /// No description provided for @upSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get upSettings;

  /// No description provided for @upDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get upDarkMode;

  /// No description provided for @upSwitchTheme.
  ///
  /// In en, this message translates to:
  /// **'Switch between light and dark theme'**
  String get upSwitchTheme;

  /// No description provided for @upFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get upFollowSystem;

  /// No description provided for @upUseSystemTheme.
  ///
  /// In en, this message translates to:
  /// **'Use system default theme'**
  String get upUseSystemTheme;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboardTitle;

  /// No description provided for @adminDashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String adminDashboardWelcome(String name);

  /// No description provided for @adminDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Administrative control panel'**
  String get adminDashboardSubtitle;

  /// No description provided for @adminGlobalMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Global Metrics'**
  String get adminGlobalMetricsTitle;

  /// No description provided for @adminMetricsUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminMetricsUsers;

  /// No description provided for @adminMetricsWorkshops.
  ///
  /// In en, this message translates to:
  /// **'Workshops'**
  String get adminMetricsWorkshops;

  /// No description provided for @adminMetricsVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get adminMetricsVehicles;

  /// No description provided for @adminMetricsServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get adminMetricsServices;

  /// No description provided for @adminMetricsAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get adminMetricsAlerts;

  /// No description provided for @adminMetricsReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get adminMetricsReviews;

  /// No description provided for @adminQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get adminQuickActionsTitle;

  /// No description provided for @adminQuickActionManageUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage Users'**
  String get adminQuickActionManageUsers;

  /// No description provided for @adminQuickActionManageWorkshops.
  ///
  /// In en, this message translates to:
  /// **'Manage Workshops'**
  String get adminQuickActionManageWorkshops;

  /// No description provided for @adminQuickActionModerateReviews.
  ///
  /// In en, this message translates to:
  /// **'Moderate Reviews'**
  String get adminQuickActionModerateReviews;

  /// No description provided for @adminQuickActionViewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Activity'**
  String get adminQuickActionViewLogs;

  /// No description provided for @adminRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get adminRecentActivityTitle;

  /// No description provided for @adminNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get adminNoRecentActivity;

  /// No description provided for @adminViewAllLogs.
  ///
  /// In en, this message translates to:
  /// **'View all logs'**
  String get adminViewAllLogs;

  /// No description provided for @authCompleteCredentials.
  ///
  /// In en, this message translates to:
  /// **'Fill in email and password.'**
  String get authCompleteCredentials;

  /// No description provided for @authEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEnterValidEmail;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authPasswordTooShort;

  /// No description provided for @addVehicleBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get addVehicleBrand;

  /// No description provided for @addVehicleBrandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What is the brand of your vehicle?'**
  String get addVehicleBrandSubtitle;

  /// No description provided for @addVehicleSearchBrand.
  ///
  /// In en, this message translates to:
  /// **'Search brand...'**
  String get addVehicleSearchBrand;

  /// No description provided for @addVehicleErrorBrands.
  ///
  /// In en, this message translates to:
  /// **'Error loading brands'**
  String get addVehicleErrorBrands;

  /// No description provided for @addVehicleRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get addVehicleRetry;

  /// No description provided for @addVehicleNotFoundBrand.
  ///
  /// In en, this message translates to:
  /// **'I can\'t find my brand...'**
  String get addVehicleNotFoundBrand;

  /// No description provided for @addVehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get addVehicleModel;

  /// No description provided for @addVehicleModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the model of your {brand}'**
  String addVehicleModelSubtitle(String brand);

  /// No description provided for @addVehicleSearchModel.
  ///
  /// In en, this message translates to:
  /// **'Search model...'**
  String get addVehicleSearchModel;

  /// No description provided for @addVehicleErrorModels.
  ///
  /// In en, this message translates to:
  /// **'Error loading models'**
  String get addVehicleErrorModels;

  /// No description provided for @addVehicleNotFoundModel.
  ///
  /// In en, this message translates to:
  /// **'I can\'t find my model...'**
  String get addVehicleNotFoundModel;

  /// No description provided for @addVehicleDetails.
  ///
  /// In en, this message translates to:
  /// **'Final Details'**
  String get addVehicleDetails;

  /// No description provided for @addVehicleDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete the remaining information'**
  String get addVehicleDetailsSubtitle;

  /// No description provided for @addVehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'License Plate'**
  String get addVehiclePlate;

  /// No description provided for @addVehiclePlateHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. P123-456'**
  String get addVehiclePlateHint;

  /// No description provided for @addVehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get addVehicleYear;

  /// No description provided for @addVehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get addVehicleColor;

  /// No description provided for @addVehicleColorHint.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get addVehicleColorHint;

  /// No description provided for @addVehicleMileage.
  ///
  /// In en, this message translates to:
  /// **'Current Mileage'**
  String get addVehicleMileage;

  /// No description provided for @addVehicleDocs.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get addVehicleDocs;

  /// No description provided for @addVehicleCardExp.
  ///
  /// In en, this message translates to:
  /// **'Card Expiration'**
  String get addVehicleCardExp;

  /// No description provided for @addVehicleSoatExp.
  ///
  /// In en, this message translates to:
  /// **'SOAT Expiration'**
  String get addVehicleSoatExp;

  /// No description provided for @addVehicleFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish Registration'**
  String get addVehicleFinish;

  /// No description provided for @addVehicleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Registered!'**
  String get addVehicleSuccess;

  /// No description provided for @addVehicleSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Your {brand} {model} is now in the garage.'**
  String addVehicleSuccessDesc(String brand, String model);

  /// No description provided for @addVehicleGoDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get addVehicleGoDashboard;

  /// No description provided for @addVehicleSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get addVehicleSelectDate;

  /// No description provided for @histTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get histTotalSpent;

  /// No description provided for @histServicesCount.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get histServicesCount;

  /// No description provided for @histAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get histAverage;

  /// No description provided for @vpQuickNotes.
  ///
  /// In en, this message translates to:
  /// **'Quick Notes'**
  String get vpQuickNotes;

  /// No description provided for @pdfHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Service History'**
  String get pdfHistoryTitle;

  /// No description provided for @pdfVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle: {brand} {model} ({year})'**
  String pdfVehicle(String brand, String model, String year);

  /// No description provided for @pdfPlate.
  ///
  /// In en, this message translates to:
  /// **'Plate: {plate}'**
  String pdfPlate(String plate);

  /// No description provided for @pdfReportDate.
  ///
  /// In en, this message translates to:
  /// **'Report Date: {date}'**
  String pdfReportDate(String date);

  /// No description provided for @pdfTotalServices.
  ///
  /// In en, this message translates to:
  /// **'Total Services: {count}'**
  String pdfTotalServices(String count);

  /// No description provided for @pdfTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent: \${amount}'**
  String pdfTotalSpent(String amount);

  /// No description provided for @adminLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get adminLogsTitle;

  /// No description provided for @adminDeleteReview.
  ///
  /// In en, this message translates to:
  /// **'Delete Review'**
  String get adminDeleteReview;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminDelete;

  /// No description provided for @adminModerateReviews.
  ///
  /// In en, this message translates to:
  /// **'Review Moderation'**
  String get adminModerateReviews;

  /// No description provided for @adminAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get adminAccessDenied;

  /// No description provided for @adminAccessDeniedDesc.
  ///
  /// In en, this message translates to:
  /// **'This screen is only available in a development environment.'**
  String get adminAccessDeniedDesc;

  /// No description provided for @adminConfigAdmins.
  ///
  /// In en, this message translates to:
  /// **'Configure Administrators'**
  String get adminConfigAdmins;

  /// No description provided for @adminConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get adminConfirm;

  /// No description provided for @adminManageWorkshops.
  ///
  /// In en, this message translates to:
  /// **'Workshop Management'**
  String get adminManageWorkshops;

  /// No description provided for @adminChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change User Role'**
  String get adminChangeRole;

  /// No description provided for @adminSelectNewRole.
  ///
  /// In en, this message translates to:
  /// **'Select the new role:'**
  String get adminSelectNewRole;

  /// No description provided for @adminManageUsers.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get adminManageUsers;

  /// No description provided for @adminSuspendAccount.
  ///
  /// In en, this message translates to:
  /// **'Suspend Account'**
  String get adminSuspendAccount;

  /// No description provided for @adminReactivateAccount.
  ///
  /// In en, this message translates to:
  /// **'Reactivate Account'**
  String get adminReactivateAccount;

  /// No description provided for @adminChangeUserRole.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get adminChangeUserRole;

  /// No description provided for @adminNoTrendData.
  ///
  /// In en, this message translates to:
  /// **'No trend data available.'**
  String get adminNoTrendData;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminApproveWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Approve Workshop'**
  String get adminApproveWorkshop;

  /// No description provided for @adminSuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get adminSuspend;

  /// No description provided for @adminReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get adminReactivate;

  /// No description provided for @adminError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String adminError(String error);

  /// No description provided for @chatOpeningSection.
  ///
  /// In en, this message translates to:
  /// **'Opening {label} section...'**
  String chatOpeningSection(String label);

  /// No description provided for @chatDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessage;

  /// No description provided for @chatCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatCamera;

  /// No description provided for @chatGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatGallery;

  /// No description provided for @chatShareVehicle.
  ///
  /// In en, this message translates to:
  /// **'Share Vehicle'**
  String get chatShareVehicle;

  /// No description provided for @chatNewReservation.
  ///
  /// In en, this message translates to:
  /// **'New Reservation'**
  String get chatNewReservation;

  /// No description provided for @chatSendQuote.
  ///
  /// In en, this message translates to:
  /// **'Send Quote'**
  String get chatSendQuote;

  /// No description provided for @chatRequestRating.
  ///
  /// In en, this message translates to:
  /// **'Request Rating'**
  String get chatRequestRating;

  /// No description provided for @chatUploadImageError.
  ///
  /// In en, this message translates to:
  /// **'Error uploading image'**
  String get chatUploadImageError;

  /// No description provided for @chatReservationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reservation {status} successfully'**
  String chatReservationSuccess(String status);

  /// No description provided for @chatReservationDetail.
  ///
  /// In en, this message translates to:
  /// **'Appointment Detail'**
  String get chatReservationDetail;

  /// No description provided for @coreAppTitle.
  ///
  /// In en, this message translates to:
  /// **'AutoDoc Workshop'**
  String get coreAppTitle;

  /// No description provided for @chatViewFullHistory.
  ///
  /// In en, this message translates to:
  /// **'View Full History'**
  String get chatViewFullHistory;

  /// No description provided for @chatConfirmProposal.
  ///
  /// In en, this message translates to:
  /// **'Confirm Proposal'**
  String get chatConfirmProposal;

  /// No description provided for @chatGenerateAndSend.
  ///
  /// In en, this message translates to:
  /// **'Generate and Send'**
  String get chatGenerateAndSend;

  /// No description provided for @chatRateService.
  ///
  /// In en, this message translates to:
  /// **'Rate Service'**
  String get chatRateService;

  /// No description provided for @chatReviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your review!'**
  String get chatReviewThanks;

  /// No description provided for @chatAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatAccept;

  /// No description provided for @chatReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get chatReject;

  /// No description provided for @chatViewDetail.
  ///
  /// In en, this message translates to:
  /// **'View detail'**
  String get chatViewDetail;

  /// No description provided for @chatService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get chatService;

  /// No description provided for @chatDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get chatDate;

  /// No description provided for @chatTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get chatTime;

  /// No description provided for @chatVehicleId.
  ///
  /// In en, this message translates to:
  /// **'Vehicle ID'**
  String get chatVehicleId;

  /// No description provided for @chatAcceptAppointment.
  ///
  /// In en, this message translates to:
  /// **'Accept Appointment'**
  String get chatAcceptAppointment;

  /// No description provided for @chatRejectReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reject / Reschedule'**
  String get chatRejectReschedule;

  /// No description provided for @chatConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message for everyone?'**
  String get chatConfirmDelete;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'You have no notifications'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @upLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language / Idioma'**
  String get upLanguage;

  /// No description provided for @upLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'EN (Enabled) / ES (Disabled)'**
  String get upLanguageDesc;

  /// No description provided for @upAbout.
  ///
  /// In en, this message translates to:
  /// **'About AutoDoc'**
  String get upAbout;

  /// No description provided for @upAboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Version, credits and legal'**
  String get upAboutDesc;

  /// No description provided for @upDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get upDeleteAccountTitle;

  /// No description provided for @upDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone and you will lose all your data.'**
  String get upDeleteAccountConfirm;

  /// No description provided for @upEnterPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'To confirm, enter your password:'**
  String get upEnterPasswordConfirm;

  /// No description provided for @upPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get upPasswordLabel;

  /// No description provided for @upGoogleReauthConfirm.
  ///
  /// In en, this message translates to:
  /// **'To confirm, you must sign in with Google again.'**
  String get upGoogleReauthConfirm;

  /// No description provided for @upPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Password cannot be empty.'**
  String get upPasswordEmpty;

  /// No description provided for @upPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get upPasswordIncorrect;

  /// No description provided for @upGoogleReauthFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not re-authenticate with Google.'**
  String get upGoogleReauthFailed;

  /// No description provided for @upDeleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting account: {error}'**
  String upDeleteAccountError(String error);

  /// No description provided for @upCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get upCancel;

  /// No description provided for @upDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get upDelete;

  /// No description provided for @upDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get upDeleteAccount;
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
