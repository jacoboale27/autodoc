# Graph Report - .  (2026-07-12)

## Corpus Check
- 273 files · ~233,084 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2709 nodes · 3676 edges · 130 communities (119 shown, 11 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 19 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101
- Community 102
- Community 103
- Community 104
- Community 105
- Community 106
- Community 107
- Community 108
- Community 109
- Community 110
- Community 111
- Community 112
- Community 113
- Community 114
- Community 115
- Community 118
- Community 119
- Community 120
- Community 127

## God Nodes (most connected - your core abstractions)
1. `AuthProvider` - 81 edges
2. `AlertProvider` - 26 edges
3. `VehicleProvider` - 26 edges
4. `AdminProvider` - 24 edges
5. `Win32Window` - 22 edges
6. `compilerOptions` - 16 edges
7. `ChatProvider` - 15 edges
8. `ThemeProvider` - 14 edges
9. `MessageHandler` - 12 edges
10. `LanguageProvider` - 11 edges

## Surprising Connections (you probably didn't know these)
- `_checkExisting` --references--> `AuthProvider`  [EXTRACTED]
  lib/core/widgets/review_sheet.dart → lib/features/auth/presentation/providers/auth_provider.dart
- `_submit` --references--> `AuthProvider`  [EXTRACTED]
  lib/core/widgets/review_sheet.dart → lib/features/auth/presentation/providers/auth_provider.dart
- `_loadRememberMePreferences` --references--> `AuthProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/features/auth/presentation/providers/auth_provider.dart
- `_persistRememberMe` --references--> `AuthProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/features/auth/presentation/providers/auth_provider.dart
- `_buildSubmitButton` --references--> `AuthProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/features/auth/presentation/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (130 total, 11 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.01
Nodes (258): app_localizations_en.dart, app_localizations_es.dart, class, adminDashboardSubtitle, adminDashboardTitle, adminDashboardWelcome, adminGlobalMetricsTitle, adminMetricsAlerts (+250 more)

### Community 1 - "Community 1"
Cohesion: 0.01
Nodes (246): app_localizations.dart, adminDashboardSubtitle, adminDashboardTitle, adminDashboardWelcome, adminGlobalMetricsTitle, adminMetricsAlerts, adminMetricsReviews, adminMetricsServices (+238 more)

### Community 2 - "Community 2"
Cohesion: 0.01
Nodes (245): adminDashboardSubtitle, adminDashboardTitle, adminDashboardWelcome, adminGlobalMetricsTitle, adminMetricsAlerts, adminMetricsReviews, adminMetricsServices, adminMetricsUsers (+237 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (56): ../../../auth/presentation/providers/auth_provider.dart, AdminDashboardScreen, _AdminDashboardScreenState, build, _buildActionChip, _buildMetricsGrid, _buildQuickActions, _buildRecentActivity (+48 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (57): build, userId, VehiculoPicker, AlertsScreen, _AlertsScreenState, build, _buildAlertCard, _buildCompactActionButton (+49 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (50): AppColors get, AppPalette, copyWith, darkError, darkOnPrimary, darkOnSecondary, darkOutline, darkPrimary (+42 more)

### Community 7 - "Community 7"
Cohesion: 0.07
Nodes (41): ChangeNotifier, DocumentSnapshot, ThemeProvider, AdminSidebar, build, _buildDrawerItem, AuthProvider, build (+33 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (43): ../../../../core/models/nhtsa_models.dart, ../../../../core/services/vehicle_api_service.dart, ../../../../core/utils/plate_formatter.dart, _allMakes, _anioController, _apiService, _brandSearchQuery, build (+35 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (40): eslint, eslint-config-next, framer-motion, dependencies, framer-motion, lucide-react, next, next-intl (+32 more)

### Community 10 - "Community 10"
Cohesion: 0.05
Nodes (38): app_colors.dart, app_radius.dart, app_text_styles.dart, GoRouter, appRouter, AppTheme, _buildTextTheme, package:animations/animations.dart (+30 more)

### Community 11 - "Community 11"
Cohesion: 0.07
Nodes (36): build, _buildMessageContent, ChatScreen, _ChatScreenState, _controller, conversacionId, createState, dispose (+28 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (35): AppRadius, full, lg, md, sm, xl, xs, xxl (+27 more)

### Community 13 - "Community 13"
Cohesion: 0.07
Nodes (31): AppSnackbar, show, SnackbarType, build, ReservaDetailScreen, build, CotizacionChatCard, isMe (+23 more)

### Community 14 - "Community 14"
Cohesion: 0.07
Nodes (32): _GlassTag, _ShowcaseImage, _SyncNode, _TabCard, _TimelineItem, build, HeroSection, image (+24 more)

### Community 15 - "Community 15"
Cohesion: 0.06
Nodes (31): build, child, ResponsiveContainer, AdminSeedScreen, build, build, _buildEmptyState, _buildFilterTab (+23 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (33): _adminAuthService, adminUid, _authPreferences, _authService, clearError, _error, fetchUserData, _isAdminSession (+25 more)

### Community 17 - "Community 17"
Cohesion: 0.07
Nodes (29): File?, build, _buildInputCard, _costController, createState, currentKm, dispose, _infoItem (+21 more)

### Community 18 - "Community 18"
Cohesion: 0.06
Nodes (30): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+22 more)

### Community 19 - "Community 19"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/role_utils.dart, _adminService, aprobarTaller, cambiarRolUsuario, clearMessages, eliminarResenia, _error, fetchAllData (+20 more)

### Community 20 - "Community 20"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 21 - "Community 21"
Cohesion: 0.07
Nodes (26): build, _buildBottomNav, _buildGlassCard, _buildLogoSection, _buildNavItem, _buildSubmitButton, _buildTextField, createState (+18 more)

### Community 22 - "Community 22"
Cohesion: 0.08
Nodes (24): BoxFit, dart:ui, build, _buildPlaceholder, fit, height, imageUrl, VehicleImageWidget (+16 more)

### Community 23 - "Community 23"
Cohesion: 0.08
Nodes (25): GoogleMapController?, build, _buildFilterChip, _buildFilters, _buildHeader, _buildMapCard, _buildMapView, _buildSearchBar (+17 more)

### Community 24 - "Community 24"
Cohesion: 0.08
Nodes (24): _abrirSelectorMapa, _buildCoordinatesPicker, _buildDropdownField, _buildInputField, _buildTopBar, createState, dispose, _elSalvadorDivipola (+16 more)

### Community 25 - "Community 25"
Cohesion: 0.10
Nodes (7): geistMono, geistSans, metadata, ThemeProvider(), Header(), {Link, redirect, usePathname, useRouter, getPathname}, routing

### Community 26 - "Community 26"
Cohesion: 0.09
Nodes (22): _activeTab, build, _buildShowcaseContent, color, CommandCenterSection, _CommandCenterSectionState, CommandCenterTab, createState (+14 more)

### Community 27 - "Community 27"
Cohesion: 0.10
Nodes (20): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, @google-cloud/functions-framework, description, engines (+12 more)

### Community 28 - "Community 28"
Cohesion: 0.11
Nodes (19): Animation, AnimationController, Duration, AnimatedCounter, _AnimatedCounterState, _animation, build, _controller (+11 more)

### Community 29 - "Community 29"
Cohesion: 0.10
Nodes (19): ../../data/models/conversacion_model.dart, ../../data/models/mensaje_model.dart, ../../data/repositories/chat_repository.dart, int get, _chatRepository, _conversaciones, _conversacionesSub, dispose (+11 more)

### Community 30 - "Community 30"
Cohesion: 0.11
Nodes (18): FirebaseFirestore, buscarConversacion, ChatRepository, crearConversacion, enviarMensaje, _firestore, marcarComoLeidos, streamConversaciones (+10 more)

### Community 31 - "Community 31"
Cohesion: 0.11
Nodes (19): FormState, _buildActionButton, _buildDetailItem, _buildDocumentationStatus, _buildDocumentationStatusItem, _buildHeader, _buildHeroImage, _buildStatusAlert (+11 more)

### Community 32 - "Community 32"
Cohesion: 0.13
Nodes (19): AuthScreen, _AuthScreenState, ServiceHistoryScreen, _ServiceHistoryScreenState, WorkshopDirectoryScreen, _WorkshopDirectoryScreenState, MechanicDashboardScreen, _MechanicDashboardScreenState (+11 more)

### Community 33 - "Community 33"
Cohesion: 0.11
Nodes (19): _buildAlertsList, _buildInvoicePicker, _buildKmInput, _buildMaintenanceTasks, _buildSectionTitle, _buildVehicleHeader, _completedTaskIds, createState (+11 more)

### Community 34 - "Community 34"
Cohesion: 0.11
Nodes (18): copyWith, correo, departamento, especialidad, estado, fcmToken, fechaRegistro, fotoPerfilUrl (+10 more)

### Community 35 - "Community 35"
Cohesion: 0.11
Nodes (18): _alreadyReviewed, build, _checkExisting, _checking, _comentarioController, createState, dispose, _estrellas (+10 more)

### Community 36 - "Community 36"
Cohesion: 0.11
Nodes (18): cotizacionEstimada, descripcion, estado, fechaCreacion, fechaHoraConfirmada, fechaHoraPropuesta, fromMap, id (+10 more)

### Community 37 - "Community 37"
Cohesion: 0.11
Nodes (17): ../../../../core/services/vehicle_image_service.dart, ../../data/services/vehicle_service.dart, addVehicle, deleteVehicle, _demoteCurrentPrimary, fetchVehicles, findVehicleByPlate, _imageService (+9 more)

### Community 38 - "Community 38"
Cohesion: 0.11
Nodes (16): CustomPainter, dart:math, build, ChatBackgroundPattern, _ChatPatternPainter, color, paint, shouldRepaint (+8 more)

### Community 39 - "Community 39"
Cohesion: 0.11
Nodes (17): GoogleSignIn, _auth, AuthService, _googleSignIn, _handleAuthException, isCurrentUserEmailVerified, registerWithEmail, reloadCurrentUser (+9 more)

### Community 40 - "Community 40"
Cohesion: 0.11
Nodes (16): UserModel, AppTopNavBar, icon, isActive, onTap, title, _TopNavLink, AccountRow (+8 more)

### Community 41 - "Community 41"
Cohesion: 0.12
Nodes (17): VehicleModel, _addUser, build, createState, dispose, _emailController, _firestore, initState (+9 more)

### Community 42 - "Community 42"
Cohesion: 0.11
Nodes (17): AppTextStyles, bodyLarge, bodyMedium, bodySmall, displayLarge, displayMedium, displaySmall, headlineLarge (+9 more)

### Community 43 - "Community 43"
Cohesion: 0.11
Nodes (16): action, AppEmptyState, build, description, icon, lottieAsset, title, appBar (+8 more)

### Community 44 - "Community 44"
Cohesion: 0.11
Nodes (17): AppTextField, build, controller, hintText, inputFormatters, keyboardType, label, maxLines (+9 more)

### Community 45 - "Community 45"
Cohesion: 0.11
Nodes (17): aprobarTaller, cambiarRolUsuario, eliminarResenia, fetchDashboardMetrics, fetchLogs, fetchResenias, fetchTalleres, fetchUsuarios (+9 more)

### Community 46 - "Community 46"
Cohesion: 0.11
Nodes (17): activeAlerts, _addOrUpdateLocalAlert, _alerts, completeAlert, createDefaultTasks, _defaultTasks, _error, fetchAlerts (+9 more)

### Community 47 - "Community 47"
Cohesion: 0.12
Nodes (16): ../../../../core/models/admin_log_model.dart, ../../../../core/models/review_model.dart, AdminRepository, countCollection, deleteResenia, deleteTaller, deleteUsuario, _firestore (+8 more)

### Community 48 - "Community 48"
Cohesion: 0.12
Nodes (16): anio, color, copyWith, fotoUrl, fromMap, idPropietario, idVehiculo, isPrimary (+8 more)

### Community 49 - "Community 49"
Cohesion: 0.12
Nodes (15): AndroidFlutterLocalNotificationsPlugin, FirebaseMessaging, _firebaseMessaging, initialize, _instance, _isInitialized, _localNotifications, NotificationService (+7 more)

### Community 50 - "Community 50"
Cohesion: 0.12
Nodes (15): @pragma, _firebaseMessagingBackgroundHandler, initializeApp, main, package:autodoc/core/router/app_router.dart, package:autodoc/core/services/notification_service.dart, package:autodoc/features/admin/presentation/providers/admin_dashboard_provider.dart, package:autodoc/features/admin/presentation/providers/admin_provider.dart (+7 more)

### Community 51 - "Community 51"
Cohesion: 0.12
Nodes (14): Color, IconData, AppStatusBadge, AppStatusType, build, icon, text, type (+6 more)

### Community 52 - "Community 52"
Cohesion: 0.12
Nodes (15): dart:async, ../../data/models/reserva_model.dart, ../../data/repositories/reserva_repository.dart, ReservaRepository, cambiarEstadoReserva, dispose, _error, inicializarReservasUsuario (+7 more)

### Community 53 - "Community 53"
Cohesion: 0.12
Nodes (15): AlertModel, AlertPriority, copyWith, descripcion, estado, fechaLimite, fromMap, idAlerta (+7 more)

### Community 54 - "Community 54"
Cohesion: 0.12
Nodes (15): ConversacionModel, estado, fromMap, id, idMecanico, idPropietario, idTaller, idVehiculo (+7 more)

### Community 55 - "Community 55"
Cohesion: 0.14
Nodes (15): build, _buildAssistantCard, _buildRecentItem, _buildRecentSearches, _buildSearchCard, _buildTopBar, createState, _formatPlate (+7 more)

### Community 56 - "Community 56"
Cohesion: 0.13
Nodes (14): int?, copyWith, costo, descripcion, fecha, fotoFacturaUrl, fromMap, idServicio (+6 more)

### Community 57 - "Community 57"
Cohesion: 0.14
Nodes (14): build, createState, dispose, initState, _isLoading, _kmController, _monthsController, _presetChip (+6 more)

### Community 58 - "Community 58"
Cohesion: 0.14
Nodes (13): fechaUltimoServicio, frecuenciaKm, frecuenciaMeses, fromMap, getStatus, getStatusLabel, id, MaintenanceStatus (+5 more)

### Community 59 - "Community 59"
Cohesion: 0.15
Nodes (10): AppLocalizations get, l10n, AppBottomNavBar, build, currentIndex, build, ImagenChatCard, isMe (+2 more)

### Community 60 - "Community 60"
Cohesion: 0.15
Nodes (12): Box, _apiKey, _baseUrl, initialize, _instance, isInitialized, translate, translateSync (+4 more)

### Community 61 - "Community 61"
Cohesion: 0.15
Nodes (12): cloud_firestore, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, firebase_storage, flutter_local_notifications, Foundation (+4 more)

### Community 62 - "Community 62"
Cohesion: 0.15
Nodes (12): AppButton, AppButtonSize, AppButtonType, build, _handlePress, hapticFeedback, icon, isLoading (+4 more)

### Community 63 - "Community 63"
Cohesion: 0.21
Nodes (7): GeneratedPluginRegistrant, FlutterEngine, FlutterLocalNotificationsPlugin, GeneratedPluginRegistrant, +registerWithRegistry, Keep, NSObject

### Community 64 - "Community 64"
Cohesion: 0.17
Nodes (11): DateTime?, accion, AdminLogModel, adminUid, detalle, fecha, fromMap, idLog (+3 more)

### Community 65 - "Community 65"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 66 - "Community 66"
Cohesion: 0.17
Nodes (11): calificacionPromedio, copyWith, especialidad, estado, fromMap, idTaller, nombre, telefono (+3 more)

### Community 67 - "Community 67"
Cohesion: 0.17
Nodes (11): activeIcon, child, colors, icon, InstagramBottomNavBar, isActive, isDark, MainScaffold (+3 more)

### Community 68 - "Community 68"
Cohesion: 0.17
Nodes (11): AuthPreferencesService, clearSavedCredentials, getRememberMe, getSavedEmail, isOnboardingCompleted, _keyOnboardingCompleted, _keyRememberMe, _keySavedEmail (+3 more)

### Community 69 - "Community 69"
Cohesion: 0.27
Nodes (12): _buildGoogleButton, _handleEmailRegister, _navigateAfterAuth, build, build, initState, Route /admin/dashboard, Route /dashboard (+4 more)

### Community 70 - "Community 70"
Cohesion: 0.17
Nodes (11): contenido, estado, fromMap, id, idRemitente, MensajeModel, metadata, timestamp (+3 more)

### Community 71 - "Community 71"
Cohesion: 0.18
Nodes (10): CollectionReference, _firestore, getReviewsForTaller, hasUserReviewedTaller, recalculateTallerRating, _resenias, ReviewService, submitReview (+2 more)

### Community 72 - "Community 72"
Cohesion: 0.18
Nodes (10): ../../../../core/models/user_model.dart, dart:io, _collection, createUserData, _firestore, getUserData, updateUserData, uploadProfilePhoto (+2 more)

### Community 73 - "Community 73"
Cohesion: 0.18
Nodes (10): ../../../../core/models/vehicle_model.dart, addVehicle, _collection, deleteVehicle, _firestore, getSharedVehicles, getVehicleByPlate, getVehiclesByOwner (+2 more)

### Community 74 - "Community 74"
Cohesion: 0.18
Nodes (10): FirebaseAuth, AdminAuthService, _auth, _firestore, getAdminByUid, isAdmin, loginAsAdmin, _resolveUsernameToEmail (+2 more)

### Community 75 - "Community 75"
Cohesion: 0.18
Nodes (10): comentario, copyWith, estrellas, fechaResenia, fromMap, idResenia, idTaller, idUsuario (+2 more)

### Community 76 - "Community 76"
Cohesion: 0.18
Nodes (10): accelerate, AppTransitions, decelerate, defaultCurve, fast, medium, slow, package:flutter/animation.dart (+2 more)

### Community 77 - "Community 77"
Cohesion: 0.18
Nodes (10): maxLines, overflow, style, text, textAlign, package:autodoc/core/providers/language_provider.dart, package:autodoc/core/services/translation_service.dart, TextAlign? (+2 more)

### Community 78 - "Community 78"
Cohesion: 0.20
Nodes (10): _availableTimes, build, createState, DisponibilidadPicker, _DisponibilidadPickerState, _focusedDay, initState, _selectedDay (+2 more)

### Community 79 - "Community 79"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 80 - "Community 80"
Cohesion: 0.20
Nodes (9): ../../../../core/models/workshop_model.dart, build, _buildInfoChip, _buildStatusChip, onAprobar, onRechazar, onSuspender, taller (+1 more)

### Community 81 - "Community 81"
Cohesion: 0.20
Nodes (9): EdgeInsetsGeometry, AppCard, build, child, margin, onTap, padding, package:autodoc/core/theme/app_radius.dart (+1 more)

### Community 82 - "Community 82"
Cohesion: 0.20
Nodes (9): build, calificacionPromedio, _chip, _info, MecanicoAdminCard, totalResenias, usuario, package:autodoc/core/models/user_model.dart (+1 more)

### Community 83 - "Community 83"
Cohesion: 0.22
Nodes (8): bool get, ../../data/services/admin_service.dart, AdminService, _adminService, _error, fetchMetrics, _isLoading, _metrics

### Community 84 - "Community 84"
Cohesion: 0.22
Nodes (8): dart:convert, _apiKey, _baseUrl, _defaultImage, _fetchFromSearchApi, _firestore, getVehicleImage, VehicleImageService

### Community 85 - "Community 85"
Cohesion: 0.22
Nodes (8): double?, AppSkeleton, borderRadius, build, card, height, width, package:shimmer/shimmer.dart

### Community 86 - "Community 86"
Cohesion: 0.28
Nodes (6): Flutter, FlutterSceneDelegate, GoogleMaps, SceneDelegate, UIKit, XCTest

### Community 87 - "Community 87"
Cohesion: 0.22
Nodes (8): _loadTheme, setThemeMode, _themeKey, _themeMode, toggleTheme, package:shared_preferences/shared_preferences.dart, ThemeMode, ThemeMode get

### Community 88 - "Community 88"
Cohesion: 0.22
Nodes (8): AppShadows, darkLg, darkMd, darkSm, lightLg, lightMd, lightSm, static List

### Community 89 - "Community 89"
Cohesion: 0.22
Nodes (8): android, DefaultFirebaseOptions, ios, web, package:autodoc/config/secrets.dart, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 90 - "Community 90"
Cohesion: 0.25
Nodes (6): Any, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, UIApplication

### Community 91 - "Community 91"
Cohesion: 0.25
Nodes (7): CarMake, CarModel, fromJson, makeId, makeName, modelId, modelName

### Community 92 - "Community 92"
Cohesion: 0.25
Nodes (7): changeLanguage, currentLanguageCode, _currentLocale, _loadLocale, Locale, Locale get, String get

### Community 93 - "Community 93"
Cohesion: 0.25
Nodes (7): baseUrl, fetchAllMakes, fetchModelsByMake, VehicleApiService, ../models/nhtsa_models.dart, package:http/http.dart, static const String

### Community 94 - "Community 94"
Cohesion: 0.36
Nodes (8): build, build, _buildHeader, _buildNearbyServices, Route /chat_list, Route /garage, Route /user_profile, Route /workshop_directory

### Community 95 - "Community 95"
Cohesion: 0.25
Nodes (7): build, LandingScreen, ../widgets/command_center_section.dart, ../widgets/hero_section.dart, ../widgets/landing_footer.dart, ../widgets/landing_header.dart, ../widgets/value_prop_section.dart

### Community 96 - "Community 96"
Cohesion: 0.38
Nodes (3): Cocoa, FlutterMacOS, RunnerTests

### Community 97 - "Community 97"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 98 - "Community 98"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 99 - "Community 99"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 100 - "Community 100"
Cohesion: 0.33
Nodes (6): LanguageProvider, build, TranslatedText, _buildSettingsSection, build, MyApp

### Community 101 - "Community 101"
Cohesion: 0.33
Nodes (5): isMechanicRole, mechanicFirestoreRoles, normalized, List, return

### Community 102 - "Community 102"
Cohesion: 0.33
Nodes (5): AppSkeletonLayouts, dashboard, listCards, workshopList, package:autodoc/core/widgets/app_skeleton.dart

### Community 103 - "Community 103"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsEs, of, LocalizationsDelegate

### Community 104 - "Community 104"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 105 - "Community 105"
Cohesion: 0.40
Nodes (4): admin, db, functions, messaging

### Community 106 - "Community 106"
Cohesion: 0.40
Nodes (4): formatEditUpdate, PlateFormatter, package:flutter/services.dart, TextInputFormatter

### Community 107 - "Community 107"
Cohesion: 0.50
Nodes (4): _buildActiveAlerts, _buildQuickActions, Route /alerts, Route /service_history

### Community 109 - "Community 109"
Cohesion: 0.67
Nodes (3): BuildContext, AppColorsExtension, L10nExtension

## Knowledge Gaps
- **1858 isolated node(s):** `functions`, `admin`, `db`, `messaging`, `name` (+1853 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthProvider` connect `Community 7` to `Community 32`, `Community 33`, `Community 35`, `Community 67`, `Community 4`, `Community 69`, `Community 5`, `Community 40`, `Community 11`, `Community 15`, `Community 16`, `Community 17`, `Community 21`, `Community 23`, `Community 24`, `Community 94`, `Community 31`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Why does `VehicleApiService` connect `Community 93` to `Community 8`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `AlertProvider` connect `Community 5` to `Community 33`, `Community 7`, `Community 46`, `Community 17`, `Community 57`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `functions`, `admin`, `db` to the rest of the system?**
  _1858 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.007722007722007722 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.008097165991902834 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.008130081300813009 - nodes in this community are weakly interconnected._