# Graph Report - .  (2026-07-15)

## Corpus Check
- Large corpus: 301 files · ~1,081,089 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 3386 nodes · 4641 edges · 150 communities (139 shown, 11 thin omitted)
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
- Community 139
- Community 140
- Community 147

## God Nodes (most connected - your core abstractions)
1. `UserSessionProvider` - 86 edges
2. `AlertProvider` - 28 edges
3. `VehicleProvider` - 28 edges
4. `ChatProvider` - 25 edges
5. `AdminProvider` - 24 edges
6. `AuthProvider` - 22 edges
7. `Win32Window` - 22 edges
8. `compilerOptions` - 16 edges
9. `ThemeProvider` - 14 edges
10. `MessageHandler` - 12 edges

## Surprising Connections (you probably didn't know these)
- `_loadRememberMePreferences` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/core/providers/user_session_provider.dart
- `_persistRememberMe` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/auth/presentation/pages/auth_screen.dart → lib/core/providers/user_session_provider.dart
- `build` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/chat/presentation/pages/reserva_detail_screen.dart → lib/core/providers/user_session_provider.dart
- `build` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/dashboard/presentation/pages/workshop_directory_screen.dart → lib/core/providers/user_session_provider.dart
- `build` --references--> `UserSessionProvider`  [EXTRACTED]
  lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart → lib/core/providers/user_session_provider.dart

## Import Cycles
- None detected.

## Communities (150 total, 11 thin omitted)

### Community 0 - "Localization & i18n"
Cohesion: 0.01
Nodes (347): app_localizations_en.dart, app_localizations_es.dart, class, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint (+339 more)

### Community 1 - "App Localizations EN"
Cohesion: 0.01
Nodes (335): app_localizations.dart, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle (+327 more)

### Community 2 - "App Localizations ES"
Cohesion: 0.01
Nodes (334): addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle, addVehicleDocs (+326 more)

### Community 3 - "Windows Desktop Native"
Cohesion: 0.02
Nodes (87): dart:typed_data, Duration get, FirebaseApp get, FirebaseFirestore get, package:mockito/src/dummies.dart, R, Settings get, SnapshotMetadata get (+79 more)

### Community 4 - "Admin Dashboard UI"
Cohesion: 0.04
Nodes (72): AlertsScreen, _AlertsScreenState, build, _buildAlertCard, _buildCompactActionButton, _buildContent, _buildHeader, _buildMileageChip (+64 more)

### Community 5 - "Alerts & Vehicles Screen"
Cohesion: 0.04
Nodes (49): app_colors.dart, app_radius.dart, app_text_styles.dart, DateTimeRange?, DocumentSnapshot, AppTheme, _buildTextTheme, build (+41 more)

### Community 6 - "Theme Color System"
Cohesion: 0.04
Nodes (50): AppColors get, AppPalette, copyWith, darkError, darkOnPrimary, darkOnSecondary, darkOutline, darkPrimary (+42 more)

### Community 7 - "Auth & Navigation Core"
Cohesion: 0.04
Nodes (44): ../../../../core/models/nhtsa_models.dart, ../../../../core/services/vehicle_api_service.dart, ../../../../core/theme/app_colors.dart, ../../../../core/utils/plate_formatter.dart, _allMakes, _anioController, _apiService, _brandSearchQuery (+36 more)

### Community 8 - "Vehicle Registration Form"
Cohesion: 0.06
Nodes (40): AdminSidebar, build, _buildDrawerItem, AuthScreen, _AuthScreenState, build, _buildGlassCard, _buildGoogleButton (+32 more)

### Community 9 - "Landing Web (Next.js)"
Cohesion: 0.05
Nodes (40): eslint, eslint-config-next, framer-motion, dependencies, framer-motion, lucide-react, next, next-intl (+32 more)

### Community 10 - "App Router & Theme"
Cohesion: 0.05
Nodes (36): adminLogs, alertas, conversaciones, FirestoreCollections, historialMantenimientos, mantenimientos, mensajes, resenias (+28 more)

### Community 11 - "Chat Messaging Screen"
Cohesion: 0.05
Nodes (35): AppRadius, full, lg, md, sm, xl, xs, xxl (+27 more)

### Community 12 - "UI Radius & Spacing"
Cohesion: 0.07
Nodes (34): ChangeNotifier, ThemeProvider, _abrirSelectorMapa, build, _buildCoordinatesPicker, _buildDropdownField, _buildInputField, _buildTopBar (+26 more)

### Community 13 - "Snackbar & UI Feedback"
Cohesion: 0.06
Nodes (33): GoRouter, appRouter, package:autodoc/core/widgets/main_scaffold.dart, package:autodoc/features/admin/presentation/pages/admin_dashboard_screen.dart, package:autodoc/features/admin/presentation/pages/admin_logs_screen.dart, package:autodoc/features/admin/presentation/pages/admin_resenias_screen.dart, package:autodoc/features/admin/presentation/pages/admin_seed_screen.dart, package:autodoc/features/admin/presentation/pages/admin_talleres_screen.dart (+25 more)

### Community 14 - "Landing Page Widgets"
Cohesion: 0.06
Nodes (30): VehicleModel, build, userId, VehiculoPicker, _buildAlertsList, _buildCostoInput, _buildInvoicePicker, _buildKmInput (+22 more)

### Community 15 - "Admin Users Screen"
Cohesion: 0.06
Nodes (30): AppShadows, darkLg, darkMd, darkSm, lightLg, lightMd, lightSm, AppTextStyles (+22 more)

### Community 16 - "Auth Provider & Admin Auth"
Cohesion: 0.08
Nodes (28): AdminSeedScreen, build, _GlassTag, _ShowcaseImage, _SyncNode, _TabCard, _TimelineItem, build (+20 more)

### Community 17 - "Service Initiation Screen"
Cohesion: 0.06
Nodes (30): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+22 more)

### Community 18 - "TypeScript Config"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/role_utils.dart, _adminService, aprobarTaller, cambiarRolUsuario, clearMessages, eliminarResenia, _error, fetchAllData (+20 more)

### Community 19 - "Admin Provider Logic"
Cohesion: 0.07
Nodes (27): GoogleMapController?, build, _buildFilterChip, _buildFilters, _buildHeader, _buildMapCard, _buildMapView, _buildSearchBar (+19 more)

### Community 20 - "Linux GTK Native"
Cohesion: 0.09
Nodes (26): ReviewModel, UserSessionProvider, build, _checkExisting, _checking, _comentarioController, createState, dispose (+18 more)

### Community 21 - "Auth Screen UI"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 22 - "Vehicle Image Widget"
Cohesion: 0.08
Nodes (24): BoxFit, dart:ui, build, _buildPlaceholder, fit, height, imageUrl, VehicleImageWidget (+16 more)

### Community 23 - "Workshop Map View"
Cohesion: 0.08
Nodes (25): ../../data/models/conversacion_model.dart, ../../data/models/cotizacion_model.dart, ../../data/repositories/chat_repository.dart, int get, actualizarEstadoCotizacion, actualizarMetadatosMensaje, _chatRepository, _conversaciones (+17 more)

### Community 24 - "Workshop Form & Picker"
Cohesion: 0.09
Nodes (7): geistMono, geistSans, metadata, ThemeProvider(), Header(), {Link, redirect, usePathname, useRouter, getPathname}, routing

### Community 25 - "Next.js App Shell"
Cohesion: 0.08
Nodes (24): build, _scanQR, _buildActionOption, _buildAppBar, _buildInfoField, _buildInfoSection, _buildProfileHeader, _buildSettingsSection (+16 more)

### Community 26 - "Landing Command Center"
Cohesion: 0.09
Nodes (23): Duration, _i1.SmartFake, _i2.FirebaseApp, _i3.AggregateQuery, _i3.DocumentReference, _i3.LoadBundleTask, _i3.PipelineSource, _i3.Settings (+15 more)

### Community 27 - "Firebase Cloud Functions"
Cohesion: 0.09
Nodes (21): ../../helpers/test_helpers.mocks.dart, _i3.Query, _i5.FirebaseStorage, _i6.AuthService, package:autodoc/features/auth/presentation/providers/auth_provider.dart, package:autodoc/features/dashboard/presentation/providers/alert_provider.dart, package:mockito/mockito.dart, authProvider (+13 more)

### Community 28 - "Animated Counter Widget"
Cohesion: 0.09
Nodes (20): IconData, action, AppEmptyState, build, description, icon, lottieAsset, title (+12 more)

### Community 29 - "Chat Provider & Models"
Cohesion: 0.10
Nodes (19): AppColors, AppSnackbar, show, SnackbarType, AuthBackgroundBlobs, build, colors, isDark (+11 more)

### Community 30 - "Chat Repository"
Cohesion: 0.09
Nodes (22): _activeTab, build, _buildShowcaseContent, color, CommandCenterSection, _CommandCenterSectionState, CommandCenterTab, createState (+14 more)

### Community 31 - "Vehicle Profile Screen"
Cohesion: 0.09
Nodes (21): _buildMessageContent, _controller, conversacionId, createState, _isTyping, _scrollController, _typingTimer, package:autodoc/features/chat/data/models/cotizacion_model.dart (+13 more)

### Community 32 - "Main Screen Routes"
Cohesion: 0.12
Nodes (20): build, dispose, _enviarMensaje, initState, _pickAndSendImage, build, _buildEmptyState, ConversacionesListScreen (+12 more)

### Community 33 - "Service Task UI"
Cohesion: 0.10
Nodes (20): build, LandingHeader, _NavLink, title, build, _buildAssistantCard, _buildRecentItem, _buildRecentSearches (+12 more)

### Community 34 - "User Model"
Cohesion: 0.10
Nodes (20): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, @google-cloud/functions-framework, description, engines (+12 more)

### Community 35 - "Review Sheet Widget"
Cohesion: 0.10
Nodes (18): AppTopNavBar, icon, isActive, onTap, title, _TopNavLink, build, isMe (+10 more)

### Community 36 - "Reservation Model"
Cohesion: 0.13
Nodes (19): ReservaModel, _mostrarMenuAdjuntos, build, _cambiarEstado, createState, _isLoading, reserva, ReservaDetailScreen (+11 more)

### Community 37 - "Vehicle Provider Logic"
Cohesion: 0.10
Nodes (20): _buildActionButton, _buildDetailItem, _buildDocumentationStatus, _buildDocumentationStatusItem, _buildExpenseSummary, _buildHeader, _buildHeroImage, _buildStatusAlert (+12 more)

### Community 38 - "Chat Background Pattern"
Cohesion: 0.10
Nodes (18): ../../../../core/models/user_model.dart, EdgeInsetsGeometry, AppCard, build, child, margin, onTap, padding (+10 more)

### Community 39 - "Auth Service"
Cohesion: 0.10
Nodes (19): copyWith, correo, departamento, especialidad, estado, fcmToken, fechaRegistro, fotoPerfilUrl (+11 more)

### Community 40 - "Top Nav & User Row"
Cohesion: 0.10
Nodes (19): activeAlerts, _addOrUpdateLocalAlert, _alerts, completeAlert, createDefaultTasks, _defaultTasks, _error, fetchAlerts (+11 more)

### Community 41 - "Admin User Management"
Cohesion: 0.11
Nodes (18): Animation, AnimationController, AnimatedCounter, _AnimatedCounterState, _animation, build, _controller, createState (+10 more)

### Community 42 - "Text Styles"
Cohesion: 0.11
Nodes (17): dart:async, ../../data/models/reserva_model.dart, ../../data/repositories/reserva_repository.dart, isMechanicRole, mechanicFirestoreRoles, normalized, cambiarEstadoReserva, dispose (+9 more)

### Community 43 - "Empty State Widget"
Cohesion: 0.11
Nodes (18): GoogleSignIn, _auth, AuthService, deleteAccount, _googleSignIn, _handleAuthException, isCurrentUserEmailVerified, registerWithEmail (+10 more)

### Community 44 - "Text Field Widget"
Cohesion: 0.11
Nodes (18): AdminLogModel, AdminRepository, package:autodoc/core/models/admin_log_model.dart, package:autodoc/features/admin/data/repositories/admin_repository.dart, package:autodoc/features/admin/data/services/admin_service.dart, adminService, FakeAdminRepository, fakeRepository (+10 more)

### Community 45 - "Admin Service Methods"
Cohesion: 0.11
Nodes (18): _authPreferences, currentUid, _error, fetchUserData, _isAdminSession, _isLoading, loadRememberMe, loadSavedEmail (+10 more)

### Community 46 - "Alert Provider Logic"
Cohesion: 0.11
Nodes (16): AppBottomNavBar, build, currentIndex, appBar, AppScaffold, body, bottomNavigationBar, build (+8 more)

### Community 47 - "Admin Repository"
Cohesion: 0.11
Nodes (18): AppTextField, build, controller, hintText, inputFormatters, keyboardType, label, maxLines (+10 more)

### Community 48 - "Vehicle Model"
Cohesion: 0.11
Nodes (18): _adminAuthService, _authService, clearError, deleteAccount, _error, isEmailPasswordUser, _isLoading, refreshEmailVerificationStatus (+10 more)

### Community 49 - "Notification Service"
Cohesion: 0.11
Nodes (17): ../../../../core/services/vehicle_image_service.dart, ../../data/services/vehicle_service.dart, addVehicle, deleteVehicle, _demoteCurrentPrimary, fetchVehicles, findVehicleByPlate, _imageService (+9 more)

### Community 50 - "App Entry Point (main)"
Cohesion: 0.11
Nodes (18): _i10.VehicleService, _i12.VehicleImageService, _i14.UserService, _i1.Mock, _i3.CollectionReference, _i3.FirebaseFirestore, _i3.QuerySnapshot, _i8.AdminAuthService (+10 more)

### Community 51 - "Status Badge Widget"
Cohesion: 0.11
Nodes (17): anio, color, copyWith, fotoUrl, fromMap, idPropietario, idVehiculo, isPrimary (+9 more)

### Community 52 - "Reservation Provider"
Cohesion: 0.11
Nodes (17): aprobarTaller, cambiarRolUsuario, eliminarResenia, fetchLogs, fetchResenias, fetchTalleres, fetchUsuarios, _logAction (+9 more)

### Community 53 - "Alert Model"
Cohesion: 0.11
Nodes (17): cotizacionEstimada, descripcion, estado, fechaCreacion, fechaHoraConfirmada, fechaHoraPropuesta, fromMap, id (+9 more)

### Community 54 - "Conversation Model"
Cohesion: 0.18
Nodes (14): Point, Size, wchar_t, Scale(), Create, Destroy, UpdateTheme, Win32Window::Win32Window() (+6 more)

### Community 55 - "Vehicle Search Screen"
Cohesion: 0.12
Nodes (16): cloud_firestore, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, firebase_storage, flutter_local_notifications, Foundation (+8 more)

### Community 56 - "Service Record Model"
Cohesion: 0.12
Nodes (15): ../constants/firestore_collections.dart, dart:convert, baseUrl, fetchAllMakes, fetchModelsByMake, VehicleApiService, _apiKey, _baseUrl (+7 more)

### Community 57 - "Maintenance Config UI"
Cohesion: 0.12
Nodes (15): File?, _buildRoleCard, createState, dispose, _imageFile, _isLoading, _nameController, _notificationsEnabled (+7 more)

### Community 58 - "Maintenance Task Model"
Cohesion: 0.12
Nodes (16): ConversacionModel, estado, fromMap, id, idMecanico, idPropietario, idTaller, idVehiculo (+8 more)

### Community 59 - "Bottom Nav & Chat Cards"
Cohesion: 0.12
Nodes (16): actualizarEstadoCotizacion, actualizarMetadatosMensaje, buscarConversacion, ChatRepository, crearConversacion, crearCotizacion, deleteMensaje, enviarMensaje (+8 more)

### Community 60 - "Translation Service"
Cohesion: 0.12
Nodes (16): build, _buildInputCard, _costController, createState, currentKm, dispose, _infoItem, _isLoading (+8 more)

### Community 61 - "Firebase Plugins"
Cohesion: 0.12
Nodes (15): AndroidFlutterLocalNotificationsPlugin, FirebaseMessaging, _firebaseMessaging, initialize, _instance, _isInitialized, _localNotifications, NotificationService (+7 more)

### Community 62 - "App Button Widget"
Cohesion: 0.14
Nodes (14): Color, dart:math, build, ChatBackgroundPattern, color, paint, shouldRepaint, build (+6 more)

### Community 63 - "iOS Plugin Registry"
Cohesion: 0.12
Nodes (15): FirebaseStorage, addPhoto, deletePhoto, _firestore, fromMap, id, _storage, streamPhotos (+7 more)

### Community 64 - "Admin Log Model"
Cohesion: 0.14
Nodes (15): int?, LanguageProvider, build, maxLines, overflow, style, text, textAlign (+7 more)

### Community 65 - "Windows Console Setup"
Cohesion: 0.17
Nodes (12): main, main, main, build, ImagenChatCard, isMe, _showImageDialog, urlArchivo (+4 more)

### Community 66 - "Workshop Model"
Cohesion: 0.12
Nodes (15): AlertModel, AlertPriority, copyWith, descripcion, estado, fechaLimite, fromMap, idAlerta (+7 more)

### Community 67 - "Main Scaffold & Nav"
Cohesion: 0.18
Nodes (16): build, build, _navigateAfterAuth, _buildHeader, _buildNearbyServices, build, initState, Route /admin/dashboard (+8 more)

### Community 68 - "Auth Preferences Service"
Cohesion: 0.13
Nodes (15): _addUser, build, createState, dispose, _emailController, _firestore, initState, _isLoading (+7 more)

### Community 69 - "Auth Routes & Redirect"
Cohesion: 0.13
Nodes (13): unique_ptr, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM, FlutterWindow (+5 more)

### Community 70 - "Message Model"
Cohesion: 0.13
Nodes (14): ../../../../core/models/admin_log_model.dart, countCollection, deleteResenia, deleteTaller, deleteUsuario, _firestore, getLogs, getResenias (+6 more)

### Community 71 - "Review Service"
Cohesion: 0.13
Nodes (14): ../../../../core/models/vehicle_model.dart, addNote, addVehicle, _collection, deleteVehicle, _firestore, getExpenseSummary, getLastVisitedWorkshop (+6 more)

### Community 72 - "User Service"
Cohesion: 0.14
Nodes (13): bool get, Box, _apiKey, _baseUrl, initialize, _instance, isInitialized, translate (+5 more)

### Community 73 - "Vehicle Service (Data)"
Cohesion: 0.14
Nodes (13): fechaUltimoServicio, frecuenciaKm, frecuenciaMeses, fromMap, getStatus, getStatusLabel, id, MaintenanceStatus (+5 more)

### Community 74 - "Admin Auth Service"
Cohesion: 0.14
Nodes (13): copyWith, costo, descripcion, fecha, fotoFacturaUrl, fromMap, idServicio, idTaller (+5 more)

### Community 75 - "Review Model"
Cohesion: 0.19
Nodes (13): AdminDashboardScreen, _AdminDashboardScreenState, build, _buildActionChip, _buildMetricsGrid, _buildSectionTitle, _buildWelcomeHeader, createState (+5 more)

### Community 76 - "App Transitions"
Cohesion: 0.20
Nodes (14): RECT, OnCreate, OnDestroy, HWND, Win32Window, child_content_, GetClientArea, OnCreate (+6 more)

### Community 77 - "Translated Text Widget"
Cohesion: 0.15
Nodes (12): @pragma, _firebaseMessagingBackgroundHandler, initializeApp, main, package:autodoc/core/router/app_router.dart, package:autodoc/core/services/notification_service.dart, package:autodoc/features/admin/presentation/providers/admin_dashboard_provider.dart, package:autodoc/features/admin/presentation/providers/admin_provider.dart (+4 more)

### Community 78 - "Availability Picker"
Cohesion: 0.15
Nodes (12): CollectionReference, ../../../../core/models/review_model.dart, _firestore, getReviewsForTaller, getUserReviewForTaller, hasUserReviewedTaller, recalculateTallerRating, _resenias (+4 more)

### Community 79 - "Web App Manifest"
Cohesion: 0.15
Nodes (12): AppButton, AppButtonSize, AppButtonType, build, _handlePress, hapticFeedback, icon, isLoading (+4 more)

### Community 80 - "Workshop Admin Card"
Cohesion: 0.17
Nodes (12): AdminTalleresScreen, _AdminTalleresScreenState, build, _buildFilterChip, createState, _filterStatus, initState, _mostrarConfirmacion (+4 more)

### Community 81 - "App Card Widget"
Cohesion: 0.17
Nodes (12): AdminUsuariosScreen, _AdminUsuariosScreenState, build, _buildFilterChip, createState, _descRol, _filterRol, initState (+4 more)

### Community 82 - "Mechanic Admin Card"
Cohesion: 0.15
Nodes (12): CotizacionModel, descripcion, estado, fecha, fromMap, id, idMecanico, idPropietario (+4 more)

### Community 83 - "Admin Dashboard Provider"
Cohesion: 0.21
Nodes (7): GeneratedPluginRegistrant, FlutterEngine, FlutterLocalNotificationsPlugin, GeneratedPluginRegistrant, +registerWithRegistry, Keep, NSObject

### Community 84 - "Vehicle Image Service"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 85 - "Skeleton Loader Widget"
Cohesion: 0.17
Nodes (11): calificacionPromedio, copyWith, especialidad, estado, fromMap, idTaller, nombre, telefono (+3 more)

### Community 86 - "iOS Scene Setup"
Cohesion: 0.17
Nodes (11): activeIcon, child, colors, icon, InstagramBottomNavBar, isActive, isDark, MainScaffold (+3 more)

### Community 87 - "Theme Provider"
Cohesion: 0.17
Nodes (11): contenido, estado, fromMap, id, idRemitente, isDeleted, metadata, timestamp (+3 more)

### Community 88 - "App Shadows"
Cohesion: 0.23
Nodes (12): ChatScreen, _ChatScreenState, ServiceHistoryScreen, _ServiceHistoryScreenState, VehicleProfileScreen, _VehicleProfileScreenState, InitiateServiceScreen, _InitiateServiceScreenState (+4 more)

### Community 89 - "Firebase Options Config"
Cohesion: 0.18
Nodes (11): AboutScreen, _AboutScreenState, build, _buildNumber, createState, _initPackageInfo, initState, _launchUrl (+3 more)

### Community 90 - "iOS App Delegate"
Cohesion: 0.18
Nodes (10): CustomPainter, _ChatPatternPainter, build, ElSalvadorLicensePlate, height, paint, placa, shouldRepaint (+2 more)

### Community 91 - "NHTSA Car Models"
Cohesion: 0.18
Nodes (10): ../../data/services/admin_service.dart, AdminService, _adminService, dispose, _error, fetchMetrics, _isLoading, _metrics (+2 more)

### Community 92 - "Language Provider"
Cohesion: 0.18
Nodes (10): DateTime?, comentario, copyWith, estrellas, fechaResenia, fromMap, idResenia, idTaller (+2 more)

### Community 93 - "Vehicle API Service"
Cohesion: 0.18
Nodes (10): FirebaseAuth, AdminAuthService, _auth, _firestore, getAdminByUid, isAdmin, loginAsAdmin, _resolveUsernameToEmail (+2 more)

### Community 94 - "Dashboard Quick Actions"
Cohesion: 0.20
Nodes (10): FormState, build, CotizacionPicker, _CotizacionPickerState, createState, _descController, dispose, _formKey (+2 more)

### Community 95 - "Landing Screen"
Cohesion: 0.18
Nodes (10): accion, adminUid, detalle, fecha, fromMap, idLog, modulo, referenciaId (+2 more)

### Community 96 - "macOS Test Config"
Cohesion: 0.18
Nodes (10): accelerate, AppTransitions, decelerate, defaultCurve, fast, medium, slow, package:flutter/animation.dart (+2 more)

### Community 97 - "macOS App Delegate"
Cohesion: 0.18
Nodes (10): _buildHeader, _buildServiceTable, _buildSummary, generateServiceHistoryPdf, PdfGenerator, ../models/service_record_model.dart, ../models/vehicle_model.dart, package:pdf/pdf.dart (+2 more)

### Community 98 - "macOS Window Setup"
Cohesion: 0.20
Nodes (10): _availableTimes, build, createState, DisponibilidadPicker, _DisponibilidadPickerState, _focusedDay, initState, _selectedDay (+2 more)

### Community 99 - "LLDB Debug Scripts"
Cohesion: 0.18
Nodes (10): addFavoriteWorkshop, _collection, createUserData, _firestore, getUserData, removeFavoriteWorkshop, updateUserData, uploadProfilePhoto (+2 more)

### Community 100 - "Language Root Widget"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 101 - "Role Utilities"
Cohesion: 0.20
Nodes (9): @GenerateMocks, package:autodoc/core/services/vehicle_image_service.dart, package:autodoc/features/admin/data/services/admin_auth_service.dart, package:autodoc/features/auth/data/services/auth_service.dart, package:autodoc/features/dashboard/data/services/vehicle_service.dart, package:autodoc/features/profile/data/services/user_service.dart, package:firebase_storage/firebase_storage.dart, package:mockito/annotations.dart (+1 more)

### Community 102 - "Skeleton Layouts"
Cohesion: 0.20
Nodes (9): ../../../../core/models/workshop_model.dart, build, _buildInfoChip, _buildStatusChip, onAprobar, onRechazar, onSuspender, taller (+1 more)

### Community 103 - "Localizations Delegates"
Cohesion: 0.20
Nodes (9): dart:io, ../../data/services/vehicle_photo_service.dart, VehiclePhotoModel, colors, foto, FullScreenImageViewer, VehicleGalleryWidget, vehicleId (+1 more)

### Community 104 - "Community 104"
Cohesion: 0.20
Nodes (9): FirebaseFirestore, _firestore, getWorkshopById, getWorkshops, getWorkshopsStream, updateWorkshopProfile, WorkshopService, package:autodoc/core/constants/firestore_collections.dart (+1 more)

### Community 105 - "Community 105"
Cohesion: 0.20
Nodes (9): UserModel, build, calificacionPromedio, _chip, _info, MecanicoAdminCard, totalResenias, usuario (+1 more)

### Community 106 - "Community 106"
Cohesion: 0.22
Nodes (9): AdminLogsScreen, _AdminLogsScreenState, build, _buildTag, _colorForAction, createState, _iconForAction, initState (+1 more)

### Community 107 - "Community 107"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 108 - "Community 108"
Cohesion: 0.22
Nodes (8): ../../../../core/constants/firestore_collections.dart, actualizarEstadoReserva, crearReserva, _firestore, getReserva, ReservaRepository, streamReservasUsuario, ../models/reserva_model.dart

### Community 109 - "Community 109"
Cohesion: 0.22
Nodes (8): double?, AppSkeleton, borderRadius, build, card, height, width, package:shimmer/shimmer.dart

### Community 110 - "Community 110"
Cohesion: 0.22
Nodes (8): android, DefaultFirebaseOptions, ios, web, package:autodoc/config/secrets.dart, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 111 - "Community 111"
Cohesion: 0.25
Nodes (6): Any, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, UIApplication

### Community 112 - "Community 112"
Cohesion: 0.25
Nodes (7): ../../data/models/mensaje_model.dart, MensajeModel, build, colors, HistorialChatCard, isMe, mensaje

### Community 113 - "Community 113"
Cohesion: 0.29
Nodes (4): RunnerTests, RunnerTests, XCTest, XCTestCase

### Community 114 - "Community 114"
Cohesion: 0.25
Nodes (7): CarMake, CarModel, fromJson, makeId, makeName, modelId, modelName

### Community 115 - "Community 115"
Cohesion: 0.25
Nodes (7): changeLanguage, currentLanguageCode, _currentLocale, _loadLocale, Locale, Locale get, String get

### Community 116 - "Community 116"
Cohesion: 0.43
Nodes (7): AdminReseniasScreen, _AdminReseniasScreenState, build, createState, initState, _mostrarConfirmarEliminar, AdminProvider

### Community 117 - "Community 117"
Cohesion: 0.25
Nodes (7): build, conversacionId, CotizacionChatCard, isMe, mensajeId, metadata, package:autodoc/features/chat/presentation/providers/chat_provider.dart

### Community 118 - "Community 118"
Cohesion: 0.25
Nodes (7): build, LandingScreen, ../widgets/command_center_section.dart, ../widgets/hero_section.dart, ../widgets/landing_footer.dart, ../widgets/landing_header.dart, ../widgets/value_prop_section.dart

### Community 119 - "Community 119"
Cohesion: 0.29
Nodes (6): AppLocalizations get, BuildContext, AppColorsExtension, l10n, L10nExtension, package:autodoc/l10n/app_localizations.dart

### Community 120 - "Community 120"
Cohesion: 0.33
Nodes (5): Flutter, FlutterSceneDelegate, GoogleMaps, SceneDelegate, UIKit

### Community 121 - "Community 121"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 122 - "Community 122"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 123 - "Community 123"
Cohesion: 0.33
Nodes (5): admin, db, functions, messaging, storage

### Community 124 - "Community 124"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 125 - "Community 125"
Cohesion: 0.33
Nodes (6): _buildQuickActions, _buildRecentActivity, Route /admin/logs, Route /admin/resenias, Route /admin/talleres, Route /admin/usuarios

### Community 126 - "Community 126"
Cohesion: 0.33
Nodes (5): build, HistorialChatCard, isMe, metadata, package:intl/intl.dart

### Community 127 - "Community 127"
Cohesion: 0.40
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsEs, of, LocalizationsDelegate

### Community 128 - "Community 128"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 129 - "Community 129"
Cohesion: 0.40
Nodes (4): formatEditUpdate, PlateFormatter, package:flutter/services.dart, TextInputFormatter

## Knowledge Gaps
- **2370 isolated node(s):** `functions`, `admin`, `db`, `messaging`, `storage` (+2365 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UserSessionProvider` connect `Linux GTK Native` to `Admin Dashboard UI`, `Alerts & Vehicles Screen`, `Vehicle Registration Form`, `UI Radius & Spacing`, `Landing Page Widgets`, `Admin Provider Logic`, `Next.js App Shell`, `Vehicle Profile Screen`, `Main Screen Routes`, `Service Task UI`, `Review Sheet Widget`, `Reservation Model`, `Vehicle Provider Logic`, `Admin Service Methods`, `Maintenance Config UI`, `App Button Widget`, `Main Scaffold & Nav`, `Review Model`, `Workshop Admin Card`, `App Card Widget`, `iOS Scene Setup`, `App Shadows`, `Community 116`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `_buildQuickActions` connect `Community 125` to `Review Model`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `_FakeFirebaseApp_0` connect `Landing Command Center` to `Windows Desktop Native`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `functions`, `admin`, `db` to the rest of the system?**
  _2370 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Localization & i18n` be split into smaller, more focused modules?**
  _Cohesion score 0.005747126436781609 - nodes in this community are weakly interconnected._
- **Should `App Localizations EN` be split into smaller, more focused modules?**
  _Cohesion score 0.005952380952380952 - nodes in this community are weakly interconnected._
- **Should `App Localizations ES` be split into smaller, more focused modules?**
  _Cohesion score 0.005970149253731343 - nodes in this community are weakly interconnected._