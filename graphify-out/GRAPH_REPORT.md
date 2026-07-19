# Graph Report - .  (2026-07-19)

## Corpus Check
- Large corpus: 328 files · ~1,095,633 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 3638 nodes · 5040 edges · 154 communities (142 shown, 12 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 19 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

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
- Community 142
- Community 143
- Community 144
- Community 148
- Community 149
- Community 153

## God Nodes (most connected - your core abstractions)
1. `UserSessionProvider` - 80 edges
2. `AlertProvider` - 28 edges
3. `VehicleProvider` - 28 edges
4. `ChatProvider` - 26 edges
5. `AdminProvider` - 25 edges
6. `AuthProvider` - 25 edges
7. `Win32Window` - 22 edges
8. `UserProfileProvider` - 19 edges
9. `compilerOptions` - 16 edges
10. `AuthSessionProvider` - 15 edges

## Surprising Connections (you probably didn't know these)
- `build` --references--> `UserProfileProvider`  [EXTRACTED]
  lib/features/dashboard/presentation/pages/workshop_directory_screen.dart → lib/core/providers/user_profile_provider.dart
- `initState` --references--> `UserProfileProvider`  [EXTRACTED]
  lib/features/mechanic/presentation/pages/workshop_settings_screen.dart → lib/core/providers/user_profile_provider.dart
- `initState` --references--> `UserProfileProvider`  [EXTRACTED]
  lib/features/profile/presentation/pages/user_profile_screen.dart → lib/core/providers/user_profile_provider.dart
- `_submit` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/core/widgets/review_sheet.dart → lib/core/providers/user_session_provider.dart
- `_loadRememberMePreferences` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/core/providers/user_session_provider.dart

## Import Cycles
- None detected.

## Communities (154 total, 12 thin omitted)

### Community 0 - "Localization & i18n"
Cohesion: 0.01
Nodes (366): app_localizations_en.dart, app_localizations_es.dart, class, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint (+358 more)

### Community 1 - "App Localizations EN"
Cohesion: 0.01
Nodes (354): app_localizations.dart, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle (+346 more)

### Community 2 - "App Localizations ES"
Cohesion: 0.01
Nodes (353): addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle, addVehicleDocs (+345 more)

### Community 3 - "Windows Desktop Native"
Cohesion: 0.02
Nodes (87): dart:typed_data, Duration get, FirebaseApp get, FirebaseFirestore get, package:mockito/src/dummies.dart, R, Settings get, SnapshotMetadata get (+79 more)

### Community 4 - "Admin Dashboard UI"
Cohesion: 0.04
Nodes (69): ChangeNotifier, DocumentSnapshot, build, child, ResponsiveContainer, AdminDashboardScreen, _AdminDashboardScreenState, build (+61 more)

### Community 5 - "Alerts & Vehicles Screen"
Cohesion: 0.05
Nodes (60): AuthSessionProvider, build, build, userId, VehiculoPicker, AlertsScreen, _AlertsScreenState, build (+52 more)

### Community 6 - "Theme Color System"
Cohesion: 0.04
Nodes (50): DateTimeRange?, AppSnackbar, show, SnackbarType, build, ServicesTrendChart, serviciosPorMes, build (+42 more)

### Community 7 - "Auth & Navigation Core"
Cohesion: 0.04
Nodes (50): AppColors get, AppPalette, copyWith, darkError, darkOnPrimary, darkOnSecondary, darkOutline, darkPrimary (+42 more)

### Community 8 - "Vehicle Registration Form"
Cohesion: 0.04
Nodes (44): ../../../../core/models/nhtsa_models.dart, ../../../../core/services/vehicle_api_service.dart, ../../../../core/theme/app_colors.dart, ../../../../core/utils/plate_formatter.dart, _allMakes, _anioController, _apiService, _brandSearchQuery (+36 more)

### Community 9 - "Landing Web (Next.js)"
Cohesion: 0.05
Nodes (43): _adminRoutes, createAppRouter, false, _homeForRole, _matchesRouteSet, _mechanicRoutes, _normalizeRole, _ownerRoutes (+35 more)

### Community 10 - "App Router & Theme"
Cohesion: 0.05
Nodes (42): eslint, eslint-config-next, framer-motion, dependencies, framer-motion, lucide-react, next, next-intl (+34 more)

### Community 11 - "Chat Messaging Screen"
Cohesion: 0.06
Nodes (32): main, main, AdminLogModel, package:autodoc/core/models/admin_log_model.dart, package:autodoc/core/models/review_model.dart, package:autodoc/core/models/workshop_model.dart, package:autodoc/features/admin/data/repositories/admin_repository.dart, package:autodoc/features/admin/data/services/admin_service.dart (+24 more)

### Community 12 - "UI Radius & Spacing"
Cohesion: 0.09
Nodes (36): UserSessionProvider, AdminUsuariosScreen, _AdminUsuariosScreenState, AuthScreen, _AuthScreenState, ChatScreen, _ChatScreenState, WorkshopDirectoryScreen (+28 more)

### Community 13 - "Snackbar & UI Feedback"
Cohesion: 0.05
Nodes (35): AppRadius, full, lg, md, sm, xl, xs, xxl (+27 more)

### Community 14 - "Landing Page Widgets"
Cohesion: 0.06
Nodes (33): VehicleModel, _buildAlertsList, _buildCostoInput, _buildInvoicePicker, _buildKmInput, _buildMaintenanceTasks, _buildSectionTitle, _buildVehicleHeader (+25 more)

### Community 15 - "Admin Users Screen"
Cohesion: 0.08
Nodes (29): _GlassTag, build, HeroSection, image, opacity, _PhoneMockup, rotate, scale (+21 more)

### Community 16 - "Auth Provider & Admin Auth"
Cohesion: 0.08
Nodes (7): geistMono, geistSans, ThemeProvider(), Header(), Workshop, {Link, redirect, usePathname, useRouter, getPathname}, routing

### Community 17 - "Service Initiation Screen"
Cohesion: 0.06
Nodes (31): GoogleMapController?, build, _buildFilterChip, _buildFilters, _buildHeader, _buildMapCard, _buildMapView, _buildSearchBar (+23 more)

### Community 18 - "TypeScript Config"
Cohesion: 0.06
Nodes (30): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+22 more)

### Community 19 - "Admin Provider Logic"
Cohesion: 0.08
Nodes (28): UserProfileProvider, build, _canEdit, _checkExisting, _checking, _comentarioController, createState, dispose (+20 more)

### Community 20 - "Linux GTK Native"
Cohesion: 0.07
Nodes (25): Color, CustomPainter, dart:math, main, build, color, icon, MetricCard (+17 more)

### Community 21 - "Auth Screen UI"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/role_utils.dart, _adminService, aprobarTaller, cambiarRolUsuario, clearMessages, eliminarResenia, _error, fetchAllData (+20 more)

### Community 22 - "Vehicle Image Widget"
Cohesion: 0.08
Nodes (24): AppBottomNavBar, build, currentIndex, AuthLogoSection, build, colors, build, conversacionId (+16 more)

### Community 23 - "Workshop Map View"
Cohesion: 0.08
Nodes (22): GeneratedPluginRegistrant, AndroidFlutterLocalNotificationsPlugin, FirebaseMessaging, FlutterEngine, FlutterLocalNotificationsPlugin, GeneratedPluginRegistrant, +registerWithRegistry, Keep (+14 more)

### Community 24 - "Workshop Form & Picker"
Cohesion: 0.07
Nodes (27): @pragma, GoRouter, authProvider, authSessionProvider, createState, dispose, _firebaseMessagingBackgroundHandler, id (+19 more)

### Community 25 - "Next.js App Shell"
Cohesion: 0.08
Nodes (25): ../../helpers/test_helpers.mocks.dart, NotificationCenterProvider, AppTopNavBar, icon, isActive, onTap, title, _TopNavLink (+17 more)

### Community 26 - "Landing Command Center"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 27 - "Firebase Cloud Functions"
Cohesion: 0.08
Nodes (26): _activeTab, build, _buildShowcaseContent, color, CommandCenterSection, _CommandCenterSectionState, CommandCenterTab, createState (+18 more)

### Community 28 - "Animated Counter Widget"
Cohesion: 0.08
Nodes (23): bool get, currentUid, isLoggedIn, refreshUser, _user, _authPreferences, currentUid, _error (+15 more)

### Community 29 - "Chat Provider & Models"
Cohesion: 0.08
Nodes (22): Box, _apiKey, _baseUrl, initialize, _instance, isInitialized, translate, translateSync (+14 more)

### Community 30 - "Chat Repository"
Cohesion: 0.08
Nodes (24): ../../data/models/conversacion_model.dart, ../../data/models/cotizacion_model.dart, ../../data/repositories/chat_repository.dart, actualizarEstadoCotizacion, actualizarMetadatosMensaje, _chatRepository, _conversaciones, _conversacionesSub (+16 more)

### Community 31 - "Vehicle Profile Screen"
Cohesion: 0.09
Nodes (21): File?, _buildDrawerItem, _buildRoleCard, createState, dispose, _imageFile, _isLoading, _nameController (+13 more)

### Community 32 - "Main Screen Routes"
Cohesion: 0.08
Nodes (24): _abrirSelectorMapa, _buildCoordinatesPicker, _buildDropdownField, _buildInputField, _buildTopBar, createState, dispose, _elSalvadorDivipola (+16 more)

### Community 33 - "Service Task UI"
Cohesion: 0.09
Nodes (22): dart:async, ../../data/models/reserva_model.dart, ../../data/repositories/reserva_repository.dart, ../../data/services/admin_service.dart, AdminService, _adminService, dispose, _error (+14 more)

### Community 34 - "User Model"
Cohesion: 0.09
Nodes (21): FirebaseFirestore, _firestore, getWorkshopById, getWorkshops, getWorkshopsStream, loadFilters, saveFilters, updateWorkshopProfile (+13 more)

### Community 35 - "Review Sheet Widget"
Cohesion: 0.09
Nodes (22): _buildActionButton, _buildDetailItem, _buildDocumentationStatus, _buildDocumentationStatusItem, _buildExpenseSummary, _buildHeader, _buildHeroImage, _buildStatusAlert (+14 more)

### Community 36 - "Reservation Model"
Cohesion: 0.10
Nodes (19): ../constants/firestore_collections.dart, dart:convert, facturas, perfiles, StoragePaths, baseUrl, fetchAllMakes, fetchModelsByMake (+11 more)

### Community 37 - "Vehicle Provider Logic"
Cohesion: 0.09
Nodes (22): _i10.VehicleService, _i12.VehicleImageService, _i14.UserService, _i1.Mock, _i3.CollectionReference, _i3.FirebaseFirestore, _i3.QuerySnapshot, _i5.FirebaseStorage (+14 more)

### Community 38 - "Chat Background Pattern"
Cohesion: 0.09
Nodes (21): build, _buildGlassCard, _buildTextField, createState, dispose, _emailController, _handleEmailSignIn, initState (+13 more)

### Community 39 - "Auth Service"
Cohesion: 0.10
Nodes (20): Animation, AnimationController, Duration, AnimatedCounter, _AnimatedCounterState, _animation, build, _controller (+12 more)

### Community 40 - "Top Nav & User Row"
Cohesion: 0.10
Nodes (20): firebase-functions, dependencies, firebase-admin, firebase-functions, @google-cloud/functions-framework, description, engines, node (+12 more)

### Community 41 - "Admin User Management"
Cohesion: 0.10
Nodes (21): _i1.SmartFake, _i2.FirebaseApp, _i3.AggregateQuery, _i3.DocumentReference, _i3.LoadBundleTask, _i3.PipelineSource, _i3.Settings, _i3.SnapshotMetadata (+13 more)

### Community 42 - "Text Styles"
Cohesion: 0.10
Nodes (18): IconData, AppStatusBadge, AppStatusType, build, icon, text, type, activeIcon (+10 more)

### Community 43 - "Empty State Widget"
Cohesion: 0.10
Nodes (19): copyWith, correo, departamento, especialidad, estado, fcmToken, fechaRegistro, fotoPerfilUrl (+11 more)

### Community 44 - "Text Field Widget"
Cohesion: 0.10
Nodes (19): _buildMessageContent, _controller, conversacionId, createState, _isTyping, _scrollController, _typingTimer, package:autodoc/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart (+11 more)

### Community 45 - "Admin Service Methods"
Cohesion: 0.10
Nodes (19): activeAlerts, _addOrUpdateLocalAlert, _alerts, completeAlert, createDefaultTasks, _defaultTasks, _error, fetchAlerts (+11 more)

### Community 46 - "Alert Provider Logic"
Cohesion: 0.11
Nodes (18): GoogleSignIn, _auth, AuthService, deleteAccount, _googleSignIn, _handleAuthException, isCurrentUserEmailVerified, registerWithEmail (+10 more)

### Community 47 - "Admin Repository"
Cohesion: 0.11
Nodes (17): int get, deleteNotification, dispose, _error, _firestore, hasUnread, initialize, _isLoading (+9 more)

### Community 48 - "Vehicle Model"
Cohesion: 0.11
Nodes (17): AppButton, AppButtonSize, AppButtonType, build, _handlePress, hapticFeedback, icon, isLoading (+9 more)

### Community 49 - "Notification Service"
Cohesion: 0.11
Nodes (18): AppTextField, build, controller, hintText, inputFormatters, keyboardType, label, maxLines (+10 more)

### Community 50 - "App Entry Point (main)"
Cohesion: 0.11
Nodes (18): _adminAuthService, _authService, clearError, deleteAccount, _error, isEmailPasswordUser, _isLoading, refreshEmailVerificationStatus (+10 more)

### Community 51 - "Status Badge Widget"
Cohesion: 0.11
Nodes (18): _buildActionOption, _buildAppBar, _buildInfoField, _buildInfoSection, _buildProfileHeader, _buildStaticField, _buildThemeOption, createState (+10 more)

### Community 52 - "Reservation Provider"
Cohesion: 0.11
Nodes (17): cloud_firestore, file_selector_macos, firebase_auth, firebase_core, firebase_crashlytics, firebase_messaging, firebase_storage, flutter_local_notifications (+9 more)

### Community 53 - "Alert Model"
Cohesion: 0.11
Nodes (17): ../../../../core/services/vehicle_image_service.dart, ../../data/services/vehicle_service.dart, addVehicle, deleteVehicle, _demoteCurrentPrimary, fetchVehicles, findVehicleByPlate, _imageService (+9 more)

### Community 54 - "Conversation Model"
Cohesion: 0.11
Nodes (17): anio, color, copyWith, fotoUrl, fromMap, idPropietario, idVehiculo, isPrimary (+9 more)

### Community 55 - "Vehicle Search Screen"
Cohesion: 0.11
Nodes (17): AppTextStyles, bodyLarge, bodyMedium, bodySmall, displayLarge, displayMedium, displaySmall, headlineLarge (+9 more)

### Community 56 - "Service Record Model"
Cohesion: 0.11
Nodes (16): action, AppEmptyState, build, description, icon, lottieAsset, title, appBar (+8 more)

### Community 57 - "Maintenance Config UI"
Cohesion: 0.11
Nodes (17): aprobarTaller, cambiarRolUsuario, eliminarResenia, fetchLogs, fetchResenias, fetchTalleres, fetchUsuarios, _logAction (+9 more)

### Community 58 - "Maintenance Task Model"
Cohesion: 0.11
Nodes (17): cotizacionEstimada, descripcion, estado, fechaCreacion, fechaHoraConfirmada, fechaHoraPropuesta, fromMap, id (+9 more)

### Community 59 - "Bottom Nav & Chat Cards"
Cohesion: 0.18
Nodes (14): Point, Size, wchar_t, Scale(), Create, Destroy, UpdateTheme, Win32Window::Win32Window() (+6 more)

### Community 60 - "Translation Service"
Cohesion: 0.12
Nodes (16): ../../../../core/models/admin_log_model.dart, AdminRepository, countCollection, deleteResenia, deleteTaller, deleteUsuario, _firestore, getLogs (+8 more)

### Community 61 - "Firebase Plugins"
Cohesion: 0.12
Nodes (16): ConversacionModel, estado, fromMap, id, idMecanico, idPropietario, idTaller, idVehiculo (+8 more)

### Community 62 - "App Button Widget"
Cohesion: 0.12
Nodes (16): build, _buildInputCard, _costController, createState, currentKm, dispose, _infoItem, _isLoading (+8 more)

### Community 63 - "iOS Plugin Registry"
Cohesion: 0.13
Nodes (15): dart:ui, _buildFeatureItem, _contents, createState, _currentPage, description, features, imageUrl (+7 more)

### Community 64 - "Admin Log Model"
Cohesion: 0.13
Nodes (14): ../../data/models/mensaje_model.dart, AppColors, AuthBottomNav, build, _buildNavAction, colors, isDark, MensajeModel (+6 more)

### Community 65 - "Windows Console Setup"
Cohesion: 0.12
Nodes (15): FirebaseStorage, addPhoto, deletePhoto, _firestore, fromMap, id, _storage, streamPhotos (+7 more)

### Community 66 - "Workshop Model"
Cohesion: 0.12
Nodes (15): AlertModel, AlertPriority, copyWith, descripcion, estado, fechaLimite, fromMap, idAlerta (+7 more)

### Community 67 - "Main Scaffold & Nav"
Cohesion: 0.12
Nodes (15): actualizarEstadoCotizacion, actualizarMetadatosMensaje, buscarConversacion, crearConversacion, crearCotizacion, deleteMensaje, enviarMensaje, _firestore (+7 more)

### Community 68 - "Auth Preferences Service"
Cohesion: 0.13
Nodes (15): _addUser, build, createState, dispose, _emailController, _firestore, initState, _isLoading (+7 more)

### Community 69 - "Auth Routes & Redirect"
Cohesion: 0.13
Nodes (13): unique_ptr, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM, FlutterWindow (+5 more)

### Community 70 - "Message Model"
Cohesion: 0.13
Nodes (14): ../../../../core/models/vehicle_model.dart, addNote, addVehicle, _collection, deleteVehicle, _firestore, getExpenseSummary, getLastVisitedWorkshop (+6 more)

### Community 71 - "Review Service"
Cohesion: 0.13
Nodes (13): dart:io, clearUserData, _error, fetchUserData, _isLoading, _setError, _setLoading, updateProfile (+5 more)

### Community 72 - "User Service"
Cohesion: 0.15
Nodes (14): int?, LanguageProvider, build, maxLines, overflow, style, text, textAlign (+6 more)

### Community 73 - "Vehicle Service (Data)"
Cohesion: 0.13
Nodes (12): _loadTheme, setThemeMode, _themeKey, _themeMode, toggleTheme, package:autodoc/core/providers/language_provider.dart, package:autodoc/core/providers/theme_provider.dart, package:shared_preferences/shared_preferences.dart (+4 more)

### Community 74 - "Admin Auth Service"
Cohesion: 0.15
Nodes (14): build, dispose, _enviarMensaje, initState, _pickAndSendImage, ChatProvider, build, conversacionId (+6 more)

### Community 75 - "Review Model"
Cohesion: 0.14
Nodes (14): build, createState, dispose, initState, _isLoading, _kmController, _monthsController, _presetChip (+6 more)

### Community 76 - "App Transitions"
Cohesion: 0.13
Nodes (14): automotive, utilities, background_color, categories, description, display, icons, name (+6 more)

### Community 77 - "Translated Text Widget"
Cohesion: 0.14
Nodes (13): CollectionReference, ../../../../core/models/review_model.dart, _firestore, getReviewsForTaller, getUserReviewForTaller, hasUserReviewedTaller, recalculateTallerRating, reportReview (+5 more)

### Community 78 - "Availability Picker"
Cohesion: 0.14
Nodes (13): @firebase/rules-unit-testing, mocha, dependencies, firebase-admin, @firebase/rules-unit-testing, mocha, description, firebase-admin (+5 more)

### Community 79 - "Web App Manifest"
Cohesion: 0.14
Nodes (13): adminLogs, alertas, conversaciones, FirestoreCollections, historialMantenimientos, mantenimientos, mensajes, resenias (+5 more)

### Community 80 - "Workshop Admin Card"
Cohesion: 0.14
Nodes (13): AppNotification, body, copyWith, deepLink, fromFirestore, fromMap, id, leida (+5 more)

### Community 81 - "App Card Widget"
Cohesion: 0.14
Nodes (13): fechaUltimoServicio, frecuenciaKm, frecuenciaMeses, fromMap, getStatus, getStatusLabel, id, MaintenanceStatus (+5 more)

### Community 82 - "Mechanic Admin Card"
Cohesion: 0.14
Nodes (13): copyWith, costo, descripcion, fecha, fotoFacturaUrl, fromMap, idServicio, idTaller (+5 more)

### Community 83 - "Admin Dashboard Provider"
Cohesion: 0.15
Nodes (13): ChatRepository, Mock, package:firebase_auth/firebase_auth.dart, package:mockito/mockito.dart, authProvider, main, mockAdminAuthService, mockAuthService (+5 more)

### Community 84 - "Vehicle Image Service"
Cohesion: 0.15
Nodes (13): build, _buildAssistantCard, _buildRecentItem, _buildRecentSearches, _buildSearchCard, _buildTopBar, createState, _formatPlate (+5 more)

### Community 85 - "Skeleton Loader Widget"
Cohesion: 0.20
Nodes (14): RECT, OnCreate, OnDestroy, HWND, Win32Window, child_content_, GetClientArea, OnCreate (+6 more)

### Community 86 - "iOS Scene Setup"
Cohesion: 0.19
Nodes (13): build, build, _buildActiveAlerts, _buildHeader, _buildNearbyServices, _buildQuickActions, Route /alerts, Route /chat_list (+5 more)

### Community 87 - "Theme Provider"
Cohesion: 0.21
Nodes (13): AdminSidebar, build, _buildGoogleButton, _buildSubmitButton, _showForgotPasswordDialog, AuthProvider, _showDeleteConfirmationDialog, _signOut (+5 more)

### Community 88 - "App Shadows"
Cohesion: 0.15
Nodes (12): CotizacionModel, descripcion, estado, fecha, fromMap, id, idMecanico, idPropietario (+4 more)

### Community 89 - "Firebase Options Config"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 90 - "iOS App Delegate"
Cohesion: 0.17
Nodes (11): comentario, copyWith, estrellas, fechaResenia, fromMap, idResenia, idTaller, idUsuario (+3 more)

### Community 91 - "NHTSA Car Models"
Cohesion: 0.17
Nodes (11): calificacionPromedio, copyWith, especialidad, estado, fromMap, idTaller, nombre, telefono (+3 more)

### Community 92 - "Language Provider"
Cohesion: 0.20
Nodes (11): ThemeProvider, build, _scanQR, build, build, _buildNavItem, MechanicSidebar, _navigate (+3 more)

### Community 93 - "Vehicle API Service"
Cohesion: 0.17
Nodes (11): AuthPreferencesService, clearSavedCredentials, getRememberMe, getSavedEmail, isOnboardingCompleted, _keyOnboardingCompleted, _keyRememberMe, _keySavedEmail (+3 more)

### Community 94 - "Dashboard Quick Actions"
Cohesion: 0.23
Nodes (12): _handleEmailRegister, _navigateAfterAuth, _checkApprovalStatus, build, build, initState, Route /admin/dashboard, Route /dashboard (+4 more)

### Community 95 - "Landing Screen"
Cohesion: 0.17
Nodes (11): contenido, estado, fromMap, id, idRemitente, isDeleted, metadata, timestamp (+3 more)

### Community 96 - "macOS Test Config"
Cohesion: 0.20
Nodes (11): _mostrarMenuAdjuntos, _cambiarEstado, ReservaProvider, build, conversacionId, isMe, mensajeId, metadata (+3 more)

### Community 97 - "macOS App Delegate"
Cohesion: 0.18
Nodes (11): AboutScreen, _AboutScreenState, build, _buildNumber, createState, _initPackageInfo, initState, _launchUrl (+3 more)

### Community 98 - "macOS Window Setup"
Cohesion: 0.18
Nodes (10): DateTime?, accion, adminUid, detalle, fecha, fromMap, idLog, modulo (+2 more)

### Community 99 - "LLDB Debug Scripts"
Cohesion: 0.20
Nodes (10): FormState, build, CotizacionPicker, _CotizacionPickerState, createState, _descController, dispose, _formKey (+2 more)

### Community 100 - "Language Root Widget"
Cohesion: 0.18
Nodes (10): accelerate, AppTransitions, decelerate, defaultCurve, fast, medium, slow, package:flutter/animation.dart (+2 more)

### Community 101 - "Role Utilities"
Cohesion: 0.18
Nodes (10): _buildHeader, _buildServiceTable, _buildSummary, generateServiceHistoryPdf, PdfGenerator, ../models/service_record_model.dart, ../models/vehicle_model.dart, package:pdf/pdf.dart (+2 more)

### Community 102 - "Skeleton Layouts"
Cohesion: 0.20
Nodes (10): _availableTimes, build, createState, DisponibilidadPicker, _DisponibilidadPickerState, _focusedDay, initState, _selectedDay (+2 more)

### Community 103 - "Localizations Delegates"
Cohesion: 0.20
Nodes (9): @GenerateMocks, package:autodoc/core/services/vehicle_image_service.dart, package:autodoc/features/admin/data/services/admin_auth_service.dart, package:autodoc/features/auth/data/services/auth_service.dart, package:autodoc/features/dashboard/data/services/vehicle_service.dart, package:autodoc/features/profile/data/services/user_service.dart, package:firebase_storage/firebase_storage.dart, package:mockito/annotations.dart (+1 more)

### Community 104 - "Community 104"
Cohesion: 0.20
Nodes (9): BoxFit, build, _buildPlaceholder, fit, height, imageUrl, VehicleImageWidget, width (+1 more)

### Community 105 - "Community 105"
Cohesion: 0.24
Nodes (5): Cocoa, FlutterMacOS, RunnerTests, RunnerTests, XCTestCase

### Community 106 - "Community 106"
Cohesion: 0.20
Nodes (9): ../../../../core/models/workshop_model.dart, build, _buildInfoChip, _buildStatusChip, onAprobar, onRechazar, onSuspender, taller (+1 more)

### Community 107 - "Community 107"
Cohesion: 0.20
Nodes (9): EdgeInsetsGeometry, AppCard, build, child, margin, onTap, padding, package:autodoc/core/theme/app_shadows.dart (+1 more)

### Community 108 - "Community 108"
Cohesion: 0.20
Nodes (9): FirebaseAuth, AdminAuthService, _auth, _firestore, getAdminByUid, isAdmin, loginAsAdmin, _resolveUsernameToEmail (+1 more)

### Community 109 - "Community 109"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 110 - "Community 110"
Cohesion: 0.22
Nodes (8): ../../../../core/constants/firestore_collections.dart, actualizarEstadoReserva, crearReserva, _firestore, getReserva, ReservaRepository, streamReservasUsuario, ../models/reserva_model.dart

### Community 111 - "Community 111"
Cohesion: 0.22
Nodes (8): ../../../../core/models/user_model.dart, AccountRow, build, isCurrentAdmin, onCambiarRol, onReactivar, onSuspender, usuario

### Community 112 - "Community 112"
Cohesion: 0.22
Nodes (8): ../../data/services/vehicle_photo_service.dart, VehiclePhotoModel, colors, foto, FullScreenImageViewer, VehicleGalleryWidget, vehicleId, package:image_picker/image_picker.dart

### Community 113 - "Community 113"
Cohesion: 0.22
Nodes (8): double?, AppSkeleton, borderRadius, build, card, height, width, package:shimmer/shimmer.dart

### Community 114 - "Community 114"
Cohesion: 0.28
Nodes (6): Flutter, FlutterSceneDelegate, GoogleMaps, SceneDelegate, UIKit, XCTest

### Community 115 - "Community 115"
Cohesion: 0.22
Nodes (8): UserModel, build, calificacionPromedio, _chip, _info, MecanicoAdminCard, totalResenias, usuario

### Community 116 - "Community 116"
Cohesion: 0.22
Nodes (8): AppShadows, darkLg, darkMd, darkSm, lightLg, lightMd, lightSm, static List

### Community 117 - "Community 117"
Cohesion: 0.25
Nodes (8): ReservaModel, build, createState, _isLoading, reserva, ReservaDetailScreen, _ReservaDetailScreenState, package:autodoc/features/chat/presentation/providers/reserva_provider.dart

### Community 118 - "Community 118"
Cohesion: 0.25
Nodes (6): Any, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, UIApplication

### Community 119 - "Community 119"
Cohesion: 0.25
Nodes (7): CarMake, CarModel, fromJson, makeId, makeName, modelId, modelName

### Community 120 - "Community 120"
Cohesion: 0.25
Nodes (7): changeLanguage, currentLanguageCode, _currentLocale, _loadLocale, Locale, Locale get, String get

### Community 121 - "Community 121"
Cohesion: 0.25
Nodes (7): build, LandingScreen, ../widgets/command_center_section.dart, ../widgets/hero_section.dart, ../widgets/landing_footer.dart, ../widgets/landing_header.dart, ../widgets/value_prop_section.dart

### Community 122 - "Community 122"
Cohesion: 0.25
Nodes (7): package:autodoc/features/chat/data/models/conversacion_model.dart, package:autodoc/features/chat/data/models/cotizacion_model.dart, package:autodoc/features/chat/data/models/mensaje_model.dart, package:autodoc/features/chat/data/repositories/chat_repository.dart, package:autodoc/features/chat/presentation/providers/chat_provider.dart, chatProvider, main

### Community 124 - "Community 124"
Cohesion: 0.29
Nodes (6): app_colors.dart, app_radius.dart, app_text_styles.dart, AppTheme, _buildTextTheme, package:animations/animations.dart

### Community 125 - "Community 125"
Cohesion: 0.29
Nodes (6): AppLocalizations get, BuildContext, AppColorsExtension, l10n, L10nExtension, package:autodoc/l10n/app_localizations.dart

### Community 126 - "Community 126"
Cohesion: 0.29
Nodes (5): admin, db, functions, messaging, storage

### Community 127 - "Community 127"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 128 - "Community 128"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 129 - "Community 129"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 130 - "Community 130"
Cohesion: 0.33
Nodes (5): AppSkeletonLayouts, dashboard, listCards, workshopList, package:autodoc/core/widgets/app_skeleton.dart

### Community 131 - "Community 131"
Cohesion: 0.33
Nodes (6): _buildQuickActions, _buildRecentActivity, Route /admin/logs, Route /admin/resenias, Route /admin/talleres, Route /admin/usuarios

### Community 132 - "Community 132"
Cohesion: 0.33
Nodes (5): build, ImagenChatCard, isMe, _showImageDialog, urlArchivo

### Community 133 - "Community 133"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsEs, of, LocalizationsDelegate

### Community 134 - "Community 134"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 135 - "Community 135"
Cohesion: 0.40
Nodes (4): formatEditUpdate, PlateFormatter, package:flutter/services.dart, TextInputFormatter

### Community 138 - "Community 138"
Cohesion: 0.67
Nodes (3): _i3.Query, _FakeQuery_6, MockQuery

## Knowledge Gaps
- **2552 isolated node(s):** `functions`, `admin`, `db`, `messaging`, `storage` (+2547 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UserSessionProvider` connect `UI Radius & Spacing` to `Admin Dashboard UI`, `Alerts & Vehicles Screen`, `Theme Color System`, `Landing Page Widgets`, `Service Initiation Screen`, `Admin Provider Logic`, `Next.js App Shell`, `Animated Counter Widget`, `Vehicle Profile Screen`, `Main Screen Routes`, `Chat Background Pattern`, `Text Styles`, `Text Field Widget`, `Status Badge Widget`, `Admin Auth Service`, `Vehicle Image Service`, `iOS Scene Setup`, `Theme Provider`, `Dashboard Quick Actions`, `Community 117`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Why does `ChatProvider` connect `Admin Auth Service` to `macOS Test Config`, `Admin Dashboard UI`, `Text Field Widget`, `UI Radius & Spacing`, `Service Initiation Screen`, `Admin Provider Logic`, `Vehicle Image Widget`, `Community 122`, `Chat Repository`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `_FakeSettings_1` connect `Admin User Management` to `Windows Desktop Native`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `functions`, `admin`, `db` to the rest of the system?**
  _2552 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Localization & i18n` be split into smaller, more focused modules?**
  _Cohesion score 0.005449591280653951 - nodes in this community are weakly interconnected._
- **Should `App Localizations EN` be split into smaller, more focused modules?**
  _Cohesion score 0.005633802816901409 - nodes in this community are weakly interconnected._
- **Should `App Localizations ES` be split into smaller, more focused modules?**
  _Cohesion score 0.005649717514124294 - nodes in this community are weakly interconnected._