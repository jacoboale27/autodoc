# Graph Report - .  (2026-07-28)

## Corpus Check
- Large corpus: 307 files · ~991,386 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 3641 nodes · 4996 edges · 151 communities (139 shown, 12 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 19 edges (avg confidence: 0.8)
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
- `LanguageProvider` --inherits--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/language_provider.dart → test/core/router/app_router_test.dart
- `NotificationCenterProvider` --inherits--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/notification_center_provider.dart → test/core/router/app_router_test.dart
- `ThemeProvider` --inherits--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/theme_provider.dart → test/core/router/app_router_test.dart
- `UserProfileProvider` --mixes_in--> `ChangeNotifier`  [EXTRACTED]
  lib/core/providers/user_profile_provider.dart → test/core/router/app_router_test.dart
- `FakeUserProfileProvider` --implements--> `UserProfileProvider`  [EXTRACTED]
  test/core/router/app_router_test.dart → lib/core/providers/user_profile_provider.dart

## Import Cycles
- None detected.

## Communities (151 total, 12 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.01
Nodes (365): app_localizations_en.dart, app_localizations_es.dart, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails (+357 more)

### Community 1 - "Community 1"
Cohesion: 0.01
Nodes (354): app_localizations.dart, addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle (+346 more)

### Community 2 - "Community 2"
Cohesion: 0.01
Nodes (353): addVehicleBrand, addVehicleBrandSubtitle, addVehicleCardExp, addVehicleColor, addVehicleColorHint, addVehicleDetails, addVehicleDetailsSubtitle, addVehicleDocs (+345 more)

### Community 3 - "Community 3"
Cohesion: 0.02
Nodes (93): Duration get, FirebaseApp get, FirebaseFirestore get, package:mockito/src/dummies.dart, R, Settings get, SnapshotMetadata get, add (+85 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (56): build, userId, VehiculoPicker, AlertsScreen, _AlertsScreenState, build, _buildAlertCard, _buildCompactActionButton (+48 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (50): DocumentSnapshot, UserProfileProvider, build, _canEdit, _checkExisting, _checking, _comentarioController, createState (+42 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (52): _adminRoutes, appRouterRedirect, createAppRouter, currentPath, currentUid, false, hasAttemptedFetch, _homeForRole (+44 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (50): AppColors get, AppPalette, copyWith, darkError, darkOnPrimary, darkOnSecondary, darkOutline, darkPrimary (+42 more)

### Community 8 - "Community 8"
Cohesion: 0.04
Nodes (44): ../../../../core/models/nhtsa_models.dart, ../../../../core/services/vehicle_api_service.dart, ../../../../core/theme/app_colors.dart, ../../../../core/utils/plate_formatter.dart, _allMakes, _anioController, _apiService, _brandSearchQuery (+36 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (43): ../../../../core/models/vehicle_model.dart, ../../../../core/services/vehicle_image_service.dart, ../../data/services/vehicle_service.dart, addNote, addVehicle, _collection, deleteVehicle, _firestore (+35 more)

### Community 10 - "Community 10"
Cohesion: 0.05
Nodes (42): eslint, eslint-config-next, framer-motion, dependencies, framer-motion, lucide-react, next, next-intl (+34 more)

### Community 11 - "Community 11"
Cohesion: 0.05
Nodes (37): dart:ui, AuthBackgroundBlobs, build, colors, isDark, _buildFeatureItem, _contents, createState (+29 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (33): main, main, AppShadows, darkLg, darkMd, darkSm, lightLg, lightMd (+25 more)

### Community 13 - "Community 13"
Cohesion: 0.06
Nodes (35): VehicleModel, _buildAlertsList, _buildCostoInput, _buildInvoicePicker, _buildKmInput, _buildMaintenanceTasks, _buildSectionTitle, _buildVehicleHeader (+27 more)

### Community 14 - "Community 14"
Cohesion: 0.05
Nodes (35): AppRadius, full, lg, md, sm, xl, xs, xxl (+27 more)

### Community 15 - "Community 15"
Cohesion: 0.06
Nodes (32): class, DateTimeRange?, AppSnackbar, show, SnackbarType, build, _buildEmptyState, _buildFilterTab (+24 more)

### Community 16 - "Community 16"
Cohesion: 0.07
Nodes (7): geistMono, geistSans, ThemeProvider(), Header(), Workshop, {Link, redirect, usePathname, useRouter, getPathname}, routing

### Community 17 - "Community 17"
Cohesion: 0.07
Nodes (31): ../../helpers/test_helpers.mocks.dart, AppNotification, body, copyWith, deepLink, fromFirestore, fromMap, id (+23 more)

### Community 18 - "Community 18"
Cohesion: 0.06
Nodes (30): GoogleMapController?, _buildFilterChip, _buildFilters, _buildHeader, _buildMapCard, _buildMapView, _buildSearchBar, _buildWorkshopCard (+22 more)

### Community 19 - "Community 19"
Cohesion: 0.06
Nodes (30): compilerOptions, allowJs, esModuleInterop, incremental, isolatedModules, jsx, lib, module (+22 more)

### Community 20 - "Community 20"
Cohesion: 0.07
Nodes (29): @pragma, GoRouter, authProvider, authSessionProvider, checkAndFetchProfile, createState, dispose, _firebaseMessagingBackgroundHandler (+21 more)

### Community 21 - "Community 21"
Cohesion: 0.07
Nodes (28): ../../../../core/utils/role_utils.dart, _adminService, aprobarTaller, cambiarRolUsuario, clearMessages, eliminarResenia, _error, fetchAllData (+20 more)

### Community 22 - "Community 22"
Cohesion: 0.10
Nodes (27): FormState, AnimatedCounter, _AnimatedCounterState, build, CotizacionPicker, _CotizacionPickerState, createState, _descController (+19 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (23): build, currentIndex, build, ServicesTrendChart, serviciosPorMes, AuthLogoSection, build, colors (+15 more)

### Community 24 - "Community 24"
Cohesion: 0.09
Nodes (27): build, _buildMessageContent, ChatScreen, _ChatScreenState, _controller, conversacionId, createState, dispose (+19 more)

### Community 25 - "Community 25"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 26 - "Community 26"
Cohesion: 0.08
Nodes (26): _abrirSelectorMapa, _buildCoordinatesPicker, _buildDropdownField, _buildInputField, _buildTopBar, createState, dispose, _elSalvadorDivipola (+18 more)

### Community 27 - "Community 27"
Cohesion: 0.08
Nodes (25): _authPreferences, AuthScreen, _AuthScreenState, build, _buildGlassCard, _buildTextField, createState, dispose (+17 more)

### Community 28 - "Community 28"
Cohesion: 0.08
Nodes (24): ../../data/models/conversacion_model.dart, ../../data/models/cotizacion_model.dart, ../../data/repositories/chat_repository.dart, actualizarEstadoCotizacion, actualizarMetadatosMensaje, _chatRepository, _conversaciones, _conversacionesSub (+16 more)

### Community 29 - "Community 29"
Cohesion: 0.08
Nodes (23): ../../data/services/vehicle_photo_service.dart, FirebaseStorage, addPhoto, deletePhoto, _firestore, fromMap, id, _storage (+15 more)

### Community 30 - "Community 30"
Cohesion: 0.09
Nodes (22): bool get, dart:async, ../../data/models/reserva_model.dart, ../../data/repositories/reserva_repository.dart, ../../data/services/admin_service.dart, _adminService, dispose, _error (+14 more)

### Community 31 - "Community 31"
Cohesion: 0.09
Nodes (22): dart:typed_data, build, HistorialChatCard, isMe, metadata, build, _buildInputCard, _costController (+14 more)

### Community 32 - "Community 32"
Cohesion: 0.10
Nodes (22): AppBottomNavBar, AppButton, AppTextField, AppTopNavBar, icon, isActive, onTap, title (+14 more)

### Community 33 - "Community 33"
Cohesion: 0.09
Nodes (20): ../constants/firestore_collections.dart, dart:convert, facturas, perfiles, StoragePaths, baseUrl, fetchAllMakes, fetchModelsByMake (+12 more)

### Community 34 - "Community 34"
Cohesion: 0.09
Nodes (22): firebase-functions, dependencies, firebase-admin, firebase-functions, @google-cloud/firestore, @google-cloud/functions-framework, description, engines (+14 more)

### Community 35 - "Community 35"
Cohesion: 0.09
Nodes (21): FirebaseFirestore, _firestore, getWorkshopById, getWorkshops, getWorkshopsStream, loadFilters, saveFilters, updateWorkshopProfile (+13 more)

### Community 36 - "Community 36"
Cohesion: 0.09
Nodes (20): action, AppEmptyState, build, description, icon, lottieAsset, title, appBar (+12 more)

### Community 37 - "Community 37"
Cohesion: 0.09
Nodes (22): _buildActionButton, _buildDetailItem, _buildDocumentationStatus, _buildDocumentationStatusItem, _buildExpenseSummary, _buildHeader, _buildHeroImage, _buildStatusAlert (+14 more)

### Community 38 - "Community 38"
Cohesion: 0.09
Nodes (22): _i10.VehicleService, _i12.VehicleImageService, _i14.UserService, _i1.Mock, _i3.FirebaseFirestore, _i3.Query, _i3.QuerySnapshot, _i5.FirebaseStorage (+14 more)

### Community 39 - "Community 39"
Cohesion: 0.10
Nodes (21): _i1.SmartFake, _i2.FirebaseApp, _i3.AggregateQuery, _i3.DocumentReference, _i3.LoadBundleTask, _i3.PipelineSource, _i3.Settings, _i3.SnapshotMetadata (+13 more)

### Community 40 - "Community 40"
Cohesion: 0.10
Nodes (17): main, showErrorSnackbar, showInfoSnackbar, showSuccessSnackbar, UiUtils, AppSkeletonLayouts, dashboard, listCards (+9 more)

### Community 41 - "Community 41"
Cohesion: 0.10
Nodes (20): AppSecrets, firebaseAndroidApiKey, firebaseAppIdAndroid, firebaseAppIdIos, firebaseAppIdWeb, firebaseAuthDomain, firebaseDatabaseUrl, firebaseIosApiKey (+12 more)

### Community 42 - "Community 42"
Cohesion: 0.10
Nodes (19): clearError, currentUid, _error, isLoggedIn, refreshUser, _user, Mock, package:autodoc/features/auth/presentation/providers/auth_provider.dart (+11 more)

### Community 43 - "Community 43"
Cohesion: 0.10
Nodes (20): activeAlerts, _addOrUpdateLocalAlert, _alerts, completeAlert, createDefaultTasks, _defaultTasks, _error, fetchAlerts (+12 more)

### Community 44 - "Community 44"
Cohesion: 0.10
Nodes (20): _buildActionOption, _buildAppBar, _buildInfoField, _buildInfoSection, _buildProfileHeader, _buildStaticField, _buildThemeOption, createState (+12 more)

### Community 45 - "Community 45"
Cohesion: 0.10
Nodes (19): copyWith, correo, departamento, especialidad, estado, fcmToken, fechaRegistro, fotoPerfilUrl (+11 more)

### Community 46 - "Community 46"
Cohesion: 0.10
Nodes (19): anio, color, copyWith, fotoUrl, fromJson, fromMap, idPropietario, idVehiculo (+11 more)

### Community 47 - "Community 47"
Cohesion: 0.11
Nodes (17): BoxFit, double?, AppSkeleton, borderRadius, build, card, height, width (+9 more)

### Community 48 - "Community 48"
Cohesion: 0.11
Nodes (18): class FakeAuthSessionProvider extends, class FakeUserProfileProvider extends, package:autodoc/core/router/app_router.dart, clearError, clearUserData, _currentUid, error, fetchedUserId (+10 more)

### Community 49 - "Community 49"
Cohesion: 0.11
Nodes (18): GoogleSignIn, _auth, AuthService, deleteAccount, _googleSignIn, _handleAuthException, isCurrentUserEmailVerified, registerWithEmail (+10 more)

### Community 50 - "Community 50"
Cohesion: 0.11
Nodes (18): _adminAuthService, _authService, clearError, deleteAccount, _error, isEmailPasswordUser, _isLoading, refreshEmailVerificationStatus (+10 more)

### Community 51 - "Community 51"
Cohesion: 0.11
Nodes (17): Animation, AnimationController, Duration, _animation, build, _controller, createState, didUpdateWidget (+9 more)

### Community 52 - "Community 52"
Cohesion: 0.11
Nodes (17): cloud_firestore, file_selector_macos, firebase_auth, firebase_core, firebase_crashlytics, firebase_messaging, firebase_storage, flutter_local_notifications (+9 more)

### Community 53 - "Community 53"
Cohesion: 0.11
Nodes (16): CustomPainter, dart:math, build, ChatBackgroundPattern, _ChatPatternPainter, color, paint, shouldRepaint (+8 more)

### Community 54 - "Community 54"
Cohesion: 0.11
Nodes (16): UserModel, AccountRow, build, isCurrentAdmin, onCambiarRol, onReactivar, onSuspender, usuario (+8 more)

### Community 55 - "Community 55"
Cohesion: 0.11
Nodes (17): aprobarTaller, cambiarRolUsuario, eliminarResenia, fetchLogs, fetchResenias, fetchTalleres, fetchUsuarios, _logAction (+9 more)

### Community 56 - "Community 56"
Cohesion: 0.11
Nodes (17): cotizacionEstimada, descripcion, estado, fechaCreacion, fechaHoraConfirmada, fechaHoraPropuesta, fromMap, id (+9 more)

### Community 57 - "Community 57"
Cohesion: 0.18
Nodes (14): Point, Size, wchar_t, Scale(), Create, Destroy, UpdateTheme, Win32Window::Win32Window() (+6 more)

### Community 58 - "Community 58"
Cohesion: 0.12
Nodes (16): ../../../../core/models/admin_log_model.dart, AdminRepository, countCollection, deleteResenia, deleteTaller, deleteUsuario, _firestore, getLogs (+8 more)

### Community 59 - "Community 59"
Cohesion: 0.12
Nodes (16): build, controller, hintText, inputFormatters, keyboardType, label, maxLines, obscureText (+8 more)

### Community 60 - "Community 60"
Cohesion: 0.12
Nodes (16): AdminService, package:autodoc/core/models/admin_log_model.dart, package:autodoc/features/admin/data/repositories/admin_repository.dart, package:autodoc/features/admin/data/services/admin_service.dart, adminService, fakeRepository, lastLog, lastUpdatedEstado (+8 more)

### Community 61 - "Community 61"
Cohesion: 0.15
Nodes (17): _buildGoogleButton, _buildSubmitButton, _handleEmailRegister, _showForgotPasswordDialog, AuthProvider, _showDeleteConfirmationDialog, _signOut, _signOut (+9 more)

### Community 62 - "Community 62"
Cohesion: 0.12
Nodes (16): ConversacionModel, estado, fromMap, id, idMecanico, idPropietario, idTaller, idVehiculo (+8 more)

### Community 63 - "Community 63"
Cohesion: 0.12
Nodes (16): build, _buildDashboardMetrics, _buildIncomeChartSection, _buildMetricCard, _buildQuickActions, _buildRecentServices, _buildServiceTile, _buildTopBar (+8 more)

### Community 64 - "Community 64"
Cohesion: 0.13
Nodes (16): build, _buildAssistantCard, _buildRecentItem, _buildRecentSearches, _buildSearchCard, _buildTopBar, createState, _formatPlate (+8 more)

### Community 65 - "Community 65"
Cohesion: 0.12
Nodes (14): Color, IconData, AppStatusBadge, AppStatusType, build, icon, text, type (+6 more)

### Community 66 - "Community 66"
Cohesion: 0.12
Nodes (15): dart:io, FirebaseMessaging, _firebaseMessaging, initialize, _instance, _isInitialized, _localNotifications, NotificationService (+7 more)

### Community 67 - "Community 67"
Cohesion: 0.13
Nodes (14): ../../data/models/mensaje_model.dart, AppColors, AuthBottomNav, build, _buildNavAction, colors, isDark, MensajeModel (+6 more)

### Community 68 - "Community 68"
Cohesion: 0.12
Nodes (15): AlertModel, AlertPriority, copyWith, descripcion, estado, fechaLimite, fromMap, idAlerta (+7 more)

### Community 69 - "Community 69"
Cohesion: 0.12
Nodes (15): actualizarEstadoCotizacion, actualizarMetadatosMensaje, buscarConversacion, crearConversacion, crearCotizacion, deleteMensaje, enviarMensaje, _firestore (+7 more)

### Community 70 - "Community 70"
Cohesion: 0.13
Nodes (15): _addUser, build, createState, dispose, _emailController, _firestore, initState, _isLoading (+7 more)

### Community 71 - "Community 71"
Cohesion: 0.13
Nodes (13): unique_ptr, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM, FlutterWindow (+5 more)

### Community 72 - "Community 72"
Cohesion: 0.15
Nodes (14): int?, LanguageProvider, build, maxLines, overflow, style, text, textAlign (+6 more)

### Community 73 - "Community 73"
Cohesion: 0.13
Nodes (12): _loadTheme, setThemeMode, _themeKey, _themeMode, toggleTheme, package:autodoc/core/providers/language_provider.dart, package:autodoc/core/providers/theme_provider.dart, package:shared_preferences/shared_preferences.dart (+4 more)

### Community 74 - "Community 74"
Cohesion: 0.17
Nodes (15): build, build, _buildActiveAlerts, _buildHeader, _buildNearbyServices, _buildQuickActions, build, Route /alerts (+7 more)

### Community 75 - "Community 75"
Cohesion: 0.14
Nodes (14): AdminLogsScreen, _AdminLogsScreenState, _buildTag, _colorForAction, createState, _filterDateFrom, _filterDateTo, _filteredLogs (+6 more)

### Community 76 - "Community 76"
Cohesion: 0.18
Nodes (14): build, _exportToCsv, initState, AdminReseniasScreen, _AdminReseniasScreenState, build, createState, initState (+6 more)

### Community 77 - "Community 77"
Cohesion: 0.14
Nodes (14): AdminUsuariosScreen, _AdminUsuariosScreenState, _buildFilterChip, createState, _descRol, _filterDateFrom, _filterEstado, _filterRol (+6 more)

### Community 78 - "Community 78"
Cohesion: 0.14
Nodes (14): build, createState, dispose, initState, _isLoading, _kmController, _monthsController, _presetChip (+6 more)

### Community 79 - "Community 79"
Cohesion: 0.13
Nodes (14): automotive, utilities, background_color, categories, description, display, icons, name (+6 more)

### Community 80 - "Community 80"
Cohesion: 0.14
Nodes (13): CollectionReference, ../../../../core/models/review_model.dart, _firestore, getReviewsForTaller, getUserReviewForTaller, hasUserReviewedTaller, recalculateTallerRating, reportReview (+5 more)

### Community 81 - "Community 81"
Cohesion: 0.14
Nodes (13): @firebase/rules-unit-testing, mocha, dependencies, firebase-admin, @firebase/rules-unit-testing, mocha, description, firebase-admin (+5 more)

### Community 82 - "Community 82"
Cohesion: 0.14
Nodes (13): int get, deleteNotification, dispose, _error, _firestore, hasUnread, initialize, _isLoading (+5 more)

### Community 83 - "Community 83"
Cohesion: 0.14
Nodes (13): adminLogs, alertas, conversaciones, FirestoreCollections, historialMantenimientos, mantenimientos, mensajes, resenias (+5 more)

### Community 84 - "Community 84"
Cohesion: 0.14
Nodes (13): fechaUltimoServicio, frecuenciaKm, frecuenciaMeses, fromMap, getStatus, getStatusLabel, id, MaintenanceStatus (+5 more)

### Community 85 - "Community 85"
Cohesion: 0.14
Nodes (13): copyWith, costo, descripcion, fecha, fotoFacturaUrl, fromMap, idServicio, idTaller (+5 more)

### Community 86 - "Community 86"
Cohesion: 0.14
Nodes (13): clearUserData, _error, _fetchedUserId, fetchUserData, _hasAttemptedFetch, hasAttemptedFetchFor, _isLoading, _setError (+5 more)

### Community 87 - "Community 87"
Cohesion: 0.19
Nodes (13): AdminDashboardScreen, _AdminDashboardScreenState, build, _buildActionChip, _buildMetricsGrid, _buildSectionTitle, _buildWelcomeHeader, createState (+5 more)

### Community 88 - "Community 88"
Cohesion: 0.20
Nodes (14): RECT, OnCreate, OnDestroy, HWND, Win32Window, child_content_, GetClientArea, OnCreate (+6 more)

### Community 89 - "Community 89"
Cohesion: 0.15
Nodes (12): Box, _apiKey, _baseUrl, initialize, _instance, isInitialized, translate, translateSync (+4 more)

### Community 90 - "Community 90"
Cohesion: 0.15
Nodes (11): EdgeInsetsGeometry, AppCard, build, child, margin, onTap, padding, package:autodoc/core/theme/app_radius.dart (+3 more)

### Community 91 - "Community 91"
Cohesion: 0.15
Nodes (12): CotizacionModel, descripcion, estado, fecha, fromMap, id, idMecanico, idPropietario (+4 more)

### Community 92 - "Community 92"
Cohesion: 0.18
Nodes (12): _mostrarMenuAdjuntos, _cambiarEstado, ReservaProvider, build, conversacionId, isMe, mensajeId, metadata (+4 more)

### Community 93 - "Community 93"
Cohesion: 0.21
Nodes (7): GeneratedPluginRegistrant, FlutterEngine, FlutterLocalNotificationsPlugin, GeneratedPluginRegistrant, +registerWithRegistry, Keep, NSObject

### Community 94 - "Community 94"
Cohesion: 0.17
Nodes (11): DateTime?, accion, AdminLogModel, adminUid, detalle, fecha, fromMap, idLog (+3 more)

### Community 95 - "Community 95"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 96 - "Community 96"
Cohesion: 0.17
Nodes (11): comentario, copyWith, estrellas, fechaResenia, fromMap, idResenia, idTaller, idUsuario (+3 more)

### Community 97 - "Community 97"
Cohesion: 0.17
Nodes (11): calificacionPromedio, copyWith, especialidad, estado, fromMap, idTaller, nombre, telefono (+3 more)

### Community 98 - "Community 98"
Cohesion: 0.23
Nodes (11): AuthSessionProvider, build, _buildEmptyState, ConversacionesListScreen, _ConversacionesListScreenState, createState, initState, package:autodoc/features/chat/presentation/providers/chat_provider.dart (+3 more)

### Community 99 - "Community 99"
Cohesion: 0.17
Nodes (11): AppButtonSize, AppButtonType, build, _handlePress, hapticFeedback, icon, isLoading, onPressed (+3 more)

### Community 100 - "Community 100"
Cohesion: 0.17
Nodes (10): AdminSeedScreen, build, android, DefaultFirebaseOptions, ios, web, package:autodoc/config/secrets.dart, package:firebase_core/firebase_core.dart (+2 more)

### Community 101 - "Community 101"
Cohesion: 0.18
Nodes (11): AdminTalleresScreen, _AdminTalleresScreenState, build, _buildFilterChip, createState, _filterStatus, initState, _mostrarConfirmacion (+3 more)

### Community 102 - "Community 102"
Cohesion: 0.17
Nodes (11): AuthPreferencesService, clearSavedCredentials, getRememberMe, getSavedEmail, isOnboardingCompleted, _keyOnboardingCompleted, _keyRememberMe, _keySavedEmail (+3 more)

### Community 103 - "Community 103"
Cohesion: 0.17
Nodes (11): contenido, estado, fromMap, id, idRemitente, isDeleted, metadata, timestamp (+3 more)

### Community 104 - "Community 104"
Cohesion: 0.18
Nodes (11): AboutScreen, _AboutScreenState, build, _buildNumber, createState, _initPackageInfo, initState, _launchUrl (+3 more)

### Community 105 - "Community 105"
Cohesion: 0.18
Nodes (10): ../../../../core/models/user_model.dart, FirebaseAuth, AdminAuthService, _auth, _firestore, getAdminByUid, isAdmin, loginAsAdmin (+2 more)

### Community 106 - "Community 106"
Cohesion: 0.22
Nodes (10): ThemeProvider, build, _scanQR, build, build, _buildNavItem, MechanicSidebar, _navigate (+2 more)

### Community 107 - "Community 107"
Cohesion: 0.18
Nodes (10): accelerate, AppTransitions, decelerate, defaultCurve, fast, medium, slow, package:flutter/animation.dart (+2 more)

### Community 108 - "Community 108"
Cohesion: 0.18
Nodes (10): _buildHeader, _buildServiceTable, _buildSummary, generateServiceHistoryPdf, PdfGenerator, ../models/service_record_model.dart, ../models/vehicle_model.dart, package:pdf/pdf.dart (+2 more)

### Community 109 - "Community 109"
Cohesion: 0.20
Nodes (10): _availableTimes, build, createState, DisponibilidadPicker, _DisponibilidadPickerState, _focusedDay, initState, _selectedDay (+2 more)

### Community 110 - "Community 110"
Cohesion: 0.20
Nodes (9): @GenerateMocks, package:autodoc/core/services/vehicle_image_service.dart, package:autodoc/features/admin/data/services/admin_auth_service.dart, package:autodoc/features/auth/data/services/auth_service.dart, package:autodoc/features/dashboard/data/services/vehicle_service.dart, package:autodoc/features/profile/data/services/user_service.dart, package:firebase_storage/firebase_storage.dart, package:mockito/annotations.dart (+1 more)

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
Cohesion: 0.22
Nodes (8): ChatRepository, package:autodoc/features/chat/data/models/conversacion_model.dart, package:autodoc/features/chat/data/models/cotizacion_model.dart, package:autodoc/features/chat/data/models/mensaje_model.dart, package:autodoc/features/chat/data/repositories/chat_repository.dart, chatProvider, main, MockChatRepository

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

## Knowledge Gaps
- **2577 isolated node(s):** `functions`, `admin`, `firestore`, `db`, `messaging` (+2572 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UserProfileProvider` connect `Community 5` to `Community 4`, `Community 11`, `Community 13`, `Community 15`, `Community 17`, `Community 18`, `Community 20`, `Community 22`, `Community 24`, `Community 26`, `Community 32`, `Community 44`, `Community 61`, `Community 63`, `Community 64`, `Community 74`, `Community 76`, `Community 77`, `Community 86`, `Community 87`, `Community 98`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `WorkshopModel` connect `Community 97` to `Community 112`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `AdminProvider` connect `Community 76` to `Community 98`, `Community 101`, `Community 75`, `Community 77`, `Community 21`, `Community 87`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `functions`, `admin`, `firestore` to the rest of the system?**
  _2577 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.00546448087431694 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.005633802816901409 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.005649717514124294 - nodes in this community are weakly interconnected._