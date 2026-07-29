import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/features/dashboard/data/services/workshop_service.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:autodoc/core/widgets/app_skeleton.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';

import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';

class WorkshopDirectoryScreen extends StatefulWidget {
  const WorkshopDirectoryScreen({super.key});

  @override
  State<WorkshopDirectoryScreen> createState() =>
      _WorkshopDirectoryScreenState();
}

class _WorkshopDirectoryScreenState extends State<WorkshopDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFavorites = false;
  bool _showMap = false;
  GoogleMapController? _mapController;
  Position? _userPosition;

  // Default center (El Salvador)
  static const LatLng _defaultCenter = LatLng(13.6929, -89.2182);

  // Filtros
  double? _minRating;
  double? _maxDistance;
  String? _specialty;
  final WorkshopService _workshopService = WorkshopService();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final filters = await _workshopService.loadFilters();
    setState(() {
      _minRating = filters['minRating'];
      _maxDistance = filters['maxDistance'];
      _specialty = filters['specialty'];
    });
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        setState(() {
          _userPosition = pos;
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
          );
        }
      }
    } catch (e) {
      debugPrint("Error requesting location permission: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      useGradient: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(colors, isDark),
            // Search Bar
            _buildSearchBar(colors, isDark),
            // Filters
            _buildFilters(colors, isDark),
            const SizedBox(height: 8),
            // Content: List or Map
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: WorkshopService().getWorkshopsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return AppSkeletonLayouts.workshopList();
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        context.l10n.wdErrorLoading,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                    );
                  }

                  var users = snapshot.data ?? [];
                  List<Map<String, dynamic>> items = [];

                  for (var user in users) {
                    final data = user.toMap();
                    double? distance;
                    final lat = user.latitud;
                    final lng = user.longitud;

                    if (_userPosition != null && lat != null && lng != null) {
                      final distInMeters = Geolocator.distanceBetween(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                        lat,
                        lng,
                      );
                      distance = distInMeters / 1000.0;
                    }

                    items.add({
                      'id': user.idUsuario,
                      'data': data,
                      'distance': distance,
                    });
                  }

                  // Sort: closer first
                  items.sort((a, b) {
                    final distA = a['distance'] as double?;
                    final distB = b['distance'] as double?;
                    if (distA != null && distB != null) {
                      return distA.compareTo(distB);
                    }
                    if (distA != null) return -1;
                    if (distB != null) return 1;
                    return 0;
                  });

                  if (_showFavorites) {
                    final usuario = context
                        .read<UserProfileProvider>()
                        .userData;
                    if (usuario != null) {
                      items = items
                          .where(
                            (item) =>
                                usuario.talleresFavoritos.contains(item['id']),
                          )
                          .toList();
                    }
                  }

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    items = items.where((item) {
                      final data = item['data'] as Map<String, dynamic>;
                      final name =
                          (data['nombre_completo'] as String?)?.toLowerCase() ??
                          '';
                      final spec =
                          (data['especialidad'] as String?)?.toLowerCase() ??
                          '';
                      return name.contains(q) || spec.contains(q);
                    }).toList();
                  }

                  // Advanced Filters
                  if (_minRating != null) {
                    items = items.where((item) {
                      final data = item['data'] as Map<String, dynamic>;
                      final rating =
                          data['calificacion_promedio']?.toDouble() ?? 5.0;
                      return rating >= _minRating!;
                    }).toList();
                  }
                  if (_maxDistance != null) {
                    items = items.where((item) {
                      final dist = item['distance'] as double?;
                      if (dist == null) return false;
                      return dist <= _maxDistance!;
                    }).toList();
                  }
                  if (_specialty != null && _specialty!.isNotEmpty) {
                    final q = _specialty!.toLowerCase();
                    items = items.where((item) {
                      final data = item['data'] as Map<String, dynamic>;
                      final spec =
                          (data['especialidad'] as String?)?.toLowerCase() ??
                          '';
                      return spec.contains(q);
                    }).toList();
                  }

                  if (_showMap) {
                    return _buildMapView(items, colors, isDark);
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: Responsive.iconSize(context, 48),
                            color: colors.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.wdNoWorkshopsFound,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: Responsive.fontSize(context, 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(
                      Responsive.padding(context, 16),
                    ).copyWith(bottom: 100),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildWorkshopCard(
                        tallerId: item['id'],
                        data: item['data'],
                        colors: colors,
                        isDark: isDark,
                        distance: item['distance'],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors, bool isDark) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: isDesktop ? null : BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: colors.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: isDesktop ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              onPressed: () => context.pop(),
            ),
            Text(
              context.l10n.wdTitle,
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
          ],
          // Toggle Map/List
          Container(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewToggle(Icons.list, !_showMap, colors.primary, isDark),
                _viewToggle(
                  Icons.map_outlined,
                  _showMap,
                  colors.primary,
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewToggle(IconData icon, bool isActive, Color primary, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _showMap = icon == Icons.map_outlined),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(Responsive.padding(context, 8)),
        decoration: BoxDecoration(
          color: isActive ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: Responsive.iconSize(context, 20),
          color: isActive
              ? Colors.white
              : (isDark ? Colors.white54 : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppColors colors, bool isDark) {
    return Padding(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AppTextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          hintText: context.l10n.wdSearchHint,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }

  Widget _buildFilters(AppColors colors, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 16),
      ),
      child: Row(
        children: [
          _buildFilterChip(
            'Todos',
            Icons.all_inclusive,
            !_showFavorites &&
                _minRating == null &&
                _maxDistance == null &&
                _specialty == null,
            () {
              setState(() {
                _showFavorites = false;
                _minRating = null;
                _maxDistance = null;
                _specialty = null;
              });
              _workshopService.saveFilters();
            },
            isDark,
            colors.textPrimary,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Favoritos',
            Icons.favorite,
            _showFavorites,
            () => setState(() => _showFavorites = true),
            isDark,
            colors.textPrimary,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Filtros Avanzados',
            Icons.tune,
            _minRating != null || _maxDistance != null || _specialty != null,
            _showFiltersSheet,
            isDark,
            colors.textPrimary,
          ),
        ],
      ),
    );
  }

  void _showFiltersSheet() {
    double tempRating = _minRating ?? 0.0;
    double tempDistance = _maxDistance ?? 50.0;
    String tempSpecialty = _specialty ?? '';
    final TextEditingController specController = TextEditingController(
      text: tempSpecialty,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = context.appColors;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(Responsive.padding(context, 20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtros Avanzados',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Calificación Mínima: ${tempRating > 0 ? tempRating.toStringAsFixed(1) : 'Cualquiera'}',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    Slider(
                      value: tempRating,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      activeColor: Colors.amber,
                      onChanged: (val) => setModalState(() => tempRating = val),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Distancia Máxima: ${tempDistance.toInt()} km',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    Slider(
                      value: tempDistance,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      activeColor: colors.primary,
                      onChanged: (val) =>
                          setModalState(() => tempDistance = val),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: specController,
                      label: 'Especialidad (ej. Frenos, Eléctrico)',
                      onChanged: (val) => tempSpecialty = val,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Aplicar Filtros',
                      onPressed: () {
                        setState(() {
                          _minRating = tempRating > 0 ? tempRating : null;
                          _maxDistance = tempDistance;
                          _specialty = tempSpecialty.trim().isNotEmpty
                              ? tempSpecialty.trim()
                              : null;
                        });
                        _workshopService.saveFilters(
                          minRating: _minRating,
                          maxDistance: _maxDistance,
                          specialty: _specialty ?? '',
                        );
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      text: 'Limpiar Filtros',
                      type: AppButtonType.secondary,
                      onPressed: () {
                        setState(() {
                          _minRating = null;
                          _maxDistance = null;
                          _specialty = null;
                        });
                        _workshopService.saveFilters(specialty: '');
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 16),
          vertical: Responsive.padding(context, 8),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.1))
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[200]!),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: Responsive.iconSize(context, 16),
              color: isSelected ? Colors.blue : textColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : textColor,
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: Responsive.iconSize(context, 16),
                color: textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ======= MAP VIEW =======
  Widget _buildMapView(
    List<Map<String, dynamic>> items,
    AppColors colors,
    bool isDark,
  ) {
    final markers = <Marker>{};

    // Marcador de la ubicación del usuario
    if (_userPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          infoWindow: InfoWindow(title: context.l10n.wdYourLocation),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      );
    }

    for (var item in items) {
      final data = item['data'] as Map<String, dynamic>;
      final lat = data['latitud']?.toDouble();
      final lng = data['longitud']?.toDouble();
      final name = data['nombre_completo'] ?? context.l10n.wdWorkshop;

      if (lat != null && lng != null) {
        final dist = item['distance'] as double?;
        final snippet = dist != null
            ? '${data['especialidad'] ?? context.l10n.wdMechanics} - ${context.l10n.wdDistanceKm(dist.toStringAsFixed(1))}'
            : data['especialidad'] ?? context.l10n.wdGeneralMechanics;

        markers.add(
          Marker(
            markerId: MarkerId(item['id']),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: name, snippet: snippet),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueViolet,
            ),
          ),
        );
      }
    }

    // Info card for workshops without coordinates
    final workshopsWithoutCoords = items.where((d) {
      final data = d['data'] as Map<String, dynamic>;
      return data['latitud'] == null || data['longitud'] == null;
    }).length;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _userPosition != null
                ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                : (markers.isNotEmpty
                      ? markers.first.position
                      : _defaultCenter),
            zoom: 12,
          ),
          markers: markers,
          onMapCreated: (controller) => _mapController = controller,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          style: isDark ? _darkMapStyle : null,
        ),
        // Floating info
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 14),
              vertical: Responsive.padding(context, 10),
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1B2E).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: colors.primary,
                  size: Responsive.iconSize(context, 18),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.wdWorkshopsOnMap(
                    (markers.length - (_userPosition != null ? 1 : 0))
                        .toString(),
                  ),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.fontSize(context, 13),
                    color: colors.textPrimary,
                  ),
                ),
                if (workshopsWithoutCoords > 0) ...[
                  const Spacer(),
                  Text(
                    context.l10n.wdNoLocationCount(
                      workshopsWithoutCoords.toString(),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: Responsive.fontSize(context, 11),
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Bottom list peek
        if (items.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 16),
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return _buildMapCard(item['data'], colors, isDark);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapCard(
    Map<String, dynamic> data,
    AppColors colors,
    bool isDark,
  ) {
    final name = data['nombre_completo'] ?? context.l10n.wdWorkshop;
    final spec = data['especialidad'] ?? context.l10n.wdGeneralMechanics;
    final rating = data['calificacion_promedio']?.toDouble() ?? 5.0;
    final location = data['ubicacion_municipio'] ?? '';

    return GestureDetector(
      onTap: () {
        final lat = data['latitud']?.toDouble();
        final lng = data['longitud']?.toDouble();
        if (lat != null && lng != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
          );
        }
      },
      child: SizedBox(
        width: 240,
        child: AppCard(
          margin: const EdgeInsets.only(right: 12),
          padding: EdgeInsets.all(Responsive.padding(context, 14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.fontSize(context, 14),
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 5),
                      vertical: Responsive.padding(context, 1),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: Responsive.iconSize(context, 12),
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 11),
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                spec,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: Responsive.iconSize(context, 13),
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 11),
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkshopCard({
    required String tallerId,
    required Map<String, dynamic> data,
    required AppColors colors,
    required bool isDark,
    double? distance,
  }) {
    final name = data['nombre_completo'] ?? context.l10n.wdNamelessWorkshop;
    final imageUrl = data['foto_url'] ?? data['foto_perfil_url'];
    final specialty = data['especialidad'] ?? context.l10n.wdGeneralMechanics;
    final rating = data['calificacion_promedio']?.toDouble() ?? 5.0;
    final reviewsCount = data['total_resenias'] ?? 0;
    final location =
        data['ubicacion_municipio'] ?? context.l10n.wdLocationNotSpecified;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => AppSkeleton.card(height: 160),
                      errorWidget: (ctx, url, err) => Icon(
                        Icons.build,
                        size: Responsive.iconSize(context, 48),
                        color: colors.textSecondary,
                      ),
                    )
                  : Icon(
                      Icons.build,
                      size: Responsive.iconSize(context, 48),
                      color: colors.textSecondary,
                    ),
            ),
            Padding(
              padding: EdgeInsets.all(Responsive.padding(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.fontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(context, 6),
                          vertical: Responsive.padding(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellow[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: Responsive.iconSize(context, 14),
                              color: Colors.yellow[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.bold,
                                color: Colors.yellow[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: Responsive.iconSize(context, 16),
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          context.l10n.wdSpecialtyIs(specialty),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: Responsive.fontSize(context, 14),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: Responsive.iconSize(context, 16),
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: Responsive.fontSize(context, 14),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.padding(context, 8),
                            vertical: Responsive.padding(context, 4),
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: Responsive.fontSize(context, 12),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[200]!,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reviewsCount == 1
                                  ? context.l10n.wdReviewCount(
                                      reviewsCount.toString(),
                                    )
                                  : context.l10n.wdReviewsCount(
                                      reviewsCount.toString(),
                                    ),
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => showReviewBottomSheet(
                                context,
                                tallerId: tallerId,
                                tallerNombre: name,
                              ),
                              icon: Icon(
                                Icons.star_outline,
                                size: Responsive.iconSize(context, 18),
                              ),
                              label: Text(context.l10n.wdReview),
                            ),
                            AppButton(
                              onPressed: () async {
                                final userSession = context
                                    .read<UserProfileProvider>();
                                final userId = userSession.userData?.idUsuario;
                                if (userId == null) return;

                                // The logged user is assuming the Propietario role in this case
                                // (Mechanics could also contact other mechanics theoretically, but usually this is Prop -> Mec)
                                final chatId = await context
                                    .read<ChatProvider>()
                                    .iniciarOCrearConversacion(
                                      idPropietario: userId,
                                      idMecanico:
                                          tallerId, // tallerId is the mechanic's UID
                                      nombrePropietario:
                                          userSession
                                              .userData
                                              ?.nombreCompleto ??
                                          'Propietario',
                                      nombreMecanico: name,
                                      idTaller: tallerId,
                                    );

                                if (chatId.isNotEmpty && mounted) {
                                  context.push('/chat/$chatId');
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Error al iniciar el chat',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              text: context.l10n.wdContact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const String _darkMapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]}
  ]''';
}
