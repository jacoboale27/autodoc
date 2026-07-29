# Graph Report - autodoc  (2026-07-28)

## Corpus Check
- 253 files · ~995,391 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3927 nodes · 5320 edges · 180 communities (165 shown, 15 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 19 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ac8dd13e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Localization & i18n
- App Localizations EN
- App Localizations ES
- Windows Desktop Native
- Admin Dashboard UI
- Alerts & Vehicles Screen
- Theme Color System
- Auth & Navigation Core
- Vehicle Registration Form
- Landing Web (Next.js)
- App Router & Theme
- Chat Messaging Screen
- UI Radius & Spacing
- Snackbar & UI Feedback
- Landing Page Widgets
- Admin Users Screen
- Auth Provider & Admin Auth
- Service Initiation Screen
- TypeScript Config
- Admin Provider Logic
- Linux GTK Native
- Auth Screen UI
- Vehicle Image Widget
- Workshop Map View
- Workshop Form & Picker
- Next.js App Shell
- Landing Command Center
- Firebase Cloud Functions
- Animated Counter Widget
- Chat Provider & Models
- Chat Repository
- Vehicle Profile Screen
- Main Screen Routes
- Service Task UI
- User Model
- Review Sheet Widget
- Reservation Model
- Vehicle Provider Logic
- Chat Background Pattern
- Auth Service
- Top Nav & User Row
- Admin User Management
- Text Styles
- Empty State Widget
- Text Field Widget
- Admin Service Methods
- Alert Provider Logic
- Admin Repository
- Vehicle Model
- Notification Service
- App Entry Point (main)
- Status Badge Widget
- Reservation Provider
- Alert Model
- Conversation Model
- Vehicle Search Screen
- Service Record Model
- Maintenance Config UI
- Maintenance Task Model
- Bottom Nav & Chat Cards
- Translation Service
- Firebase Plugins
- App Button Widget
- iOS Plugin Registry
- Admin Log Model
- Windows Console Setup
- Workshop Model
- Main Scaffold & Nav
- Auth Preferences Service
- Auth Routes & Redirect
- Message Model
- Review Service
- User Service
- Vehicle Service (Data)
- Admin Auth Service
- Review Model
- App Transitions
- Translated Text Widget
- Availability Picker
- Web App Manifest
- Workshop Admin Card
- App Card Widget
- Mechanic Admin Card
- Admin Dashboard Provider
- Vehicle Image Service
- Skeleton Loader Widget
- iOS Scene Setup
- Theme Provider
- App Shadows
- Firebase Options Config
- iOS App Delegate
- NHTSA Car Models
- Language Provider
- Vehicle API Service
- Dashboard Quick Actions
- Landing Screen
- macOS Test Config
- macOS App Delegate
- macOS Window Setup
- LLDB Debug Scripts
- Language Root Widget
- Role Utilities
- Skeleton Layouts
- Localizations Delegates
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
- Community 116
- Community 117
- Community 118
- Community 119
- Community 120
- Community 121
- Community 122
- Community 123
- Community 124
- Community 125
- Community 126
- Community 127
- Community 128
- Community 129
- Community 130
- Community 131
- Community 132
- Community 133
- Community 134
- Community 135
- Community 136
- Community 137
- Community 138
- Community 139
- Community 140
- Community 141
- Community 145
- Community 146
- Community 150
- Community 151
- Community 152
- Community 153
- Community 154
- Community 155
- Community 156
- Community 157
- AutoDoc 🚗📋
- FIREBASE_FUNCTIONS.md
- AutoDoc — Índices de Firestore Requeridos
- Global Constraints
- Global Constraints
- AutoDoc — Términos de Servicio
- AutoDoc — Política de Privacidad
- vehicle_provider_test.dart
- 🚀 Setup rápido
- app_skeleton_layouts.dart
- auth_bottom_nav.dart
- imagen_chat_card.dart
- 🚢 Despliegue
- README.md
- map_injector_web.dart
- ▶️ Ejecutar la app
- 🧪 Tests
- invoice_upload_service.dart
- invoice_upload_service_test.dart
- README.md
- map_injector.dart
- map_injector_stub.dart

## God Nodes (most connected - your core abstractions)
1. `UserProfileProvider` - 83 edges
2. `AlertProvider` - 28 edges
3. `VehicleProvider` - 28 edges
4. `ChatProvider` - 26 edges
5. `AdminProvider` - 25 edges
6. `AuthProvider` - 25 edges
7. `AuthSessionProvider` - 22 edges
8. `Win32Window` - 22 edges
9. `compilerOptions` - 16 edges
10. `ChangeNotifier` - 15 edges

## Surprising Connections (you probably didn't know these)
- `AuthSessionProvider` --mixes_in--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/auth_session_provider.dart → test/core/router/app_router_test.dart
- `FakeAuthSessionProvider` --implements--> `AuthSessionProvider`  [EXTRACTED]
  test/core/router/app_router_test.dart → lib/core/providers/auth_session_provider.dart
- `LanguageProvider` --inherits--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/language_provider.dart → test/core/router/app_router_test.dart
- `NotificationCenterProvider` --inherits--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/notification_center_provider.dart → test/core/router/app_router_test.dart
- `ThemeProvider` --inherits--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/theme_provider.dart → test/core/router/app_router_test.dart

## Import Cycles
- None detected.

## Communities (180 total, 15 thin omitted)

### Community 0 - "Localization & i18n"
Cohesion: 0.01
Nodes (365): app_localizations_en.dart, app_localizations_es.dart, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails (+357 more)

### Community 1 - "App Localizations EN"
Cohesion: 0.01
Nodes (353): addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle, addVehicleDocs (+345 more)

### Community 2 - "App Localizations ES"
Cohesion: 0.01
Nodes (354): app_localizations.dart, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle (+346 more)

### Community 3 - "Windows Desktop Native"
Cohesion: 0.01
Nodes (169): Duration get, FirebaseApp get, FirebaseFirestore get, MultiFactor get, package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart, package:mockito/src/dummies.dart, R, Settings get (+161 more)

### Community 4 - "Admin Dashboard UI"
Cohesion: 0.04
Nodes (61): AuthSessionProvider, build, build, build, _buildActiveAlerts, _buildAlertCard, _buildEmptyVehicleState, _buildMaintenanceSemaphore (+53 more)

### Community 5 - "Alerts & Vehicles Screen"
Cohesion: 0.05
Nodes (50): DocumentSnapshot, UserProfileProvider, build, _canEdit, _checkExisting, _checking, _comentarioController, createState (+42 more)

### Community 6 - "Theme Color System"
Cohesion: 0.04
Nodes (52): _adminRoutes, appRouterRedirect, createAppRouter, currentPath, currentUid, false, hasAttemptedFetch, _homeForRole (+44 more)

### Community 7 - "Auth & Navigation Core"
Cohesion: 0.04
Nodes (50): AppColors get, AppPalette, copyWith, darkError, darkOnPrimary, darkOnSecondary, darkOutline, darkPrimary (+42 more)

### Community 8 - "Vehicle Registration Form"
Cohesion: 0.04
Nodes (44): ../../../../core/models/nhtsa_models.dart, ../../../../core/services/vehicle_api_service.dart, ../../../../core/theme/app_colors.dart, ../../../../core/utils/plate_formatter.dart, _allMakes, _anioController, _apiService, _brandSearchQuery (+36 more)

### Community 9 - "Landing Web (Next.js)"
Cohesion: 0.05
Nodes (43): ../../../../core/models/vehicle_model.dart, ../../../../core/services/vehicle_image_service.dart, ../../data/services/vehicle_service.dart, addNote, addVehicle, _collection, deleteVehicle, _firestore (+35 more)

### Community 10 - "App Router & Theme"
Cohesion: 0.05
Nodes (42): eslint, eslint-config-next, framer-motion, dependencies, framer-motion, lucide-react, next, next-intl (+34 more)

### Community 11 - "Chat Messaging Screen"
Cohesion: 0.13
Nodes (15): dart:ui, _buildFeatureItem, _contents, createState, _currentPage, description, features, imageUrl (+7 more)

### Community 12 - "UI Radius & Spacing"
Cohesion: 0.11
Nodes (17): AppTextStyles, bodyLarge, bodyMedium, bodySmall, displayLarge, displayMedium, displaySmall, headlineLarge (+9 more)

### Community 13 - "Snackbar & UI Feedback"
Cohesion: 0.04
Nodes (59): AlertsScreen, _AlertsScreenState, _buildAlertCard, _buildCompactActionButton, _buildContent, _buildHeader, _buildMileageChip, _buildSectionHeader (+51 more)

### Community 14 - "Landing Page Widgets"
Cohesion: 0.05
Nodes (35): AppRadius, full, lg, md, sm, xl, xs, xxl (+27 more)

### Community 15 - "Admin Users Screen"
Cohesion: 0.05
Nodes (46): class, DateTimeRange?, build, HistorialChatCard, isMe, metadata, build, _buildEmptyState (+38 more)

### Community 16 - "Auth Provider & Admin Auth"
Cohesion: 0.07
Nodes (7): geistMono, geistSans, ThemeProvider(), Header(), Workshop, {Link, redirect, usePathname, useRouter, getPathname}, routing

### Community 17 - "Service Initiation Screen"
Cohesion: 0.14
Nodes (13): AppNotification, body, copyWith, deepLink, fromFirestore, fromMap, id, leida (+5 more)

### Community 18 - "TypeScript Config"
Cohesion: 0.06
Nodes (33): GoogleMapController?, build, _buildFilterChip, _buildFilters, _buildHeader, _buildMapCard, _buildMapView, _buildSearchBar (+25 more)

### Community 19 - "Admin Provider Logic"
Cohesion: 0.06
Nodes (30): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+22 more)

### Community 20 - "Linux GTK Native"
Cohesion: 0.08
Nodes (24): GoRouter, authProvider, authSessionProvider, checkAndFetchProfile, createState, dispose, id, initState (+16 more)

### Community 21 - "Auth Screen UI"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/role_utils.dart, _adminService, aprobarTaller, cambiarRolUsuario, clearMessages, eliminarResenia, _error, fetchAllData (+20 more)

### Community 22 - "Vehicle Image Widget"
Cohesion: 0.20
Nodes (10): FormState, build, CotizacionPicker, _CotizacionPickerState, createState, _descController, dispose, _formKey (+2 more)

### Community 23 - "Workshop Map View"
Cohesion: 0.13
Nodes (14): build, ServicesTrendChart, serviciosPorMes, build, isMe, metadata, VehiculoChatCard, build (+6 more)

### Community 24 - "Workshop Form & Picker"
Cohesion: 0.09
Nodes (27): build, _buildMessageContent, ChatScreen, _ChatScreenState, _controller, conversacionId, createState, dispose (+19 more)

### Community 25 - "Next.js App Shell"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 26 - "Landing Command Center"
Cohesion: 0.08
Nodes (26): _abrirSelectorMapa, _buildCoordinatesPicker, _buildDropdownField, _buildInputField, _buildTopBar, createState, dispose, _elSalvadorDivipola (+18 more)

### Community 27 - "Firebase Cloud Functions"
Cohesion: 0.08
Nodes (26): _authPreferences, AuthScreen, _AuthScreenState, build, _buildGlassCard, _buildSubmitButton, _buildTextField, createState (+18 more)

### Community 28 - "Animated Counter Widget"
Cohesion: 0.08
Nodes (24): ../../data/models/conversacion_model.dart, ../../data/models/cotizacion_model.dart, ../../data/repositories/chat_repository.dart, actualizarEstadoCotizacion, actualizarMetadatosMensaje, _chatRepository, _conversaciones, _conversacionesSub (+16 more)

### Community 29 - "Chat Provider & Models"
Cohesion: 0.12
Nodes (15): FirebaseStorage, addPhoto, deletePhoto, _firestore, fromMap, id, _storage, streamPhotos (+7 more)

### Community 30 - "Chat Repository"
Cohesion: 0.15
Nodes (12): ../../data/models/reserva_model.dart, ../../data/repositories/reserva_repository.dart, cambiarEstadoReserva, dispose, _error, inicializarReservasUsuario, _isLoading, _reservaRepository (+4 more)

### Community 31 - "Vehicle Profile Screen"
Cohesion: 0.12
Nodes (17): dart:typed_data, build, _buildInputCard, _costController, createState, currentKm, dispose, _infoItem (+9 more)

### Community 32 - "Main Screen Routes"
Cohesion: 0.13
Nodes (16): activeIcon, child, colors, icon, InstagramBottomNavBar, isActive, isDark, MainScaffold (+8 more)

### Community 33 - "Service Task UI"
Cohesion: 0.09
Nodes (20): ../constants/firestore_collections.dart, dart:convert, facturas, perfiles, StoragePaths, baseUrl, fetchAllMakes, fetchModelsByMake (+12 more)

### Community 34 - "User Model"
Cohesion: 0.09
Nodes (22): firebase-functions, dependencies, firebase-admin, firebase-functions, @google-cloud/firestore, @google-cloud/functions-framework, description, engines (+14 more)

### Community 35 - "Review Sheet Widget"
Cohesion: 0.14
Nodes (12): _firestore, getWorkshopById, getWorkshops, getWorkshopsStream, loadFilters, saveFilters, updateWorkshopProfile, WorkshopService (+4 more)

### Community 36 - "Reservation Model"
Cohesion: 0.22
Nodes (8): appBar, AppScaffold, body, bottomNavigationBar, build, floatingActionButton, useGradient, PreferredSizeWidget?

### Community 37 - "Vehicle Provider Logic"
Cohesion: 0.06
Nodes (31): 10. Escalación y contactos, 11. Checklist pre-lanzamiento (Soft Launch), 1. Acceso a herramientas de operación, 2.1 Cambiar contraseña de admin, 2.2 Rotar service account (CI/CD), 2.3 Rotar FCM API Key, 2. Rotación de credenciales admin, 3. Suspender usuario (+23 more)

### Community 38 - "Chat Background Pattern"
Cohesion: 0.06
Nodes (32): _i11.VehicleService, _i13.VehicleImageService, _i15.UserService, _i18.FirebaseMessaging, _i1.Mock, _i3.DocumentReference, _i3.FirebaseFirestore, _i3.Query (+24 more)

### Community 39 - "Auth Service"
Cohesion: 0.05
Nodes (39): Duration, _i1.SmartFake, _i2.FirebaseApp, _i3.AggregateQuery, _i3.DocumentSnapshot, _i3.LoadBundleTask, _i3.PipelineSource, _i3.Settings (+31 more)

### Community 40 - "Top Nav & User Row"
Cohesion: 0.17
Nodes (11): main, main, main, showErrorSnackbar, showInfoSnackbar, showSuccessSnackbar, UiUtils, package:autodoc/core/widgets/app_snackbar.dart (+3 more)

### Community 41 - "Admin User Management"
Cohesion: 0.10
Nodes (20): AppSecrets, firebaseAndroidApiKey, firebaseAppIdAndroid, firebaseAppIdIos, firebaseAppIdWeb, firebaseAuthDomain, firebaseDatabaseUrl, firebaseIosApiKey (+12 more)

### Community 42 - "Text Styles"
Cohesion: 0.12
Nodes (16): bool get, clearError, currentUid, _error, _firebaseAuth, isLoggedIn, refreshUser, _user (+8 more)

### Community 43 - "Empty State Widget"
Cohesion: 0.10
Nodes (19): activeAlerts, _addOrUpdateLocalAlert, _alerts, completeAlert, createDefaultTasks, _defaultTasks, _error, fetchAlerts (+11 more)

### Community 44 - "Text Field Widget"
Cohesion: 0.04
Nodes (57): _loadTheme, setThemeMode, _themeKey, _themeMode, ThemeProvider, toggleTheme, AppSnackbar, show (+49 more)

### Community 45 - "Admin Service Methods"
Cohesion: 0.10
Nodes (19): copyWith, correo, departamento, especialidad, estado, fcmToken, fechaRegistro, fotoPerfilUrl (+11 more)

### Community 46 - "Alert Provider Logic"
Cohesion: 0.10
Nodes (19): anio, color, copyWith, fotoUrl, fromJson, fromMap, idPropietario, idVehiculo (+11 more)

### Community 47 - "Admin Repository"
Cohesion: 0.20
Nodes (9): BoxFit, build, _buildPlaceholder, fit, height, imageUrl, VehicleImageWidget, width (+1 more)

### Community 48 - "Vehicle Model"
Cohesion: 0.10
Nodes (21): class FakeAuthSessionProvider extends, class FakeUserProfileProvider extends, package:autodoc/core/router/app_router.dart, ChangeNotifier, clearError, clearUserData, _currentUid, error (+13 more)

### Community 49 - "Notification Service"
Cohesion: 0.11
Nodes (18): GoogleSignIn, _auth, AuthService, deleteAccount, _googleSignIn, _handleAuthException, isCurrentUserEmailVerified, registerWithEmail (+10 more)

### Community 50 - "App Entry Point (main)"
Cohesion: 0.11
Nodes (18): _adminAuthService, _authService, clearError, deleteAccount, _error, isEmailPasswordUser, _isLoading, refreshEmailVerificationStatus (+10 more)

### Community 51 - "Status Badge Widget"
Cohesion: 0.06
Nodes (35): Animation, AnimatedCounter, _AnimatedCounterState, _animation, build, _controller, createState, didUpdateWidget (+27 more)

### Community 52 - "Reservation Provider"
Cohesion: 0.11
Nodes (17): cloud_firestore, file_selector_macos, firebase_auth, firebase_core, firebase_crashlytics, firebase_messaging, firebase_storage, flutter_local_notifications (+9 more)

### Community 53 - "Alert Model"
Cohesion: 0.18
Nodes (10): CustomPainter, _ChatPatternPainter, build, ElSalvadorLicensePlate, height, paint, placa, shouldRepaint (+2 more)

### Community 54 - "Conversation Model"
Cohesion: 0.11
Nodes (16): UserModel, AccountRow, build, isCurrentAdmin, onCambiarRol, onReactivar, onSuspender, usuario (+8 more)

### Community 55 - "Vehicle Search Screen"
Cohesion: 0.11
Nodes (17): aprobarTaller, cambiarRolUsuario, eliminarResenia, fetchLogs, fetchResenias, fetchTalleres, fetchUsuarios, _logAction (+9 more)

### Community 56 - "Service Record Model"
Cohesion: 0.11
Nodes (17): cotizacionEstimada, descripcion, estado, fechaCreacion, fechaHoraConfirmada, fechaHoraPropuesta, fromMap, id (+9 more)

### Community 57 - "Maintenance Config UI"
Cohesion: 0.18
Nodes (14): Point, Size, wchar_t, Scale(), Create, Destroy, UpdateTheme, Win32Window::Win32Window() (+6 more)

### Community 58 - "Maintenance Task Model"
Cohesion: 0.12
Nodes (16): ../../../../core/models/admin_log_model.dart, AdminRepository, countCollection, deleteResenia, deleteTaller, deleteUsuario, _firestore, getLogs (+8 more)

### Community 59 - "Bottom Nav & Chat Cards"
Cohesion: 0.11
Nodes (17): AppTextField, build, controller, hintText, inputFormatters, keyboardType, label, maxLines (+9 more)

### Community 60 - "Translation Service"
Cohesion: 0.12
Nodes (16): AdminLogModel, package:autodoc/core/models/admin_log_model.dart, package:autodoc/features/admin/data/repositories/admin_repository.dart, package:autodoc/features/admin/data/services/admin_service.dart, adminService, fakeRepository, lastLog, lastUpdatedEstado (+8 more)

### Community 61 - "Firebase Plugins"
Cohesion: 0.09
Nodes (23): class FakePushNotificationService extends, ../../helpers/test_helpers.mocks.dart, PushNotificationService, package:autodoc/core/models/app_notification_model.dart, package:autodoc/core/providers/auth_session_provider.dart, package:autodoc/core/providers/notification_center_provider.dart, package:autodoc/core/services/push_notification_service.dart, package:firebase_auth/firebase_auth.dart (+15 more)

### Community 62 - "App Button Widget"
Cohesion: 0.12
Nodes (16): ConversacionModel, estado, fromMap, id, idMecanico, idPropietario, idTaller, idVehiculo (+8 more)

### Community 63 - "iOS Plugin Registry"
Cohesion: 0.10
Nodes (18): IconData, AppBottomNavBar, build, currentIndex, action, AppEmptyState, build, description (+10 more)

### Community 64 - "Admin Log Model"
Cohesion: 0.11
Nodes (19): build, build, _buildAssistantCard, _buildRecentItem, _buildRecentSearches, _buildSearchCard, _buildTopBar, createState (+11 more)

### Community 65 - "Windows Console Setup"
Cohesion: 0.10
Nodes (19): AnimationController, Color, dart:math, build, color, icon, MetricCard, title (+11 more)

### Community 66 - "Workshop Model"
Cohesion: 0.14
Nodes (13): FirebaseMessaging, _firebaseMessaging, initialize, _instance, _isInitialized, _localNotifications, NotificationService, _onForegroundMessage (+5 more)

### Community 67 - "Main Scaffold & Nav"
Cohesion: 0.12
Nodes (16): ../../data/models/mensaje_model.dart, AppTopNavBar, icon, isActive, onTap, title, _TopNavLink, build (+8 more)

### Community 68 - "Auth Preferences Service"
Cohesion: 0.12
Nodes (15): AlertModel, AlertPriority, copyWith, descripcion, estado, fechaLimite, fromMap, idAlerta (+7 more)

### Community 69 - "Auth Routes & Redirect"
Cohesion: 0.12
Nodes (15): actualizarEstadoCotizacion, actualizarMetadatosMensaje, buscarConversacion, crearConversacion, crearCotizacion, deleteMensaje, enviarMensaje, _firestore (+7 more)

### Community 70 - "Message Model"
Cohesion: 0.13
Nodes (15): _addUser, build, createState, dispose, _emailController, _firestore, initState, _isLoading (+7 more)

### Community 71 - "Review Service"
Cohesion: 0.13
Nodes (13): unique_ptr, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM, FlutterWindow (+5 more)

### Community 72 - "User Service"
Cohesion: 0.15
Nodes (14): int?, LanguageProvider, build, maxLines, overflow, style, text, textAlign (+6 more)

### Community 73 - "Vehicle Service (Data)"
Cohesion: 0.20
Nodes (8): package:autodoc/core/models/workshop_model.dart, package:autodoc/core/providers/language_provider.dart, package:autodoc/core/providers/theme_provider.dart, package:flutter_test/flutter_test.dart, package:shared_preferences/shared_preferences.dart, main, main, main

### Community 74 - "Admin Auth Service"
Cohesion: 0.14
Nodes (18): build, build, _handleEmailRegister, _buildHeader, _buildNearbyServices, _checkApprovalStatus, build, initState (+10 more)

### Community 75 - "Review Model"
Cohesion: 0.12
Nodes (17): AdminLogsScreen, _AdminLogsScreenState, build, _buildTag, _colorForAction, createState, _exportToCsv, _filterDateFrom (+9 more)

### Community 76 - "App Transitions"
Cohesion: 0.43
Nodes (7): AdminReseniasScreen, _AdminReseniasScreenState, build, createState, initState, _mostrarConfirmarEliminar, AdminProvider

### Community 77 - "Translated Text Widget"
Cohesion: 0.13
Nodes (15): AdminUsuariosScreen, _AdminUsuariosScreenState, build, _buildFilterChip, createState, _descRol, _filterDateFrom, _filterEstado (+7 more)

### Community 78 - "Availability Picker"
Cohesion: 0.15
Nodes (14): AppColors, AdminSeedScreen, build, AuthBackgroundBlobs, build, colors, isDark, AuthLogoSection (+6 more)

### Community 79 - "Web App Manifest"
Cohesion: 0.13
Nodes (14): automotive, utilities, background_color, categories, description, display, icons, name (+6 more)

### Community 80 - "Workshop Admin Card"
Cohesion: 0.14
Nodes (13): CollectionReference, ../../../../core/models/review_model.dart, _firestore, getReviewsForTaller, getUserReviewForTaller, hasUserReviewedTaller, recalculateTallerRating, reportReview (+5 more)

### Community 81 - "App Card Widget"
Cohesion: 0.14
Nodes (13): @firebase/rules-unit-testing, mocha, dependencies, firebase-admin, @firebase/rules-unit-testing, mocha, description, firebase-admin (+5 more)

### Community 82 - "Mechanic Admin Card"
Cohesion: 0.14
Nodes (13): int get, deleteNotification, dispose, _error, _firestore, hasUnread, initialize, _isLoading (+5 more)

### Community 83 - "Admin Dashboard Provider"
Cohesion: 0.14
Nodes (13): adminLogs, alertas, conversaciones, FirestoreCollections, historialMantenimientos, mantenimientos, mensajes, resenias (+5 more)

### Community 84 - "Vehicle Image Service"
Cohesion: 0.14
Nodes (13): fechaUltimoServicio, frecuenciaKm, frecuenciaMeses, fromMap, getStatus, getStatusLabel, id, MaintenanceStatus (+5 more)

### Community 85 - "Skeleton Loader Widget"
Cohesion: 0.14
Nodes (13): copyWith, costo, descripcion, fecha, fotoFacturaUrl, fromMap, idServicio, idTaller (+5 more)

### Community 86 - "iOS Scene Setup"
Cohesion: 0.14
Nodes (13): clearUserData, _error, _fetchedUserId, fetchUserData, _hasAttemptedFetch, hasAttemptedFetchFor, _isLoading, _setError (+5 more)

### Community 87 - "Theme Provider"
Cohesion: 0.17
Nodes (14): AdminDashboardScreen, _AdminDashboardScreenState, build, _buildActionChip, _buildMetricsGrid, _buildSectionTitle, _buildWelcomeHeader, createState (+6 more)

### Community 88 - "App Shadows"
Cohesion: 0.20
Nodes (14): RECT, OnCreate, OnDestroy, HWND, Win32Window, child_content_, GetClientArea, OnCreate (+6 more)

### Community 89 - "Firebase Options Config"
Cohesion: 0.17
Nodes (11): Box, _apiKey, _baseUrl, initialize, _instance, isInitialized, translate, translateSync (+3 more)

### Community 90 - "iOS App Delegate"
Cohesion: 0.15
Nodes (11): EdgeInsetsGeometry, AppCard, build, child, margin, onTap, padding, package:autodoc/core/theme/app_radius.dart (+3 more)

### Community 91 - "NHTSA Car Models"
Cohesion: 0.15
Nodes (12): CotizacionModel, descripcion, estado, fecha, fromMap, id, idMecanico, idPropietario (+4 more)

### Community 92 - "Language Provider"
Cohesion: 0.18
Nodes (12): _mostrarMenuAdjuntos, _cambiarEstado, ReservaProvider, build, conversacionId, isMe, mensajeId, metadata (+4 more)

### Community 93 - "Vehicle API Service"
Cohesion: 0.21
Nodes (7): GeneratedPluginRegistrant, FlutterEngine, FlutterLocalNotificationsPlugin, GeneratedPluginRegistrant, +registerWithRegistry, Keep, NSObject

### Community 94 - "Dashboard Quick Actions"
Cohesion: 0.18
Nodes (10): DateTime?, accion, adminUid, detalle, fecha, fromMap, idLog, modulo (+2 more)

### Community 95 - "Landing Screen"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 96 - "macOS Test Config"
Cohesion: 0.13
Nodes (13): comentario, copyWith, estrellas, fechaResenia, fromMap, idResenia, idTaller, idUsuario (+5 more)

### Community 97 - "macOS App Delegate"
Cohesion: 0.17
Nodes (11): calificacionPromedio, copyWith, especialidad, estado, fromMap, idTaller, nombre, telefono (+3 more)

### Community 98 - "macOS Window Setup"
Cohesion: 0.25
Nodes (7): build, conversacionId, CotizacionChatCard, isMe, mensajeId, metadata, package:autodoc/features/chat/presentation/providers/chat_provider.dart

### Community 99 - "LLDB Debug Scripts"
Cohesion: 0.15
Nodes (12): AppButton, AppButtonSize, AppButtonType, build, _handlePress, hapticFeedback, icon, isLoading (+4 more)

### Community 100 - "Language Root Widget"
Cohesion: 0.22
Nodes (8): android, DefaultFirebaseOptions, ios, web, package:autodoc/config/secrets.dart, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static FirebaseOptions get

### Community 101 - "Role Utilities"
Cohesion: 0.18
Nodes (11): AdminTalleresScreen, _AdminTalleresScreenState, _buildFilterChip, createState, _filterStatus, initState, _mostrarConfirmacion, _searchQuery (+3 more)

### Community 102 - "Skeleton Layouts"
Cohesion: 0.17
Nodes (11): AuthPreferencesService, clearSavedCredentials, getRememberMe, getSavedEmail, isOnboardingCompleted, _keyOnboardingCompleted, _keyRememberMe, _keySavedEmail (+3 more)

### Community 103 - "Localizations Delegates"
Cohesion: 0.12
Nodes (16): hashCode, operator, read, typeId, write, contenido, estado, fromMap (+8 more)

### Community 104 - "Community 104"
Cohesion: 0.18
Nodes (11): AboutScreen, _AboutScreenState, build, _buildNumber, createState, _initPackageInfo, initState, _launchUrl (+3 more)

### Community 105 - "Community 105"
Cohesion: 0.18
Nodes (10): ../../../../core/models/user_model.dart, FirebaseAuth, AdminAuthService, _auth, _firestore, getAdminByUid, isAdmin, loginAsAdmin (+2 more)

### Community 106 - "Community 106"
Cohesion: 0.14
Nodes (13): @pragma, @visibleForTesting, FirebaseFirestore, _firebaseMessagingBackgroundHandler, _firestore, initialize, initializeApp, _instance (+5 more)

### Community 107 - "Community 107"
Cohesion: 0.18
Nodes (10): accelerate, AppTransitions, decelerate, defaultCurve, fast, medium, slow, package:flutter/animation.dart (+2 more)

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (10): _buildHeader, _buildServiceTable, _buildSummary, generateServiceHistoryPdf, PdfGenerator, ../models/service_record_model.dart, ../models/vehicle_model.dart, package:pdf/pdf.dart (+2 more)

### Community 109 - "Community 109"
Cohesion: 0.15
Nodes (13): _buildRoleCard, createState, dispose, _imageFile, _isLoading, _nameController, _notificationsEnabled, _picker (+5 more)

### Community 110 - "Community 110"
Cohesion: 0.20
Nodes (9): @GenerateMocks, package:autodoc/core/services/vehicle_image_service.dart, package:autodoc/features/admin/data/services/admin_auth_service.dart, package:autodoc/features/auth/data/services/auth_service.dart, package:autodoc/features/dashboard/data/services/vehicle_service.dart, package:autodoc/features/profile/data/services/user_service.dart, package:firebase_messaging/firebase_messaging.dart, package:mockito/annotations.dart (+1 more)

### Community 111 - "Community 111"
Cohesion: 0.24
Nodes (5): Cocoa, FlutterMacOS, RunnerTests, RunnerTests, XCTestCase

### Community 112 - "Community 112"
Cohesion: 0.20
Nodes (9): ../../../../core/models/workshop_model.dart, build, _buildInfoChip, _buildStatusChip, onAprobar, onRechazar, onSuspender, taller (+1 more)

### Community 113 - "Community 113"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 114 - "Community 114"
Cohesion: 0.22
Nodes (8): ../../../../core/constants/firestore_collections.dart, actualizarEstadoReserva, crearReserva, _firestore, getReserva, ReservaRepository, streamReservasUsuario, ../models/reserva_model.dart

### Community 115 - "Community 115"
Cohesion: 0.28
Nodes (6): Flutter, FlutterSceneDelegate, GoogleMaps, SceneDelegate, UIKit, XCTest

### Community 116 - "Community 116"
Cohesion: 0.22
Nodes (6): admin, db, firestore, functions, messaging, storage

### Community 117 - "Community 117"
Cohesion: 0.14
Nodes (13): @HiveType, MensajeModelAdapter, dart:io, MensajeModel, package:autodoc/features/chat/data/models/conversacion_model.dart, package:autodoc/features/chat/data/models/cotizacion_model.dart, package:autodoc/features/chat/data/models/mensaje_model.dart, package:autodoc/features/chat/data/repositories/chat_repository.dart (+5 more)

### Community 118 - "Community 118"
Cohesion: 0.22
Nodes (8): build, conversacionId, isMe, mensajeId, metadata, ReviewChatCard, tallerId, package:autodoc/core/widgets/review_sheet.dart

### Community 119 - "Community 119"
Cohesion: 0.25
Nodes (6): Any, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, UIApplication

### Community 120 - "Community 120"
Cohesion: 0.25
Nodes (7): CarMake, CarModel, fromJson, makeId, makeName, modelId, modelName

### Community 121 - "Community 121"
Cohesion: 0.25
Nodes (7): changeLanguage, currentLanguageCode, _currentLocale, _loadLocale, Locale, Locale get, String get

### Community 123 - "Community 123"
Cohesion: 0.29
Nodes (6): app_colors.dart, app_radius.dart, app_text_styles.dart, AppTheme, _buildTextTheme, package:animations/animations.dart

### Community 124 - "Community 124"
Cohesion: 0.29
Nodes (6): AppLocalizations get, BuildContext, AppColorsExtension, l10n, L10nExtension, package:autodoc/l10n/app_localizations.dart

### Community 125 - "Community 125"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 126 - "Community 126"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 127 - "Community 127"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 128 - "Community 128"
Cohesion: 0.33
Nodes (5): isMechanicRole, mechanicFirestoreRoles, normalized, List, return

### Community 129 - "Community 129"
Cohesion: 0.33
Nodes (6): _buildQuickActions, _buildRecentActivity, Route /admin/logs, Route /admin/resenias, Route /admin/talleres, Route /admin/usuarios

### Community 130 - "Community 130"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsEs, of, LocalizationsDelegate

### Community 131 - "Community 131"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 132 - "Community 132"
Cohesion: 0.40
Nodes (4): formatEditUpdate, PlateFormatter, package:flutter/services.dart, TextInputFormatter

### Community 135 - "Community 135"
Cohesion: 0.67
Nodes (3): _i3.CollectionReference, _FakeCollectionReference_2, MockCollectionReference

### Community 137 - "Community 137"
Cohesion: 0.18
Nodes (12): NotificationCenterProvider, build, _buildBody, _colorForType, colors, _iconForType, notification, NotificationsScreen (+4 more)

### Community 145 - "Community 145"
Cohesion: 0.17
Nodes (11): addFavoriteWorkshop, _collection, createUserData, _firestore, getUserData, removeFavoriteWorkshop, updateUserData, uploadProfilePhoto (+3 more)

### Community 151 - "Community 151"
Cohesion: 0.18
Nodes (10): dart:async, ../../data/services/admin_service.dart, AdminService, _adminService, dispose, _error, fetchMetrics, _isLoading (+2 more)

### Community 152 - "Community 152"
Cohesion: 0.18
Nodes (9): package:autodoc/core/models/vehicle_model.dart, package:autodoc/features/dashboard/presentation/providers/alert_provider.dart, main, alertProvider, main, mockAlertsCollection, mockFirestore, mockQuery (+1 more)

### Community 153 - "Community 153"
Cohesion: 0.20
Nodes (10): 1. Arquitectura (Clean Architecture + Provider), 2.1 Tema y Colores, 2.2 Responsive Design, 2. Reglas de UI (Tema global, Responsive), 3.1 Base de Datos (Firestore), 3.2 Roles de Usuario, 3. Reglas de Firebase (Roles, Estructura de Colecciones), 4. Lint Rules y Estilo de Código (+2 more)

### Community 154 - "Community 154"
Cohesion: 0.20
Nodes (10): 1. `checkAlertsDaily`, 2. `checkMileageOnVehicleUpdate`, 3. `requestReviewOnServiceComplete`, 4. `notifyOnNewChatMessage`, 5. `notifyOnNewReservation`, 6. `notifyOnReservationStatusChange`, 7. `sendReservationReminders`, 8. `onUserDelete` (+2 more)

### Community 155 - "Community 155"
Cohesion: 0.22
Nodes (8): ../../data/services/vehicle_photo_service.dart, VehiclePhotoModel, colors, foto, FullScreenImageViewer, VehicleGalleryWidget, vehicleId, package:image_picker/image_picker.dart

### Community 156 - "Community 156"
Cohesion: 0.22
Nodes (8): double?, AppSkeleton, borderRadius, build, card, height, width, package:shimmer/shimmer.dart

### Community 157 - "Community 157"
Cohesion: 0.22
Nodes (8): AppShadows, darkLg, darkMd, darkSm, lightLg, lightMd, lightSm, static List

### Community 158 - "AutoDoc 🚗📋"
Cohesion: 0.22
Nodes (9): AutoDoc 🚗📋, 🤝 Contribuir, 📚 Documentación adicional, 📁 Estructura del proyecto, Para obtener los archivos de configuración:, ⚙️ Requisitos, 👥 Roles, 📋 Tabla de contenido (+1 more)

### Community 159 - "FIREBASE_FUNCTIONS.md"
Cohesion: 0.25
Nodes (5): Cómo desplegar, Cómo probar con emulador, Diagrama general de flujo, Resumen, Variables de Entorno

### Community 160 - "AutoDoc — Índices de Firestore Requeridos"
Cohesion: 0.25
Nodes (7): AutoDoc — Índices de Firestore Requeridos, Colección `alertas`, Colección `conversaciones`, Colección `mensajes` (Subcolección de conversaciones), Colección `resenias`, Colección `servicios`, Colección `usuarios`

### Community 161 - "Global Constraints"
Cohesion: 0.25
Nodes (7): Global Constraints, Plan de Mejora UI/UX de AutoDoc en Flutter usando Kombai, Plan Handoff, Task 1: Configuración de Sistema de Diseño Kombai y Tokens en Flutter, Task 2: Refactorización Visual de Componentes Core en Kombai, Task 3: Rediseño Kombai de Pantallas Dashboard y Garaje Virtual, Task 4: Rediseño Kombai de Pantallas de Talleres y Reseñas

### Community 162 - "Global Constraints"
Cohesion: 0.25
Nodes (7): AutoDoc v1.1 Implementation Plan, Global Constraints, Task 1: Google Sign-In Integration, Task 2: Push Notifications (FCM), Task 3: ChatProvider Offline Cache, Task 4: Multilingual Support (i18n), Task 5: Invoice Uploads (PDF & Quality)

### Community 163 - "AutoDoc — Términos de Servicio"
Cohesion: 0.25
Nodes (7): 1. Aceptación de los términos, 2. Uso del servicio, 3. Contenido de los usuarios, 4. Disponibilidad del servicio, 5. Cambios a los términos, 6. Jurisdicción, AutoDoc — Términos de Servicio

### Community 164 - "AutoDoc — Política de Privacidad"
Cohesion: 0.29
Nodes (6): 1. Información que recopilamos, 2. Cómo usamos la información, 3. Compartir información, 4. Retención y eliminación, 5. Contacto, AutoDoc — Política de Privacidad

### Community 165 - "vehicle_provider_test.dart"
Cohesion: 0.29
Nodes (6): VehicleModel, package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart, main, mockVehicleImageService, mockVehicleService, vehicleProvider

### Community 166 - "🚀 Setup rápido"
Cohesion: 0.29
Nodes (7): 1. Clonar y configurar Flutter, 2. Firebase, 3. Emuladores Firebase (desarrollo local), 4. Cloud Functions, 5. Landing Web (Next.js), 6. Generar localizaciones, 🚀 Setup rápido

### Community 167 - "app_skeleton_layouts.dart"
Cohesion: 0.33
Nodes (5): AppSkeletonLayouts, dashboard, listCards, workshopList, package:autodoc/core/widgets/app_skeleton.dart

### Community 168 - "auth_bottom_nav.dart"
Cohesion: 0.33
Nodes (5): AuthBottomNav, build, _buildNavAction, colors, isDark

### Community 169 - "imagen_chat_card.dart"
Cohesion: 0.33
Nodes (5): build, ImagenChatCard, isMe, _showImageDialog, urlArchivo

### Community 170 - "🚢 Despliegue"
Cohesion: 0.33
Nodes (6): APK / App Bundle (Android), Cloud Functions, 🚢 Despliegue, Firestore Rules + Storage Rules, Flutter Web, Landing Web (Vercel)

### Community 171 - "README.md"
Cohesion: 0.50
Nodes (3): Deploy on Vercel, Getting Started, Learn More

### Community 172 - "map_injector_web.dart"
Cohesion: 0.50
Nodes (3): head, injectGoogleMapsScript, package:web/web.dart

### Community 173 - "▶️ Ejecutar la app"
Cohesion: 0.50
Nodes (4): Android / iOS, Con emuladores Firebase, ▶️ Ejecutar la app, Web

### Community 174 - "🧪 Tests"
Cohesion: 0.50
Nodes (4): 🧪 Tests, Tests de integración, Tests de reglas Firestore, Tests unitarios

## Knowledge Gaps
- **2772 isolated node(s):** `functions`, `admin`, `firestore`, `db`, `messaging` (+2767 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UserProfileProvider` connect `Alerts & Vehicles Screen` to `Admin Dashboard UI`, `Community 137`, `Snackbar & UI Feedback`, `Admin Users Screen`, `TypeScript Config`, `Linux GTK Native`, `Workshop Form & Picker`, `Landing Command Center`, `Main Screen Routes`, `Text Field Widget`, `Vehicle Model`, `Status Badge Widget`, `Admin Log Model`, `Windows Console Setup`, `Main Scaffold & Nav`, `Admin Auth Service`, `App Transitions`, `Translated Text Widget`, `iOS Scene Setup`, `Theme Provider`, `Community 109`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `WorkshopModel` connect `macOS App Delegate` to `Community 112`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `build` connect `Admin Auth Service` to `Main Scaffold & Nav`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `functions`, `admin`, `firestore` to the rest of the system?**
  _2772 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Localization & i18n` be split into smaller, more focused modules?**
  _Cohesion score 0.00546448087431694 - nodes in this community are weakly interconnected._
- **Should `App Localizations EN` be split into smaller, more focused modules?**
  _Cohesion score 0.005649717514124294 - nodes in this community are weakly interconnected._
- **Should `App Localizations ES` be split into smaller, more focused modules?**
  _Cohesion score 0.005633802816901409 - nodes in this community are weakly interconnected._