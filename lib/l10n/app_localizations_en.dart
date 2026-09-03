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
  String get authOpenLinkOnRegister =>
      'Open the link in the email to activate your account. You can continue in the meantime.';

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
  String get dashTallerPendienteTitulo =>
      'A new workshop wants access to the history';

  @override
  String dashTallerPendienteSolicitante(String tallerName) {
    return 'Requested by: $tallerName';
  }

  @override
  String get dashTallerPendienteNombreDesconocido => 'A workshop';

  @override
  String get dashTallerPendienteDesc =>
      'This workshop is requesting permanent access to this vehicle\'s maintenance history. Confirm only if you recognize this visit.';

  @override
  String get dashTallerPendienteConfirmError => 'Error confirming the workshop';

  @override
  String get dashTallerPendienteRechazarError => 'Error rejecting the workshop';

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
  String alertsInconsistentMileage(String km) {
    return 'Current mileage is lower than the last recorded service ($km km). Correct the vehicle\'s mileage.';
  }

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
  String get wdMapUnavailableTitle => 'Map unavailable';

  @override
  String get wdMapUnavailableBody =>
      'The map could not be loaded because this build is missing its Google Maps key. In the meantime you can browse the workshops in list view.';

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

  @override
  String get authCompleteCredentials => 'Fill in email and password.';

  @override
  String get authEnterValidEmail => 'Enter a valid email address.';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters.';

  @override
  String get addVehicleBrand => 'Brand';

  @override
  String get addVehicleBrandSubtitle => 'What is the brand of your vehicle?';

  @override
  String get addVehicleSearchBrand => 'Search brand...';

  @override
  String get addVehicleErrorBrands => 'Error loading brands';

  @override
  String get addVehicleRetry => 'Retry';

  @override
  String get addVehicleNotFoundBrand => 'I can\'t find my brand...';

  @override
  String get addVehicleModel => 'Model';

  @override
  String addVehicleModelSubtitle(String brand) {
    return 'Select the model of your $brand';
  }

  @override
  String get addVehicleSearchModel => 'Search model...';

  @override
  String get addVehicleErrorModels => 'Error loading models';

  @override
  String get addVehicleNotFoundModel => 'I can\'t find my model...';

  @override
  String get addVehicleDetails => 'Final Details';

  @override
  String get addVehicleDetailsSubtitle => 'Complete the remaining information';

  @override
  String get addVehiclePlate => 'License Plate';

  @override
  String get addVehiclePlateHint => 'e.g. P123-456';

  @override
  String get addVehicleYear => 'Year';

  @override
  String get addVehicleYearHint => 'Select the year';

  @override
  String get addVehicleYearInvalid => 'Invalid year';

  @override
  String get addVehicleColor => 'Color';

  @override
  String get addVehicleColorHint => 'Gray';

  @override
  String get addVehicleColorRequired => 'Color is required';

  @override
  String get addVehicleColorInvalidChars => 'Only letters and spaces';

  @override
  String get addVehicleMileage => 'Current Mileage';

  @override
  String get addVehicleDocs => 'Documentation';

  @override
  String get addVehicleCardExp => 'Card Expiration';

  @override
  String get addVehicleSoatExp => 'SOAT Expiration';

  @override
  String get addVehicleFinish => 'Finish Registration';

  @override
  String get addVehicleSuccess => 'Vehicle Registered!';

  @override
  String addVehicleSuccessDesc(String brand, String model) {
    return 'Your $brand $model is now in the garage.';
  }

  @override
  String get addVehicleGoDashboard => 'Go to Dashboard';

  @override
  String get addVehicleSelectDate => 'Select date';

  @override
  String get histTotalSpent => 'Total spent';

  @override
  String get histServicesCount => 'Services';

  @override
  String get histAverage => 'Average';

  @override
  String get vpQuickNotes => 'Quick Notes';

  @override
  String get pdfHistoryTitle => 'Service History';

  @override
  String pdfVehicle(String brand, String model, String year) {
    return 'Vehicle: $brand $model ($year)';
  }

  @override
  String pdfPlate(String plate) {
    return 'Plate: $plate';
  }

  @override
  String pdfReportDate(String date) {
    return 'Report Date: $date';
  }

  @override
  String pdfTotalServices(String count) {
    return 'Total Services: $count';
  }

  @override
  String pdfTotalSpent(String amount) {
    return 'Total Spent: \$$amount';
  }

  @override
  String get adminLogsTitle => 'Activity Log';

  @override
  String get adminDeleteReview => 'Delete Review';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminDelete => 'Delete';

  @override
  String get adminModerateReviews => 'Review Moderation';

  @override
  String get adminAccessDenied => 'Access Denied';

  @override
  String get adminAccessDeniedDesc =>
      'This screen is only available in a development environment.';

  @override
  String get adminConfigAdmins => 'Configure Administrators';

  @override
  String get adminConfirm => 'Confirm';

  @override
  String get adminManageWorkshops => 'Workshop Management';

  @override
  String get adminChangeRole => 'Change User Role';

  @override
  String get adminSelectNewRole => 'Select the new role:';

  @override
  String get adminManageUsers => 'User Management';

  @override
  String get adminApproveAccount => 'Approve Account';

  @override
  String get adminSuspendAccount => 'Suspend Account';

  @override
  String get adminReactivateAccount => 'Reactivate Account';

  @override
  String get adminChangeUserRole => 'Change Role';

  @override
  String get adminNoTrendData => 'No trend data available.';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminApproveWorkshop => 'Approve Workshop';

  @override
  String get adminSuspend => 'Suspend';

  @override
  String get adminReactivate => 'Reactivate';

  @override
  String adminError(String error) {
    return 'Error: $error';
  }

  @override
  String adminVerificacionTallerId(String uid) {
    return 'ID: $uid';
  }

  @override
  String get adminVerificacionAbrirDocumentoError =>
      'Couldn\'t open the document. Please try again.';

  @override
  String get tallerVerifCambiar => 'Change';

  @override
  String get tallerVerifSubir => 'Upload';

  @override
  String get tallerVerifConfirmarYSubir => 'Confirm and upload';

  @override
  String tallerVerifArchivoPendientePdf(String nombre, String tamano) {
    return '$nombre · $tamano MB. Not uploaded yet.';
  }

  @override
  String get tallerVerifArchivoSubido => 'File uploaded. Tap to view it.';

  @override
  String get tallerVerifSubiendo => 'Uploading the file…';

  @override
  String get tallerVerifPendienteBloqueado =>
      'Your request is already under review: you can\'t upload this selection now. You can discard it.';

  @override
  String get tallerVerifDescartar => 'Discard';

  @override
  String chatOpeningSection(String label) {
    return 'Opening $label section...';
  }

  @override
  String get chatDeleteMessage => 'Delete message';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatGallery => 'Gallery';

  @override
  String get chatShareVehicle => 'Share Vehicle';

  @override
  String get chatNewReservation => 'New Reservation';

  @override
  String get chatSendQuote => 'Send Quote';

  @override
  String get chatRequestRating => 'Request Rating';

  @override
  String get chatUploadImageError => 'Error uploading image';

  @override
  String chatReservationSuccess(String status) {
    return 'Reservation $status successfully';
  }

  @override
  String get chatReservationDetail => 'Appointment Detail';

  @override
  String get coreAppTitle => 'AutoDoc Workshop';

  @override
  String get chatViewFullHistory => 'View Full History';

  @override
  String get chatConfirmProposal => 'Confirm Proposal';

  @override
  String get chatGenerateAndSend => 'Generate and Send';

  @override
  String get chatRateService => 'Rate Service';

  @override
  String get chatReviewThanks => 'Thank you for your review!';

  @override
  String get chatAccept => 'Accept';

  @override
  String get chatReject => 'Reject';

  @override
  String get chatViewDetail => 'View detail';

  @override
  String get chatService => 'Service';

  @override
  String get chatDate => 'Date';

  @override
  String get chatTime => 'Time';

  @override
  String get chatVehicleId => 'Vehicle ID';

  @override
  String get chatAcceptAppointment => 'Accept Appointment';

  @override
  String get chatRejectReschedule => 'Reject / Reschedule';

  @override
  String get chatConfirmDelete =>
      'Are you sure you want to delete this message for everyone?';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'You have no notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get upLanguage => 'Language / Idioma';

  @override
  String get upLanguageDesc => 'Turn the switch on to use the app in English';

  @override
  String get upAbout => 'About AutoDoc';

  @override
  String get upAboutDesc => 'Version, credits and legal';

  @override
  String get upDeleteAccountTitle => 'Delete Account';

  @override
  String get upDeleteAccountConfirm =>
      'Are you sure you want to delete your account? This action cannot be undone and you will lose all your data.';

  @override
  String get upEnterPasswordConfirm => 'To confirm, enter your password:';

  @override
  String get upPasswordLabel => 'Password';

  @override
  String get upGoogleReauthConfirm =>
      'To confirm, you must sign in with Google again.';

  @override
  String get upPasswordEmpty => 'Password cannot be empty.';

  @override
  String get upPasswordIncorrect => 'Incorrect password.';

  @override
  String get upGoogleReauthFailed => 'Could not re-authenticate with Google.';

  @override
  String upDeleteAccountError(String error) {
    return 'Error deleting account: $error';
  }

  @override
  String get upCancel => 'Cancel';

  @override
  String get upDelete => 'Delete';

  @override
  String get upDeleteAccount => 'Delete account';

  @override
  String get topNavThemeTooltip => 'Toggle theme';

  @override
  String get topNavLanguageTooltip => 'Change language';

  @override
  String get topNavAccountTooltip => 'Your account';
}
