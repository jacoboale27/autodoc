// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'AutoDoc';

  @override
  String get navPlatform => 'Platform';

  @override
  String get navOwners => 'For Owners';

  @override
  String get navWorkshops => 'Workshops';

  @override
  String get navLogin => 'Log In';

  @override
  String get navTryFree => 'Try for Free';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authRegisterFree => 'Sign up for free';

  @override
  String get authLogin => 'Log in';

  @override
  String get authCopilotSubtitle => 'Your copilot for total vehicle control';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authCreateAccount => 'Create your account';

  @override
  String get authEnterCredentials => 'Enter your credentials to access';

  @override
  String get authRegisterToManage => 'Sign up to start managing your documents';

  @override
  String get authEmailOrUserLabel => 'Email or Username';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailOrUserHint => 'name@example.com or username';

  @override
  String get authEmailHint => 'name@example.com';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => '••••••••';

  @override
  String get authRememberMe => 'Remember me';

  @override
  String get authForgotPassword => 'Forgot your password?';

  @override
  String get authLoginButton => 'Log In';

  @override
  String get authRegisterButton => 'Sign Up';

  @override
  String get authOrContinueWith => 'OR CONTINUE WITH';

  @override
  String get authGoogleLogin => 'Log in with Google';

  @override
  String get authTabLogin => 'Log In';

  @override
  String get authTabRegister => 'Sign Up';

  @override
  String get authTabSupport => 'Support';

  @override
  String get authForgotPassTitle => 'Recover Password';

  @override
  String get authForgotPassDesc =>
      'We will send a link to your email to reset your password.';

  @override
  String get authCancel => 'Cancel';

  @override
  String get authSendLink => 'Send link';

  @override
  String get authInvalidEmail => 'Enter a valid email.';

  @override
  String get authSendEmailError => 'Could not send the email.';

  @override
  String get authCheckInbox => 'Check your inbox at ';

  @override
  String get authAndSpam => ' (and the spam folder).';

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String get authSentLinkTo => 'We sent a verification link to:';

  @override
  String get authAccountNotVerified =>
      'Your account is not verified yet. Check the email sent to:';

  @override
  String get authOpenLinkThenVerify =>
      'Open the link in the email and then press \"I already verified\" to continue.';

  @override
  String get authUnderstood => 'Understood';

  @override
  String get authContinueWithoutVerify => 'Continue without verifying';

  @override
  String get authResendEmail => 'Resend email';

  @override
  String get authEmailResent => 'Verification email resent.';

  @override
  String get authResendError => 'Could not resend.';

  @override
  String get authAlreadyVerified => 'I already verified';

  @override
  String get authEmailVerifiedSuccess => 'Email verified successfully!';

  @override
  String get authVerificationNotDetected =>
      'We still don\'t detect the verification. Open the link in the email and try again.';

  @override
  String get authSupportCenter => 'Support Center';

  @override
  String get authSupportDesc =>
      'Need help with your account, email verification, or access?';

  @override
  String get authSupportEmail => 'Support email';

  @override
  String get authEmailCopied => 'Email copied to clipboard';

  @override
  String get authEmailVerification => 'Email verification';

  @override
  String get authEmailNotReceived =>
      'Email didn\'t arrive → check spam or resend from login';

  @override
  String get authLoginToResend =>
      'Log in with your email to resend verification.';

  @override
  String get authForgotPassTileTitle => 'I forgot my password';

  @override
  String get authReceiveRecoveryLink => 'Receive a recovery link by email';

  @override
  String get authSupportHours => 'Support hours: Mon–Fri 8:00–18:00';

  @override
  String get heroBadge => 'TOTAL CONTROL IN YOUR HANDS';

  @override
  String get heroTitle => 'Your Virtual Garage,\nElevated';

  @override
  String get heroSubtitle =>
      'Digitize your vehicle today. Certified clinical history, smart SOAT and maintenance alerts, connected with the best workshops.';

  @override
  String get heroStartGarage => 'Start my Garage';

  @override
  String get heroViewDirectory => 'View Directory';

  @override
  String get commandCenterTitle => 'Command Center';

  @override
  String get commandCenterSubtitle => 'Everything you need in one place';

  @override
  String get tabGarageTitle => 'Garage';

  @override
  String get tabGarageSubtitle => 'Your vehicles';

  @override
  String get tabHistoryTitle => 'History';

  @override
  String get tabHistorySubtitle => 'Services';

  @override
  String get tabAlertsTitle => 'Alerts';

  @override
  String get tabAlertsSubtitle => 'Reminders';

  @override
  String get tabSyncTitle => 'Sync';

  @override
  String get tabSyncSubtitle => 'Data';

  @override
  String get valuePropTitle => 'Why choose AutoDoc';

  @override
  String get valuePropSubtitle => 'Exclusive benefits';

  @override
  String get statSatisfaction => '99% Satisfaction';

  @override
  String get statWorkshops => '+500 Workshops';

  @override
  String get footerDesc => 'The best app for your vehicle care';

  @override
  String get footerOwners => 'For Owners';

  @override
  String get footerWorkshops => 'For Workshops';

  @override
  String get footerSocial => 'Social Media';

  @override
  String get footerCopyright => '© 2026 AutoDoc. All rights reserved.';

  @override
  String dashHello(String userName) {
    return 'Hello, $userName 👋';
  }

  @override
  String get dashReadyForRoad => 'Ready for the road today?';

  @override
  String get dashMaintCritical => 'Maintenance overdue — immediate attention';

  @override
  String get dashMaintWarning => 'Upcoming maintenance — check alerts';

  @override
  String get dashMaintOptimal => 'Vehicle in good condition';

  @override
  String get dashMaintStatusLabel => 'Maintenance Status';

  @override
  String get dashNoVehicles => 'No vehicles registered';

  @override
  String get dashNoVehiclesDesc =>
      'Add your first vehicle to start tracking its maintenance and status.';

  @override
  String get dashRegisterVehicle => 'Register Vehicle';

  @override
  String get dashMainVehicle => 'MAIN VEHICLE';

  @override
  String dashLicensePlate(String placa) {
    return 'License plate: $placa';
  }

  @override
  String get dashMileage => 'MILEAGE';

  @override
  String get dashKm => 'km';

  @override
  String get dashViewVehicleState => 'View Vehicle Status';

  @override
  String get dashAddVehicleError => 'Error adding vehicle';

  @override
  String get dashActiveAlerts => 'Active Alerts';

  @override
  String get dashViewAll => 'View All';

  @override
  String get dashNoAlertsPending => 'Excellent! You have no pending alerts.';

  @override
  String get dashNearbyWorkshops => 'Nearby Workshops';

  @override
  String get dashViewAllWorkshops => 'View all';

  @override
  String get garageMyVehicles => 'My Vehicles';

  @override
  String get garageNoVehicles => 'You don\'t have vehicles in your garage';

  @override
  String get garageOptimal => 'Optimal';

  @override
  String get garageSuggestedReview => 'Suggested Review';

  @override
  String get garageMakePrimary => 'Make Primary';

  @override
  String garageNowPrimary(String vehicleName) {
    return '$vehicleName is now your primary vehicle';
  }

  @override
  String get garageMakePrimaryError => 'Could not set primary vehicle';

  @override
  String get garageAddVehicleError => 'Error adding vehicle';

  @override
  String get vpProfileTitle => 'Vehicle Profile';

  @override
  String get vpShareVehicle => 'Share Vehicle';

  @override
  String get vpDeleteVehicle => 'Delete Vehicle';

  @override
  String get vpActiveStatus => 'ACTIVE';

  @override
  String get vpOwnerPersonal => 'Owner: Personal';

  @override
  String get vpYear => 'Year';

  @override
  String get vpColor => 'Color';

  @override
  String get vpMileage => 'Mileage';

  @override
  String get vpKm => 'km';

  @override
  String get vpBrand => 'Brand';

  @override
  String get vpDocAndAlerts => 'Documentation and Alerts';

  @override
  String get vpCirculationCard => 'Circulation Card';

  @override
  String get vpSoatInsurance => 'SOAT Insurance';

  @override
  String get vpDateNotRegistered => 'Date not registered';

  @override
  String get vpUpdate => 'Update';

  @override
  String vpExpiredOn(String date) {
    return 'Expired on $date';
  }

  @override
  String vpExpiresInDays(String days, String date) {
    return 'Expires in $days days ($date)';
  }

  @override
  String get vpRenew => 'Renew';

  @override
  String get vpUpdateMileage => 'Update Mileage';

  @override
  String vpEnterNewMileage(String km) {
    return 'Enter the current mileage. It must be greater than $km km.';
  }

  @override
  String get vpNewMileageLabel => 'New Mileage';

  @override
  String get vpEnterValue => 'Enter a value';

  @override
  String get vpEnterValidNumber => 'Enter a valid number';

  @override
  String vpMustBeGreaterThan(String km) {
    return 'Must be greater than $km';
  }

  @override
  String get vpSave => 'Save';

  @override
  String get vpMileageUpdatedSuccess => 'Mileage updated successfully';

  @override
  String get vpUpdateError => 'Update error';

  @override
  String vpConfirmDelete(String brand, String model) {
    return 'Are you sure you want to delete the $brand $model? This action cannot be undone.';
  }

  @override
  String get vpEnterPassword => 'Enter your password';

  @override
  String get vpIncorrectPassword => 'Incorrect password';

  @override
  String get vpDeleteSuccess => 'Vehicle deleted successfully';

  @override
  String get vpDeleteError => 'Error deleting vehicle';

  @override
  String get vpQuickActions => 'Quick Actions';

  @override
  String get vpHistory => 'History';

  @override
  String get vpServices => 'Services';

  @override
  String get vpPapers => 'Papers';

  @override
  String get vpDateUpdatedSuccess => 'Date updated successfully';

  @override
  String get vpDateUpdateError => 'Error updating date';

  @override
  String get alertsSelectVehicle => 'Select a vehicle first';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsUpdateMileage => 'Update Mileage';

  @override
  String get alertsTabAll => 'All';

  @override
  String get alertsTabUrgent => 'Urgent';

  @override
  String get alertsTabUpcoming => 'Upcoming';

  @override
  String get alertsAllGood => 'All up to date!';

  @override
  String get alertsNoAlertsInCategory => 'No alerts in this category.';

  @override
  String get alertsHighPriority => 'High Priority';

  @override
  String alertsPendingCount(String count) {
    return '$count pending';
  }

  @override
  String get alertsUpcomingExpirations => 'Upcoming Expirations';

  @override
  String alertsEventsCount(String count) {
    return '$count events';
  }

  @override
  String get alertsSuggestions => 'Suggestions';

  @override
  String get alertsCurrentMileage => 'Current mileage: ';

  @override
  String alertsOverdue(String km) {
    return 'Overdue by $km km. Immediate attention!';
  }

  @override
  String alertsMissingKm(String km) {
    return '$km km left for scheduled review.';
  }

  @override
  String alertsNextServiceApprox(String km) {
    return 'Next service in approx $km km.';
  }

  @override
  String alertsLastKm(String km) {
    return 'Last: $km km';
  }

  @override
  String alertsEveryKm(String km) {
    return 'Every $km km';
  }

  @override
  String get alertsConfig => 'Configure';

  @override
  String get alertsComplete => 'Complete';

  @override
  String get alertsSave => 'Save';

  @override
  String get alertsCancel => 'Cancel';

  @override
  String get alertsNewMileage => 'New Mileage';

  @override
  String get histTitle => 'Service History';

  @override
  String get histTabAll => 'All';

  @override
  String get histTabManual => 'Manual';

  @override
  String get histTabWorkshop => 'Workshop';

  @override
  String get histNoServices => 'No services registered';

  @override
  String get histNoServicesDesc => 'Maintenances will appear here';

  @override
  String get histOwner => 'Owner';

  @override
  String get histWorkshop => 'Workshop';

  @override
  String get histEvidence => 'Evidence';

  @override
  String get histReviewWorkshop => 'Review workshop';

  @override
  String get wdErrorLoading => 'Error loading workshops';

  @override
  String get wdNoWorkshopsFound => 'No workshops found';

  @override
  String get wdTitle => 'Workshop Directory';

  @override
  String get wdSearchHint => 'Search mechanics or services...';

  @override
  String get wdFilterMunicipality => 'Municipality';

  @override
  String get wdFilterSpecialty => 'Specialty';

  @override
  String get wdFilterRating => 'Rating';

  @override
  String get wdYourLocation => 'Your Location';

  @override
  String get wdWorkshop => 'Workshop';

  @override
  String get wdGeneralMechanics => 'General Mechanics';

  @override
  String get wdMechanics => 'Mechanics';

  @override
  String wdDistanceKm(String km) {
    return '$km km away';
  }

  @override
  String wdWorkshopsOnMap(String count) {
    return '$count workshops on map';
  }

  @override
  String wdNoLocationCount(String count) {
    return '$count without location';
  }

  @override
  String get wdNoPhoneRegistered => 'This workshop has no registered phone';

  @override
  String wdContactName(String name) {
    return 'Contact $name';
  }

  @override
  String get wdCopy => 'Copy';

  @override
  String get wdClose => 'Close';

  @override
  String get wdPhoneCopied => 'Phone copied to clipboard';

  @override
  String get wdNamelessWorkshop => 'Nameless Workshop';

  @override
  String get wdLocationNotSpecified => 'Location not specified';

  @override
  String wdSpecialtyIs(String specialty) {
    return 'Specialty: $specialty';
  }

  @override
  String wdReviewsCount(String count) {
    return '$count reviews';
  }

  @override
  String wdReviewCount(String count) {
    return '$count review';
  }

  @override
  String get wdReview => 'Review';

  @override
  String get wdContact => 'Contact';

  @override
  String upErrorUploadingImage(String error) {
    return 'Error uploading image: $error';
  }

  @override
  String get upProfileUpdatedSuccess => 'Profile updated successfully';

  @override
  String get upProfileTitle => 'Profile';

  @override
  String get upProfileDataNotFound => 'Profile data not found';

  @override
  String get upPleaseCompleteSetup => 'Please complete your profile setup.';

  @override
  String get upSetupProfile => 'Setup Profile';

  @override
  String get upSignOut => 'Sign Out';

  @override
  String get upSaveChanges => 'Save Changes';

  @override
  String get upMyProfile => 'My Profile';

  @override
  String get upFullName => 'Full Name';

  @override
  String get upEmailAddress => 'Email Address';

  @override
  String get upMemberSince => 'Member Since';

  @override
  String get upSettings => 'Settings';

  @override
  String get upDarkMode => 'Dark Mode';

  @override
  String get upSwitchTheme => 'Switch between light and dark theme';

  @override
  String get upFollowSystem => 'Follow System';

  @override
  String get upUseSystemTheme => 'Use system default theme';

  @override
  String get adminDashboardTitle => 'Admin Dashboard';

  @override
  String adminDashboardWelcome(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get adminDashboardSubtitle => 'Administrative control panel';

  @override
  String get adminGlobalMetricsTitle => 'Global Metrics';

  @override
  String get adminMetricsUsers => 'Users';

  @override
  String get adminMetricsWorkshops => 'Workshops';

  @override
  String get adminMetricsVehicles => 'Vehicles';

  @override
  String get adminMetricsServices => 'Services';

  @override
  String get adminMetricsAlerts => 'Alerts';

  @override
  String get adminMetricsReviews => 'Reviews';

  @override
  String get adminQuickActionsTitle => 'Quick Actions';

  @override
  String get adminQuickActionManageUsers => 'Manage Users';

  @override
  String get adminQuickActionManageWorkshops => 'Manage Workshops';

  @override
  String get adminQuickActionModerateReviews => 'Moderate Reviews';

  @override
  String get adminQuickActionViewLogs => 'View Activity';

  @override
  String get adminRecentActivityTitle => 'Recent Activity';

  @override
  String get adminNoRecentActivity => 'No recent activity';

  @override
  String get adminViewAllLogs => 'View all logs';
}
