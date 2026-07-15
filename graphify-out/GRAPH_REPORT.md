# Graph Report - .  (2026-07-14)

## Corpus Check
- Large corpus: 299 files · ~1,074,348 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 3079 nodes · 4276 edges · 158 communities (147 shown, 11 thin omitted)
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
- Community 147
- Community 148
- Community 155

## God Nodes (most connected - your core abstractions)
1. `UserSessionProvider` - 81 edges
2. `VehicleProvider` - 28 edges
3. `AlertProvider` - 27 edges
4. `ChatProvider` - 25 edges
5. `AdminProvider` - 24 edges
6. `AuthProvider` - 22 edges
7. `Win32Window` - 22 edges
8. `compilerOptions` - 16 edges
9. `ThemeProvider` - 14 edges
10. `MessageHandler` - 12 edges

## Surprising Connections (you probably didn't know these)
- `_checkExisting` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/core/widgets/review_sheet.dart → lib/core/providers/user_session_provider.dart
- `_submit` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/core/widgets/review_sheet.dart → lib/core/providers/user_session_provider.dart
- `_loadRememberMePreferences` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/core/providers/user_session_provider.dart
- `_persistRememberMe` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/core/providers/user_session_provider.dart
- `build` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/dashboard/presentation/pages/workshop_directory_screen.dart → lib/core/providers/user_session_provider.dart

## Import Cycles
- None detected.

## Communities (158 total, 11 thin omitted)

### Community 0 - "Localization & i18n"
Cohesion: 0.01
Nodes (258): app_localizations_en.dart, app_localizations_es.dart, class, adminDashboardSubtitle, adminDashboardTitle, adminDashboardWelcome, adminGlobalMetricsTitle, adminMetricsAlerts (+250 more)

### Community 1 - "App Localizations EN"
Cohesion: 0.01
Nodes (246): app_localizations.dart, adminDashboardSubtitle, adminDashboardTitle, adminDashboardWelcome, adminGlobalMetricsTitle, adminMetricsAlerts, adminMetricsReviews, adminMetricsServices (+238 more)

### Community 2 - "App Localizations ES"
Cohesion: 0.01
Nodes (245): adminDashboardSubtitle, adminDashboardTitle, adminDashboardWelcome, adminGlobalMetricsTitle, adminMetricsAlerts, adminMetricsReviews, adminMetricsServices, adminMetricsUsers (+237 more)

### Community 3 - "Windows Desktop Native"
Cohesion: 0.02
Nodes (87): dart:typed_data, Duration get, FirebaseApp get, FirebaseFirestore get, package:mockito/src/dummies.dart, R, Settings get, SnapshotMetadata get (+79 more)

### Community 4 - "Admin Dashboard UI"
Cohesion: 0.04
Nodes (50): AppColors get, AppPalette, copyWith, darkError, darkOnPrimary, darkOnSecondary, darkOutline, darkPrimary (+42 more)

### Community 5 - "Alerts & Vehicles Screen"
Cohesion: 0.06
Nodes (43): ThemeProvider, build, _buildSubmitButton, _showForgotPasswordDialog, AuthProvider, build, userId, VehiculoPicker (+35 more)

### Community 6 - "Theme Color System"
Cohesion: 0.07
Nodes (39): AppBottomNavBar, build, currentIndex, AuthLogoSection, build, colors, build, ReservaDetailScreen (+31 more)

### Community 7 - "Auth & Navigation Core"
Cohesion: 0.05
Nodes (43): ../../../../core/models/nhtsa_models.dart, ../../../../core/services/vehicle_api_service.dart, ../../../../core/utils/plate_formatter.dart, _allMakes, _anioController, _apiService, _brandSearchQuery, build (+35 more)

### Community 8 - "Vehicle Registration Form"
Cohesion: 0.07
Nodes (37): DateTimeRange?, DocumentSnapshot, UserSessionProvider, AdminSidebar, _buildDrawerItem, build, HistorialChatCard, isMe (+29 more)

### Community 9 - "Landing Web (Next.js)"
Cohesion: 0.08
Nodes (38): AdminLogsScreen, _AdminLogsScreenState, build, _buildTag, _colorForAction, createState, _iconForAction, initState (+30 more)

### Community 10 - "App Router & Theme"
Cohesion: 0.05
Nodes (39): app_colors.dart, app_radius.dart, app_text_styles.dart, GoRouter, appRouter, AppTheme, _buildTextTheme, package:animations/animations.dart (+31 more)

### Community 11 - "Chat Messaging Screen"
Cohesion: 0.05
Nodes (40): eslint, eslint-config-next, framer-motion, dependencies, framer-motion, lucide-react, next, next-intl (+32 more)

### Community 12 - "UI Radius & Spacing"
Cohesion: 0.05
Nodes (35): AppRadius, full, lg, md, sm, xl, xs, xxl (+27 more)

### Community 13 - "Snackbar & UI Feedback"
Cohesion: 0.08
Nodes (32): build, _buildGlassCard, _buildGoogleButton, _buildTextField, createState, dispose, _emailController, _handleEmailRegister (+24 more)

### Community 14 - "Landing Page Widgets"
Cohesion: 0.06
Nodes (30): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+22 more)

### Community 15 - "Admin Users Screen"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/role_utils.dart, _adminService, aprobarTaller, cambiarRolUsuario, clearMessages, eliminarResenia, _error, fetchAllData (+20 more)

### Community 16 - "Auth Provider & Admin Auth"
Cohesion: 0.08
Nodes (24): EdgeInsetsGeometry, AppCard, build, child, margin, onTap, padding, appBar (+16 more)

### Community 17 - "Service Initiation Screen"
Cohesion: 0.08
Nodes (27): _showUpdateMileageDialog, _showAddVehicleDialog, build, _buildActionButton, _buildDetailItem, _buildDocumentationStatus, _buildDocumentationStatusItem, _buildExpenseSummary (+19 more)

### Community 18 - "TypeScript Config"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 19 - "Admin Provider Logic"
Cohesion: 0.07
Nodes (26): GoogleMapController?, build, _buildFilterChip, _buildFilters, _buildHeader, _buildMapCard, _buildMapView, _buildSearchBar (+18 more)

### Community 20 - "Linux GTK Native"
Cohesion: 0.07
Nodes (25): _buildHeader, _buildServiceTable, _buildSummary, generateServiceHistoryPdf, PdfGenerator, build, _buildEmptyState, _buildFilterTab (+17 more)

### Community 21 - "Auth Screen UI"
Cohesion: 0.08
Nodes (26): _abrirSelectorMapa, _buildCoordinatesPicker, _buildDropdownField, _buildInputField, _buildTopBar, createState, dispose, _elSalvadorDivipola (+18 more)

### Community 22 - "Vehicle Image Widget"
Cohesion: 0.08
Nodes (25): ../../data/models/conversacion_model.dart, ../../data/models/cotizacion_model.dart, ../../data/repositories/chat_repository.dart, int get, actualizarEstadoCotizacion, actualizarMetadatosMensaje, _chatRepository, _conversaciones (+17 more)

### Community 23 - "Workshop Map View"
Cohesion: 0.09
Nodes (24): didChangeDependencies, GarageScreen, _submitCompletion, AlertProvider, build, _buildAlertsList, _buildInvoicePicker, _buildKmInput (+16 more)

### Community 24 - "Workshop Form & Picker"
Cohesion: 0.08
Nodes (24): _activeTab, build, _buildShowcaseContent, color, CommandCenterSection, _CommandCenterSectionState, CommandCenterTab, createState (+16 more)

### Community 25 - "Next.js App Shell"
Cohesion: 0.10
Nodes (7): geistMono, geistSans, metadata, ThemeProvider(), Header(), {Link, redirect, usePathname, useRouter, getPathname}, routing

### Community 26 - "Landing Command Center"
Cohesion: 0.11
Nodes (23): build, build, build, _buildActiveAlerts, _buildAlertCard, _buildEmptyVehicleState, _buildHeader, _buildMaintenanceSemaphore (+15 more)

### Community 27 - "Firebase Cloud Functions"
Cohesion: 0.10
Nodes (20): ../../helpers/test_helpers.mocks.dart, package:autodoc/core/models/vehicle_model.dart, package:autodoc/features/auth/presentation/providers/auth_provider.dart, package:autodoc/features/dashboard/presentation/providers/alert_provider.dart, package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart, package:mockito/mockito.dart, authProvider, main (+12 more)

### Community 28 - "Animated Counter Widget"
Cohesion: 0.09
Nodes (21): _buildMessageContent, _controller, conversacionId, createState, _isTyping, _scrollController, _typingTimer, package:autodoc/features/chat/data/models/cotizacion_model.dart (+13 more)

### Community 29 - "Chat Provider & Models"
Cohesion: 0.10
Nodes (20): Animation, AnimationController, Duration, AnimatedCounter, _AnimatedCounterState, _animation, build, _controller (+12 more)

### Community 30 - "Chat Repository"
Cohesion: 0.12
Nodes (20): ChangeNotifier, AdminDashboardScreen, _AdminDashboardScreenState, build, _buildActionChip, _buildMetricsGrid, _buildQuickActions, _buildRecentActivity (+12 more)

### Community 31 - "Vehicle Profile Screen"
Cohesion: 0.10
Nodes (19): Color, AppButton, AppButtonSize, AppButtonType, build, _handlePress, hapticFeedback, icon (+11 more)

### Community 32 - "Main Screen Routes"
Cohesion: 0.10
Nodes (20): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, @google-cloud/functions-framework, description, engines (+12 more)

### Community 33 - "Service Task UI"
Cohesion: 0.10
Nodes (21): _i1.SmartFake, _i2.FirebaseApp, _i3.AggregateQuery, _i3.DocumentReference, _i3.LoadBundleTask, _i3.PipelineSource, _i3.Settings, _i3.SnapshotMetadata (+13 more)

### Community 34 - "User Model"
Cohesion: 0.10
Nodes (19): copyWith, correo, departamento, especialidad, estado, fcmToken, fechaRegistro, fotoPerfilUrl (+11 more)

### Community 35 - "Review Sheet Widget"
Cohesion: 0.11
Nodes (19): _alreadyReviewed, build, _checkExisting, _checking, _comentarioController, createState, dispose, _estrellas (+11 more)

### Community 36 - "Reservation Model"
Cohesion: 0.10
Nodes (19): _adminAuthService, _authService, clearError, deleteAccount, _error, _isLoading, refreshEmailVerificationStatus, register (+11 more)

### Community 37 - "Vehicle Provider Logic"
Cohesion: 0.10
Nodes (19): activeAlerts, _addOrUpdateLocalAlert, _alerts, completeAlert, createDefaultTasks, _defaultTasks, _error, fetchAlerts (+11 more)

### Community 38 - "Chat Background Pattern"
Cohesion: 0.11
Nodes (17): ../../../../core/models/workshop_model.dart, AppTopNavBar, icon, isActive, onTap, title, _TopNavLink, build (+9 more)

### Community 39 - "Auth Service"
Cohesion: 0.11
Nodes (18): GoogleSignIn, _auth, AuthService, deleteAccount, _googleSignIn, _handleAuthException, isCurrentUserEmailVerified, registerWithEmail (+10 more)

### Community 40 - "Top Nav & User Row"
Cohesion: 0.11
Nodes (19): _i10.VehicleService, _i12.VehicleImageService, _i14.UserService, _i1.Mock, _i3.FirebaseFirestore, _i3.Query, _i5.FirebaseStorage, _i6.AuthService (+11 more)

### Community 41 - "Admin User Management"
Cohesion: 0.15
Nodes (14): main, main, main, build, ImagenChatCard, isMe, urlArchivo, package:autodoc/core/theme/app_theme.dart (+6 more)

### Community 42 - "Text Styles"
Cohesion: 0.11
Nodes (18): _authPreferences, currentUid, _error, fetchUserData, _isAdminSession, _isLoading, loadRememberMe, loadSavedEmail (+10 more)

### Community 43 - "Empty State Widget"
Cohesion: 0.11
Nodes (18): cotizacionEstimada, descripcion, estado, fechaCreacion, fechaHoraConfirmada, fechaHoraPropuesta, fromMap, id (+10 more)

### Community 44 - "Text Field Widget"
Cohesion: 0.11
Nodes (17): ../../../../core/services/vehicle_image_service.dart, ../../data/services/vehicle_service.dart, addVehicle, deleteVehicle, _demoteCurrentPrimary, fetchVehicles, findVehicleByPlate, _imageService (+9 more)

### Community 45 - "Admin Service Methods"
Cohesion: 0.11
Nodes (16): CustomPainter, dart:math, build, ChatBackgroundPattern, _ChatPatternPainter, color, paint, shouldRepaint (+8 more)

### Community 46 - "Alert Provider Logic"
Cohesion: 0.11
Nodes (17): anio, color, copyWith, fotoUrl, fromMap, idPropietario, idVehiculo, isPrimary (+9 more)

### Community 47 - "Admin Repository"
Cohesion: 0.11
Nodes (17): AppTextStyles, bodyLarge, bodyMedium, bodySmall, displayLarge, displayMedium, displaySmall, headlineLarge (+9 more)

### Community 48 - "Vehicle Model"
Cohesion: 0.11
Nodes (17): AppTextField, build, controller, hintText, inputFormatters, keyboardType, label, maxLines (+9 more)

### Community 49 - "Notification Service"
Cohesion: 0.18
Nodes (14): Point, Size, wchar_t, Scale(), Create, Destroy, UpdateTheme, Win32Window::Win32Window() (+6 more)

### Community 50 - "App Entry Point (main)"
Cohesion: 0.12
Nodes (15): ../constants/firestore_collections.dart, dart:convert, baseUrl, fetchAllMakes, fetchModelsByMake, VehicleApiService, _apiKey, _baseUrl (+7 more)

### Community 51 - "Status Badge Widget"
Cohesion: 0.12
Nodes (16): dart:ui, build, _buildFeatureItem, _contents, createState, _currentPage, description, features (+8 more)

### Community 52 - "Reservation Provider"
Cohesion: 0.12
Nodes (16): VehicleModel, _addUser, build, createState, dispose, _emailController, _firestore, initState (+8 more)

### Community 53 - "Alert Model"
Cohesion: 0.12
Nodes (16): aprobarTaller, cambiarRolUsuario, eliminarResenia, fetchDashboardMetrics, fetchLogs, fetchResenias, fetchTalleres, fetchUsuarios (+8 more)

### Community 54 - "Conversation Model"
Cohesion: 0.12
Nodes (16): ConversacionModel, estado, fromMap, id, idMecanico, idPropietario, idTaller, idVehiculo (+8 more)

### Community 55 - "Vehicle Search Screen"
Cohesion: 0.12
Nodes (16): actualizarEstadoCotizacion, actualizarMetadatosMensaje, buscarConversacion, ChatRepository, crearConversacion, crearCotizacion, deleteMensaje, enviarMensaje (+8 more)

### Community 56 - "Service Record Model"
Cohesion: 0.12
Nodes (16): AlertsScreen, _AlertsScreenState, build, _buildAlertCard, _buildCompactActionButton, _buildContent, _buildHeader, _buildMileageChip (+8 more)

### Community 57 - "Maintenance Config UI"
Cohesion: 0.12
Nodes (15): AndroidFlutterLocalNotificationsPlugin, FirebaseMessaging, _firebaseMessaging, initialize, _instance, _isInitialized, _localNotifications, NotificationService (+7 more)

### Community 58 - "Maintenance Task Model"
Cohesion: 0.12
Nodes (15): cloud_firestore, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, firebase_storage, flutter_local_notifications, Foundation (+7 more)

### Community 59 - "Bottom Nav & Chat Cards"
Cohesion: 0.12
Nodes (15): ../../../../core/models/admin_log_model.dart, AdminRepository, countCollection, deleteResenia, deleteTaller, deleteUsuario, _firestore, getLogs (+7 more)

### Community 60 - "Translation Service"
Cohesion: 0.13
Nodes (14): ../../data/models/mensaje_model.dart, AppColors, AuthBottomNav, build, _buildNavAction, colors, isDark, MensajeModel (+6 more)

### Community 61 - "Firebase Plugins"
Cohesion: 0.12
Nodes (15): FirebaseStorage, addPhoto, deletePhoto, _firestore, fromMap, id, _storage, streamPhotos (+7 more)

### Community 62 - "App Button Widget"
Cohesion: 0.12
Nodes (14): IconData, action, AppEmptyState, build, description, icon, lottieAsset, title (+6 more)

### Community 63 - "iOS Plugin Registry"
Cohesion: 0.12
Nodes (15): AlertModel, AlertPriority, copyWith, descripcion, estado, fechaLimite, fromMap, idAlerta (+7 more)

### Community 64 - "Admin Log Model"
Cohesion: 0.14
Nodes (15): LanguageProvider, build, maxLines, overflow, style, text, textAlign, TranslatedText (+7 more)

### Community 65 - "Windows Console Setup"
Cohesion: 0.14
Nodes (13): AppSnackbar, show, SnackbarType, build, ServicesTrendChart, serviciosPorMes, build, _buildMetricColumn (+5 more)

### Community 66 - "Workshop Model"
Cohesion: 0.13
Nodes (15): build, _buildInputCard, _costController, createState, currentKm, dispose, _infoItem, _isLoading (+7 more)

### Community 67 - "Main Scaffold & Nav"
Cohesion: 0.14
Nodes (15): build, _buildAssistantCard, _buildRecentItem, _buildRecentSearches, _buildSearchCard, _buildTopBar, createState, _formatPlate (+7 more)

### Community 68 - "Auth Preferences Service"
Cohesion: 0.13
Nodes (13): unique_ptr, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM, FlutterWindow (+5 more)

### Community 69 - "Auth Routes & Redirect"
Cohesion: 0.13
Nodes (14): ../../../../core/models/vehicle_model.dart, addNote, addVehicle, _collection, deleteVehicle, _firestore, getExpenseSummary, getLastVisitedWorkshop (+6 more)

### Community 70 - "Message Model"
Cohesion: 0.13
Nodes (14): dart:async, ../../data/models/reserva_model.dart, ../../data/repositories/reserva_repository.dart, cambiarEstadoReserva, dispose, _error, inicializarReservasUsuario, _isLoading (+6 more)

### Community 71 - "Review Service"
Cohesion: 0.13
Nodes (14): int?, copyWith, costo, descripcion, fecha, fotoFacturaUrl, fromMap, idServicio (+6 more)

### Community 72 - "User Service"
Cohesion: 0.14
Nodes (14): build, createState, dispose, initState, _isLoading, _kmController, _monthsController, _presetChip (+6 more)

### Community 73 - "Vehicle Service (Data)"
Cohesion: 0.14
Nodes (13): @pragma, _firebaseMessagingBackgroundHandler, initializeApp, main, package:autodoc/core/router/app_router.dart, package:autodoc/core/services/notification_service.dart, package:autodoc/features/admin/presentation/providers/admin_dashboard_provider.dart, package:autodoc/features/admin/presentation/providers/admin_provider.dart (+5 more)

### Community 74 - "Admin Auth Service"
Cohesion: 0.14
Nodes (13): adminLogs, alertas, conversaciones, FirestoreCollections, historialMantenimientos, mantenimientos, mensajes, resenias (+5 more)

### Community 75 - "Review Model"
Cohesion: 0.14
Nodes (13): fechaUltimoServicio, frecuenciaKm, frecuenciaMeses, fromMap, getStatus, getStatusLabel, id, MaintenanceStatus (+5 more)

### Community 76 - "App Transitions"
Cohesion: 0.15
Nodes (12): AuthBackgroundBlobs, build, colors, isDark, build, _controller, createState, dispose (+4 more)

### Community 77 - "Translated Text Widget"
Cohesion: 0.16
Nodes (13): build, dispose, _enviarMensaje, initState, _mostrarMenuAdjuntos, _pickAndSendImage, ChatProvider, build (+5 more)

### Community 78 - "Availability Picker"
Cohesion: 0.20
Nodes (14): RECT, OnCreate, OnDestroy, HWND, Win32Window, child_content_, GetClientArea, OnCreate (+6 more)

### Community 79 - "Web App Manifest"
Cohesion: 0.15
Nodes (12): Box, _apiKey, _baseUrl, initialize, _instance, isInitialized, translate, translateSync (+4 more)

### Community 80 - "Workshop Admin Card"
Cohesion: 0.17
Nodes (12): File?, _buildRoleCard, createState, dispose, _imageFile, _isLoading, _nameController, _notificationsEnabled (+4 more)

### Community 81 - "App Card Widget"
Cohesion: 0.15
Nodes (12): CotizacionModel, descripcion, estado, fecha, fromMap, id, idMecanico, idPropietario (+4 more)

### Community 82 - "Mechanic Admin Card"
Cohesion: 0.15
Nodes (12): _buildVehicleCard, build, _buildEmptyState, _buildHeader, _buildVehicleCard, _setVehicleAsPrimary, _showAddVehicleDialog, package:autodoc/core/widgets/app_scaffold.dart (+4 more)

### Community 83 - "Admin Dashboard Provider"
Cohesion: 0.21
Nodes (7): GeneratedPluginRegistrant, FlutterEngine, FlutterLocalNotificationsPlugin, GeneratedPluginRegistrant, +registerWithRegistry, Keep, NSObject

### Community 84 - "Vehicle Image Service"
Cohesion: 0.17
Nodes (11): CollectionReference, ../../../../core/constants/firestore_collections.dart, ../../../../core/models/review_model.dart, _firestore, getReviewsForTaller, hasUserReviewedTaller, recalculateTallerRating, _resenias (+3 more)

### Community 85 - "Skeleton Loader Widget"
Cohesion: 0.17
Nodes (11): DateTime?, comentario, copyWith, estrellas, fechaResenia, fromMap, idResenia, idTaller (+3 more)

### Community 86 - "iOS Scene Setup"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 87 - "Theme Provider"
Cohesion: 0.17
Nodes (11): calificacionPromedio, copyWith, especialidad, estado, fromMap, idTaller, nombre, telefono (+3 more)

### Community 88 - "App Shadows"
Cohesion: 0.17
Nodes (11): activeIcon, child, colors, icon, InstagramBottomNavBar, isActive, isDark, MainScaffold (+3 more)

### Community 89 - "Firebase Options Config"
Cohesion: 0.17
Nodes (11): AuthPreferencesService, clearSavedCredentials, getRememberMe, getSavedEmail, isOnboardingCompleted, _keyOnboardingCompleted, _keyRememberMe, _keySavedEmail (+3 more)

### Community 90 - "iOS App Delegate"
Cohesion: 0.23
Nodes (12): AuthScreen, _AuthScreenState, ChatScreen, _ChatScreenState, VehicleProfileScreen, _VehicleProfileScreenState, WorkshopDirectoryScreen, _WorkshopDirectoryScreenState (+4 more)

### Community 91 - "NHTSA Car Models"
Cohesion: 0.17
Nodes (11): contenido, estado, fromMap, id, idRemitente, isDeleted, metadata, timestamp (+3 more)

### Community 92 - "Language Provider"
Cohesion: 0.18
Nodes (11): build, _buildEmptyState, ConversacionesListScreen, _ConversacionesListScreenState, createState, fallbackName, initState, style (+3 more)

### Community 93 - "Vehicle API Service"
Cohesion: 0.17
Nodes (11): addFavoriteWorkshop, _collection, createUserData, _firestore, getUserData, removeFavoriteWorkshop, updateUserData, uploadProfilePhoto (+3 more)

### Community 94 - "Dashboard Quick Actions"
Cohesion: 0.18
Nodes (11): AboutScreen, _AboutScreenState, build, _buildNumber, createState, _initPackageInfo, initState, _launchUrl (+3 more)

### Community 95 - "Landing Screen"
Cohesion: 0.18
Nodes (10): FirebaseAuth, AdminAuthService, _auth, _firestore, getAdminByUid, isAdmin, loginAsAdmin, _resolveUsernameToEmail (+2 more)

### Community 96 - "macOS Test Config"
Cohesion: 0.20
Nodes (10): FormState, build, CotizacionPicker, _CotizacionPickerState, createState, _descController, dispose, _formKey (+2 more)

### Community 97 - "macOS App Delegate"
Cohesion: 0.18
Nodes (10): accion, AdminLogModel, adminUid, detalle, fecha, fromMap, idLog, modulo (+2 more)

### Community 98 - "macOS Window Setup"
Cohesion: 0.18
Nodes (10): accelerate, AppTransitions, decelerate, defaultCurve, fast, medium, slow, package:flutter/animation.dart (+2 more)

### Community 99 - "LLDB Debug Scripts"
Cohesion: 0.20
Nodes (10): _availableTimes, build, createState, DisponibilidadPicker, _DisponibilidadPickerState, _focusedDay, initState, _selectedDay (+2 more)

### Community 100 - "Language Root Widget"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 101 - "Role Utilities"
Cohesion: 0.20
Nodes (9): BoxFit, build, _buildPlaceholder, fit, height, imageUrl, VehicleImageWidget, width (+1 more)

### Community 102 - "Skeleton Layouts"
Cohesion: 0.20
Nodes (9): ../../../../core/models/user_model.dart, UserModel, AccountRow, build, isCurrentAdmin, onCambiarRol, onReactivar, onSuspender (+1 more)

### Community 103 - "Localizations Delegates"
Cohesion: 0.20
Nodes (9): dart:io, ../../data/services/vehicle_photo_service.dart, VehiclePhotoModel, colors, foto, FullScreenImageViewer, VehicleGalleryWidget, vehicleId (+1 more)

### Community 104 - "Community 104"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 105 - "Community 105"
Cohesion: 0.22
Nodes (8): bool get, ../../data/services/admin_service.dart, AdminService, _adminService, _error, fetchMetrics, _isLoading, _metrics

### Community 106 - "Community 106"
Cohesion: 0.22
Nodes (8): double?, AppSkeleton, borderRadius, build, card, height, width, package:shimmer/shimmer.dart

### Community 107 - "Community 107"
Cohesion: 0.22
Nodes (8): FirebaseFirestore, actualizarEstadoReserva, crearReserva, _firestore, getReserva, ReservaRepository, streamReservasUsuario, ../models/reserva_model.dart

### Community 108 - "Community 108"
Cohesion: 0.28
Nodes (6): Flutter, FlutterSceneDelegate, GoogleMaps, SceneDelegate, UIKit, XCTest

### Community 109 - "Community 109"
Cohesion: 0.22
Nodes (8): _loadTheme, setThemeMode, _themeKey, _themeMode, toggleTheme, package:shared_preferences/shared_preferences.dart, ThemeMode, ThemeMode get

### Community 110 - "Community 110"
Cohesion: 0.22
Nodes (8): AppShadows, darkLg, darkMd, darkSm, lightLg, lightMd, lightSm, static List

### Community 111 - "Community 111"
Cohesion: 0.22
Nodes (8): build, calificacionPromedio, _chip, _info, MecanicoAdminCard, totalResenias, usuario, package:autodoc/core/models/user_model.dart

### Community 112 - "Community 112"
Cohesion: 0.22
Nodes (8): build, conversacionId, isMe, mensajeId, metadata, ReviewChatCard, tallerId, package:autodoc/core/widgets/review_sheet.dart

### Community 113 - "Community 113"
Cohesion: 0.22
Nodes (8): _firestore, getWorkshopById, getWorkshops, getWorkshopsStream, updateWorkshopProfile, WorkshopService, package:autodoc/core/constants/firestore_collections.dart, package:autodoc/core/utils/role_utils.dart

### Community 114 - "Community 114"
Cohesion: 0.22
Nodes (8): android, DefaultFirebaseOptions, ios, web, package:autodoc/config/secrets.dart, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 115 - "Community 115"
Cohesion: 0.25
Nodes (7): @GenerateMocks, package:autodoc/core/services/vehicle_image_service.dart, package:autodoc/features/dashboard/data/services/vehicle_service.dart, package:autodoc/features/profile/data/services/user_service.dart, package:cloud_firestore/cloud_firestore.dart, package:mockito/annotations.dart, main

### Community 116 - "Community 116"
Cohesion: 0.25
Nodes (6): Any, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, UIApplication

### Community 117 - "Community 117"
Cohesion: 0.25
Nodes (7): CarMake, CarModel, fromJson, makeId, makeName, modelId, modelName

### Community 118 - "Community 118"
Cohesion: 0.25
Nodes (7): changeLanguage, currentLanguageCode, _currentLocale, _loadLocale, Locale, Locale get, String get

### Community 119 - "Community 119"
Cohesion: 0.25
Nodes (7): build, conversacionId, CotizacionChatCard, isMe, mensajeId, metadata, package:autodoc/features/chat/presentation/providers/chat_provider.dart

### Community 120 - "Community 120"
Cohesion: 0.25
Nodes (7): build, LandingScreen, ../widgets/command_center_section.dart, ../widgets/hero_section.dart, ../widgets/landing_footer.dart, ../widgets/landing_header.dart, ../widgets/value_prop_section.dart

### Community 121 - "Community 121"
Cohesion: 0.38
Nodes (3): Cocoa, FlutterMacOS, RunnerTests

### Community 122 - "Community 122"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 123 - "Community 123"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 124 - "Community 124"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 125 - "Community 125"
Cohesion: 0.33
Nodes (5): isMechanicRole, mechanicFirestoreRoles, normalized, List, return

### Community 126 - "Community 126"
Cohesion: 0.33
Nodes (5): AppSkeletonLayouts, dashboard, listCards, workshopList, package:autodoc/core/widgets/app_skeleton.dart

### Community 127 - "Community 127"
Cohesion: 0.33
Nodes (5): build, isMe, metadata, VehiculoChatCard, Map

### Community 128 - "Community 128"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsEs, of, LocalizationsDelegate

### Community 129 - "Community 129"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 130 - "Community 130"
Cohesion: 0.40
Nodes (4): admin, db, functions, messaging

### Community 131 - "Community 131"
Cohesion: 0.40
Nodes (4): facturas, perfiles, StoragePaths, static const String

### Community 132 - "Community 132"
Cohesion: 0.40
Nodes (4): formatEditUpdate, PlateFormatter, package:flutter/services.dart, TextInputFormatter

### Community 133 - "Community 133"
Cohesion: 0.50
Nodes (3): AppLocalizations get, l10n, package:autodoc/l10n/app_localizations.dart

### Community 136 - "Community 136"
Cohesion: 0.67
Nodes (3): BuildContext, AppColorsExtension, L10nExtension

### Community 137 - "Community 137"
Cohesion: 0.67
Nodes (3): _i3.CollectionReference, _FakeCollectionReference_2, MockCollectionReference

### Community 138 - "Community 138"
Cohesion: 0.67
Nodes (3): _i3.QuerySnapshot, _FakeQuerySnapshot_5, MockQuerySnapshot

## Knowledge Gaps
- **2080 isolated node(s):** `functions`, `admin`, `db`, `messaging`, `name` (+2075 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UserSessionProvider` connect `Vehicle Registration Form` to `Alerts & Vehicles Screen`, `Landing Web (Next.js)`, `Snackbar & UI Feedback`, `Service Initiation Screen`, `Admin Provider Logic`, `Auth Screen UI`, `Workshop Map View`, `Landing Command Center`, `Animated Counter Widget`, `Chat Repository`, `Review Sheet Widget`, `Chat Background Pattern`, `Text Styles`, `App Transitions`, `Translated Text Widget`, `Workshop Admin Card`, `Mechanic Admin Card`, `App Shadows`, `iOS App Delegate`, `Language Provider`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `_FakeFirebaseApp_0` connect `Service Task UI` to `Windows Desktop Native`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `functions`, `admin`, `db` to the rest of the system?**
  _2080 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Localization & i18n` be split into smaller, more focused modules?**
  _Cohesion score 0.007722007722007722 - nodes in this community are weakly interconnected._
- **Should `App Localizations EN` be split into smaller, more focused modules?**
  _Cohesion score 0.008097165991902834 - nodes in this community are weakly interconnected._
- **Should `App Localizations ES` be split into smaller, more focused modules?**
  _Cohesion score 0.008130081300813009 - nodes in this community are weakly interconnected._
- **Should `Windows Desktop Native` be split into smaller, more focused modules?**
  _Cohesion score 0.022727272727272728 - nodes in this community are weakly interconnected._